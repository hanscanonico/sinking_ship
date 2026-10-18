class_name BreachFx
extends Node3D
## The breach as seen from inside her (SinkingFx plays the planners' cues of it here):
## the sea jetting in through the gash in a sheet of white water thrown across the room,
## boiling up on the room's water over it, the water welling up through a floor's plates
## from the void under it — each from a pool of emitters of fixed size, the one a cue's
## source last took going on until no cue has kept it up for HOLD — and the rents in her
## plating along the gash, lying on her lining and her hull from the strike on, from a
## pool of fixed size too, its torn lip and the sea behind it lit faintly of their own so
## a dark room still shows them. Seeing the breach is the point (#148): the jet hushes —
## slower, in specks, see-through — only within JET_HUSHED of the eye or where its sheet is
## thrown at the eye, never across a room, and the boil and the rent never; the welling,
## as every other effect near the eye, lies low on the floor, small and faint.

## How many emitters of each, and how many grains each draws at most.
const JETS := 4
const BOILS := 4
const WELLS := 6
const JET_GRAINS := 96
const BOIL_GRAINS := 32
const WELL_GRAINS := 12
## Every grain they can draw at once.
const GRAINS := JETS * JET_GRAINS + BOILS * BOIL_GRAINS + WELLS * WELL_GRAINS
## How many rents are drawn at once, at most.
const RENTS := 24
## An emitter goes on this long after the last cue that kept it up, in seconds: past
## the planners' beats (GashPlanner.BREACH_TICKS, FxPlanner.WELL_TICKS).
const HOLD := 0.45
## The jet hushes within JET_HUSHED of the eye, in metres — of its sheet, from the gash
## out as far as it is thrown — easing into its full self over JET_HUSH_EASE: far nearer
## than SinkingFx.HUSHED.
const JET_HUSHED := 2.0
const JET_HUSH_EASE := 1.0
## A drop of the jet, across, in metres, at least, and at most as big as its sheet asks
## to be solid; and how fast the sea comes in, in m/s, from the least head to the most.
## A drop lives as long as the slowest crosses as far as it is thrown, JET_LIFE at the
## most — the sea comes in faster where that is too short.
const DROP := 0.22
const DROP_MOST := 0.7
const JET_SPEED := Vector2(1.5, 6.0)
const JET_LIFE := 2.5
## A bubble of the boil and of the welling, across, in metres; how fast they come up, in
## m/s, at the least and the most; how far round its line a boil spreads.
const BUBBLE := 0.18
const BUBBLE_SPEED := Vector2(0.08, 0.3)
const BOIL_BREADTH := 0.35
## The boil: a dome of white water and foam this high over the room's water, in metres,
## from the least head to the most, its water falling back this fast, in m/s², fanned
## out this far from straight up, in degrees, in foam this many times a bubble's size.
const DOME := Vector2(0.2, 0.7)
const DOME_FALL := 5.0
const DOME_SPREAD := 40.0
const FOAM := Vector2(1.6, 2.6)
## The rent: its torn lip of bare steel, how much bigger than the hole it rings, and
## how far it stands off the plating it is torn in, so the plating never hides it.
const LIP := 1.45
const RENT_LIFT := 0.02
const HOLE := Color("0d2229")
const BARE_STEEL := Color("b4ada3")
## How brightly the lip and the sea behind the hole light themselves.
const LIP_GLOW := 0.45
const HOLE_GLOW := 0.25
## How many points round each of a rent's torn edges.
const TEARS := 14
## A jet's sheet is looked at from the gash out in this many steps for the eye.
const THROW_STEPS := 6

var _jets: Array[CPUParticles3D] = []
var _boils: Array[CPUParticles3D] = []
var _wells: Array[CPUParticles3D] = []
## Per emitter, in the order emitters() gives them: the source it was last taken for,
## the seconds it goes on, and where it stands in her, ship-local.
var _sources := PackedInt32Array()
var _left := PackedFloat32Array()
var _placed: Array[Transform3D] = []
## Follows the ship as drawn: the rents lie in it.
var _hull: Node3D
var _rents: Array[MeshInstance3D] = []
var _next_rent := 0


func _init() -> void:
	var drop := FxGrains.billboard(DROP, FxGrains.blob(), FxGrains.CLEAR, FxGrains.WHITE_GLOW)
	for index in JETS:
		var jet := _emitter(JET_GRAINS, drop, "BreachJet%d" % index)
		FxGrains.water(jet, 0.8)
		jet.particle_flag_align_y = false
		jet.gravity = Vector3.DOWN * Flotsam.GRAVITY
		jet.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		jet.spread = 8.0
		_jets.append(jet)
	var bubble := FxGrains.billboard(BUBBLE, FxGrains.blob(), FxGrains.CLEAR, FxGrains.BUBBLE_GLOW)
	for index in BOILS:
		var boil := _emitter(BOIL_GRAINS, bubble, "BreachBoil%d" % index)
		FxGrains.boil(boil)
		boil.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_boils.append(boil)
	for index in WELLS:
		var well := _emitter(WELL_GRAINS, bubble, "Well%d" % index)
		FxGrains.boil(well)
		_wells.append(well)
	_sources.resize(JETS + BOILS + WELLS)
	_sources.fill(-1)
	_left.resize(JETS + BOILS + WELLS)
	_placed.resize(JETS + BOILS + WELLS)
	_hull = Node3D.new()
	_hull.name = "Rents"
	add_child(_hull)
	var mesh := rent_mesh()
	for index in RENTS:
		var rent := MeshInstance3D.new()
		rent.name = "Rent%d" % index
		rent.mesh = mesh
		rent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rent.visible = false
		_hull.add_child(rent)
		_rents.append(rent)


## A rent in plating, a metre along x and a metre up y, facing +z: a dark hole, ragged
## along its top and bottom and pinched to nothing at its ends, ringed by a torn lip of
## bare steel.
static func rent_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for layer: int in 2:
		var grown := LIP if layer == 0 else 1.0
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in TEARS:
			var a := _tear(index, grown)
			var b := _tear(index + 1, grown)
			var lift := Vector3(0.0, 0.0, RENT_LIFT * layer)
			for point: Vector3 in [a[0], a[1], b[1], a[0], b[1], b[0]]:
				tool.set_normal(Vector3.BACK)
				tool.add_vertex(point + lift)
		var material := StandardMaterial3D.new()
		material.albedo_color = BARE_STEEL if layer == 0 else HOLE
		material.roughness = 0.6 if layer == 0 else 1.0
		material.metallic = 0.5 if layer == 0 else 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Faint of their own, so a room's lamps need not find them.
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = LIP_GLOW if layer == 0 else HOLE_GLOW
		tool.set_material(material)
		tool.commit(mesh)
	return mesh


## The [param index]th of TEARS + 1 points along a rent's bottom and top edges,
## [param grown] times its size: ragged, the same every time it is built.
static func _tear(index: int, grown: float) -> Array[Vector3]:
	var along := float(index) / TEARS
	var x := (along - 0.5) * grown
	var pinch := sin(along * PI)
	var ragged := 0.55 + 0.45 * absf(sin(index * 2.39 + 0.7))
	var ragged_too := 0.55 + 0.45 * absf(sin(index * 1.71 + 2.1))
	var half := 0.5 * grown * pinch
	return [Vector3(x, -half * ragged, 0.0), Vector3(x, half * ragged_too, 0.0)]


## Plays [param cue] — a JET, BOIL or WELL — on a ship drawn at [param ship], seen by
## [param camera] (none: from everywhere): the emitter its source last took, or the one
## nearest done, set going from where it says.
func play(cue: FxCue, ship: Transform3D, camera: Camera3D) -> void:
	var pool := _wells
	var first := JETS + BOILS
	if cue.kind == FxCue.Kind.JET:
		pool = _jets
		first = 0
	elif cue.kind == FxCue.Kind.BOIL:
		pool = _boils
		first = JETS
	var slot := _take(first, pool.size(), cue.source)
	var emitter := pool[slot - first]
	var at := ship * cue.position
	var to := ship * cue.end
	var shows := 1.0
	if camera != null and cue.kind != FxCue.Kind.BOIL:
		var eye := camera.global_position
		shows = SinkingFx.shown(SinkingFx.nearest_on(at, to, eye).distance_to(eye))
		if cue.kind == FxCue.Kind.JET:
			shows = jet_shown(at, to, ship.basis * cue.toward * cue.rise, eye)
	var length := cue.position.distance_to(cue.end)
	var basis := Basis()
	if length > 0.05:
		var along := (cue.end - cue.position) / length
		basis = Basis(along, Vector3.UP, along.cross(Vector3.UP))
	_placed[slot] = Transform3D(basis, (cue.position + cue.end) * 0.5)
	emitter.global_transform = ship * _placed[slot]
	var alpha := lerpf(SinkingFx.HUSHED_ALPHA, 1.0, shows) * lerpf(0.5, 1.0, cue.strength)
	emitter.color = Color(1.0, 1.0, 1.0, alpha)
	var speed := lerpf(BUBBLE_SPEED.x, BUBBLE_SPEED.y, cue.strength) * lerpf(0.5, 1.0, shows)
	match cue.kind:
		FxCue.Kind.JET:
			_jet(emitter, cue, ship, length, shows)
		FxCue.Kind.BOIL:
			_dome(emitter, cue, length)
		FxCue.Kind.WELL:
			emitter.emission_ring_radius = maxf(cue.radius, 0.1)
			emitter.initial_velocity_min = speed * 0.4
			emitter.initial_velocity_max = speed * 0.8
			emitter.scale_amount_max = lerpf(0.5, 1.0, cue.strength) * lerpf(0.6, 1.0, shows)
	_left[slot] = HOLD
	if not emitter.emitting:
		emitter.restart()
		emitter.emitting = true


## Lays the rent [param cue] tells of in her plating, there from now on.
func rent(cue: FxCue) -> void:
	var rent := _rents[_next_rent]
	_next_rent = (_next_rent + 1) % RENTS
	var along := cue.end - cue.position
	var up := Vector3(0.0, cue.radius * 2.0, 0.0)
	# Its face toward the way it faces, the right way round.
	if along.cross(up).dot(cue.toward) < 0.0:
		along = -along
	var facing := along.cross(up).normalized()
	rent.transform = Transform3D(Basis(along, up, facing), (cue.position + cue.end) * 0.5)
	rent.visible = true


## Lets [param delta] seconds go by with the ship drawn at [param ship]: what is
## going stays where it is in her, and stops once nothing has kept it up for HOLD.
func advance(ship: Transform3D, delta: float) -> void:
	_hull.transform = ship
	var all := emitters()
	for slot in all.size():
		if not all[slot].emitting:
			continue
		_left[slot] -= delta
		if _left[slot] <= 0.0:
			all[slot].emitting = false
			_sources[slot] = -1
			continue
		all[slot].global_transform = ship * _placed[slot]


## Nothing going, nothing torn, and nothing asked for.
func clear() -> void:
	for emitter: CPUParticles3D in emitters():
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = false
	_sources.fill(-1)
	_left.fill(0.0)
	for rent: MeshInstance3D in _rents:
		rent.visible = false
	_next_rent = 0


## Every emitter it has: the jets, the boils, the wells.
func emitters() -> Array[CPUParticles3D]:
	var all: Array[CPUParticles3D] = []
	all.append_array(_jets)
	all.append_array(_boils)
	all.append_array(_wells)
	return all


## How much of itself a jet thrown [param throw] (world) from the line [param from]–
## [param to] (world) shows to an eye at [param eye]: none within JET_HUSHED of its
## sheet, all of it from JET_HUSHED + JET_HUSH_EASE on.
static func jet_shown(from: Vector3, to: Vector3, throw: Vector3, eye: Vector3) -> float:
	var nearest := INF
	for step in THROW_STEPS + 1:
		var out := throw * float(step) / THROW_STEPS
		nearest = minf(nearest, SinkingFx.nearest_on(from + out, to + out, eye).distance_to(eye))
	return clampf((nearest - JET_HUSHED) / JET_HUSH_EASE, 0.0, 1.0)


## How many rents are torn in her.
func rent_count() -> int:
	return _rents.filter(func(rent: MeshInstance3D) -> bool: return rent.visible).size()


## The sheet of white water [param cue] throws in, [param length] along the gash, on
## a ship drawn at [param ship], from [param emitter]: thrown as hard as its head, its
## slowest drops living to get as far into the room as it says, falling as far as it
## says on the way, as thick as the gash is big, in drops big enough to make it a
## sheet; [param shows] of itself near the eye — slower and in specks.
func _jet(
	emitter: CPUParticles3D, cue: FxCue, ship: Transform3D, length: float, shows: float
) -> void:
	var thick := lerpf(0.03, maxf(cue.radius * 0.5, 0.03), shows)
	emitter.emission_box_extents = Vector3(length * 0.5, thick, 0.02)
	var basis := emitter.global_basis
	emitter.direction = basis.transposed() * (ship.basis * cue.toward).normalized()
	var reach := maxf(cue.rise, 0.1)
	var speed := lerpf(JET_SPEED.x, JET_SPEED.y, cue.strength) * lerpf(0.5, 1.0, shows)
	speed = maxf(speed, reach / (0.7 * JET_LIFE))
	emitter.initial_velocity_min = speed * 0.7
	emitter.initial_velocity_max = speed
	emitter.damping_min = 0.0
	emitter.damping_max = 0.0
	emitter.lifetime = reach / emitter.initial_velocity_min
	# The fastest drops fall as far as the cue says getting across; the slower, further.
	var crossing := reach / speed
	emitter.gravity = Vector3.DOWN * 2.0 * cue.drop / (crossing * crossing)
	var sheet := sqrt(length * reach / JET_GRAINS)
	var grain := clampf(sheet, DROP * (1.0 + cue.strength), DROP_MOST)
	grain = lerpf(SinkingFx.SPECK, grain, shows)
	emitter.scale_amount_max = grain / DROP
	emitter.scale_amount_min = minf(0.6, emitter.scale_amount_max)


## The dome of white water and foam [param cue] throws up on the room's water over the
## gash, [param length] along it, from [param emitter]: as high as the head, over
## all of the gash, falling back.
func _dome(emitter: CPUParticles3D, cue: FxCue, length: float) -> void:
	emitter.emission_box_extents = Vector3(length * 0.5, 0.02, BOIL_BREADTH)
	var up := sqrt(2.0 * DOME_FALL * lerpf(DOME.x, DOME.y, cue.strength))
	emitter.direction = Vector3.UP
	emitter.spread = DOME_SPREAD
	emitter.initial_velocity_min = up * 0.6
	emitter.initial_velocity_max = up
	emitter.gravity = Vector3.DOWN * DOME_FALL
	emitter.lifetime = 2.0 * up / DOME_FALL
	emitter.scale_amount_max = lerpf(FOAM.x, FOAM.y, cue.strength)


## The slot among the [param count] from [param first] for [param source]: the one
## it last took if that is still going, else the one nearest done.
func _take(first: int, count: int, source: int) -> int:
	var nearest := first
	for slot in range(first, first + count):
		if source >= 0 and _sources[slot] == source and _left[slot] > 0.0:
			return slot
		if _left[slot] < _left[nearest]:
			nearest = slot
	_sources[nearest] = source
	return nearest


## A pool's emitter of [param grains] grains of [param mesh], in the world, named
## [param called].
func _emitter(grains: int, mesh: Mesh, called: String) -> CPUParticles3D:
	var emitter := FxGrains.emitter(grains, mesh, false)
	emitter.name = called
	emitter.visibility_range_end = SinkingFx.FAR + 30.0
	add_child(emitter)
	return emitter
