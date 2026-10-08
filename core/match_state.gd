class_name MatchState
extends RefCounted
## Everything about a match that changes as it is played. MatchSim mutates it;
## to_dict() is the snapshot's state (D5).

enum Phase { COUNTDOWN, LIVE, ENDED }

## The next tick to be stepped.
var tick: int
var phase: Phase = Phase.COUNTDOWN
var match_seed: int
## The match stream (spawn shuffle). Its state is part of the snapshot.
var rng: RandomNumberGenerator
## Indexed by seat id, ascending.
var seats: Array[PlayerState] = []
## The ship's loose cargo, indexed as [member ShipLayout.props] (SH10).
var props: Array[PropState] = []
## Per railing of the layout, the hits it has left; a span at 0 is broken (SH10).
var railing_hp := PackedFloat64Array()
## Per piece of her (Pieces, SH33; the whole ship alone while she does not break), which
## of its axes the match stands on there as up (Faces.Up, SH32): whose faces are floors,
## and the frame the facing, look and move of every seat on it are in; -1 for a piece she
## has not broken into yet.
var up := PackedInt32Array([Faces.Up.DECK])
## The last stepped tick's events: hints for presentation, not state.
var events: Array[SimEvent] = []


func remaining() -> int:
	var count := 0
	for player: PlayerState in seats:
		if not player.is_out():
			count += 1
	return count


## The last seat in once the match has ended, or -1 (still playing, or a draw).
func winner() -> int:
	if phase != Phase.ENDED:
		return -1
	for player: PlayerState in seats:
		if not player.is_out():
			return player.seat
	return -1


## The frame the seat of [param entry] — a seat of [param snapshot] — stands in: its
## piece's (Faces.Up).
static func up_of(snapshot: Dictionary, entry: Dictionary) -> int:
	return snapshot["up"][entry["piece"]]


## The railings, by index, that the match has broken.
func broken_railings() -> PackedInt32Array:
	return broken_in(railing_hp)


## The railings, by index, broken in [param hp] — a snapshot's "railing_hp".
static func broken_in(hp: PackedFloat64Array) -> PackedInt32Array:
	var broken := PackedInt32Array()
	for index in hp.size():
		if hp[index] <= 0.0:
			broken.append(index)
	return broken


func to_dict(version: int) -> Dictionary:
	var seat_entries: Array[Dictionary] = []
	for player: PlayerState in seats:
		seat_entries.append(player.to_dict())
	var prop_entries: Array[Dictionary] = []
	for crate: PropState in props:
		prop_entries.append(crate.to_dict())
	var event_entries: Array[Dictionary] = []
	for event: SimEvent in events:
		event_entries.append(event.to_dict())
	return {
		"v": version,
		"tick": tick,
		"seed": match_seed,
		"phase": phase,
		"rng": rng.state,
		"seats": seat_entries,
		"props": prop_entries,
		"railing_hp": railing_hp.duplicate(),
		"up": Array(up),
		"events": event_entries,
	}
