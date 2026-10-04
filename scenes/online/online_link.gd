class_name OnlineLink
extends RefCounted
## Where a person playing online goes, and as whom (SH12): a server's address, a room
## to create or a code to join, and a display name. Natively it comes from the flags
## --connect=ws://HOST:PORT, --create or --room=CODE, and --name; in a browser, from
## the page's own address — `?room=ABCD&name=Ada` joins, `?create=1&name=Ada` creates —
## on the server at the page's origin under SERVER_PATH, unless `?server=wss://…`
## names another on the page's own host — any, for a page on the loopback. All of it
## is hostile input: the query is bounded, a code must be code letters, a name one the
## server takes, and a server a ws:// or wss:// address with a plain host, a port and
## a path. Whatever is wrong is a problem to show the player, never a connection made.

## Where the reverse proxy in front of a deployed server upgrades to its WebSocket.
const SERVER_PATH := "/ws"
## The longest page query and server address read at all.
const MAX_QUERY := 512
const MAX_URL := 256
## The query's keys this reads; any other is left to the page.
const KEYS: Array[String] = ["server", "room", "create", "name"]
## A host's characters besides letters and digits: names and IPv4 addresses only.
const HOST_PUNCTUATION := ".-"
## A DNS name's longest, and its labels'.
const MAX_HOST := 253
const MAX_LABEL := 63
## The hosts a page may be on to name a server on another: a local test's.
const LOOPBACK_HOSTS: Array[String] = ["127.0.0.1", "localhost"]
## A path's characters besides letters and digits.
const PATH_PUNCTUATION := "/._~-"

## Whether this launch asks to play online at all.
var wanted := false
var server_url := ""
var create := false
## The room to join, upper case; "" when creating one.
var room := ""
var player_name := ""
## What is wrong with the link, for the player: empty when it can be played.
var problems := PackedStringArray()


## This launch's link: the page's address in a browser, the flags [param args] holds
## anywhere else.
static func for_launch(args: MatchArgs) -> OnlineLink:
	var rules := ServerRules.load_default()
	if not OS.has_feature("web"):
		return from_args(args, rules)
	return from_page(
		str(JavaScriptBridge.eval("window.location.search", true)),
		str(JavaScriptBridge.eval("window.location.protocol", true)),
		str(JavaScriptBridge.eval("window.location.host", true)),
		rules
	)


## The link the native flags in [param args] make: wanted once --connect names a server.
static func from_args(args: MatchArgs, rules: ServerRules) -> OnlineLink:
	var link := OnlineLink.new()
	link.wanted = not args.connect_url.is_empty()
	if not link.wanted:
		return link
	link._check(args.connect_url, args.create_room, args.room_code, args.player_name, rules)
	return link


## The link a page's address makes: [param query] is its `location.search`, and
## [param page_protocol] and [param page_host] its `location.protocol` and `location.host`
## — where the server is unless the query says. Wanted once the query names any of KEYS.
static func from_page(
	query: String, page_protocol: String, page_host: String, rules: ServerRules
) -> OnlineLink:
	var link := OnlineLink.new()
	if query.length() > MAX_QUERY:
		link.wanted = true
		link.problems.append("The page's address is too long to read.")
		return link
	var values := {}
	for pair: String in query.trim_prefix("?").split("&", false):
		var key := _decoded(pair.get_slice("=", 0))
		if not key in KEYS:
			continue
		if values.has(key):
			link.problems.append("The address names %s more than once." % key)
		values[key] = _decoded(pair.substr(pair.find("=") + 1)) if pair.contains("=") else ""
	link.wanted = not values.is_empty()
	if not link.wanted:
		return link
	var create_value: String = values.get("create", "")
	if values.has("create") and create_value != "1":
		link.problems.append("create takes 1, as in create=1.")
	# A server on another host is left unfollowed rather than refused: a link anyone
	# can share must not send its visitors to someone else's server.
	var server: String = values.get("server", "")
	if not values.has("server") or (is_server_url(server) and not _may_name(server, page_host)):
		server = _page_server(page_protocol, page_host)
	link._check(
		server, values.has("create"), values.get("room", ""), values.get("name", "Player"), rules
	)
	return link


## Whether [param url] is a server this reaches: ws:// or wss:// in lower case, a host
## _is_host takes, an optional port and an optional plain path — nothing else, at most
## MAX_URL characters.
static func is_server_url(url: String) -> bool:
	if url.length() > MAX_URL:
		return false
	var rest := ""
	if url.begins_with("ws://"):
		rest = url.trim_prefix("ws://")
	elif url.begins_with("wss://"):
		rest = url.trim_prefix("wss://")
	else:
		return false
	var slash := rest.find("/")
	var authority := rest if slash < 0 else rest.left(slash)
	var path := "" if slash < 0 else rest.substr(slash)
	if not _is_host(authority.get_slice(":", 0)) or not _is_path(path):
		return false
	if authority.get_slice_count(":") > 2:
		return false
	if authority.contains(":"):
		var port := authority.get_slice(":", 1)
		if not _only(port, "") or port.length() > 5 or not port.is_valid_int():
			return false
		if port.to_int() < 1 or port.to_int() > 0xFFFF:
			return false
	return true


## Whether [param host] is a DNS name — labels of letters, digits and inner hyphens —
## or an IPv4 address of four decimal parts. A browser reads a name whose last label
## is a number, decimal or 0x, as an address in any of its forms: it must be the plain
## one.
static func _is_host(host: String) -> bool:
	if host.is_empty() or host.length() > MAX_HOST or not _only(host, HOST_PUNCTUATION):
		return false
	var labels := host.split(".")
	for label: String in labels:
		if label.is_empty() or label.length() > MAX_LABEL:
			return false
		if label.begins_with("-") or label.ends_with("-"):
			return false
	var last := labels[-1].to_lower()
	if not last.is_valid_int() and not last.begins_with("0x"):
		return true
	if labels.size() != 4:
		return false
	for part: String in labels:
		if not part.is_valid_int() or part.length() > 3:
			return false
		if (part.length() > 1 and part.begins_with("0")) or part.to_int() > 255:
			return false
	return true


## Whether [param path] is empty or a plain one: PATH_PUNCTUATION besides letters and
## digits, and no "." or ".." segment.
static func _is_path(path: String) -> bool:
	if not _only(path, PATH_PUNCTUATION):
		return false
	for segment: String in path.split("/"):
		if segment == "." or segment == "..":
			return false
	return true


## Whether a page on [param page_host] may play on [param server], a server address:
## one on the page's own host, or any for a page on the loopback.
static func _may_name(server: String, page_host: String) -> bool:
	var page := page_host.get_slice(":", 0).to_lower()
	var named := server.get_slice("://", 1).get_slice("/", 0).get_slice(":", 0).to_lower()
	return page in LOOPBACK_HOSTS or named == page


## The server at the page's own origin: wss:// for an https page, ws:// for http.
static func _page_server(page_protocol: String, page_host: String) -> String:
	match page_protocol:
		"https:":
			return "wss://%s%s" % [page_host, SERVER_PATH]
		"http:":
			return "ws://%s%s" % [page_host, SERVER_PATH]
	return ""


## A query part with its `+` and `%XX` escapes undone.
static func _decoded(part: String) -> String:
	return part.replace("+", " ").uri_decode()


## Whether [param text] holds ASCII letters and digits and [param punctuation] alone.
static func _only(text: String, punctuation: String) -> bool:
	for letter: String in text:
		var code := letter.unicode_at(0)
		var alphanumeric := (
			(code >= 0x30 and code <= 0x39)
			or (code >= 0x41 and code <= 0x5A)
			or (code >= 0x61 and code <= 0x7A)
		)
		if not alphanumeric and not punctuation.contains(letter):
			return false
	return true


## Takes up a link's parts, each checked, its problems noted.
func _check(
	server: String, creating: bool, code: String, display_name: String, rules: ServerRules
) -> void:
	if is_server_url(server):
		server_url = server
	else:
		problems.append("The server must be a ws:// or wss:// address.")
	create = creating
	if creating and not code.is_empty():
		problems.append("Create a room or join one, not both.")
	elif not creating:
		room = RoomCodec.normalize_code(code)
		if code.is_empty():
			problems.append("Name a room to join, or create one.")
		elif room.is_empty():
			problems.append(
				"A room code is %d letters, as the room's host sees it." % RoomCodec.CODE_LENGTH
			)
	player_name = rules.clean_name(display_name)
	if player_name.is_empty():
		problems.append(
			(
				"A name is 1 to %d letters, digits, spaces or %s."
				% [rules.name_length, ServerRules.NAME_PUNCTUATION.strip_edges()]
			)
		)
