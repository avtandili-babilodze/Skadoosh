extends Node2D
## Arena manager: handles ring-outs (falling off the screen), lives/stocks,
## respawning, and a simple HUD showing each fighter's damage % and lives.

## How far beyond the screen edge a fighter must travel to be "ringed out".
## Small = leaving the screen is quickly lethal (no wandering off invisibly).
@export var kill_margin: float = 90.0
## Lives (stocks) each fighter starts with.
@export var starting_lives: int = 3

@onready var _label_p1: Label = $HUD/P1
@onready var _label_p2: Label = $HUD/P2
@onready var _message: Label = $HUD/Message

var _view: Vector2         # viewport size in px
var _side_margin: float    # how far off the left/right edges a player may go before ring-out
var _bottom_margin: float  # how far below the screen a player may fall before ring-out
var _players: Array = []   # ordered left-to-right
var _lives: Array = []     # parallel to _players
var _game_over: bool = false


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
	# How far off-screen you may travel before ringing out; an edge marker tracks
	# the player while they're out there. The top is fully open (no limit).
	_side_margin = 500.0
	_bottom_margin = 1000.0

	_players = get_tree().get_nodes_in_group("players")
	_players.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	for _p in _players:
		_lives.append(starting_lives)

	_message.hide()
	_update_hud()


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
		if pos.x < -_side_margin or pos.x > _view.x + _side_margin or pos.y > _view.y + _bottom_margin:
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
	return "%s\n%d%%   Lives: %d" % [p.hero.hero_name, int(p.damage_taken), _lives[i]]
