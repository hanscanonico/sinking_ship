class_name RoomScreen
extends CanvasLayer
## A room on a server, as its players wait in it (SH12), over the main menu's backdrop:
## its code, large, to read out or copy — and in a browser the page's address that
## brings a friend straight to it, never with a name in it — and who is aboard, seat by
## seat: the host and "you" marked, the seats nobody holds as the bots that will
## take them, and under them whoever watches rather than plays. Watch has this player
## watch the match without a seat, while the room waits (GLOSSARY: Watch). The host's
## Start asks for the match once per showing — until the server's answer, a refusal
## or the room changed shows the room again — and is there but dead for everyone else,
## who wait for the host, and while everyone in the room watches. A quick game counts
## down to the moment it starts on its own, its host still free to start it sooner. Leave
## room, and ui_cancel, leave.
##
## Every name in it is another player's typing, so it is a plain Label, cut short with
## an ellipsis where it is too long for its seat's line.

signal start_requested
signal leave_requested
## Watch was toggled: this player asks to watch when [param on], else to play.
signal watch_requested(on: bool)

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
## Whether the match the room still shows as on is the one this player just finished:
## the server holds a finished match a moment (ServerRules.finished_linger) before the
## room waits for its host again.
var _ended := false
## Whether the host pressed Start while that match lingered: asked for once it is gone.
var _queued := false
## When a waiting quick game starts, on the engine's clock in msec; -1 for no such room.
var _quick_ends_msec := -1
## The seconds left the status last said; -1 when it said none.
var _shown_seconds := -1

@onready var _panel: PanelContainer = $Panel
@onready var _code: Label = %Code
@onready var _copy_code: Button = %CopyCode
@onready var _copy_invite: Button = %CopyInvite
@onready var _status: Label = %Status
@onready var _note: Label = %Note
@onready var _start: Button = %Start
@onready var _leave: Button = %Leave
@onready var _watch: CheckButton = %Watch
@onready var _aboard: Label = %Aboard
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	UiTheme.apply_to(self)
	hide()
	_copy_code.pressed.connect(_copy.bind(_copy_code, _copy_code.text, false))
	_copy_invite.pressed.connect(_copy.bind(_copy_invite, _copy_invite.text, true))
	_start.pressed.connect(_on_start)
	_leave.pressed.connect(leave_requested.emit)
	_watch.toggled.connect(watch_requested.emit)


## Shows [param roster]'s room, and [param note] — a refusal, say — under it; [param ended]
## when the match it shows as on is the one this player has just seen end (back from the
## results): the room then says it opens again in a moment, and a Start pressed meanwhile
## is asked for as soon as it does.
func show_room(roster: RoomRoster, note: String = "", ended: bool = false) -> void:
	var hosting := roster.you_host()
	var same := _roster != null and _roster.code == roster.code
	_ended = roster.playing and (ended or _ended and same)
	var start_now := _queued and not roster.playing and hosting
	_queued = _queued and _ended and hosting
	_roster = roster
	_asked = _queued
	_code.text = roster.code
	_copy_invite.visible = on_web
	_note.text = note
	_note.visible = not note.is_empty()
	_start.text = "Starting…" if _queued else "Start"
	# The server refuses a match nobody plays in (RoomCodec.Refusal.NO_PLAYERS): Start
	# is dead while everyone in the room watches, and the room says why.
	var nobody_plays := roster.seated().is_empty()
	_start.disabled = (roster.playing and not _ended) or not hosting or _queued or nobody_plays
	_watch.set_pressed_no_signal(roster.you_watch())
	_watch.disabled = roster.playing
	_quick_ends_msec = -1
	if roster.quick and not roster.playing:
		_quick_ends_msec = Time.get_ticks_msec() + int(Ticks.to_seconds(roster.starts_in) * 1000.0)
	_show_status()
	_show_seats(roster)
	show()
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _panel.is_ancestor_of(focused) or not focused.is_visible_in_tree():
		(_start if not _start.disabled else _copy_code).grab_focus()
	if start_now:
		_on_start()


## The panel the backdrop's ship stands beside.
func panel() -> Control:
	return _panel


# A waiting quick game counts down to its start, a second at a time.
func _process(_delta: float) -> void:
	if visible and _quick_ends_msec >= 0 and _seconds_left() != _shown_seconds:
		_show_status()


## The whole seconds until a waiting quick game starts, as its roster said.
func _seconds_left() -> int:
	return ceili(maxi(_quick_ends_msec - Time.get_ticks_msec(), 0) / 1000.0)


## What the room is waiting for, under its code.
func _show_status() -> void:
	var roster := _roster
	var hosting := roster.you_host()
	var nobody_plays := roster.seated().is_empty()
	_shown_seconds = _seconds_left() if _quick_ends_msec >= 0 else -1
	if _ended:
		_status.text = Language.t("That match is over: the room opens again in a moment.")
	elif roster.playing:
		_status.text = Language.t("A match is on in this room: it waits for that one to end.")
	elif nobody_plays:
		_status.text = Language.t("Everyone here watches: someone has to play.")
	elif roster.quick and _shown_seconds > 0:
		_status.text = (
			Language.t("Quick game: it starts in %d s with everyone aboard. Bots take the rest.")
			% _shown_seconds
		)
	elif roster.quick:
		_status.text = Language.t("Quick game: starting…")
	elif hosting:
		_status.text = Language.t(
			"You host: start when everyone is aboard. Bots take the empty seats."
		)
	else:
		_status.text = Language.t("Waiting for the host to start.")
	if roster.you_watch() and not roster.playing and not nobody_plays:
		_status.text += Language.t(" You watch: you take no seat.")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave_requested.emit()


func _on_start() -> void:
	if _roster == null or not _roster.you_host() or _asked:
		return
	if _roster.playing and not _ended:
		return
	_asked = true
	_start.disabled = true
	_start.text = "Starting…"
	_copy_code.grab_focus()
	if _roster.playing:
		_queued = true
		return
	start_requested.emit()


## Every seat of the match, a line each: the players in seat order, then the bots' —
## and after them a line for each who watches.
func _show_seats(roster: RoomRoster) -> void:
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var seated := roster.seated()
	var players := mini(seated.size(), seats)
	_aboard.text = Language.t("Aboard · %d of %d") % [players, seats]
	for seat in seats:
		var row := _row(str(seat + 1))
		if seat >= players:
			_name(row, Language.t("A bot takes this seat"), UiTheme.MUTED)
			continue
		_player(row, seated[seat], roster)
	for player: RoomRoster.Player in roster.players:
		if player.watching:
			var row := _row("·")
			_player(row, player, roster)
			_tag(row, "watching", UiTheme.MUTED)


## A new line of the list, led by [param lead]: a seat's number, or a watcher's dot.
func _row(lead: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_rows.add_child(row)
	_tag(row, lead, UiTheme.MUTED).custom_minimum_size.x = 18.0
	return row


## [param player] of [param roster] on [param row]: their name, and whether a bot plays
## for them, they host, and they are this player.
func _player(row: HBoxContainer, player: RoomRoster.Player, roster: RoomRoster) -> void:
	var yours := roster.you >= 0 and roster.you < roster.players.size()
	var is_you := yours and roster.players[roster.you] == player
	_name(row, player.name, UiTheme.TRIM.lightened(0.45) if is_you else UiTheme.TEXT)
	if player.bot:
		_tag(row, "gone · a bot plays", UiTheme.MUTED)
	if player.host:
		_tag(row, "host", UiTheme.TRIM)
	if is_you:
		_tag(row, "you", UiTheme.TRIM.lightened(0.45))


## A player's name — or a bot's — on [param row]: as much of it as its line holds.
func _name(row: HBoxContainer, text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	# A player's name is theirs, never a word to translate.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
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
