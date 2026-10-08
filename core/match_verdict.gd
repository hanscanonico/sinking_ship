class_name MatchVerdict
extends RefCounted
## How the sea settles a match and how its seats are placed (§5b.1, D4): who the sea
## puts out on a tick, and each seat's place as it goes out, the match ending with one
## seat or none left. MatchSim asks it each tick, after the water, in seat order.


## The seats of [param live] — the seats on one piece of her (Pieces, SH33): every seat,
## while she does not break — who go out with that piece on [param tick]: on the tick it
## is gone ([param gone_tick]), whoever is still inside it, in seat order, as
## [param pose_now] has its cells — the frame the tick stands in on it (SH32).
static func gone_with(
	live: Array[PlayerState], pose_now: ShipPose, tick: int, gone_tick: int
) -> Array[PlayerState]:
	var going: Array[PlayerState] = []
	for player: PlayerState in live:
		if tick == gone_tick and pose_now.cell_at(player.pos) != CellMap.NONE:
			going.append(player)
	return going


## The seats of [param left] — every seat still in that no piece took with it
## (gone_with) — the sea puts out once nothing but the cold can change: every one of them
## swims and [param sunk] says every surface of her still standing is wade_depth under
## the sea (Surfaces.sunk, asked only then). They all go out by the cold, but for the one
## with the most cold left when it has the most alone. A tie for the most is a draw, the
## sea's; the places go by the cold they had left (place). Nothing else ends a match: on a
## wreck that keeps dry footing — on her side on the bottom, or upside down on her air —
## it goes on until one seat is left, however long (Q21).
static func by_the_cold(left: Array[PlayerState], sunk: Callable) -> Array[PlayerState]:
	var going: Array[PlayerState] = []
	if left.size() < 2:
		return going
	for player: PlayerState in left:
		if player.body != PlayerState.Body.SWIMMING:
			return going
	if not sunk.call():
		return going
	var most := 0.0
	var warmest := 0
	for player: PlayerState in left:
		if player.cold > most:
			most = player.cold
			warmest = 0
		if player.cold == most:
			warmest += 1
	for player: PlayerState in left:
		if warmest > 1 or player.cold != most:
			going.append(player)
	return going


## Places [param exits], the seats out of [param state]'s match on [param tick], into
## [param events]: seats out on the same tick share a place, unless their cold meters
## differ — more cold left places higher. One or none left ends the match.
static func place(
	state: MatchState, exits: Array[PlayerState], tick: int, events: Array[SimEvent]
) -> void:
	if exits.is_empty():
		return
	var remaining := state.remaining()
	for player: PlayerState in exits:
		var warmer := 0
		for other: PlayerState in exits:
			if other.cold > player.cold:
				warmer += 1
		player.place = remaining + 1 + warmer
		events.append(
			SimEvent.seat_out(
				tick,
				player.seat,
				player.place,
				player.out_cause,
				player.last_hit_by,
				player.last_hit_crate
			)
		)
	if remaining > 1:
		return
	state.phase = MatchState.Phase.ENDED
	var winner := state.winner()
	if winner != -1:
		state.seats[winner].place = 1
	events.append(SimEvent.match_ended(tick, winner))
