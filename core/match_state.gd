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


func to_dict(version: int) -> Dictionary:
	var seat_entries: Array[Dictionary] = []
	for player: PlayerState in seats:
		seat_entries.append(player.to_dict())
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
		"events": event_entries,
	}
