extends GutTest
## The Online screen (SH12): a name the server takes — its rule shown, never silently
## changed — a server natively and the page's own in a browser, and a room code typed in
## any case or picked a letter at a time; only what OnlineLink finds no problem with is
## asked for, and the name and the server are remembered. A link to a room plays at once
## when the name is known, and asks for it otherwise. No socket: the screen only asks.

const SETTINGS_PATH := "user://test_online_settings.json"

var _menu: OnlineMenu
## Every link the screen asked to play, in order.
var _asked: Array[OnlineLink] = []


func before_each() -> void:
	_asked.clear()


func after_each() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


## The screen as a browser's page shows it when [param on_web], natively otherwise, open.
func _open(on_web: bool = false) -> OnlineMenu:
	_menu = load("res://scenes/online/online_menu.tscn").instantiate()
	_menu.settings_path = SETTINGS_PATH
	_menu.on_web = on_web
	_menu.page_server = "wss://ship.example.org/ws" if on_web else ""
	_menu.play_requested.connect(func(link: OnlineLink) -> void: _asked.append(link))
	add_child_autofree(_menu)
	_menu.open()
	return _menu


func _node(path: String) -> Node:
	return _menu.get_node(path)


func _status() -> String:
	var status: Label = _node("%Status")
	return status.text if status.visible else ""


## A key typed at whatever has the focus.
func _type(text: String) -> void:
	for letter: String in text:
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = OS.find_keycode_from_string(letter.to_upper())
		key.unicode = letter.unicode_at(0)
		get_viewport().push_input(key)


func _act(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func test_the_name_rule_is_shown_and_held_to() -> void:
	_open()
	var rules := ServerRules.load_default()
	assert_eq((_node("%NameRule") as Label).text, OnlineLink.name_rule(rules))
	var field: LineEdit = _node("%Name")
	assert_eq(field.max_length, rules.name_length, "no longer a name than the server takes")
	for bad: String in ["", "   ", "<b>Ada</b>", "Zoë", "Ad\na"]:
		field.text = bad
		(_node("%Create") as Button).pressed.emit()
		assert_eq(_status(), "A name is %s." % OnlineLink.name_rule(rules), "%s" % bad.c_escape())
		assert_eq(field.text, bad, "and left as typed")
	assert_eq(_asked, [] as Array[OnlineLink], "nothing asked for")


func test_a_room_is_created_and_the_choices_remembered() -> void:
	_open()
	(_node("%Name") as LineEdit).text = " Ada "
	(_node("%Server") as LineEdit).text = "ws://127.0.0.1:47931"
	(_node("%Create") as Button).pressed.emit()
	assert_eq(_asked.size(), 1)
	assert_true(_asked[0].create)
	assert_eq(_asked[0].player_name, "Ada")
	assert_eq(_asked[0].server_url, "ws://127.0.0.1:47931")
	var saved := OnlineSettings.read(SETTINGS_PATH)
	assert_eq(saved.player_name, "Ada")
	assert_eq(saved.server_url, "ws://127.0.0.1:47931")
	var again := _open()
	assert_eq((again.get_node("%Name") as LineEdit).text, "Ada", "the next run's name")
	assert_eq((again.get_node("%Server") as LineEdit).text, "ws://127.0.0.1:47931")


func test_a_server_is_a_ws_address() -> void:
	_open()
	(_node("%Name") as LineEdit).text = "Ada"
	for bad: String in ["http://127.0.0.1:47923", "127.0.0.1:47923", "", "ws://eve@host/ws"]:
		(_node("%Server") as LineEdit).text = bad
		(_node("%Create") as Button).pressed.emit()
		assert_eq(_status(), "The server must be a ws:// or wss:// address.", bad)
	assert_eq(_asked, [] as Array[OnlineLink])


## In a browser the server is the page's own: the field is gone and nothing of it saved.
func test_a_page_plays_on_its_own_server() -> void:
	_open(true)
	assert_false((_node("%Server") as LineEdit).is_visible_in_tree())
	assert_false((_node("%ServerLabel") as Label).is_visible_in_tree())
	(_node("%Name") as LineEdit).text = "Ada"
	(_node("%Create") as Button).pressed.emit()
	assert_eq(_asked.size(), 1)
	assert_eq(_asked[0].server_url, "wss://ship.example.org/ws")
	assert_eq(OnlineSettings.read(SETTINGS_PATH).server_url, "", "the page's is not remembered")


## Typed in either case, a code goes in upper case; letters a code never has, and
## anything but letters, stay out. Backspace clears back; the last letter moves on to
## Join.
func test_a_code_is_typed_in_any_case() -> void:
	_open()
	(_node("%Name") as LineEdit).text = "Bea"
	var code: CodePicker = _node("%Code")
	code.first_slot().grab_focus()
	_type("ki7o-xr")
	assert_eq(code.code(), "KXR", "I, O, digits and marks are left out")
	_type("t")
	assert_eq(code.code(), "KXRT")
	assert_eq(get_viewport().gui_get_focus_owner(), _node("%Join"), "on to Join")
	(_node("%Join") as Button).pressed.emit()
	assert_eq(_asked.size(), 1)
	assert_false(_asked[0].create)
	assert_eq(_asked[0].room, "KXRT")
	code.get_child(3).grab_focus()
	var backspace := InputEventKey.new()
	backspace.pressed = true
	backspace.keycode = KEY_BACKSPACE
	get_viewport().push_input(backspace)
	assert_eq(code.code(), "KXR")
	(_node("%Join") as Button).pressed.emit()
	assert_eq(_status(), "A room code is 4 letters, as the room's host sees it.")
	assert_eq(_asked.size(), 1, "a short code is not asked for")


## With a pad: pressing a slot takes it up, up and down turn its letter, round the ends,
## left and right carry it to the next slot, and pressing again puts it down — then up
## and down move on through the screen as anywhere else.
func test_a_code_is_picked_with_a_pad() -> void:
	_open()
	# Laid out, so the focus has somewhere to go below the row.
	await wait_process_frames(2)
	var code: CodePicker = _node("%Code")
	var first := code.first_slot()
	first.grab_focus()
	_act(&"ui_accept")
	assert_true(first.button_pressed, "taken up")
	_act(&"ui_up")
	_act(&"ui_up")
	assert_eq(code.code(), "B")
	_act(&"ui_down")
	_act(&"ui_down")
	assert_eq(code.code(), "Z", "round the ends")
	_act(&"ui_right")
	var second: Button = code.get_child(1)
	assert_true(second.has_focus() and second.button_pressed, "the next slot taken up")
	assert_false(first.button_pressed)
	_act(&"ui_up")
	assert_eq(code.code(), "ZA")
	_act(&"ui_accept")
	assert_false(second.button_pressed, "put down")
	_act(&"ui_down")
	assert_false(second.has_focus(), "down leaves the row")


func test_a_pasted_code_fills_the_slots() -> void:
	_open()
	var code: CodePicker = _node("%Code")
	code.set_code(" kx-rt ")
	assert_eq(code.code(), "KXRT")
	code.set_code("ab")
	assert_eq(code.code(), "AB", "the slots past it emptied")


## A page's link to a room plays at once when its name is known — the link's own or the
## one remembered — and asks for the name otherwise, the code filled in.
func test_a_link_to_a_room_asks_for_a_name_it_does_not_know() -> void:
	var rules := ServerRules.load_default()
	var link := OnlineLink.from_page("?room=kxrt", "https:", "ship.example.org", rules)
	_open(true)
	_menu.take_link(link)
	await wait_process_frames(1)
	assert_eq(_asked, [] as Array[OnlineLink], "no name, no join")
	assert_eq((_node("%Code") as CodePicker).code(), "KXRT", "the code filled in")
	assert_string_contains(_status(), "Choose a name")
	assert_true((_node("%Name") as LineEdit).has_focus())
	_menu.queue_free()
	var settings := OnlineSettings.new()
	settings.player_name = "Bea"
	assert_eq(settings.save(SETTINGS_PATH), OK)
	_open(true)
	_menu.take_link(link)
	await wait_process_frames(1)
	assert_eq(_asked.size(), 1, "a name remembered joins at once")
	assert_eq(_asked[0].room, "KXRT")
	assert_eq(_asked[0].player_name, "Bea", "the remembered name, not the link's default")


## A page's link is anyone's to share, and may carry a name: it never stands in for the
## visitor's own, and it is played under — shown in the field — but not remembered when
## the visitor has none.
func test_a_links_name_never_replaces_the_one_remembered() -> void:
	var rules := ServerRules.load_default()
	var link := OnlineLink.from_page("?room=kxrt&name=Eve", "https:", "ship.example.org", rules)
	_open(true)
	_menu.take_link(link)
	await wait_process_frames(1)
	assert_eq(_asked.size(), 1, "a named link joins at once")
	assert_eq(_asked[0].player_name, "Eve")
	assert_eq((_node("%Name") as LineEdit).text, "Eve", "shown in the field")
	assert_eq(OnlineSettings.read(SETTINGS_PATH).player_name, "", "and not remembered")
	_menu.queue_free()
	_asked.clear()
	var settings := OnlineSettings.new()
	settings.player_name = "Bea"
	assert_eq(settings.save(SETTINGS_PATH), OK)
	_open(true)
	_menu.take_link(link)
	await wait_process_frames(1)
	assert_eq(_asked.size(), 1)
	assert_eq(_asked[0].player_name, "Bea", "the visitor's own name")
	assert_eq((_node("%Name") as LineEdit).text, "Bea")
	assert_eq(OnlineSettings.read(SETTINGS_PATH).player_name, "Bea", "still remembered")


## The remembered file is the player's to edit, and so anyone's: read as plain JSON, and
## each value kept only when it is one the screen could have saved.
func test_what_is_remembered_is_checked_as_it_is_read() -> void:
	var tampered: Array[String] = [
		'{"player_name": "<b>Eve</b>", "server_url": "javascript:alert(1)"}',
		'{"player_name": 7, "server_url": ["ws://127.0.0.1:47931"]}',
		'["Ada", "ws://127.0.0.1:47931"]',
		'[gd_resource type="Resource" format=3]\n[resource]\nplayer_name = "Ada"',
		'{"player_name": "Ada", "pad": "%s"}' % "x".repeat(OnlineSettings.MAX_BYTES),
	]
	for text: String in tampered:
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		var read := OnlineSettings.read(SETTINGS_PATH)
		assert_eq(read.player_name, "", text.left(60))
		assert_eq(read.server_url, "", text.left(60))
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string('{"player_name": "Ada", "server_url": "javascript:alert(1)"}')
	file.close()
	var mixed := OnlineSettings.read(SETTINGS_PATH)
	assert_eq(mixed.player_name, "Ada", "a good value kept beside a bad one")
	assert_eq(mixed.server_url, "")


func test_a_link_with_a_problem_says_it() -> void:
	_open(true)
	var link := OnlineLink.from_page(
		"?room=ABCI&name=Ada", "https:", "ship.example.org", ServerRules.load_default()
	)
	_menu.take_link(link)
	await wait_process_frames(1)
	assert_eq(_asked, [] as Array[OnlineLink])
	assert_eq(_status(), link.problems[0])


## Connecting, the choices wait and Back is the way out; what went wrong comes back with
## Rejoin when there is a room to go back to.
func test_connecting_then_rejoining() -> void:
	_open()
	(_node("%Name") as LineEdit).text = "Bea"
	_menu.show_connecting()
	assert_true((_node("%Create") as Button).disabled)
	assert_true((_node("%Back") as Button).has_focus())
	(_node("%Create") as Button).pressed.emit()
	assert_eq(_asked, [] as Array[OnlineLink], "nothing while connecting")
	_menu.open(OnlinePlay.LOST, "KXRT")
	assert_eq(_status(), OnlinePlay.LOST)
	var rejoin: Button = _node("%Rejoin")
	assert_true(rejoin.visible and rejoin.has_focus())
	rejoin.pressed.emit()
	assert_eq(_asked.size(), 1)
	assert_eq(_asked[0].room, "KXRT")
	_menu.open()
	assert_false(rejoin.visible, "no room, no Rejoin")


func test_back_and_cancel_leave() -> void:
	_open()
	watch_signals(_menu)
	(_node("%Back") as Button).pressed.emit()
	_act(&"ui_cancel")
	assert_signal_emit_count(_menu, "back_requested", 2)
