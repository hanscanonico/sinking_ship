class_name MatchArgs
extends RefCounted
## The user arguments a match host takes after `--`:
##   --seed=N  --seats=N  --ship=NAME  --stop=MM:SS  --hit=PATH  --autoplay  --capture=PATH
##   --capture-at=S
##   --observer  --capture-eye=SEAT  --observer-cut=M  --observer-cells  --greybox
##   --observer-side=starboard|port
##   --net-sim=latency:MS,jitter:MS,loss:PERCENT
##   --server  --port=N  --bind=ADDRESS  --matches=N
##   --connect=ws://HOST:PORT  --create | --room=CODE  --name=NAME  --start-at=N
##   --capture-screen=SCREEN  --capture-from=X,Y,Z,YAW[,PITCH]  --capture-sway=S
##   --quality=low|medium|high  --render-scale=F  --bake-budget=MS  --phys=H:MM:SS  --jump
## The game reads --seed, --seats and --ship as the menu's choices — --ship a ship of
## the Fleet, by name, played in her open-sea scenario; --stop (or --seconds, in
## seconds) is the match time a headless run is stopped at and reported unfinished — a
## tool's limit, never a rule of the match; --hit strikes her with the explicit hit
## the IcebergHit at PATH is, past the must-sink rule (§5b.1), so a tool can play a
## chosen sinking; --autoplay presses its
## Play, and without it --capture saves the menu. A capture is taken from the
## observer camera unless --capture-eye names the seat whose eyes it looks through;
## --observer opens the observer camera for QA, --observer-cut cuts its view of
## the ship away to show the inside, and --observer-cells draws the ship's cells over
## it, every one named, framing the whole ship; --observer-side has it watch from her
## port side rather than her starboard; --greybox draws the greybox the rules' data
## makes in place of the dressed ship; --net-sim makes the wire between the local host
## and the client lie about latency, jitter and loss (SH11); --capture-screen stages a
## screen for the capture: menu, settings (over the menu), graphics (the settings on
## their Graphics page), pause, results, online (the Online screen), room (a room, its
## players made up), online-pause (the online pause over the match), online-settings
## (the settings opened from it) or hold (the countdown held for a slow bake, its bar
## half way); --capture-from stands the capture's eyes on chosen feet in ship space,
## looking YAW degrees from the bow toward starboard and PITCH above the horizon;
## --capture-sway holds the menu
## backdrop's drift at S (-1…1, one end of its sway to the other); --quality and
## --render-scale draw this run as if the settings screen had chosen them, to measure
## or capture a choice (make fps); --bake-budget gives a held countdown's sinking that
## many milliseconds of each frame to bake in, to measure the hold or show it (R20);
## --phys takes a capture at that moment of physics time after the hit rather than at
## --capture-at's match time, and with --jump the match starts a little before it —
## every seat on what is dry then (MatchJump) — rather than hours of brawl before it.
## No menu reaches any of them (D14). --server serves
## rooms over WebSocket, headless, on --port and --bind (ServerRules' unless given),
## its matches' seeds drawn from --seed when given — its rooms' codes never are — until
## --matches matches have finished (forever at 0); --connect plays in a server's room,
## --create making one or --room joining one by its code, as --name (SH12): a person at
## the keys, the Online screen opened on them (OnlineLink checks every one of them), or
## with --autoplay a bot, headless, whose creator starts the match once --start-at
## players are in.

## -1 when not given: the host picks one.
var seed_value: int = -1
## 0 when not given: the match data's seat count.
var seats: int = 0
## A ship of the Fleet, by name; empty when not given: the match data's.
var ship_name: StringName = &""
## How much match time a headless run may take before it stops, unfinished (STOP=,
## est. 15:00).
var seconds: float = 900.0
## An explicit hit's .tres to strike her with; empty for the match's own.
var hit_path: String = ""
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
## The ship's cells drawn over the observer's view (CellOverlay): a tool, never a
## player's view.
var observer_cells: bool = false
## Which side of her the observer camera watches from.
var observer_side := ObserverCamera.Beam.STARBOARD
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
## The screen a capture shows over or instead of the match; empty for the match alone.
var capture_screen: String = ""
## Where a capture's eyes stand and look: x, y, z of the feet in ship space, yaw and
## pitch in degrees; empty for the seat's own.
var capture_from := PackedFloat64Array()
## Where a capture holds the menu backdrop's drift, -1…1; NAN to let it drift.
var capture_sway := NAN
## The graphics preset and render scale this run draws with whatever is saved;
## ViewSettings.AUTOMATIC when not given.
var quality: int = ViewSettings.AUTOMATIC
var render_scale: float = ViewSettings.AUTOMATIC
## Milliseconds of each frame a held countdown's bake may take; 0 for the game's own.
var bake_budget_ms := 0.0
## The moment of the sinking a capture is taken at, in physics seconds after the hit;
## -1 for none. Whether the match jumps there rather than plays there.
var phys_seconds := -1.0
var jump := false


## The seconds [param text] says: mm:ss, h:mm:ss or plain seconds.
static func clock_seconds(text: String) -> float:
	var seconds := 0.0
	for part: String in text.split(":"):
		seconds = seconds * 60.0 + part.to_float()
	return seconds


## [param scenario] struck by the explicit hit --hit names, or itself without one.
func struck(scenario: SinkScenario) -> SinkScenario:
	if hit_path.is_empty():
		return scenario
	var given: SinkScenario = scenario.duplicate()
	given.explicit_hit = _hit()
	return given


## What is wrong with the arguments for a match: a --ship the Fleet has not, a --hit
## that names no IcebergHit.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if not ship_name.is_empty() and Fleet.layout(ship_name) == null:
		found.append(
			"--ship: no ship called %s; the fleet has %s" % [ship_name, ", ".join(Fleet.names())]
		)
	if not hit_path.is_empty() and _hit() == null:
		found.append("--hit: %s is not an IcebergHit" % hit_path)
	return found


func _hit() -> IcebergHit:
	if not ResourceLoader.exists(hit_path):
		return null
	return load(hit_path) as IcebergHit


static func parse(args: PackedStringArray) -> MatchArgs:
	var parsed := MatchArgs.new()
	for arg: String in args:
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--seed":
				parsed.seed_value = value.to_int()
			"--seats":
				parsed.seats = value.to_int()
			"--ship":
				parsed.ship_name = StringName(value)
			"--seconds":
				parsed.seconds = value.to_float()
			"--stop":
				parsed.seconds = clock_seconds(value)
			"--hit":
				parsed.hit_path = value
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
			"--observer-cells":
				parsed.observer_cells = true
			"--observer-side":
				parsed.observer_side = ObserverCamera.Beam.keys().find(value.to_upper())
				if parsed.observer_side < 0:
					push_warning("--observer-side takes starboard or port, not %s" % value)
					parsed.observer_side = ObserverCamera.Beam.STARBOARD
			"--greybox":
				parsed.greybox = true
			"--capture-screen":
				parsed.capture_screen = value
			"--capture-from":
				parsed.capture_from = value.split_floats(",")
			"--capture-sway":
				parsed.capture_sway = value.to_float()
			"--quality":
				parsed.quality = GraphicsQuality.Preset.keys().find(value.to_upper())
				if parsed.quality == ViewSettings.AUTOMATIC:
					push_warning("--quality takes low, medium or high, not %s" % value)
			"--render-scale":
				parsed.render_scale = value.to_float()
			"--bake-budget":
				parsed.bake_budget_ms = value.to_float()
			"--phys":
				parsed.phys_seconds = clock_seconds(value)
			"--jump":
				parsed.jump = true
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
