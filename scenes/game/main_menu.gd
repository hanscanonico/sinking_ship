class_name MainMenu
extends CanvasLayer
## Play vs bots: every ship of the Fleet, the seat counts the picked one takes, every
## bot tier there is a profile for, a seed — blank for a random one —, whether she
## sinks fast, whether the match is survival (MatchRules.Goal) and whether bonuses come
## aboard, handed on as they stand: one MatchChoices, which Game turns into a match (D13).
## Beside it, Play online opens the Online screen (SH12). It stands over the ship at dusk
## (MenuBackdrop) under the wordmark in her livery: cream on a boot-top red rule
## between brass lines — and the online screens stand over the same, its own panel put
## away (show_behind). The seed, the pace and the bonuses are a tester's knobs: folded
## under Custom match — Fast sinking ticked for a player (MatchArgs.player_choices),
## unticked for her slow, realistic pace, and Bonuses beside it, ticked unless the plain
## brawl is wanted —, closed unless the command line set a seed, that slow pace or no
## bonuses. The build's version stands in
## the bottom-right corner; Credits opens the credits (CreditsMenu).

signal play_requested(choices: MatchChoices)
## The picker has moved to [param ship], by name.
signal ship_picked
signal online_requested
signal replays_requested
signal credits_requested
signal settings_requested
signal quit_requested

@onready var _ship: OptionButton = %Ship
@onready var _seats: OptionButton = %Seats
@onready var _tier: OptionButton = %Tier
@onready var _seed: LineEdit = %Seed
@onready var _fast: CheckButton = %Fast
@onready var _bonuses: CheckButton = %Bonuses
@onready var _survival: CheckButton = %Survival
@onready var _problem: Label = %Problem
@onready var _play: Button = %Play
@onready var _custom: Button = %Custom
@onready var _custom_choices: Control = %CustomChoices
@onready var _panel: PanelContainer = $Panel
@onready var _backdrop: MenuBackdrop = $Backdrop
## The choices the menu was set up with: what it offers no picker for — the command
## line's scenario and hit — travels on with every Play.
var _given := MatchChoices.new()


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
	%Replays.pressed.connect(replays_requested.emit)
	%Credits.pressed.connect(credits_requested.emit)
	%Version.text = version_text()
	_custom.toggled.connect(_show_custom)
	_show_custom(_custom.button_pressed)
	%Settings.pressed.connect(settings_requested.emit)
	%QuitGame.pressed.connect(quit_requested.emit)


## Offers the Fleet's ships, the seat counts the picked one takes and the tiers under
## data/bots/, with [param choices] chosen where offered — each one unmade the
## [param match_rules]' (MatchChoices.filled), Survival ticked when that goal is —, over
## [param match_rules]' ship.
func setup(match_rules: MatchRules, choices: MatchChoices) -> void:
	_given = choices
	var full := choices.filled(match_rules)
	_backdrop.show_ship(match_rules)
	_ship.clear()
	var ships := Fleet.names()
	# A test-only ship (Fleet, SH33) is offered only when asked for by name.
	if not ships.has(String(full.ship)) and Fleet.layout(full.ship) != null:
		ships.append(String(full.ship))
	for offered: String in ships:
		_ship.add_item(offered)
		if offered == full.ship:
			_ship.select(_ship.item_count - 1)
	_offer_seats(full.seats, match_rules.seats)
	_tier.clear()
	for offered: String in BotProfile.tiers():
		_tier.add_item(offered)
		if offered == full.bot_tier:
			_tier.select(_tier.item_count - 1)
	_seed.text = full.seed_text
	_fast.button_pressed = full.fast
	_bonuses.button_pressed = full.bonuses
	_survival.button_pressed = full.goal == MatchChoices.SURVIVAL
	# A seed, a pace other than a player's, or no bonuses, given on the command line is
	# shown, not hidden under the fold.
	_custom.button_pressed = (
		not full.seed_text.is_empty() or full.fast != MatchChoices.PLAYERS_FAST or not full.bonuses
	)


## The choices as they stand: the ship, seats, tier, seed, pace, bonuses and goal picked
## here, the rest as the menu was set up with them.
func choices() -> MatchChoices:
	var picked := _given.with_seed(_seed.text)
	picked.ship = picked_ship()
	picked.seats = _seats.get_selected_id()
	picked.bot_tier = (
		StringName(_tier.get_item_text(_tier.selected)) if _tier.selected != -1 else &""
	)
	picked.fast = _fast.button_pressed
	picked.bonuses = _bonuses.button_pressed
	picked.goal = MatchChoices.SURVIVAL if _survival.button_pressed else MatchChoices.LAST_STANDING
	return picked


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


## Whether the backdrop's ship is drawn, not still being dressed (MenuBackdrop.dressed).
func dressed() -> bool:
	return _backdrop.dressed()


func show_problem(text: String) -> void:
	_problem.text = text
	_problem.show()


## Whether the seed, the pace and the bonuses are shown, under Custom match.
func custom_shown() -> bool:
	return _custom_choices.visible


## The build's version as the menu's corner shows it: "v" and the project's
## application/config/version, or "dev" for a build that sets none.
static func version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	return "dev" if version.is_empty() else "v" + version


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
## [param otherwise] as near as she takes it.
func _offer_seats(seats: int, otherwise: int) -> void:
	_seats.clear()
	var layout := Fleet.layout(picked_ship())
	if layout == null:
		return
	for count in range(layout.min_seats, layout.max_seats + 1):
		_seats.add_item(str(count), count)
	var seat_index := _seats.get_item_index(seats)
	if seat_index == -1:
		seat_index = _seats.get_item_index(layout.seats_near(otherwise))
	_seats.select(seat_index)


## Opens or folds the seed, the pace and the bonuses, the fold's mark and the way down
## from it following. The mark is a plus or a minus: Playfair has no triangles, and a web
## build has no system font to borrow one from.
func _show_custom(shown: bool) -> void:
	_custom_choices.visible = shown
	_custom.text = ("− " if shown else "+ ") + "Custom match"
	_custom.focus_neighbor_bottom = _custom.get_path_to(_seed if shown else _play)


func _on_ship_picked(_index: int) -> void:
	var seats := _seats.get_selected_id()
	_offer_seats(seats, seats)
	ship_picked.emit()


func _on_play() -> void:
	play_requested.emit(choices())
