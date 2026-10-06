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


## The snapshot of [param config]'s match jumped to [param tick].
static func snapshot(config: MatchConfig, tick: int) -> Dictionary:
	var sim := MatchSim.create(config)
	var state := sim.state
	state.tick = tick
	if tick >= config.countdown_ticks:
		state.phase = MatchState.Phase.LIVE
	var pose := sim.schedule.pose_at(tick)
	var up := sim.faces.up_at(pose, Faces.Up.DECK)
	state.up = up
	var framed := sim.faces.framed(pose, up)
	var surfaces := sim.faces.surfaces(up)
	if up == Faces.Up.DECK:
		surfaces.honour(pose, state.broken_railings(), state.props)
	else:
		surfaces.honour(framed)
	var step := config.rules.step_height
	var floors := sim.faces.layout(up).platforms
	var dry := _dry_platforms(floors, surfaces, framed, step)
	var into := Faces.to_frame(up)
	var placed := 0
	for player: PlayerState in state.seats:
		var feet := into * player.pos
		if not (_dry(surfaces, framed, feet, step) or dry.is_empty()):
			var platform := floors[dry[placed % dry.size()]]
			var centre := platform.area.get_center()
			var along := (placed / dry.size()) * APART
			var x := clampf(centre.x + along, platform.area.position.x, platform.area.end.x)
			feet = Vector3(x, platform.height, centre.y)
			player.last_look = InputFrame.quantize_yaw(Vector2(-feet.x, -feet.z).angle())
			player.facing = InputFrame.yaw_angle(player.last_look)
			placed += 1
		player.surface = surfaces.under(feet, step)
		player.pos = Faces.to_ship(up) * feet
	return sim.snapshot()


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
