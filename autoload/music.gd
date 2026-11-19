extends Node
## Background music (autoloaded as "Music"). One track plays across the whole
## session, so moving between menus and a match never restarts it. In the menus
## it is muffled behind a low-pass filter and turned down; in a match the filter
## opens up and the track plays at full strength.

const TRACK := preload("res://assets/audio/music/Clavar La Espada.mp3")
## Filter cutoff in menus (Hz); the battle value is effectively "no filter".
const MENU_CUTOFF := 900.0
const BATTLE_CUTOFF := 20500.0
const MENU_DB := -9.0
const BATTLE_DB := -3.0

## Toggled with the "7" key from anywhere, and by the pause-menu switch.
var enabled: bool = true

var _player: AudioStreamPlayer
var _filter: AudioEffectLowPassFilter
var _tween: Tween
## Headless runs (tests, CI) never start playback.
var _silent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	if _silent:
		return
	_player = AudioStreamPlayer.new()
	_player.bus = Settings.MUSIC_BUS
	var stream: AudioStreamMP3 = TRACK
	stream.loop = true
	_player.stream = stream
	_player.volume_db = MENU_DB
	add_child(_player)

	_filter = AudioEffectLowPassFilter.new()
	_filter.cutoff_hz = MENU_CUTOFF
	AudioServer.add_bus_effect(AudioServer.get_bus_index(Settings.MUSIC_BUS), _filter)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_7:
		set_enabled(not enabled)


## Muffled and quiet: title, character select, map select, pause, results.
func menu_mode(fade: float = 0.6) -> void:
	_glide(MENU_CUTOFF, MENU_DB, fade)


## Full and bright: the fight itself.
func battle_mode(fade: float = 0.5) -> void:
	_glide(BATTLE_CUTOFF, BATTLE_DB, fade)


func set_enabled(on: bool) -> void:
	enabled = on
	if _silent:
		return
	_player.stream_paused = not on
	if on and not _player.playing:
		_player.play()


func _glide(cutoff: float, volume_db: float, fade: float) -> void:
	if _silent:
		return
	if enabled and not _player.playing:
		_player.play()
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	# Hearing is logarithmic in pitch, so the cutoff glides exponentially.
	_tween.tween_method(func(v: float): _filter.cutoff_hz = exp(v),
			log(_filter.cutoff_hz), log(cutoff), fade)
	_tween.tween_property(_player, "volume_db", volume_db, fade)
