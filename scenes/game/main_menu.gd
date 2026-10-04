class_name MainMenu
extends CanvasLayer
## Play vs bots: the seat counts the match data offers, every bot tier there is a
## profile for, and a seed — blank for a random one — handed on as they stand.
## Game turns them into a match through MatchConfig.from_menu (D13). It stands over
## the ship at dusk (MenuBackdrop) under the wordmark in her livery: cream on a
## boot-top red rule between brass lines.

signal play_requested(seats: int, tier: StringName, seed_text: String)
signal settings_requested
signal quit_requested

@onready var _seats: OptionButton = %Seats
@onready var _tier: OptionButton = %Tier
@onready var _seed: LineEdit = %Seed
@onready var _problem: Label = %Problem
@onready var _play: Button = %Play
@onready var _backdrop: MenuBackdrop = $Backdrop


func _ready() -> void:
	UiTheme.apply_to(self)
	%Shade.texture = UiTheme.shade()
	%TrimAbove.color = UiTheme.TRIM
	%BootTop.color = UiTheme.RULE
	%TrimBelow.color = UiTheme.TRIM
	_backdrop.frame_beside($Panel)
	visibility_changed.connect(func() -> void: _backdrop.run(visible))
	_play.pressed.connect(_on_play)
	_seed.text_submitted.connect(func(_text: String) -> void: _on_play())
	_seed.gui_input.connect(_leave_seed)
	%Settings.pressed.connect(settings_requested.emit)
	%QuitGame.pressed.connect(quit_requested.emit)


## Offers [param match_rules]' seat counts and the tiers under data/bots/, with
## [param seats], [param tier] and [param seed_text] chosen where offered, over
## [param match_rules]' ship.
func setup(match_rules: MatchRules, seats: int, tier: StringName, seed_text: String) -> void:
	_backdrop.show_ship(match_rules)
	_seats.clear()
	for count in range(match_rules.min_seats, match_rules.max_seats + 1):
		_seats.add_item(str(count), count)
	var seat_index := _seats.get_item_index(seats)
	_seats.select(seat_index if seat_index != -1 else _seats.get_item_index(match_rules.seats))
	_tier.clear()
	for offered: String in BotProfile.tiers():
		_tier.add_item(offered)
		if offered == tier:
			_tier.select(_tier.item_count - 1)
	_seed.text = seed_text


func open() -> void:
	_problem.hide()
	show()
	_play.grab_focus()


func show_problem(text: String) -> void:
	_problem.text = text
	_problem.show()


## A one-line field has no lines to move between, so up and down leave it as they
## leave every other choice — otherwise the arrow keys could never get out of it.
func _leave_seed(event: InputEvent) -> void:
	var side: Side
	if event.is_action_pressed("ui_up", true):
		side = SIDE_TOP
	elif event.is_action_pressed("ui_down", true):
		side = SIDE_BOTTOM
	else:
		return
	var next := _seed.find_valid_focus_neighbor(side)
	if next != null:
		next.grab_focus()
	_seed.accept_event()


func _on_play() -> void:
	var tier := StringName(_tier.get_item_text(_tier.selected)) if _tier.selected != -1 else &""
	play_requested.emit(_seats.get_selected_id(), tier, _seed.text)
