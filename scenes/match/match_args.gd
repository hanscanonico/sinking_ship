class_name MatchArgs
extends RefCounted
## The user arguments a match host takes after `--`:
##   --seed=N  --seats=N  --seconds=S  --autoplay  --capture=PATH  --capture-at=S
##   --observer  --capture-eye=SEAT  --observer-cut=M  --greybox
##   --net-sim=latency:MS,jitter:MS,loss:PERCENT
##   --server  --port=N  --bind=ADDRESS  --matches=N
##   --connect=ws://HOST:PORT  --create | --room=CODE  --name=NAME  --start-at=N
## The game reads --seed and --seats as the menu's choices; --autoplay presses its
## Play, and without it --capture saves the menu. A capture is taken from the
## observer camera unless --capture-eye names the seat whose eyes it looks through;
## --observer opens the observer camera for QA, and --observer-cut cuts its view of
## the ship away to show the inside; --greybox draws the greybox the rules' data
## makes in place of the dressed ship; --net-sim makes the wire between the local host
## and the client lie about latency, jitter and loss (SH11). No menu reaches any of
## them (D14). --server serves rooms over WebSocket, headless, on --port and --bind
## (ServerRules' unless given), its matches' seeds drawn from --seed when given — its
## rooms' codes never are — until --matches matches have finished (forever at 0);
## --connect plays in a server's room, --create making one or --room joining one by
## its code, as --name (SH12): a person at the keys (OnlinePlay, which checks every one
## of them), or with --autoplay a bot, headless, whose creator starts the match once
## --start-at players are in.

## -1 when not given: the host picks one.
var seed_value: int = -1
## 0 when not given: the match data's seat count.
var seats: int = 0
## How much match time a headless run may take before it stops.
var seconds: float = 300.0
## A bot plays the local seat, and nobody waits at the menu.
var autoplay: bool = false
var capture_path: String = ""
## Match time to save the capture at; -1 for the end of the match.
var capture_at: float = -1.0
## The elevated observer camera instead of the local seat's eyes: a tool, never a
## player's view.
var observer: bool = false
## The seat a capture looks through the eyes of; -1 for the observer camera.
var capture_eye: int = -1
## The observer's cut-away: nothing of the ship standing at or above this
## ship-local height is drawn, and the observer camera watches the whole ship rather
## than one seat. INF draws everything.
var observer_cut: float = INF
## The greybox instead of the dressed ship: a QA tool, never a player's view.
var greybox: bool = false
## What the loopback between the local host and the client pretends the wire does;
## nothing, unless --net-sim says.
var net_sim := NetConditions.new()
## Serve rooms instead of playing.
var server: bool = false
## 0 and "" when not given: ServerRules' port and address.
var port: int = 0
var bind_address: String = ""
## Matches a server finishes before it quits; 0 for no end.
var matches: int = 0
## The server to play on; "" to play here.
var connect_url: String = ""
var create_room: bool = false
var room_code: String = ""
var player_name: String = "Player"
## Players in the room created before its creator starts the match.
var start_at: int = 1


static func parse(args: PackedStringArray) -> MatchArgs:
	var parsed := MatchArgs.new()
	for arg: String in args:
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--seed":
				parsed.seed_value = value.to_int()
			"--seats":
				parsed.seats = value.to_int()
			"--seconds":
				parsed.seconds = value.to_float()
			"--autoplay":
				parsed.autoplay = true
			"--capture":
				parsed.capture_path = value
			"--capture-at":
				parsed.capture_at = value.to_float()
			"--observer":
				parsed.observer = true
			"--capture-eye":
				parsed.capture_eye = value.to_int()
			"--observer-cut":
				parsed.observer_cut = value.to_float()
			"--greybox":
				parsed.greybox = true
			"--net-sim":
				var conditions := NetConditions.parse(value)
				if conditions == null:
					push_warning(
						"--net-sim takes latency:MS,jitter:MS,loss:PERCENT, not %s" % value
					)
				else:
					parsed.net_sim = conditions
			"--server":
				parsed.server = true
			"--port":
				parsed.port = value.to_int()
			"--bind":
				parsed.bind_address = value
			"--matches":
				parsed.matches = value.to_int()
			"--connect":
				parsed.connect_url = value
			"--create":
				parsed.create_room = true
			"--room":
				parsed.room_code = value
			"--name":
				parsed.player_name = value
			"--start-at":
				parsed.start_at = value.to_int()
			_:
				push_warning("unknown argument %s" % arg)
	return parsed
