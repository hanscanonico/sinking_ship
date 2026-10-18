class_name FxProbe
extends RefCounted
## What the sinking's effects suites read (test_fx_planner, test_breach_planner,
## test_sinking_fx, test_breach_fx): the planner driven over a match's ticks, and an
## emitter read for how high, how big and how opaque its grains go. Test data, never a
## match's.


## [param sim]'s snapshot moved to [param tick], carrying [param events]: its seats
## and cargo shared with every other, as the planner only reads them.
static func snapshot_at(sim: MatchSim, tick: int, events: Array[SimEvent] = []) -> Dictionary:
	var snapshot := sim.snapshot().duplicate()
	snapshot["tick"] = tick
	snapshot["phase"] = MatchState.Phase.LIVE
	var entries: Array[Dictionary] = []
	for event: SimEvent in events:
		entries.append(event.to_dict())
	snapshot["events"] = entries
	return snapshot


## What [param planner] shows of [param sim] stepped from [param from] to [param to],
## [param stride] ticks a step.
static func sink(
	planner: FxPlanner, sim: MatchSim, from: int, to: int, stride: int = 1
) -> Array[FxCue]:
	var seen: Array[FxCue] = []
	var previous := snapshot_at(sim, from)
	for tick in range(from + stride, to + 1, stride):
		var current := snapshot_at(sim, tick)
		seen.append_array(planner.plan(previous, current))
		previous = current
	return seen


## What [param planner] shows as the iceberg strikes [param sim].
static func strike(planner: FxPlanner, sim: MatchSim) -> Array[FxCue]:
	var struck := sim.schedule.hit_tick()
	return planner.plan(
		snapshot_at(sim, struck), snapshot_at(sim, struck + 1, [SimEvent.holed(struck)])
	)


## The cues among [param cues] of [param kind].
static func of(cues: Array[FxCue], kind: FxCue.Kind) -> Array[FxCue]:
	return cues.filter(func(cue: FxCue) -> bool: return cue.kind == kind)


## [param cues], each told as a line.
static func described(cues: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for cue: FxCue in cues:
		lines.append(cue.describe())
	return lines


## The emitters of [param fx] that playing [param cues] to [param camera], in
## [param eye_room], set going.
static func played(
	fx: SinkingFx, cues: Array[FxCue], camera: Camera3D, eye_room := -1
) -> Array[CPUParticles3D]:
	fx.clear()
	fx.play(cues, Transform3D(), camera, eye_room)
	return fx.emitters().filter(func(emitter: CPUParticles3D) -> bool: return emitter.emitting)


## The most a grain of [param emitter] climbs over its emitter, in the emitter's own
## up: the depth it starts from, its flight, and its top edge, if it stands up.
static func climb(emitter: CPUParticles3D) -> float:
	var way := emitter.direction.normalized()
	var tilt := maxf(acos(clampf(way.y, -1.0, 1.0)) - deg_to_rad(emitter.spread), 0.0)
	var rising := maxf(cos(tilt), 0.0) * emitter.initial_velocity_max
	var pull := (emitter.global_basis.transposed() * emitter.gravity).y
	var life := emitter.lifetime
	var flight := rising * life + 0.5 * pull * life * life
	if pull < 0.0 and rising / -pull < life:
		flight = rising * rising / (-2.0 * pull)
	var start := 0.0
	if emitter.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX:
		start = emitter.emission_box_extents.y
	elif emitter.emission_shape == CPUParticles3D.EMISSION_SHAPE_SPHERE:
		start = emitter.emission_sphere_radius
	# A grain lying flat stands no higher than its middle.
	var top := 0.0 if lying(emitter) else grain(emitter) * 0.5
	return start + maxf(flight, 0.0) + top


## How big a grain of [param emitter] grows, at most, in metres: a streak drawn out
## along its flight, end to end; any other, the side of a square covering as much as
## it does.
static func grain(emitter: CPUParticles3D) -> float:
	var grown := 1.0
	if emitter.scale_amount_curve != null:
		# Its biggest at any age: white water grows as it flies, the strike's dwindles.
		for age in 11:
			grown = maxf(grown, emitter.scale_amount_curve.sample(age / 10.0))
	var size := side(emitter)
	if emitter.particle_flag_align_y and emitter.mesh is QuadMesh:
		size = (emitter.mesh as QuadMesh).size.y
	return size * emitter.scale_amount_max * grown


## How opaque a grain of [param emitter] is drawn at most anywhere within HUSHED of
## the eye, its material fading it out as it nears (fx_grain.gdshaderinc).
static func near_opacity(emitter: CPUParticles3D) -> float:
	var material := emitter.mesh.surface_get_material(0) as ShaderMaterial
	if material == null:
		return opacity(emitter)
	var from: float = material.get_shader_parameter(&"clear_from")
	var to: float = material.get_shader_parameter(&"clear_to")
	return opacity(emitter) * smoothstep(from, to, SinkingFx.HUSHED)


## Whether [param emitter]'s grains lie flat in its plane.
static func lying(emitter: CPUParticles3D) -> bool:
	return emitter.mesh is QuadMesh and (emitter.mesh as QuadMesh).orientation == PlaneMesh.FACE_Y


## The side of a square covering as much as a grain of [param emitter] does as it is
## born; 0 for one that is not a quad.
static func side(emitter: CPUParticles3D) -> float:
	if not emitter.mesh is QuadMesh:
		return 0.0
	var size := (emitter.mesh as QuadMesh).size
	return sqrt(size.x * size.y)


## How opaque a grain of [param emitter] is drawn at most, wherever it is.
static func opacity(emitter: CPUParticles3D) -> float:
	var peak := 0.0
	for colour: Color in emitter.color_ramp.colors:
		peak = maxf(peak, colour.a)
	return emitter.color.a * peak


## The emitters of [param fx] going whose names begin [param called].
static func going(fx: SinkingFx, called: String) -> Array[CPUParticles3D]:
	return fx.emitters().filter(
		func(emitter: CPUParticles3D) -> bool:
			return emitter.emitting and emitter.name.begins_with(called)
	)
