class_name MatchJump
extends RefCounted
## A match begun at a moment of its sinking rather than at its first tick — a tool's,
## never a rule (`make capture … PHYS= JUMP=1`, §5b.4), and valid because the sinking
## never depends on play (D7, Q19). It is the match MatchSim.create starts, moved on to
## that tick and live, standing on whichever of her faces are floors then (Faces, from
## her decks), every seat stood on dry footing: on its own spawn where that is dry, else
## on the dry floors, highest in the world first, each taking its turn, a body's width
## apart along it. Nothing else of the time before is made up: railings whole, crates as
## loaded. A snapshot (D5), which a host and its client start from as from any other.

## Seats sharing one floor stand this far apart along her, in metres.
const APART := 0.9


## The snapshot of [param config]'s match jumped to [param tick]: once she has broken
## (SH33), each seat on the piece of her its spawn stands over — the aft one, where it
## stands in a gap between two — on that piece's own floors.
static func snapshot(config: MatchConfig, tick: int) -> Dictionary:
	var sim := MatchSim.create(config)
	var state := sim.state
	state.tick = tick
	if tick >= config.countdown_ticks:
		state.phase = MatchState.Phase.LIVE
	var pose := sim.schedule.pose_at(tick)
	var step := config.rules.step_height
	var placed := {}
	var dry_of := {}
	for player: PlayerState in state.seats:
		var piece := sim.pieces.piece_at(pose.standing, player.pos.x)
		if piece == -1:
			piece = _aft_of(sim.schedule, pose.standing, player.pos.x)
		player.piece = piece
		var faces := sim.pieces.faces(piece)
		var own := pose.of_piece(piece)
		var up := faces.up_at(own, Faces.Up.DECK)
		var framed := faces.framed(own, up)
		var surfaces := faces.surfaces(up, framed)
		if not dry_of.has(piece):
			state.up[piece] = up
			if up == Faces.Up.DECK:
				sim.pieces.honour(piece, pose, state.broken_railings(), state.props)
			else:
				surfaces.honour(framed)
			dry_of[piece] = _dry_platforms(faces.layout(up).platforms, surfaces, framed, step)
			placed[piece] = 0
		var floors := faces.layout(up).platforms
		var dry: PackedInt32Array = dry_of[piece]
		var into := Faces.to_frame(up)
		var feet := into * player.pos
		if not (_dry(surfaces, framed, feet, step) or dry.is_empty()):
			var at: int = placed[piece]
			var platform := floors[dry[at % dry.size()]]
			var centre := platform.area.get_center()
			var along := (at / dry.size()) * APART
			var x := clampf(centre.x + along, platform.area.position.x, platform.area.end.x)
			feet = Vector3(x, platform.height, centre.y)
			player.last_look = InputFrame.quantize_yaw(Vector2(-feet.x, -feet.z).angle())
			player.facing = InputFrame.yaw_angle(player.last_look)
			placed[piece] = at + 1
		player.surface = surfaces.under(feet, step)
		player.pos = Faces.to_ship(up) * feet
	return sim.snapshot()


## Of [param standing], the piece whose span holds [param x] along her, torn ends and
## all.
static func _aft_of(schedule: SinkSchedule, standing: PackedInt32Array, x: float) -> int:
	for piece: int in standing:
		if x <= schedule.span_of(piece).y:
			return piece
	return standing[standing.size() - 1]


## Whether a body's feet at [param feet] stand on a surface the sea has not reached.
static func _dry(surfaces: Surfaces, pose: ShipPose, feet: Vector3, step: float) -> bool:
	var under := surfaces.under(feet, step)
	return under != Surfaces.NONE and not surfaces.wet(feet, pose)


## The floors of [param floors] whose middles stand dry under [param pose] and hold a
## body there, the highest in the world first, the lower number first between two as
## high.
static func _dry_platforms(
	floors: Array[ShipPlatform], surfaces: Surfaces, pose: ShipPose, step: float
) -> PackedInt32Array:
	var found: Array[Vector2] = []
	for index in floors.size():
		var platform := floors[index]
		var centre := platform.area.get_center()
		var feet := Vector3(centre.x, platform.height, centre.y)
		if _dry(surfaces, pose, feet, step) and surfaces.under(feet, step) == index:
			found.append(Vector2(pose.world_height(feet), index))
	found.sort_custom(
		func(a: Vector2, b: Vector2) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y)
	)
	var made := PackedInt32Array()
	for entry: Vector2 in found:
		made.append(int(entry.y))
	return made
