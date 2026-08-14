extends Node2D
## Arena manager: handles ring-outs (falling off the screen), lives/stocks,
## respawning, and a simple HUD showing each fighter's damage % and lives.

## Horizontal distance beyond either side before a ring-out.
@export var side_kill_margin: float = 500.0
## Distance below the viewport before a ring-out. The top intentionally stays open.
@export var bottom_kill_margin: float = 1000.0
## Lives (stocks) each fighter starts with.
@export var starting_lives: int = 3

@onready var _label_p1: Label = $HUD/P1
@onready var _label_p2: Label = $HUD/P2
@onready var _message: Label = $HUD/Message
@onready var _music: AudioStreamPlayer = $Music

var _view: Vector2         # viewport size in px
var _players: Array = []   # ordered left-to-right
var _lives: Array = []     # parallel to _players
var _icons: Array = []     # hero icon shown in each player's HUD corner (parallel to _players)
var _game_over: bool = false
var _music_on: bool = true # toggled by the HUD button or the "7" key
var _music_button: Button

const HUD_ICON_SIZE := 96.0   # on-screen size of the HUD hero icon, in px
const HUD_MARGIN := 24.0      # gap from the screen corner


func _enter_tree() -> void:
	# Apply the picks made on the character-select screen. This runs before the
	# Player children's _ready (parent enters the tree first), so the override
	# lands before they read their hero. When the arena is launched directly the
	# picks are null and the heroes wired into the scene are kept.
	if Roster.p1_hero != null:
		$Player1.hero = Roster.p1_hero
	if Roster.p2_hero != null:
		$Player2.hero = Roster.p2_hero


func _ready() -> void:
	_view = get_viewport_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_players = get_tree().get_nodes_in_group("players")
	_players.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	for _p in _players:
		_lives.append(maxi(1, starting_lives))

	_build_hud_icons()
	_message.hide()
	_update_hud()
	# Loop the battle music for the whole match. On restart the scene reloads, so
	# _ready runs again and the music starts over from the top.
	_music.play()
	_build_music_button()
	_update_responsive_layout()


func _on_viewport_size_changed() -> void:
	_view = get_viewport_rect().size
	_update_responsive_layout()


func _update_responsive_layout() -> void:
	if _icons.size() >= 2:
		_icons[1].position = Vector2(_view.x - HUD_MARGIN - HUD_ICON_SIZE, HUD_MARGIN)
	# The original scene is authored at 1152×648. Keep the right HUD and center
	# message attached to their semantic positions when the window changes size.
	_label_p2.offset_left = _view.x - 420.0
	_label_p2.offset_right = _view.x - HUD_MARGIN
	_message.offset_left = (_view.x - 500.0) * 0.5
	_message.offset_right = _message.offset_left + 500.0


## Places each player's hero icon in their HUD corner (leftmost player → top-left,
## rightmost → top-right) and moves the damage-% label to sit just below it.
func _build_hud_icons() -> void:
	var labels: Array = [_label_p1, _label_p2]
	for i in _players.size():
		var icon := TextureRect.new()
		icon.texture = _players[i].hero.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(HUD_ICON_SIZE, HUD_ICON_SIZE)
		icon.size = Vector2(HUD_ICON_SIZE, HUD_ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0:
			icon.position = Vector2(HUD_MARGIN, HUD_MARGIN)              # top-left
		else:
			icon.position = Vector2(_view.x - HUD_MARGIN - HUD_ICON_SIZE, HUD_MARGIN)  # top-right
		_message.get_parent().add_child(icon)
		_icons.append(icon)
		# Drop the label just below the icon so the % reads under the portrait.
		if i < labels.size():
			labels[i].offset_top = HUD_MARGIN + HUD_ICON_SIZE + 8.0
			labels[i].offset_bottom = labels[i].offset_top + 80.0


## A small mute/unmute button under Player 1's HUD cluster (icon + % text).
func _build_music_button() -> void:
	_music_button = Button.new()
	_music_button.focus_mode = Control.FOCUS_NONE   # don't steal keyboard focus from the game
	_music_button.add_theme_font_size_override("font_size", 18)
	_music_button.custom_minimum_size = Vector2(130, 34)
	_music_button.position = Vector2(HUD_MARGIN, HUD_MARGIN + HUD_ICON_SIZE + 92.0)
	_music_button.pressed.connect(func(): _set_music(not _music_on))
	$HUD.add_child(_music_button)
	_refresh_music_button()


func _unhandled_input(event: InputEvent) -> void:
	# "7" toggles the music too (physical key, so it's layout-independent).
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_7:
		_set_music(not _music_on)


func _set_music(on: bool) -> void:
	_music_on = on
	if on:
		if not _music.playing:
			_music.play()
		_music.stream_paused = false
	else:
		_music.stream_paused = true
	_refresh_music_button()


func _refresh_music_button() -> void:
	if _music_button != null:
		_music_button.text = "♪ Music: On" if _music_on else "♪ Music: Off"


func _physics_process(_delta: float) -> void:
	if _game_over:
		if Input.is_physical_key_pressed(KEY_ENTER):
			get_tree().reload_current_scene()
		return

	for i in _players.size():
		if _lives[i] <= 0:
			continue
		# Ring out past the sides (up to _side_margin off-screen) and below the bottom.
		# The top is open, so players can fly as high as they like — off-screen
		# markers track them at the top and sides while they're out of view.
		var pos: Vector2 = _players[i].global_position
		if (pos.x < -side_kill_margin
				or pos.x > _view.x + side_kill_margin
				or pos.y > _view.y + bottom_kill_margin):
			_ring_out(i)

	_update_hud()


func _ring_out(i: int) -> void:
	_lives[i] -= 1
	if _lives[i] > 0:
		_players[i].respawn()
	else:
		_players[i].eliminate()
	_check_game_over()


func _check_game_over() -> void:
	var alive: Array = []
	for i in _players.size():
		if _lives[i] > 0:
			alive.append(i)
	if alive.size() <= 1:
		_game_over = true
		_music.stop()   # match's over — cut the music until someone restarts
		get_tree().call_group("projectiles", "queue_free")
		for player in _players:
			if player.has_method("set_match_active"):
				player.set_match_active(false)
		if alive.size() == 1:
			_message.text = "%s WINS!\nPress Enter to restart" % _players[alive[0]].hero.hero_name
		else:
			_message.text = "Draw!\nPress Enter to restart"
		_message.show()


func _update_hud() -> void:
	if _players.size() >= 1:
		_label_p1.text = _hud_line(0)
	if _players.size() >= 2:
		_label_p2.text = _hud_line(1)


func _hud_line(i: int) -> String:
	var p = _players[i]
	return "%d%%\nLives: %d" % [int(p.damage_taken), _lives[i]]
