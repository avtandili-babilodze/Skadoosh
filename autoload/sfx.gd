extends Node
## Sound effects (autoloaded as "Sfx"). Call Sfx.play("hit_heavy") from anywhere.
##
## Sounds live in assets/audio/sfx/, built from recorded CC0 sources by
## tools/build_sfx.py. A sound may have variants (hit_heavy_1.ogg,
## hit_heavy_2.ogg, ...): each play picks one at random, never the same one twice
## in a row, and nudges the pitch, so repeated hits never sound machine-stamped.
## A small pool of players lets sounds overlap.

const FOLDER := "res://assets/audio/sfx/"
const NAMES := [
	"hit_light", "hit_heavy", "hit_blade_light", "hit_blade_heavy",
	"hit_fire", "hit_water", "hit_magic",
	"swing_light", "swing_heavy", "blade_light", "blade_heavy",
	"claw_light", "claw_heavy", "whip_light", "whip_heavy",
	"cast_fire", "cast_water", "cast_dark", "spike",
	"step", "jump", "double_jump", "land", "dash", "dodge", "ko", "respawn",
	"ui_move", "ui_select", "ui_back", "ui_lock", "count_beep", "count_go", "win",
]
const MAX_VARIANTS := 8
const POOL_SIZE := 16

## sound name -> Array of streams
var _streams: Dictionary = {}
var _last: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
## Headless runs (tests, CI) have no audio device worth feeding.
var _silent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	if _silent:
		return
	for sound_name: String in NAMES:
		var variants: Array = []
		for ext: String in [".ogg", ".wav"]:
			var single: String = FOLDER + sound_name + ext
			if ResourceLoader.exists(single):
				variants.append(load(single))
			for i in range(1, MAX_VARIANTS + 1):
				var path := FOLDER + "%s_%d%s" % [sound_name, i, ext]
				if ResourceLoader.exists(path):
					variants.append(load(path))
		if not variants.is_empty():
			_streams[sound_name] = variants
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = Settings.SFX_BUS
		add_child(player)
		_pool.append(player)


func has_sound(sound_name: String) -> bool:
	return _silent or _streams.has(sound_name)


## Plays a sound once. `pitch_spread` is the random pitch range around `pitch`.
func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0,
		pitch_spread: float = 0.05) -> void:
	if _silent or not _streams.has(sound_name):
		return
	var variants: Array = _streams[sound_name]
	var pick := randi() % variants.size()
	if variants.size() > 1 and pick == _last.get(sound_name, -1):
		pick = (pick + 1 + randi() % (variants.size() - 1)) % variants.size()
	_last[sound_name] = pick
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = variants[pick]
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_spread, pitch_spread))
	player.play()


## Interface sounds stay at a fixed pitch: a menu should sound the same every time.
func ui(sound_name: String) -> void:
	play(sound_name, -4.0, 1.0, 0.0)
