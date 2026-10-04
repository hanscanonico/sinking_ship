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
