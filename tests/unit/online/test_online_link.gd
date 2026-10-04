extends GutTest
## A browser's way in (SH12): the page's address names the room and the player, the
## server at the page's own origin unless it names another, and every part of it is
## hostile input — a problem shown, never a connection. Natively the flags say the same
## and are checked the same.

var _rules := ServerRules.load_default()


func test_a_page_joins_a_room_at_its_own_origin() -> void:
	var link := OnlineLink.from_page("?room=abcd&name=Ada", "https:", "ship.example.org", _rules)
	assert_true(link.wanted)
	assert_eq(link.problems, PackedStringArray())
	assert_eq(link.server_url, "wss://ship.example.org/ws", "wss under an https page")
	assert_false(link.create)
	assert_eq(link.room, "ABCD", "a code however it is cased")
	assert_eq(link.player_name, "Ada")


func test_a_page_creates_a_room_on_the_server_it_names() -> void:
	var link := OnlineLink.from_page(
		"?create=1&name=Ada+Lovelace&server=ws%3A%2F%2F127.0.0.1%3A47985",
		"http:",
		"127.0.0.1:47984",
		_rules
	)
	assert_eq(link.problems, PackedStringArray())
	assert_true(link.create)
	assert_eq(link.room, "")
	assert_eq(link.player_name, "Ada Lovelace", "+ and %XX undone")
	assert_eq(link.server_url, "ws://127.0.0.1:47985")
	var own := OnlineLink.from_page("?create=1", "http:", "127.0.0.1:47984", _rules)
	assert_eq(own.server_url, "ws://127.0.0.1:47984/ws", "ws under an http page")
	assert_eq(own.player_name, "Player", "a name when none is given")


## A link anyone can share must not send its visitors to someone else's server: a
## deployed page plays on a server of its own host whatever `server=` says, and only a
## page on the loopback — a local test — may name any.
func test_a_page_plays_on_its_own_host_alone() -> void:
	for named: String in ["wss://eve.example.net/ws", "ws://127.0.0.1:47985", "wss://example.org"]:
		var link := OnlineLink.from_page(
			"?room=ABCD&server=" + named.uri_encode(), "https:", "ship.example.org", _rules
		)
		assert_eq(link.problems, PackedStringArray(), named)
		assert_eq(link.server_url, "wss://ship.example.org/ws", "%s is not followed" % named)
	var own := OnlineLink.from_page(
		"?room=ABCD&server=wss://Ship.Example.org:8443/game", "https:", "ship.example.org", _rules
	)
	assert_eq(own.server_url, "wss://Ship.Example.org:8443/game", "the page's own host is")
	for page: String in ["127.0.0.1:47984", "localhost:47984", "localhost"]:
		var local := OnlineLink.from_page(
			"?room=ABCD&server=wss://eve.example.net/ws", "http:", page, _rules
		)
		assert_eq(local.server_url, "wss://eve.example.net/ws", "a page on %s names any" % page)
	var native := OnlineLink.from_args(
		MatchArgs.parse(PackedStringArray(["--connect=wss://eve.example.net/ws", "--create"])),
		_rules
	)
	assert_eq(native.server_url, "wss://eve.example.net/ws", "the native flags are the player's")


## A server address is a ws:// or wss:// scheme in lower case, a DNS name of letters,
## digits and inner hyphens or an IPv4 address in four decimal parts, an optional port
## of 1 to 65535 in digits, and a plain path with no dot segment.
func test_a_server_address_is_plain() -> void:
	for good: String in [
		"ws://127.0.0.1:47923",
		"wss://ship.example.org/ws",
		"ws://localhost:8080/ws",
		"wss://xn--bcher-kva.example/a_b/c.d~e-f",
		"ws://10.0.0.255/",
		"ws://0.0.0.0:1",
		"ws://a:65535",
	]:
		assert_true(OnlineLink.is_server_url(good), good)
	for bad: String in [
		"WS://ship.example.org/ws",
		"Wss://ship.example.org/ws",
		"data:text/html,x",
		"ws://-/ws",
		"ws://-ship.example.org/ws",
		"ws://ship-.example.org/ws",
		"ws://ship.-example.org/ws",
		"ws://ship.example.org./ws",
		"ws://.ship.example.org/ws",
		"ws://ship..example.org/ws",
		"ws://.../ws",
		"ws://" + "a".repeat(64) + ".example.org/ws",
		"ws://ship.example.org/../ws",
		"ws://ship.example.org/ws/..",
		"ws://ship.example.org/./ws",
		"ws://0x7f000001/ws",
		"ws://0x7f.0.0.1/ws",
		"ws://0177.0.0.1/ws",
		"ws://2130706433/ws",
		"ws://127.1/ws",
		"ws://1.2.3.256/ws",
		"ws://1.2.3.4.5/ws",
		"ws://ship.example.0x10/ws",
		"ws://ship.example.org:0/ws",
		"ws://ship.example.org:+80/ws",
		"ws://ship.example.org:-80/ws",
		"ws://ship.example.org:65536/ws",
		"ws://ship.example.org\\@eve.example.net/ws",
		"ws://ship\\.example.org/ws",
		"ws://ship .example.org/ws",
		"ws://ship.example.org /ws",
		"ws://ship\t.example.org/ws",
		"ws://ship\n.example.org/ws",
		"ws://ship%c.example.org/ws" % char(1),
		"ws://ship%c.example.org/ws" % char(0x7F),
	]:
		assert_false(OnlineLink.is_server_url(bad), "%s is refused" % bad.c_escape())


func test_a_page_naming_no_room_plays_offline() -> void:
	for query: String in ["", "?", "?utm_source=mail&ref=x", "?roomy=ABCD"]:
		var link := OnlineLink.from_page(query, "https:", "ship.example.org", _rules)
		assert_false(link.wanted, "%s is not an online link" % query)


func test_hostile_pages_are_refused() -> void:
	var hostile: Array[String] = [
		"?room=ABC",
		"?room=ABCI",
		"?room=%41%42%43%44%45",
		"?room=AB%00D",
		"?room=ABCD&create=1",
		"?create=yes",
		"?room=ABCD&room=EFGH",
		"?name=Ada",
		"?room=ABCD&name=",
		"?room=ABCD&name=%3Cscript%3E",
		"?room=ABCD&name=Zo%C3%AB",
		"?room=ABCD&name=Ad%0Aa",
		"?room=ABCD&name=" + "N".repeat(_rules.name_length + 1),
		"?room=ABCD&server=http://ship.example.org/ws",
		"?room=ABCD&server=javascript:alert(1)",
		"?room=ABCD&server=ws://eve@ship.example.org/ws",
		"?room=ABCD&server=ws://ship.example.org:99999/ws",
		"?room=ABCD&server=ws://ship.example.org:/ws",
		"?room=ABCD&server=ws://ship.example.org/ws?x=1",
		"?room=ABCD&server=ws://ship.example.org/ws%23x",
		"?room=ABCD&server=ws://[::1]:80/ws",
		"?room=ABCD&server=ws://ship.example.org/w s",
		"?room=ABCD&server=ws://",
		"?room=ABCD&server=data:text/html,x",
		"?room=ABCD&server=WS://ship.example.org/ws",
		"?room=ABCD&server=ws://ship.example.org:0/ws",
		"?room=ABCD&server=ws://ship.example.org:%2B80/ws",
		"?room=ABCD&server=ws://ship.example.org%5C@eve.example.net/ws",
		"?room=ABCD&server=ws://ship%09.example.org/ws",
		"?room=ABCD&server=ws://ship%01.example.org/ws",
		"?room=ABCD&server=ws://ship.example.org./ws",
		"?room=ABCD&server=ws://0x7f000001/ws",
		"?room=ABCD&server=wss://" + "a".repeat(OnlineLink.MAX_URL),
		"?room=ABCD&pad=" + "x".repeat(OnlineLink.MAX_QUERY),
	]
	for query: String in hostile:
		var link := OnlineLink.from_page(query, "https:", "ship.example.org", _rules)
		assert_true(link.wanted, "%s is meant for online play" % query.left(60))
		assert_false(link.problems.is_empty(), "%s is refused" % query.left(60))


func test_a_page_off_the_web_needs_a_server_named() -> void:
	var link := OnlineLink.from_page("?room=ABCD", "file:", "", _rules)
	assert_false(link.problems.is_empty())
	assert_eq(link.server_url, "", "nothing to connect to")


func test_the_native_flags_are_checked_the_same() -> void:
	var good := OnlineLink.from_args(
		MatchArgs.parse(
			PackedStringArray(["--connect=ws://127.0.0.1:47923", "--room=abcd", "--name=Bea"])
		),
		_rules
	)
	assert_true(good.wanted)
	assert_eq(good.problems, PackedStringArray())
	assert_eq(good.room, "ABCD")
	assert_eq(good.server_url, "ws://127.0.0.1:47923")
	for flags: PackedStringArray in [
		PackedStringArray(["--connect=http://127.0.0.1:47923", "--create"]),
		PackedStringArray(["--connect=ws://127.0.0.1:47923"]),
		PackedStringArray(["--connect=ws://127.0.0.1:47923", "--create", "--name=<b>"]),
	]:
		var link := OnlineLink.from_args(MatchArgs.parse(flags), _rules)
		assert_false(link.problems.is_empty(), " ".join(flags))
	assert_false(
		OnlineLink.from_args(MatchArgs.parse(PackedStringArray(["--seed=1701"])), _rules).wanted
	)


## A page asking for nothing online still has a server: the one its Online screen plays
## on.
func test_a_page_names_its_own_server_for_the_online_screen() -> void:
	var link := OnlineLink.from_page("", "https:", "ship.example.org", _rules)
	assert_false(link.wanted)
	assert_eq(link.server_url, "wss://ship.example.org/ws")
	assert_eq(OnlineLink.from_page("", "file:", "", _rules).server_url, "", "none off the web")
	assert_false(OnlineLink.from_page("?room=ABCD", "https:", "s.example", _rules).named)
	assert_true(OnlineLink.from_page("?room=ABCD&name=Bea", "https:", "s.example", _rules).named)
	var named := OnlineLink.from_page(
		"?server=ws://127.0.0.1:47985", "http:", "127.0.0.1:47984", _rules
	)
	assert_false(named.wanted, "a server alone opens the menu")
	assert_eq(named.server_url, "ws://127.0.0.1:47985", "to play there")
	var elsewhere := OnlineLink.from_page(
		"?server=wss://eve.example.net/ws", "https:", "ship.example.org", _rules
	)
	assert_eq(elsewhere.server_url, "wss://ship.example.org/ws", "on the page's host alone")


## A page naming a server that is not one: a link that asks to play says so, and the
## Online screen still plays on the page's own server — never on none.
func test_a_page_naming_a_bad_server_keeps_its_own() -> void:
	for query: String in [
		"?server=javascript:alert(1)",
		"?server=",
		"?room=ABCD&server=http://ship.example.org/ws",
		"?create=1&name=Ada&server=ws://",
		"?room=ABCD&server=wss://" + "a".repeat(OnlineLink.MAX_URL),
	]:
		var link := OnlineLink.from_page(query, "https:", "ship.example.org", _rules)
		assert_eq(link.server_url, "wss://ship.example.org/ws", query.left(60))
	var wanted := OnlineLink.from_page(
		"?room=ABCD&server=javascript:alert(1)", "https:", "ship.example.org", _rules
	)
	assert_eq(wanted.problems, PackedStringArray(["The server must be a ws:// or wss:// address."]))


## What the Online screen makes is checked as every link is.
func test_the_online_screen_links_are_checked_the_same() -> void:
	var made := OnlineLink.from_menu("ws://127.0.0.1:47923", false, "kxrt", " Bea ", _rules)
	assert_eq(made.problems, PackedStringArray())
	assert_true(made.wanted and made.named)
	assert_eq(made.room, "KXRT")
	assert_eq(made.player_name, "Bea")
	var creating := OnlineLink.from_menu("ws://127.0.0.1:47923", true, "KXRT", "Bea", _rules)
	assert_eq(creating.problems, PackedStringArray(), "a code beside Create is no problem")
	assert_eq(creating.room, "")
	for bad: Array in [
		["http://127.0.0.1:47923", true, "", "Bea"],
		["ws://127.0.0.1:47923", false, "KXR", "Bea"],
		["ws://127.0.0.1:47923", false, "KXRT", "<b>"],
	]:
		assert_false(
			OnlineLink.from_menu(bad[0], bad[1], bad[2], bad[3], _rules).problems.is_empty()
		)


## The name rule the player is shown is the one the server holds names to.
func test_the_name_rule_is_the_servers() -> void:
	var rule := OnlineLink.name_rule(_rules)
	assert_string_contains(rule, str(_rules.name_length))
	for mark: String in ServerRules.NAME_PUNCTUATION.strip_edges():
		assert_string_contains(rule, mark)
		assert_eq(_rules.clean_name("A" + mark + "B"), "A" + mark + "B", "%s is taken" % mark)


## An invite brings a friend to the room on the page's server — and names it only when it
## is not the page's own — and never carries a name: whoever opens it chooses theirs.
func test_an_invite_names_the_room_and_never_the_player() -> void:
	assert_eq(
		OnlineLink.invite("https:", "ship.example.org", "/", "wss://ship.example.org/ws", "KXRT"),
		"https://ship.example.org/?room=KXRT"
	)
	var local := OnlineLink.invite(
		"http:", "127.0.0.1:47984", "/index.html", "ws://127.0.0.1:47985", "KXRT"
	)
	assert_eq(
		local, "http://127.0.0.1:47984/index.html?room=KXRT&server=ws%3A%2F%2F127.0.0.1%3A47985"
	)
	var back := OnlineLink.from_page(local.get_slice("?", 1), "http:", "127.0.0.1:47984", _rules)
	assert_eq(back.problems, PackedStringArray(), "it plays back")
	assert_eq(back.room, "KXRT")
	assert_eq(back.server_url, "ws://127.0.0.1:47985")
	assert_false(back.named, "and asks the friend's name")
	assert_eq(
		OnlineLink.invite("https:", "s.example", "/a/../<x>", "wss://s.example/ws", "KXRT"),
		"https://s.example/?room=KXRT",
		"a path that is not plain is left out"
	)
