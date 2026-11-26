class_name CrewClock
extends RefCounted
## One clock for a crew of games on one machine (`make crew`, --crew=DIR): a --server and
## the sessions agents play by turns (PlayDriver), each a process of its own, stepped a
## frame at a time together. A session holds its game while its player thinks; under one
## clock that holds everyone — the server's beats and every other player's match — so
## however long any one agent takes over a turn, the online match has not gone on
## without them, and no connection falls silent for want of frames.
##
## Each member keeps DIR/NAME.clock: its process id and the frames it has run. A member
## runs its next frame once no other member has run fewer, so the crew is never more
## than a frame apart, and one member held — a session waiting on its next batch — holds
## the rest a frame on. A member that joins starts at the crew's frame, never pulling it
## back. A member says it is still there at least every HEARTBEAT_MS, while it waits on
## the crew as well as while it is held (hold()); one whose file has said nothing for
## STALE_SECONDS — its process gone — is struck off, its file removed.
##
## A crew's sockets wait out a held crew: a member's WebSocket handshakes may take
## HANDSHAKE_SECONDS (WebSocketTransport.handshake_override), where the rules' few
## seconds of the time of day would drop a player who dialled while another thought.

const SUFFIX := ".clock"
## How long a waiting member sleeps between looks at the crew, in milliseconds.
const POLL_MS := 1
## How often a waiting or held member rewrites its file, in milliseconds.
const HEARTBEAT_MS := 1000
## A member's file unwritten this long is a member gone: past the longest frame a game
## takes, a match built and dressed.
const STALE_SECONDS := 120
const HANDSHAKE_SECONDS := 3600.0

var _dir: String
var _name: String
var _path: String
var _pid: int
## The frames this member has run; -1 before it joined.
var _frames := -1
## When this member's file was last written, in msec.
var _written := -1


## A member of the crew whose clock is the folder [param dir], called [param member_name].
## It sets its process up as a crew's ([param whole_process]): handshakes that wait out a
## held crew, and frames no faster than the ticks, so a free seat plays on at the time
## of day and the crew with it. A test's members leave the process as it is.
func _init(dir: String, member_name: String, whole_process: bool = true) -> void:
	_dir = dir.trim_suffix("/")
	_name = member_name.validate_filename()
	_path = _dir.path_join(_name + SUFFIX)
	_pid = OS.get_process_id()
	if whole_process:
		WebSocketTransport.handshake_override = HANDSHAKE_SECONDS
		Engine.max_fps = Ticks.RATE


## Waits until this member may run its next frame, and counts it run.
func tick() -> void:
	if _frames < 0:
		DirAccess.make_dir_recursive_absolute(_dir)
		_frames = joining_frame(_read().values())
	var checked := Time.get_ticks_msec()
	while true:
		var crew := _read()
		if not crew.has("") and may_step(_frames, crew.values()):
			break
		hold()
		if Time.get_ticks_msec() - checked >= HEARTBEAT_MS:
			_strike_off_the_gone()
			checked = Time.get_ticks_msec()
		OS.delay_msec(POLL_MS)
	_frames += 1
	_write()


## Says this member is still there while it is held outside tick() — a session waiting
## on its next batch — at most once every HEARTBEAT_MS.
func hold() -> void:
	if _frames >= 0 and Time.get_ticks_msec() - _written >= HEARTBEAT_MS:
		_write()


## The frames this member has run.
func frames() -> int:
	return maxi(_frames, 0)


## Leaves the crew: nobody waits on this member again.
func leave() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


## Whether a member that has run [param own] frames may run its next, the others having
## run [param others]: once none has run fewer.
static func may_step(own: int, others: Array) -> bool:
	for frames_run: Variant in others:
		if (frames_run as int) < own:
			return false
	return true


## The frames a member joining a crew whose members have run [param others] counts as
## run: the most any has, so it never holds them back to its own start.
static func joining_frame(others: Array) -> int:
	var most := 0
	for frames_run: Variant in others:
		most = maxi(most, frames_run as int)
	return most


## Whether a member whose file was last written at [param modified] has gone by
## [param now], both in seconds of the Unix epoch.
static func is_stale(modified: int, now: float) -> bool:
	return modified > 0 and now - modified > STALE_SECONDS


## What "PID FRAMES" in a member's file says, as [pid, frames]; [] when it says nothing
## readable — a file caught being written.
static func parse(text: String) -> Array[int]:
	var words := text.strip_edges().split(" ", false)
	if words.size() != 2 or not words[0].is_valid_int() or not words[1].is_valid_int():
		return []
	return [words[0].to_int(), words[1].to_int()]


## The other members by name, the frames each has run; a "" key when one could not be
## read just then.
func _read() -> Dictionary:
	var crew := {}
	for file: String in DirAccess.get_files_at(_dir):
		if not file.ends_with(SUFFIX) or file == _name + SUFFIX:
			continue
		# Bytes, not text: a file caught being written can read as garbage.
		var said := parse(
			FileAccess.get_file_as_bytes(_dir.path_join(file)).get_string_from_ascii()
		)
		if said.is_empty():
			crew[""] = 0
		else:
			crew[file.trim_suffix(SUFFIX)] = said[1]
	return crew


func _write() -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file != null:
		file.store_string("%d %d\n" % [_pid, _frames])
		file.close()
	_written = Time.get_ticks_msec()


## Removes the file of every member that has said nothing for STALE_SECONDS. (The
## engine can tell only of the processes it started whether they still run.)
func _strike_off_the_gone() -> void:
	var now := Time.get_unix_time_from_system()
	for file: String in DirAccess.get_files_at(_dir):
		if not file.ends_with(SUFFIX) or file == _name + SUFFIX:
			continue
		var path := _dir.path_join(file)
		if is_stale(FileAccess.get_modified_time(path), now):
			print("crew: %s is gone; the clock goes on without it" % file.trim_suffix(SUFFIX))
			DirAccess.remove_absolute(path)
