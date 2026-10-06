class_name HeldPose
extends SinkSchedule
## A sinking held at one pose, for the suites that try rules against the water and air
## in a ship's cells (SH29's swimming and bots) without a bake: the steamer level, sunk
## so far, some of her cells holding water and some of those a pocket over it, every
## other cell dry. Test data, never a match's: a match's pose is its bake's (D7).

var _held: ShipPose


func _init(pose: ShipPose) -> void:
	super(SimFixtures.calm(), 0.0, RandomNumberGenerator.new())
	_held = pose


func pose_at(_tick: int) -> ShipPose:
	return _held


## [param layout] level, sunk until the sea stands [param sea] m over her main deck: each
## cell named in [param waters] holds water up to the ship-local height its entry gives
## first, and with a second, a pocket over it whose air stands that many metres of sea
## over the atmosphere's; every other cell is dry.
static func flooded(layout: ShipLayout, sea: float, waters: Dictionary) -> ShipPose:
	var origin := -sea
	var pose := ShipPose.new(
		layout.freeboard + sea, 0.0, 0.0, Transform3D(Basis.IDENTITY, Vector3(0.0, origin, 0.0))
	)
	var structure := layout.structure
	var physics := SeaPhysics.load_default()
	var atmosphere := physics.air_pressure / (physics.sea_density * physics.gravity)
	pose.cells = CellMap.new(structure)
	for cell: FloodCell in structure.cells:
		var water: Array = waters.get(cell.name, [cell.low.y])
		pose.levels.append(float(water[0]) + origin)
		pose.pockets.append(atmosphere + float(water[1]) if water.size() > 1 else 0.0)
	return pose


## [param match_sim]'s sinking held at [param pose], its surfaces honouring it.
static func hold(match_sim: MatchSim, pose: ShipPose) -> void:
	match_sim.schedule = HeldPose.new(pose)
	match_sim.surfaces.honour(pose)
