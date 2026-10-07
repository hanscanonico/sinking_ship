class_name BotView
extends RefCounted
## What a bot perceives (D10): the snapshot from reaction_ticks ago, cut down to the
## bodies it could have perceived from where it stood then — those its eyes see, with
## no wall, deck or hull between (Surfaces.line_of_sight, the HUD's own question), and
## those within its hearing through anything, as a person hears footsteps; in the dark —
## either of them in a cell nothing lights, as the pose has it (SH31) — no farther than
## dark_sight_m — plus where it last perceived each of the others, for as long as it
## remembers; and the ship's
## current pose, the water with it. What a player sees on screen, never the
## schedule's future (Q16, R16). The cargo and the railings' hits left (SH10) come
## through as the delayed snapshot has them: for the MVP every crate is seen, walls or
## not, and only bodies are looked for, heard and remembered.

## Marks a seat's entry that is a memory: where it was last perceived, not where it is.
const REMEMBERED := "remembered"

var _seat: int
var _delay: int
var _eye: float
var _hearing: float
var _dark_sight: float
var _memory_ticks: int
## A body out of earshot is looked at once this many ticks — a think's worth — and
## between looks is where the last one saw it.
var _look_every: int
var _surfaces: Surfaces
var _snapshots: Array[Dictionary] = []
var _pose: ShipPose
## The delayed snapshot as perceived, and the tick it is of.
var _perceived: Dictionary
var _perceived_tick := -1
## Per seat: the tick of the snapshot the next look at it is due on.
var _look_due := {}
## Per seat: its entry when last perceived — marked REMEMBERED once it no longer is —
## and the tick it was.
var _memory := {}
var _memory_tick := {}


func _init(seat: int, profile: BotProfile, surfaces: Surfaces) -> void:
	_seat = seat
	_delay = profile.reaction_ticks
	_eye = profile.eye_height_m
	_hearing = profile.hearing_m
	_dark_sight = profile.dark_sight_m
	_memory_ticks = Ticks.from_seconds(profile.memory_seconds)
	_look_every = profile.think_period
	_surfaces = surfaces


func push(latest: Dictionary, pose_at_latest: ShipPose) -> void:
	_snapshots.append(latest)
	if _snapshots.size() > _delay + 1:
		_snapshots.pop_front()
	_pose = pose_at_latest


func is_empty() -> bool:
	return _snapshots.is_empty()


## The delayed snapshot — the oldest one held while the ring is still filling — with
## only the seats the bot perceives in it, and the ones it remembers.
func snapshot() -> Dictionary:
	var delayed := _snapshots[0]
	if delayed["tick"] != _perceived_tick:
		_perceived = _perceive(delayed)
		_perceived_tick = delayed["tick"]
	return _perceived


func pose() -> ShipPose:
	return _pose


## How many seats are still in the match in the delayed snapshot: the HUD's "Seats
## left", which every player reads on screen, not a sighting.
func seats_left() -> int:
	var left := 0
	for entry: Dictionary in _snapshots[0]["seats"]:
		if not entry["out"]:
			left += 1
	return left


func _perceive(delayed: Dictionary) -> Dictionary:
	var me := {}
	for entry: Dictionary in delayed["seats"]:
		if entry["seat"] == _seat:
			me = entry
	if me.is_empty():
		return delayed
	var tick: int = delayed["tick"]
	var seats: Array[Dictionary] = []
	var whole := true
	for entry: Dictionary in delayed["seats"]:
		var seat: int = entry["seat"]
		if seat == _seat or entry["out"] or _hears(me, entry) or _sees(me, entry, tick):
			seats.append(entry)
			_memory[seat] = entry
			_memory_tick[seat] = tick
			continue
		whole = false
		if _memory.has(seat) and tick - _memory_tick[seat] <= _memory_ticks:
			var last: Dictionary = _memory[seat]
			if not last.has(REMEMBERED):
				last = last.duplicate()
				last[REMEMBERED] = true
				_memory[seat] = last
			seats.append(last)
	if whole:
		return delayed
	var perceived := delayed.duplicate()
	perceived["seats"] = seats
	return perceived


## Whether [param entry] is within the bot's hearing of [param me]: through anything.
func _hears(me: Dictionary, entry: Dictionary) -> bool:
	var my_pos: Vector3 = me["pos"]
	return my_pos.distance_to(entry["pos"]) <= _hearing


## Whether the bot, as [param me], looks at [param entry] in the snapshot of
## [param tick] and nothing stands between their eyes — nor, in the dark, more than
## dark_sight_m.
func _sees(me: Dictionary, entry: Dictionary, tick: int) -> bool:
	var seat: int = entry["seat"]
	if tick < _look_due.get(seat, tick):
		return false
	# Spread over the period, so that every bot does not look at every body at once.
	var offset := (seat + _seat) % _look_every
	_look_due[seat] = tick + _look_every - posmod(tick - offset, _look_every)
	var my_pos: Vector3 = me["pos"]
	var their_pos: Vector3 = entry["pos"]
	var mine := my_pos + Vector3.UP * _eye
	var theirs := their_pos + Vector3.UP * _eye
	var dark := (
		_pose.lit_at(mine) == ShipPower.Power.DARK or _pose.lit_at(theirs) == ShipPower.Power.DARK
	)
	if dark and my_pos.distance_to(their_pos) > _dark_sight:
		return false
	return _surfaces.line_of_sight(mine, theirs, _pose)
