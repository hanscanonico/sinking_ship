class_name RoomScreen
extends CanvasLayer
## A room on a server, as its players wait in it (SH12), over the main menu's backdrop:
## its code, large, to read out or copy — and in a browser the page's address that
## brings a friend straight to it, never with a name in it — and who is aboard, seat by
## seat: the host and "you" marked, and the seats nobody holds as the bots that will
## take them. The host's Start asks for the match once per showing — until the server's
## answer, a refusal or the room changed shows the room again — and is there but dead
## for everyone else, who wait for the host. Leave room, and ui_cancel, leave.
##
## Every name in it is another player's typing, so it is a plain Label, cut short with
## an ellipsis where it is too long for its seat's line.

signal start_requested
signal leave_requested

## How long a Copy button says it copied.
const COPIED_SECONDS := 1.5

## Seats in the room's match: the players' and the bots'.
var seats := 0
## The server the room is on, for the invite.
var server_url := ""
## Whether this runs in a browser: only a page has an address to invite to.
var on_web := OS.has_feature("web")

## The room shown; null while none is.
var _roster: RoomRoster
## Whether the start has been asked for since the room was shown.
var _asked := false

@onready var _panel: PanelContainer = $Panel
@onready var _code: Label = %Code
@onready var _copy_code: Button = %CopyCode
@onready var _copy_invite: Button = %CopyInvite
@onready var _status: Label = %Status
@onready var _note: Label = %Note
@onready var _start: Button = %Start
@onready var _leave: Button = %Leave
@onready var _aboard: Label = %Aboard
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_copy_code.pressed.connect(_copy.bind(_copy_code, _copy_code.text, false))
	_copy_invite.pressed.connect(_copy.bind(_copy_invite, _copy_invite.text, true))
	_start.pressed.connect(_on_start)
	_leave.pressed.connect(leave_requested.emit)


## Shows [param roster]'s room, and [param note] — a refusal, say — under it.
func show_room(roster: RoomRoster, note: String = "") -> void:
	_roster = roster
	_asked = false
	_code.text = roster.code
	_copy_invite.visible = on_web
	_note.text = note
	_note.visible = not note.is_empty()
	var hosting := roster.you_host()
	_start.text = "Start"
	_start.disabled = roster.playing or not hosting
	if roster.playing:
		_status.text = "A match is on in this room: it waits for that one to end."
	elif hosting:
		_status.text = "You host: start when everyone is aboard. Bots take the empty seats."
	else:
		_status.text = "Waiting for the host to start."
	_show_seats(roster)
	show()
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _panel.is_ancestor_of(focused) or not focused.is_visible_in_tree():
		(_start if not _start.disabled else _copy_code).grab_focus()


## The panel the backdrop's ship stands beside.
func panel() -> Control:
	return _panel


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave_requested.emit()


func _on_start() -> void:
	if _roster == null or _roster.playing or not _roster.you_host() or _asked:
		return
	_asked = true
	_start.disabled = true
	_start.text = "Starting…"
	_copy_code.grab_focus()
	start_requested.emit()


## Every seat of the match, a line each: the players in seat order, then the bots'.
func _show_seats(roster: RoomRoster) -> void:
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var players := mini(roster.players.size(), seats)
	_aboard.text = "Aboard · %d of %d" % [players, seats]
	for seat in seats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_rows.add_child(row)
		_tag(row, str(seat + 1), UiTheme.MUTED).custom_minimum_size.x = 18.0
		if seat >= players:
			_name(row, "A bot takes this seat", UiTheme.MUTED)
			continue
		var player := roster.players[seat]
		_name(
			row, player.name, UiTheme.TRIM.lightened(0.45) if seat == roster.you else UiTheme.TEXT
		)
		if player.bot:
			_tag(row, "gone · a bot plays", UiTheme.MUTED)
		if player.host:
			_tag(row, "host", UiTheme.TRIM)
		if seat == roster.you:
			_tag(row, "you", UiTheme.TRIM.lightened(0.45))


## A player's name — or a bot's — on [param row]: as much of it as its line holds.
func _name(row: HBoxContainer, text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)


func _tag(row: HBoxContainer, text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = UiTheme.HINT_LABEL
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)
	return label


## Copies the room's code — or, when [param invite], this page's address for it — and
## says so on [param button] for a moment, before it reads [param label] again.
func _copy(button: Button, label: String, invite: bool) -> void:
	if _roster == null:
		return
	var text := OnlineLink.page_invite(server_url, _roster.code) if invite else _roster.code
	DisplayServer.clipboard_set(text)
	button.text = "Copied"
	create_tween().tween_callback(func() -> void: button.text = label).set_delay(COPIED_SECONDS)
