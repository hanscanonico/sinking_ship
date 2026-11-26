class_name PlayDriver
extends Node
## Plays the game for someone who is not at the keys (`make play`, --play=DIR): an agent
## sat in the local seat, taking turns with the game. It reads batches of commands from
## DIR/in/NNNN.txt, one after another from 0001, runs each batch — keys, mouse and
## action presses injected as the events a keyboard and a mouse would send, frames let
## run, frames saved — and answers each in DIR/out/NNNN.txt with what a player would
## know then: the text on the screen, where each button is, the local seat as the
## latest snapshot has it — and the ghost, while the view walks as one —, what happened
## to her and to the seat since, the frames saved
## (DIR/shots). Between
## batches nothing moves: the game is held on its frame until the next batch comes, so
## however long the player thinks, the match has not gone on without them. Launched with
## --fixed-fps, a frame is one tick, and `wait 30` is a second of the match.
##
## The window takes neither the keys nor the mouse of whoever is at the machine, and the
## match never holds their pointer: every event is the driver's. A session nobody feeds
## for [member idle_seconds] quits, so a player gone leaves no window behind.
##
## Under a CrewClock (--crew, make crew) it runs each frame in step with the crew — a
## server and the other played sessions — so while its batch is awaited every one of
## them is held as well: an online match stands still for whoever is thinking.
##
## Commands, one a line, `#` to the line's end a comment (tools/play.sh sends them):
##   wait N                  let N frames run
##   shot [NAME]             save the next frame drawn as DIR/shots/NNNN_NAME.png
##   hold ACTION             press what the input map binds ACTION to, and keep it down
##   release ACTION | all    let it go; all, everything held
##   tap ACTION [FRAMES]     press it, FRAMES frames (2), let it go
##   key NAME [down|up]      a key by its name (Escape, Tab, Enter, A); tapped when neither
##   type TEXT               the text typed, a key a character
##   turn DEG [UP]           the mouse moved as far as turns the look DEG to the right and
##                           UP degrees up, at the saved sensitivity
##   mouse DX DY             the mouse moved by that many pixels
##   point X Y               the pointer put at X, Y of the frame saved
##   click X Y [right]       a click there
##   click "TEXT" [right]    a click on the button, tab or field showing TEXT
##   until text "TEXT" [N]   frames run until TEXT shows on the screen, N at most (600)
##   until gone "TEXT" [N]   … until it no longer shows
##   until live|over|out [N] … until the match is live, has ended, the local seat is out
##   quit                    the game quits
## A command that cannot be run ends its batch there, and the answer says why.


## What the match's PointerCapture holds instead of the machine's mouse.
class Pointer:
	extends RefCounted
	var mouse_mode := Input.MOUSE_MODE_VISIBLE


const DEFAULT_IDLE_SECONDS := 600.0
const UNTIL_FRAMES := 600
## Frames a shot waits to be drawn before it is given up: a window the system stopped
## drawing (DrawWatch).
const SHOT_FRAMES := 300
const TAP_FRAMES := 2
## The lines an answer keeps of the screen's text and of what happened.
const SCREEN_LINES := 160
const EVENT_LINES := 60
const TEXT_LENGTH := 140
## How long the held game sleeps between looks for the next batch, in milliseconds.
const POLL_MS := 20
## Before every node of the scene: what a batch presses is down for the frame's own.
const FIRST := -1000

## Seconds the game waits for a batch before it quits.
var idle_seconds := DEFAULT_IDLE_SECONDS

var _dir: String
var _batch := 0
var _queue: Array[PackedStringArray] = []
## Whether the batch being run has been answered.
var _answered := true
var _failure := ""
var _notes: PackedStringArray = []
var _shots: PackedStringArray = []
var _events: PackedStringArray = []
var _events_dropped := 0
var _event_tick := -1
## Frames left to let run before the next command.
var _frames := 0
## The condition frames run until, its frames left; empty for none.
var _until: PackedStringArray = []
var _until_frames := 0
## The shot waiting for its frame, and the frames it has waited.
var _shot_path := ""
var _shot_waited := 0
## What is held down, by what named it: the event to let go.
var _held: Dictionary[String, InputEvent] = {}
var _pointer := Pointer.new()
var _pointer_at := Vector2.ZERO
var _match: MatchScene
var _closing := false
## The crew's clock (--crew); null when this session's frames are its own.
var _crew: CrewClock
## When a free seat began running on with no batch, in msec; -1 when it is not.
var _free_since := -1


func _init(dir: String, idle: float = DEFAULT_IDLE_SECONDS, crew_dir: String = "") -> void:
	_dir = dir.trim_suffix("/")
	idle_seconds = idle
	if not crew_dir.is_empty():
		_crew = CrewClock.new(crew_dir, _dir.get_file())
	name = "PlayDriver"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = FIRST


func _ready() -> void:
	for sub: String in ["in", "out", "shots"]:
		DirAccess.make_dir_recursive_absolute(_dir.path_join(sub))
	for sub: String in ["in", "out"]:
		for file: String in DirAccess.get_files_at(_dir.path_join(sub)):
			DirAccess.remove_absolute(_dir.path_join(sub).path_join(file))
	var window := get_window()
	window.set_flag(Window.FLAG_NO_FOCUS, true)
	window.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)
	_pointer_at = Vector2(window.size) / 2.0
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)
	_write(_dir.path_join("ready"), "user data: %s\n" % OS.get_user_data_dir())
	print("play: taking batches from %s/in" % _dir)


func _exit_tree() -> void:
	DirAccess.remove_absolute(_dir.path_join("ready"))
	if _crew != null:
		_crew.leave()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_closing = true


func _process(_delta: float) -> void:
	if _crew != null:
		_crew.tick()
	_gather_events()
	if not _shot_path.is_empty():
		_shot_waited += 1
		if _shot_waited > SHOT_FRAMES:
			_fail("shot: no frame drawn in %d frames: is the window in sight?" % SHOT_FRAMES)
			_shot_path = ""
		else:
			return
	if _frames > 0:
		_frames -= 1
		return
	if not _until.is_empty():
		if not _met(_until) and _until_frames > 0:
			_until_frames -= 1
			return
		if not _met(_until):
			_notes.append("until %s: not within its frames" % " ".join(_until))
		_until = []
	while true:
		if _queue.is_empty():
			if not _answered:
				_answer()
			if _runs_free():
				return
			if not _take_batch():
				get_tree().quit()
				return
		if not _run(_queue.pop_front()):
			return


## Runs one command; whether the next may run in the same frame.
func _run(words: PackedStringArray) -> bool:
	var rest := words.slice(1)
	var again := true
	match words[0]:
		"wait":
			_frames = maxi(_number(rest, 0, 1.0) as int, 1) - 1
			again = false
		"shot":
			var label := rest[0].validate_filename() if not rest.is_empty() else "shot"
			_shot_path = _dir.path_join("shots/%04d_%s.png" % [_batch, label])
			_shot_waited = 0
			again = false
		"hold":
			if _need(rest, 1, "hold ACTION"):
				_press_action(rest[0])
		"release":
			if _need(rest, 1, "release ACTION|all"):
				if rest[0] == "all":
					_release_all()
				else:
					_release(rest[0])
		"tap":
			if _need(rest, 1, "tap ACTION [FRAMES]") and _press_action(rest[0]):
				var frames := str(maxi(_number(rest, 1, TAP_FRAMES) as int, 1))
				_first(["wait " + frames, "release " + rest[0], "wait 1"])
		"key":
			_key(rest)
		"type":
			for at in " ".join(rest).length():
				var typed := InputEventKey.new()
				typed.unicode = " ".join(rest).unicode_at(at)
				_send_pair(typed)
		"turn":
			var per_pixel := ViewSettings.local().mouse_deg_per_pixel
			var up := -_number(rest, 1, 0.0) * (-1.0 if ViewSettings.local().invert_y else 1.0)
			_move_mouse(Vector2(_number(rest, 0, 0.0), up) / per_pixel)
		"mouse":
			_move_mouse(Vector2(_number(rest, 0, 0.0), _number(rest, 1, 0.0)))
		"point":
			_point(_shot_to_window(Vector2(_number(rest, 0, 0.0), _number(rest, 1, 0.0))))
		"click":
			_click(rest)
		"until":
			if _need(rest, 1, "until text|gone|live|over|out"):
				var numbered := rest[-1].is_valid_int() and rest.size() > 1
				_until_frames = rest[-1].to_int() if numbered else UNTIL_FRAMES
				_until = rest.slice(0, -1) if numbered else rest
				again = false
		"quit":
			_answer()
			get_tree().quit()
			again = false
		_:
			_fail("unknown command: %s" % " ".join(words))
	return again


## Whether this frame runs on with no batch: a crew's free seat (DIR/free, tools/crew.sh
## free) plays on while its next batch is awaited — what it holds held still — rather
## than holding the crew. A free seat left unfed for [member idle_seconds] quits.
func _runs_free() -> bool:
	if _closing:
		return false
	var next := _dir.path_join("in/%04d.txt" % (_batch + 1))
	if (
		_crew == null
		or FileAccess.file_exists(next)
		or not FileAccess.file_exists(_dir.path_join("free"))
	):
		_free_since = -1
		return false
	if _free_since < 0:
		_free_since = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _free_since <= idle_seconds * 1000.0:
		return true
	print("play: no batch for %d s: quitting" % roundi(idle_seconds))
	_closing = true
	return false


## The next batch's commands, waited for with the game held; false when the wait is over
## with none — nobody fed it, or the window was closed.
func _take_batch() -> bool:
	var path := _dir.path_join("in/%04d.txt" % (_batch + 1))
	var since := Time.get_ticks_msec()
	while not FileAccess.file_exists(path):
		if _closing:
			return false
		if Time.get_ticks_msec() - since > idle_seconds * 1000.0:
			print("play: no batch for %d s: quitting" % roundi(idle_seconds))
			return false
		OS.delay_msec(POLL_MS)
		if _crew != null:
			_crew.hold()
		# The window still answers the system while the game is held.
		DisplayServer.process_events()
	_batch += 1
	_answered = false
	_failure = ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var words := split_words(line.get_slice("#", 0))
		if not words.is_empty():
			_queue.append(words)
	if _queue.is_empty():
		_queue.append(PackedStringArray(["wait", "1"]))
	return true


## [param line] as its words, a "quoted one" kept whole.
static func split_words(line: String) -> PackedStringArray:
	var words: PackedStringArray = []
	var parts := line.strip_edges().split('"')
	for at in parts.size():
		if at % 2 == 1:
			words.append(parts[at])
		else:
			words.append_array(parts[at].split(" ", false))
	return words


func _first(lines: Array) -> void:
	for at in range(lines.size() - 1, -1, -1):
		_queue.push_front(split_words(lines[at]))


func _need(rest: PackedStringArray, count: int, usage: String) -> bool:
	if rest.size() < count:
		_fail("usage: %s" % usage)
		return false
	return true


func _number(rest: PackedStringArray, at: int, otherwise: float) -> float:
	return rest[at].to_float() if at < rest.size() and rest[at].is_valid_float() else otherwise


## The batch stops here, and its answer says [param why].
func _fail(why: String) -> void:
	_failure = why
	_queue.clear()


func _press_action(action: String) -> bool:
	if not InputMap.has_action(action):
		_fail("no action %s; the map has: %s" % [action, ", ".join(_actions())])
		return false
	if _held.has(action):
		return true
	var event: InputEvent = null
	for bound: InputEvent in InputMap.action_get_events(action):
		if bound is InputEventKey or bound is InputEventMouseButton:
			event = bound.duplicate()
			break
	if event == null:
		var plain := InputEventAction.new()
		plain.action = action
		event = plain
	if event is InputEventMouseButton:
		(event as InputEventMouseButton).position = _pointer_at
	_set_pressed(event, true)
	_held[action] = event
	Input.parse_input_event(event)
	return true


func _actions() -> PackedStringArray:
	var names: PackedStringArray = []
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			names.append(action)
	return names


func _release(held: String) -> void:
	if not _held.has(held):
		return
	var event: InputEvent = _held[held].duplicate()
	_held.erase(held)
	_set_pressed(event, false)
	Input.parse_input_event(event)


func _release_all() -> void:
	for held: String in _held.keys():
		_release(held)


func _set_pressed(event: InputEvent, pressed: bool) -> void:
	if event is InputEventKey:
		(event as InputEventKey).pressed = pressed
	elif event is InputEventMouseButton:
		(event as InputEventMouseButton).pressed = pressed
	elif event is InputEventAction:
		(event as InputEventAction).pressed = pressed


func _key(rest: PackedStringArray) -> void:
	if not _need(rest, 1, "key NAME [down|up]"):
		return
	var code := OS.find_keycode_from_string(rest[0])
	if code == KEY_NONE:
		_fail("no key called %s (Escape, Enter, Tab, Space, Up, A…)" % rest[0])
		return
	var held := "key " + rest[0]
	var way := rest[1] if rest.size() > 1 else "tap"
	if way == "up":
		_release(held)
		return
	if not _held.has(held):
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = true
		_held[held] = event
		Input.parse_input_event(event)
	if way == "tap":
		_first(["wait %d" % TAP_FRAMES, "key %s up" % rest[0], "wait 1"])


func _send_pair(event: InputEventKey) -> void:
	event.pressed = true
	Input.parse_input_event(event)
	var up: InputEventKey = event.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _move_mouse(by: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _pointer_at
	motion.global_position = _pointer_at
	motion.relative = by
	motion.screen_relative = by
	Input.parse_input_event(motion)


func _point(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = at - _pointer_at
	motion.screen_relative = at - _pointer_at
	_pointer_at = at
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)


func _click(rest: PackedStringArray) -> void:
	if not _need(rest, 1, 'click X Y [right] | click "TEXT" [right]'):
		return
	var at: Vector2
	var more := rest.slice(2)
	if rest[0].is_valid_float():
		at = _shot_to_window(Vector2(_number(rest, 0, 0.0), _number(rest, 1, 0.0)))
	else:
		more = rest.slice(1)
		var found := _control_showing(rest[0])
		if found == null:
			_fail('click: nothing on the screen shows "%s"' % rest[0])
			return
		at = _window_point(found)
	_point(at)
	var button := MOUSE_BUTTON_RIGHT if more.has("right") else MOUSE_BUTTON_LEFT
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.position = at
	press.global_position = at
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_RIGHT if more.has("right") else MOUSE_BUTTON_MASK_LEFT
	var held := "click:%d" % button
	_held[held] = press
	Input.parse_input_event(press)
	_first(["wait 1", "release " + held, "wait 1"])


## Window pixels to those of a saved frame and back: the frame is the root viewport's
## texture, the window stretched over it.
func _shot_to_window(at: Vector2) -> Vector2:
	var shot := Vector2(get_viewport().get_texture().get_size())
	return at * Vector2(get_window().size) / shot


func _window_to_shot(at: Vector2) -> Vector2:
	var shot := Vector2(get_viewport().get_texture().get_size())
	return at * shot / Vector2(get_window().size)


## The middle of [param control], in window pixels.
func _window_point(control: Control) -> Vector2:
	var middle := control.get_global_transform_with_canvas() * (control.size / 2.0)
	return control.get_viewport().get_final_transform() * middle


func _met(condition: PackedStringArray) -> bool:
	var snapshot := _snapshot()
	var met := true
	match condition[0]:
		"text":
			met = condition.size() > 1 and _shows(condition[1])
		"gone":
			met = condition.size() > 1 and not _shows(condition[1])
		"live":
			met = snapshot.get("phase", -1) == MatchState.Phase.LIVE
		"over":
			met = snapshot.get("phase", -1) == MatchState.Phase.ENDED
		"out":
			met = not snapshot.is_empty() and snapshot["seats"][MatchScene.LOCAL_SEAT]["out"]
		_:
			_fail("until: no condition %s" % condition[0])
	return met


func _snapshot() -> Dictionary:
	if not is_instance_valid(_match) or not _match.is_inside_tree():
		return {}
	return _match.current()


func _on_node_added(node: Node) -> void:
	if node is PointerCapture:
		(node as PointerCapture).device = _pointer
	elif node is MatchScene:
		_match = node


func _on_frame_drawn() -> void:
	if _shot_path.is_empty():
		return
	var path := _shot_path
	_shot_path = ""
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error == OK:
		_shots.append(path)
	else:
		_fail("shot: %s: %s" % [path, error_string(error)])


func _gather_events() -> void:
	var snapshot := _snapshot()
	if snapshot.is_empty() or snapshot["tick"] == _event_tick:
		return
	_event_tick = snapshot["tick"]
	for event: Dictionary in snapshot["events"]:
		if not tells(event):
			continue
		if _events.size() >= EVENT_LINES:
			_events_dropped += 1
			continue
		_events.append(event_line(event))


## Whether an answer tells of [param event]: what happens to her, who goes out, how the
## match ends, and whatever the local seat does or has done to it — never the bots'
## brawl among themselves, a hundred shoves a minute.
static func tells(event: Dictionary) -> bool:
	if event["kind"] in [SimEvent.Kind.SEAT_OUT, SimEvent.Kind.MATCH_ENDED]:
		return true
	var local := MatchScene.LOCAL_SEAT
	return event["seat"] < 0 or local in [event["seat"], event["target"], event["credit"]]


## One sim event as a line: its kind, then every field of it that says something.
static func event_line(event: Dictionary) -> String:
	var said: PackedStringArray = []
	for key: String in event:
		var value: Variant = event[key]
		if key in ["kind", "tick"]:
			continue
		# A seat, a prop or a railing nobody named is -1; seat 0 is the local player.
		if (value is int and value < 0) or (value is float and value == 0.0):
			continue
		if value is int and value == 0 and key in ["place", "cause", "stagger"]:
			continue
		if (value is String or value is StringName) and str(value).is_empty():
			continue
		said.append("%s=%s" % [key, value])
	var kind: String = SimEvent.Kind.keys()[event["kind"]]
	return "%s %s %s" % [MatchTranscript.clock(event["tick"]), kind, " ".join(said)]


func _answer() -> void:
	_answered = true
	var lines: PackedStringArray = []
	var verdict := "ok" if _failure.is_empty() else "FAILED: " + _failure
	lines.append("batch %04d %s (frame %d)" % [_batch, verdict, Engine.get_process_frames()])
	for note: String in _notes:
		lines.append("note: " + note)
	for shot: String in _shots:
		lines.append("shot: " + shot)
	if not _held.is_empty():
		lines.append("held: " + ", ".join(_held.keys()))
	lines.append_array(match_lines(_snapshot()))
	# The match scene's own ghost, read where it keeps it: its file has no line to spare
	# for a way to ask (gdlint's max-file-lines).
	var ghost: GhostWalk = _match._ghost if is_instance_valid(_match) else null
	if ghost != null and ghost.active:
		lines.append(ghost_line(ghost.body, ghost.look.yaw))
	if not _events.is_empty():
		lines.append("events:")
		for event: String in _events:
			lines.append("  " + event)
		if _events_dropped > 0:
			lines.append("  … and %d more" % _events_dropped)
	lines.append("screen:")
	var screen := _screen_lines()
	for line: String in screen.slice(0, SCREEN_LINES):
		lines.append("  " + line)
	if screen.size() > SCREEN_LINES:
		lines.append("  … and %d more" % (screen.size() - SCREEN_LINES))
	_notes = []
	_shots = []
	_events = []
	_events_dropped = 0
	_write(_dir.path_join("out/%04d.txt" % _batch), "\n".join(lines) + "\n")


## Written whole or not at all: under another name, then renamed.
func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path + ".part", FileAccess.WRITE)
	if file == null:
		push_error("play: cannot write %s" % path)
		return
	file.store_string(text)
	file.close()
	DirAccess.rename_absolute(path + ".part", path)


## The ghost the view walks as (GhostWalk), as a seat's first line says a seat: its
## [param body] in its piece's space and the [param yaw] it looks along — what a walk by
## dead reckoning goes by while the local seat is out, watched or replayed.
static func ghost_line(body: PlayerState, yaw: float) -> String:
	return (
		"ghost: %s at (%.1f, %.1f, %.1f) piece %d surface %d, facing %d°"
		% [
			PlayerState.Body.keys()[body.body],
			body.pos.x,
			body.pos.y,
			body.pos.z,
			body.piece,
			body.surface,
			roundi(rad_to_deg(wrapf(yaw, -PI, PI))),
		]
	)


## The match as the local seat knows it from [param snapshot]: the clock, who is in,
## the seat itself, and the others still in by how near they are — each how far, and how
## many degrees to the right of the seat's facing (negative: to its left).
static func match_lines(snapshot: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if snapshot.is_empty():
		return lines
	var seats: Array = snapshot["seats"]
	var still_in := 0
	for seat: Dictionary in seats:
		still_in += 0 if seat["out"] else 1
	(
		lines
		. append(
			(
				"match: %s tick %d %s, %d of %d in"
				% [
					MatchTranscript.clock(snapshot["tick"]),
					snapshot["tick"],
					MatchState.Phase.keys()[snapshot["phase"]],
					still_in,
					seats.size(),
				]
			)
		)
	)
	var me: Dictionary = seats[MatchScene.LOCAL_SEAT]
	var pos: Vector3 = me["pos"]
	var vel: Vector3 = me["vel"]
	(
		lines
		. append(
			(
				"me: %s at (%.1f, %.1f, %.1f) piece %d surface %d, speed %.1f, facing %d°"
				% [
					PlayerState.Body.keys()[me["state"]],
					pos.x,
					pos.y,
					pos.z,
					me["piece"],
					me["surface"],
					vel.length(),
					roundi(rad_to_deg(me["facing"])),
				]
			)
		)
	)
	(
		lines
		. append(
			(
				"me: action %s, stamina %.0f%s, cold %.2f, bonuses %s%s"
				% [
					PlayerState.Action.keys()[me["action"]],
					me["stamina"],
					" (exhausted)" if me["exhausted"] else "",
					me["cold"],
					me["bonuses"],
					(
						(
							", out %s, place %d"
							% [PlayerState.Cause.keys()[me["out_cause"]], me["place"]]
						)
						if me["out"]
						else ""
					),
				]
			)
		)
	)
	var near: Array[Dictionary] = []
	for seat: Dictionary in seats:
		if seat["out"] or seat["seat"] == me["seat"]:
			continue
		var away: Vector3 = seat["pos"] - pos
		var bearing := wrapf(atan2(away.z, away.x) - me["facing"], -PI, PI)
		(
			near
			. append(
				{
					"far": away.length() if seat["piece"] == me["piece"] else INF,
					"line":
					(
						"seat %d %s %.1f m, %d° right, %.1f m up"
						% [
							seat["seat"],
							PlayerState.Body.keys()[seat["state"]],
							away.length(),
							roundi(rad_to_deg(bearing)),
							away.y,
						]
					),
				}
			)
		)
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["far"] < b["far"])
	for other: Dictionary in near.slice(0, 5):
		lines.append("  " + other["line"])
	return lines


## Every word a player can read on the screen, in tree order, each with the middle of
## its control in the pixels of a saved frame, and what it is when it is not plain text.
func _screen_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var frame := Rect2(Vector2.ZERO, get_viewport().get_texture().get_size())
	for control: Control in _controls(get_tree().root):
		var said := _said(control)
		if said.is_empty():
			continue
		var at := _window_to_shot(_window_point(control))
		if not frame.has_point(at):
			continue
		lines.append("%s @%d,%d" % [said, roundi(at.x), roundi(at.y)])
	return lines


## The controls under [param node] a player can see: shown, and not faded out.
func _controls(node: Node, faded: bool = false) -> Array[Control]:
	var found: Array[Control] = []
	if node is CanvasItem:
		var item := node as CanvasItem
		if not item.visible or item.modulate.a < 0.05 or item.self_modulate.a < 0.05:
			faded = true
	elif node is CanvasLayer and not (node as CanvasLayer).visible:
		faded = true
	if faded:
		return found
	if node is Control:
		found.append(node)
	for child: Node in node.get_children(true):
		found.append_array(_controls(child, faded))
	return found


## What [param control] says to a player: empty when it shows no words.
func _said(control: Control) -> String:
	var said := ""
	if control is BaseButton:
		said = _button_said(control as BaseButton)
	elif control is LineEdit:
		var edit := control as LineEdit
		var hint := _short(_shown(control, edit.placeholder_text))
		said = 'field "%s" (%s)' % [_short(edit.text), hint]
	elif control is Label:
		said = _quoted(_shown(control, (control as Label).text))
	elif control is RichTextLabel:
		said = _quoted((control as RichTextLabel).get_parsed_text())
	elif control is TabBar:
		var bar := control as TabBar
		var tabs: PackedStringArray = []
		for at in bar.tab_count:
			var title := _shown(control, bar.get_tab_title(at))
			tabs.append(("[%s]" if at == bar.current_tab else "%s") % title)
		said = "tabs %s" % " ".join(tabs)
	elif control is Slider or control is SpinBox:
		var ranged := control as Range
		var kind := control.get_class().to_lower()
		said = "%s %s (%s…%s)" % [kind, ranged.value, ranged.min_value, ranged.max_value]
	elif control is ProgressBar:
		said = "bar %d%%" % roundi(100.0 * (control as ProgressBar).ratio)
	if not said.is_empty() and control.has_focus():
		said += " [focus]"
	return said


func _button_said(button: BaseButton) -> String:
	var text := (button as Button).text if button is Button else ""
	if text.is_empty():
		text = button.tooltip_text if not button.tooltip_text.is_empty() else button.name
	var kind := "button"
	if button is OptionButton:
		kind = "choice"
	elif button is CheckBox or button is CheckButton or button.toggle_mode:
		kind = "tick [x]" if button.button_pressed else "tick [ ]"
	var off := " (disabled)" if button.disabled else ""
	return '%s "%s"%s' % [kind, _short(_shown(button, text)), off]


## [param text] in quotes, or nothing when it has no words.
func _quoted(text: String) -> String:
	return '"%s"' % _short(text) if not text.strip_edges().is_empty() else ""


## [param control]'s [param text] as the screen shows it: in the language played.
func _shown(control: Control, text: String) -> String:
	return control.atr(text) if control.can_auto_translate() else text


func _short(text: String) -> String:
	var flat := " ".join(text.split("\n", false)).strip_edges()
	return flat if flat.length() <= TEXT_LENGTH else flat.left(TEXT_LENGTH) + "…"


func _shows(text: String) -> bool:
	return _control_showing(text) != null


## The control on the screen saying [param text], in the language played or the one its
## words are written in: the one saying exactly that before one that only has it in what
## it says, whatever the case.
func _control_showing(text: String) -> Control:
	var wanted := text.to_lower()
	var within: Control = null
	for control: Control in _controls(get_tree().root):
		var said := _plain(control).to_lower()
		var shown := _shown(control, _plain(control)).to_lower()
		if said == wanted or shown == wanted:
			return control
		var has := said.contains(wanted) or shown.contains(wanted)
		if within == null and not wanted.is_empty() and has:
			within = control
	return within


func _plain(control: Control) -> String:
	if control is BaseButton:
		# A button with no words is named in the answer as _button_said names it.
		var text := (control as Button).text if control is Button else ""
		if text.is_empty():
			text = control.tooltip_text if not control.tooltip_text.is_empty() else control.name
		return text
	if control is Label:
		return (control as Label).text
	if control is LineEdit:
		var edit := control as LineEdit
		return edit.text if not edit.text.is_empty() else edit.placeholder_text
	if control is RichTextLabel:
		return (control as RichTextLabel).get_parsed_text()
	return ""
