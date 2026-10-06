class_name MatchVerdict
extends RefCounted
## How the sea settles a match and how its seats are placed (§5b.1, D4): who the sea
## puts out on a tick, and each seat's place as it goes out, the match ending with one
## seat or none left. MatchSim asks it each tick, after the water, in seat order.


## The seats of [param live] the sea puts out on [param tick], in seat order: on the
## tick she is gone ([param gone_tick]), whoever is still inside her goes out with her;
## and once every surface still standing is [param wade_depth] under the sea, as
## [param surfaces] has it under [param pose_now], and every seat left swims — when
## nothing but the cold can change — they all go out by the cold, but for the one with
## the most cold left when it has the most alone. A tie for the most is a draw, the
## sea's; the places go by the cold they had left (place).
static func settled_by_the_sea(
	live: Array[PlayerState],
	pose_now: ShipPose,
	tick: int,
	gone_tick: int,
	surfaces: Surfaces,
	wade_depth: float
) -> Array[PlayerState]:
	var going: Array[PlayerState] = []
	var left: Array[PlayerState] = []
	for player: PlayerState in live:
		if tick == gone_tick and pose_now.cell_at(player.pos) != CellMap.NONE:
			going.append(player)
		else:
			left.append(player)
	if left.size() < 2:
		return going
	for player: PlayerState in left:
		if player.body != PlayerState.Body.SWIMMING:
			return going
	if not surfaces.sunk(pose_now, wade_depth):
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
