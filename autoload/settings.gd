extends Node
## Player preferences (autoloaded as "Settings"), saved to user://settings.cfg.
##
## Owns the audio buses too: "Music" and "SFX" are created here at startup, so
## every other script can route sound to them by name without a bus layout file.

signal changed

const DesktopShortcut := preload("res://autoload/desktop_shortcut.gd")

const PATH := "user://settings.cfg"
## Layout of the settings file. Version 2 made fullscreen the default: an older
## file only ever recorded the old windowed default, so its value is not kept.
const VERSION := 2
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

## 0..1 slider positions; 0 mutes the bus.
var music_volume: float = 0.7
var sfx_volume: float = 0.9
## The game opens covering the whole screen; F11 or the settings panel switch
## it to a window.
var fullscreen: bool = true
## Whether this player has been given a desktop shortcut yet, and the file that
## shortcut starts ("" when the one on the desktop is not the game's to change).
var shortcut_offered: bool = false
var shortcut_target: String = ""
## A run started with WINDOW_FLAG stays in a window whatever the saved setting
## says, without changing that setting: tools and capture runs rely on it. (The
## engine's own -w switch loses to the project's fullscreen start.)
const WINDOW_FLAG := "--windowed"
var _window_forced: bool = false
## Camera shake on hits and knock-outs.
var screen_shake: bool = true
## Lives each fighter starts a match with.
var stocks: int = 3
## How well the CPU plays in one-player matches: 0 easy, 1 normal, 2 hard.
var cpu_level: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load()
	# A user argument: godot --path . -- --windowed
	_window_forced = OS.get_cmdline_user_args().has(WINDOW_FLAG)
	apply()
	if not fullscreen or _window_forced:
		_fit_window_to_screen()
	_offer_desktop_shortcut()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F11:
		fullscreen = not fullscreen
		apply()
		save()


## A window that fills the screen or hangs off it (one that has just left
## fullscreen, or the default size on a small display) goes back to the
## default window size, shrunk to fit if needed, and is centred.
func _fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var window := DisplayServer.window_get_size()
	if window.x <= screen.size.x * 0.96 and window.y <= screen.size.y * 0.96:
		return
	var wanted := Vector2(
			ProjectSettings.get_setting("display/window/size/window_width_override"),
			ProjectSettings.get_setting("display/window/size/window_height_override"))
	var shrink := minf(1.0, minf(screen.size.x * 0.9 / wanted.x, screen.size.y * 0.9 / wanted.y))
	var fitted := Vector2i(wanted * shrink)
	DisplayServer.window_set_size(fitted)
	DisplayServer.window_set_position(screen.position + (screen.size - fitted) / 2)


## Pushes the current values into the engine (bus volumes, window mode).
func apply() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)
	_apply_window_mode()
	changed.emit()


## Switches between fullscreen and a window only when the setting changed, so
## a window the player resized or maximised is left as it is.
func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wanted := fullscreen and not _window_forced
	var mode := DisplayServer.window_get_mode()
	var is_full := (mode == DisplayServer.WINDOW_MODE_FULLSCREEN
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if is_full == wanted:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if wanted
			else DisplayServer.WINDOW_MODE_WINDOWED)
	if not wanted:
		_fit_window_to_screen()


## A released build puts its own shortcut on the desktop the first time it
## runs, and repoints that shortcut when the game has since moved to another
## file. Any run makes one when started with DesktopShortcut.FLAG.
func _offer_desktop_shortcut() -> void:
	if not DesktopShortcut.supported():
		return
	var released := OS.has_feature("template")
	var program := OS.get_executable_path()
	var first := released and not shortcut_offered
	var wanted := OS.get_cmdline_user_args().has(DesktopShortcut.FLAG)
	if not wanted and released:
		wanted = DesktopShortcut.is_due(shortcut_offered, shortcut_target, program,
				DesktopShortcut.exists())
	if wanted and DesktopShortcut.make():
		# A shortcut asked for from a source run is the developer's own to keep.
		shortcut_target = program if released else ""
	if wanted or first:
		shortcut_offered = true
		save()


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("meta", "version", VERSION)
	file.set_value("shortcut", "offered", shortcut_offered)
	file.set_value("shortcut", "target", shortcut_target)
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("video", "fullscreen", fullscreen)
	file.set_value("video", "screen_shake", screen_shake)
	file.set_value("match", "stocks", stocks)
	file.set_value("match", "cpu_level", cpu_level)
	file.save(PATH)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	music_volume = clampf(file.get_value("audio", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(file.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)
	if int(file.get_value("meta", "version", 1)) >= 2:
		fullscreen = bool(file.get_value("video", "fullscreen", fullscreen))
	shortcut_offered = bool(file.get_value("shortcut", "offered", shortcut_offered))
	shortcut_target = str(file.get_value("shortcut", "target", shortcut_target))
	screen_shake = bool(file.get_value("video", "screen_shake", screen_shake))
	stocks = clampi(int(file.get_value("match", "stocks", stocks)), 1, 9)
	cpu_level = clampi(int(file.get_value("match", "cpu_level", cpu_level)), 0, 2)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


func _set_bus_volume(bus: StringName, slider: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, slider <= 0.001)
	# Squaring the slider gives an even-feeling loudness ramp.
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, slider * slider)))
