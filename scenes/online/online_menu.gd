class_name OnlineMenu
extends CanvasLayer
## The Online screen (SH12), over the main menu's backdrop: a display name — the rule the
## server holds it to shown under it — and natively the server to play on; then Create a
## room, or Join one by its code (CodePicker). In a browser the server is the page's own
## and the field is gone. What the player chose becomes an OnlineLink, checked as every
## link is, and only a link with no problem is asked for; the name and the server are
## remembered for the next run (OnlineSettings). What went wrong on the way — a refusal,
## the connection never made or lost — comes back here as a short sentence, with Rejoin
## when there is a room to go back to. Back and ui_cancel leave for the main menu.

signal play_requested(link: OnlineLink)
signal back_requested

## Where the name and the server are remembered; a test points it elsewhere.
var settings_path := OnlineSettings.PATH
## Whether this runs in a browser: the server is the page's own then.
var on_web := OS.has_feature("web")
## The page's own server, in a browser.
var page_server := ""

var _rules := ServerRules.load_default()
var _settings: OnlineSettings
## The room Rejoin goes back to; "" when there is none.
var _rejoin := ""
var _busy := false

@onready var _panel: PanelContainer = $Panel
@onready var _name: LineEdit = %Name
@onready var _server: LineEdit = %Server
@onready var _code: CodePicker = %Code
@onready var _join: Button = %Join
@onready var _create: Button = %Create
@onready var _rejoin_button: Button = %Rejoin
@onready var _back: Button = %Back
@onready var _status: Label = %Status


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	%NameRule.text = OnlineLink.name_rule(_rules)
	_name.max_length = _rules.name_length
	_server.max_length = OnlineLink.MAX_URL
	for field: LineEdit in [_name, _server]:
		field.gui_input.connect(MainMenu.leave_field.bind(field))
	_name.text_submitted.connect(func(_text: String) -> void: _create.grab_focus())
	_server.text_submitted.connect(func(_text: String) -> void: _create.grab_focus())
	_code.lead_to(_join)
	_create.pressed.connect(_submit.bind(true))
	_join.pressed.connect(_submit.bind(false))
	_rejoin_button.pressed.connect(_on_rejoin)
	_back.pressed.connect(back_requested.emit)
	_settings = OnlineSettings.read(settings_path)
	_name.text = _settings.player_name
	_server.text = (
		_settings.server_url
		if not _settings.server_url.is_empty()
		else "ws://127.0.0.1:%d" % _rules.port
	)


## Shows the screen, [param note] — what went wrong, if anything — under the choices,
## and Rejoin when [param rejoin] names a room to go back to.
func open(note: String = "", rejoin: String = "") -> void:
	%ServerLabel.visible = not on_web
	_server.visible = not on_web
	_rejoin = rejoin
	_set_busy(false)
	_rejoin_button.visible = not rejoin.is_empty()
	_say(note, true)
	show()
	if _rejoin_button.visible:
		_rejoin_button.grab_focus()
	elif _name.text.strip_edges().is_empty():
		_name.grab_focus()
	else:
		_create.grab_focus()


## Takes up a launch's [param link] — a page's address or the native flags — and plays it
## at once when it names a room or asks for one, has no problem, and the player's name is
## known: the link's own, or the one remembered. Otherwise its problem is shown, or the
## name asked for. A page's link is anyone's to share: the name it carries stands in only
## for a visitor who has none remembered — shown in the field, played under, and never
## remembered for them unless they press Create or Join themselves.
func take_link(link: OnlineLink) -> void:
	if not on_web and not link.server_url.is_empty():
		_server.text = link.server_url
	var remembered := on_web and not _settings.player_name.is_empty()
	if link.named and not link.player_name.is_empty() and not remembered:
		_name.text = link.player_name
	_code.set_code(link.room)
	if not link.problems.is_empty():
		_say(link.problems[0], true)
		return
	if _name.text.strip_edges().is_empty():
		_say(
			"Choose a name to play under, then %s." % ("create the room" if link.create else "join")
		)
		_name.grab_focus()
		return
	_submit.call_deferred(link.create, "", not on_web)


## While a link is being played: the choices wait, and Back gives up on it.
func show_connecting() -> void:
	_set_busy(true)
	_rejoin_button.hide()
	_say("Connecting to the server…")
	_back.grab_focus()


## The panel the backdrop's ship stands beside.
func panel() -> Control:
	return _panel


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Asks to play what the player chose — [param creating] a room, or joining the code in
## the slots, or [param code]'s — when it can be played, remembering the name and the
## server when [param remember] says; says what is wrong otherwise.
func _submit(creating: bool, code: String = "", remember: bool = true) -> void:
	if _busy:
		return
	var server := page_server if on_web else _server.text.strip_edges()
	var joining := code if not code.is_empty() else _code.code()
	var link := OnlineLink.from_menu(server, creating, joining, _name.text, _rules)
	if not link.problems.is_empty():
		_say(link.problems[0], true)
		return
	if remember:
		_settings.player_name = link.player_name
		if not on_web:
			_settings.server_url = link.server_url
		var saved := _settings.save(settings_path)
		if saved != OK:
			push_warning("online: not saved: %s" % error_string(saved))
	play_requested.emit(link)


func _on_rejoin() -> void:
	_code.set_code(_rejoin)
	_submit(false, _rejoin)


func _set_busy(busy: bool) -> void:
	_busy = busy
	for control: Control in [_name, _server]:
		(control as LineEdit).editable = not busy
	for button: Button in [_create, _join, _rejoin_button]:
		button.disabled = busy
	for slot: Node in _code.get_children():
		(slot as Button).disabled = busy


## [param text] under the choices — as a problem when [param problem] — or nothing.
func _say(text: String, problem: bool = false) -> void:
	_status.text = text
	_status.theme_type_variation = UiTheme.PROBLEM_LABEL if problem else &""
	_status.visible = not text.is_empty()
