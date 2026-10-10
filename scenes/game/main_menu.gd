class_name MainMenu
extends CanvasLayer
## Play vs bots: every ship of the Fleet, the seat counts the picked one takes, every
## bot tier there is a profile for, a seed — blank for a random one — and whether she
## sinks fast, handed on as they stand.
## Game turns them into a match through MatchConfig.from_menu (D13). Beside it, Play
## online opens the Online screen (SH12). It stands over the ship at dusk
## (MenuBackdrop) under the wordmark in her livery: cream on a boot-top red rule
## between brass lines — and the online screens stand over the same, its own panel put
## away (show_behind).

signal play_requested(ship: StringName, seats: int, tier: StringName, seed_text: String, fast: bool)
## The picker has moved to [param ship], by name.
signal ship_picked(ship: StringName)
signal online_requested
signal settings_requested
signal quit_requested

@onready var _ship: OptionButton = %Ship
@onready var _seats: OptionButton = %Seats
@onready var _tier: OptionButton = %Tier
@onready var _seed: LineEdit = %Seed
@onready var _fast: CheckButton = %Fast
@onready var _problem: Label = %Problem
@onready var _play: Button = %Play
@onready var _panel: PanelContainer = $Panel
@onready var _backdrop: MenuBackdrop = $Backdrop


func _ready() -> void:
	UiTheme.apply_to(self)
	%Shade.texture = UiTheme.shade()
	%TrimAbove.color = UiTheme.TRIM
	%BootTop.color = UiTheme.RULE
	%TrimBelow.color = UiTheme.TRIM
	_backdrop.frame_beside(_panel)
	visibility_changed.connect(func() -> void: _backdrop.run(visible))
	_play.pressed.connect(_on_play)
	_ship.item_selected.connect(_on_ship_picked)
	_seed.text_submitted.connect(func(_text: String) -> void: _on_play())
	_seed.gui_input.connect(leave_field.bind(_seed))
	%Online.pressed.connect(online_requested.emit)
	%Settings.pressed.connect(settings_requested.emit)
	%QuitGame.pressed.connect(quit_requested.emit)


## Offers the Fleet's ships, the seat counts the picked one takes and the tiers under
## data/bots/, with [param ship], [param seats], [param tier] and [param seed_text]
## chosen where offered — [param match_rules]' ship and seat count where not —, and
## Fast sinking ticked when [param fast], over [param match_rules]' ship.
func setup(
	match_rules: MatchRules,
	ship: StringName,
	seats: int,
	tier: StringName,
	seed_text: String,
	fast := false
) -> void:
	_backdrop.show_ship(match_rules)
	_ship.clear()
	var ships := Fleet.names()
	# A test-only ship (Fleet, SH33) is offered only when asked for by name.
	if not ship.is_empty() and not ships.has(String(ship)) and Fleet.layout(ship) != null:
		ships.append(String(ship))
	for offered: String in ships:
		_ship.add_item(offered)
		if offered == ship or (ship.is_empty() and offered == Fleet.name_of(match_rules.ship)):
			_ship.select(_ship.item_count - 1)
	_offer_seats(seats, match_rules.seats)
	_tier.clear()
	for offered: String in BotProfile.tiers():
		_tier.add_item(offered)
		if offered == tier:
			_tier.select(_tier.item_count - 1)
	_seed.text = seed_text
	_fast.button_pressed = fast


func open() -> void:
	_problem.hide()
	_panel.show()
	_backdrop.frame_beside(_panel)
	show()
	_play.grab_focus()


## The backdrop and the wordmark alone, the ship framed beside [param panel]: another
## screen's, over this one.
func show_behind(panel: Control) -> void:
	_panel.hide()
	_backdrop.frame_beside(panel)
	show()


## Holds the backdrop's drift at [param sway] (-1…1), for a capture.
func hold_drift(sway: float) -> void:
	_backdrop.hold_drift(sway)


## Draws the backdrop as [param settings]' graphics now say.
func show_graphics(settings: ViewSettings) -> void:
	_backdrop.show_graphics(settings)


func show_problem(text: String) -> void:
	_problem.text = text
	_problem.show()


## A one-line field has no lines to move between, so up and down leave [param field]
## as they leave every other choice — otherwise the arrow keys could never get out of
## it. Every screen's one-line fields take it, on their gui_input.
static func leave_field(event: InputEvent, field: LineEdit) -> void:
	var side: Side
	if event.is_action_pressed("ui_up", true):
		side = SIDE_TOP
	elif event.is_action_pressed("ui_down", true):
		side = SIDE_BOTTOM
	else:
		return
	var next := field.find_valid_focus_neighbor(side)
	if next != null:
		next.grab_focus()
	field.accept_event()


## The ship picked, by name; empty when none is.
func picked_ship() -> StringName:
	return StringName(_ship.get_item_text(_ship.selected)) if _ship.selected != -1 else &""


## The seat counts the picked ship takes, [param seats] chosen where she takes it, else
## [param otherwise], else her fewest.
func _offer_seats(seats: int, otherwise: int) -> void:
	_seats.clear()
	var layout := Fleet.layout(picked_ship())
	if layout == null:
		return
	for count in range(layout.min_seats, layout.max_seats + 1):
		_seats.add_item(str(count), count)
	var seat_index := _seats.get_item_index(seats)
	if seat_index == -1:
		seat_index = maxi(_seats.get_item_index(otherwise), 0)
	_seats.select(seat_index)


func _on_ship_picked(_index: int) -> void:
	var seats := _seats.get_selected_id()
	_offer_seats(seats, seats)
	ship_picked.emit(picked_ship())


func _on_play() -> void:
	var tier := StringName(_tier.get_item_text(_tier.selected)) if _tier.selected != -1 else &""
	play_requested.emit(
		picked_ship(), _seats.get_selected_id(), tier, _seed.text, _fast.button_pressed
	)
