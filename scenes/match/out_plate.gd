class_name OutPlate
extends CanvasLayer
## The local seat's result the moment it goes out, the match going on: the title the
## results will give it — "Overboard — 6th of 8 — shoved by Bot 3", its place fixed the
## tick it went (EndOverlay.title_of) — over Watch, Rematch and Menu, or online Watch and
## Leave (offer_room). Shown once a match, on a small plate with no scrim: the world
## plays on behind it, and it takes only the mouse and the keys it names. Watch — its
## button, Esc or the pad's Start or B — closes it and the spectating goes on as it
## always did; the others close it too and go where the results' do. The match ending
## under it, it gives way to the results (EndOverlay). Nothing shows for a seat nobody
## plays (-1), a watcher's match or a replay.

signal rematch_requested
signal menu_requested

## How long the plate ignores presses once it shows (EndOverlay.PRESS_GUARD_SECONDS):
## the jump or the shove mashed going over the side must not close it unseen.
const PRESS_GUARD_SECONDS := EndOverlay.PRESS_GUARD_SECONDS
## The line under the title: this is no end of the match.
const GOES_ON := "The match goes on"

## The stats of the match the plate last showed for: once a match.
var _shown_for: MatchStats
## Whether the match is on a server: no rematch, and the way out leaves it (offer_room).
var _online := false
var _guard := Timer.new()
var _title := Label.new()
var _hint := Label.new()
var _watch := Button.new()
var _rematch := Button.new()
var _menu := Button.new()


func _init() -> void:
	name = "OutPlate"
	layer = 2


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	var plate := PanelContainer.new()
	plate.name = "Panel"
	plate.set_anchors_preset(Control.PRESET_CENTER)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	plate.add_child(box)
	_title.name = "Title"
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var goes_on := Label.new()
	goes_on.text = GOES_ON
	goes_on.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(goes_on)
	_hint.name = "Hint"
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_button(buttons, _watch, "Watch", _close)
	_button(buttons, _rematch, "Rematch", _leave_by.bind(rematch_requested))
	_button(buttons, _menu, "Menu", _leave_by.bind(menu_requested))
	_guard.one_shot = true
	_guard.wait_time = PRESS_GUARD_SECONDS
	_guard.timeout.connect(_accept_presses)
	add_child(_guard)
	offer_room(_online)


## Shows the plate once [param stats] say [param seat] — the seat a person plays here, -1
## for none — is out of a match still going (due), the once for those stats; and takes
## it away as the match ends or another begins. [param names], [param survival] and
## [param aboard] word its title as the results will (EndOverlay.title_of); [param prompts]
## its hint, on the device last used.
func offer(
	stats: MatchStats,
	seat: int,
	names: PackedStringArray,
	survival := false,
	aboard := false,
	prompts: InputPrompts = null
) -> void:
	if not due(stats, seat):
		if visible:
			_close()
		return
	if prompts != null:
		_hint.text = hint_words(prompts, _online)
	if stats == _shown_for:
		return
	_shown_for = stats
	_title.text = EndOverlay.title_of(stats, seat, names, survival, aboard)
	for button: Button in [_watch, _rematch, _menu]:
		button.disabled = true
	show()
	_guard.start()


## Whether [param stats] say [param seat] has its result while the match goes on: out,
## its place fixed, and the match not ended. Never for no seat (-1).
static func due(stats: MatchStats, seat: int) -> bool:
	if stats == null or stats.ended or seat < 0 or seat >= stats.seats.size():
		return false
	return stats.seats[seat].place > 0


## Online ([param online]) nothing is played again mid-match: no Rematch, and the menu's
## button leaves the match and its room, as the results' does (EndOverlay.offer_room).
func offer_room(online := true) -> void:
	_online = online
	_rematch.visible = not online
	_menu.text = "Leave" if online else "Menu"


## The hint line on the device [param prompts] says was used last: what watches on, and,
## in a local match, what plays again — unless one button does both, as a pad's Start:
## it watches, and Rematch is the button's.
static func hint_words(prompts: InputPrompts, online: bool) -> String:
	var watch := prompts.word(&"pause")
	var rematch := prompts.word(&"restart")
	var hint := "%s — %s" % [watch, Language.t("watch")]
	if not online and rematch != watch:
		hint += "   ·   %s — %s" % [rematch, Language.t("rematch")]
	return hint


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var watch := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	var rematch := not _online and event.is_action_pressed("restart")
	if not watch and not rematch:
		return
	get_viewport().set_input_as_handled()
	# A press inside the guard is taken and does nothing: it must not pause the match.
	if not _guard.is_stopped():
		return
	if watch:
		_close()
	else:
		_leave_by(rematch_requested)


## [param button] in [param row], named and worded [param text]: its press does [param press].
func _button(row: HBoxContainer, button: Button, text: String, press: Callable) -> void:
	button.name = text
	button.text = text
	button.custom_minimum_size = Vector2(120.0, 0.0)
	button.theme_type_variation = UiTheme.GUARDED_BUTTON
	button.pressed.connect(press)
	row.add_child(button)


## The plate closed, to watch on: the mouse is the view's again (MatchScene).
func _close() -> void:
	_guard.stop()
	hide()


## The plate closed for good by Rematch or Menu, which [param asked] tells the match.
func _leave_by(asked: Signal) -> void:
	_close()
	asked.emit()


func _accept_presses() -> void:
	for button: Button in [_watch, _rematch, _menu]:
		button.disabled = false
	# A menu over the match — the online pause — keeps the focus it has.
	if visible and get_viewport().gui_get_focus_owner() == null:
		_watch.grab_focus()
