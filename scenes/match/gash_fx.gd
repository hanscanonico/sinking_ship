class_name GashFx
extends Node3D
## The iceberg's strike as seen (SinkingFx plays GashPlanner's cues here): white water
## burst up out of the gash from emitters of its own, and spurting up after it from
## others, so nothing after it cuts it short; spray mist billowing up her side over it
## and drifting off downwind; foam lying on the sea along it, thinning out. Each from a
## pool of fixed size. Near the eye, as every effect, low, small and faint: SinkingFx
## throws the white water as it throws all of it, the mist is see-through and the foam
## lies flat on the sea.

## How many emitters of each, and how many grains each draws at most.
const STRIKES := 8
const SPURTS := 2
const MISTS := 6
const FROTHS := 3
const STRIKE_GRAINS := 60
const SPURT_GRAINS := 30
const MIST_GRAINS := 8
const FROTH_GRAINS := 40
## Every grain they can draw at once.
const GRAINS := (
	STRIKES * STRIKE_GRAINS + SPURTS * SPURT_GRAINS + MISTS * MIST_GRAINS + FROTHS * FROTH_GRAINS
)
## A drop of the gash's white water, across, in metres: round, so however it flies it
## never shows as a straw.
const DROP := 0.25
## A billow of mist, across, in metres, how bright it is drawn, and how much of its
## edge it has worn away by the end of its life: white to the last, never a grey film.
const MIST_PUFF := 1.6
const MIST_GLOW := 1.3
const MIST_WEAR := 0.25
## Mist billows up out of a sheet this far over the sea and this deep, this far
## either side of it across, in metres.
const MIST_FROM := 0.3
const MIST_ACROSS := 0.4
## A patch of foam on the sea, across, in metres, a piece of a sheet of lace this many
## metres across; it lies this far over the sea and spreads off her this far at most.
const FROTH_PATCH := Vector2(1.1, 1.1)
const FROTH_SHEET := 2.2
const FROTH_LIFT := 0.03
const FROTH_BREADTH := 1.2

var _strikes: Array[CPUParticles3D] = []
var _next_strike := 0
var _spurts: Array[CPUParticles3D] = []
var _next_spurt := 0
var _mists: Array[CPUParticles3D] = []
var _next_mist := 0
var _mist_material: ShaderMaterial
## Foam on the sea: each one's emitter, the ends of its line along the gash and the
## way it drifts off, ship-local; how thick it lies, its seconds in all and left.
var _froths: Array[CPUParticles3D] = []
var _next_froth := 0
var _froth_line := PackedVector3Array()
var _froth_way := PackedVector3Array()
var _froth_strength := PackedFloat32Array()
var _froth_seconds := PackedFloat32Array()
var _froth_left := PackedFloat32Array()


## Draws its mist in [param billow]'s shape (FxGrains.shape).
func _init(billow: Texture2D) -> void:
	var drop := FxGrains.billboard(DROP, FxGrains.blob(), FxGrains.CLEAR, FxGrains.WHITE_GLOW)
	for index in STRIKES:
		var strike := _emitter(STRIKE_GRAINS, drop, true, "Strike%d" % index)
		FxGrains.struck(strike)
		_strikes.append(strike)
	for index in SPURTS:
		var spurt := _emitter(SPURT_GRAINS, drop, true, "Spurt%d" % index)
		FxGrains.struck(spurt)
		_spurts.append(spurt)
	var puff := FxGrains.billows(
		MIST_PUFF, billow, ArtPalette.SPRAY, ArtPalette.SPRAY_SHADE, MIST_GLOW, FxGrains.STEAM_CLEAR
	)
	_mist_material = puff.material
	_mist_material.set_shader_parameter(&"wear", MIST_WEAR)
	for index in MISTS:
		var mist := _emitter(MIST_GRAINS, puff, true, "Mist%d" % index)
		FxGrains.mist(mist)
		_mists.append(mist)
	var patch := FxGrains.laces(FROTH_PATCH, FxGrains.lace(), FROTH_SHEET)
	for index in FROTHS:
		var froth := _emitter(FROTH_GRAINS, patch, false, "Froth%d" % index)
		FxGrains.froth(froth)
		_froths.append(froth)
	_froth_line.resize(FROTHS * 2)
	_froth_way.resize(FROTHS)
	_froth_strength.resize(FROTHS)
	_froth_seconds.resize(FROTHS)
	_froth_left.resize(FROTHS)


## Lights the mist from [param sun] (toward it, in the world).
func lit_from(sun: Vector3) -> void:
	_mist_material.set_shader_parameter(&"sun", sun)


## The emitter the next sheet of the strike's white water is thrown from: its own, never
## one the spurts after it take.
func sheet() -> CPUParticles3D:
	var strike := _strikes[_next_strike]
	_next_strike = (_next_strike + 1) % STRIKES
	return strike


## The emitter white water next spurts up out of the gash from, after the strike.
func spurt() -> CPUParticles3D:
	var spurting := _spurts[_next_spurt]
	_next_spurt = (_next_spurt + 1) % SPURTS
	return spurting


## Spray mist billowing up off the sheet [param cue] runs along, on a ship drawn at
## [param ship], up to its rise over the sea; see-through near [param camera]'s eye.
func mist(cue: FxCue, ship: Transform3D, camera: Camera3D) -> void:
	var mist := _mists[_next_mist]
	_next_mist = (_next_mist + 1) % MISTS
	var from := _on_sea(ship * cue.position)
	var to := _on_sea(ship * cue.end)
	var shows := 1.0
	if camera != null:
		var eye := camera.global_position
		shows = SinkingFx.shown(SinkingFx.nearest_on(from, to, eye).distance_to(eye))
	var basis := Basis()
	var length := from.distance_to(to)
	if length > 0.05:
		var along := (to - from) / length
		basis = Basis(along, Vector3.UP, along.cross(Vector3.UP))
	mist.global_transform = Transform3D(basis, (from + to) * 0.5 + Vector3.UP * MIST_FROM)
	mist.emission_box_extents = Vector3(length * 0.5, MIST_FROM, MIST_ACROSS)
	mist.direction = basis.transposed() * (ship.basis * cue.toward).normalized()
	mist.scale_amount_max = lerpf(0.75, 1.05, cue.strength)
	# Its billows' middles slow to a stop a billow short of its top.
	var climb := maxf(cue.rise - MIST_FROM - MIST_PUFF * mist.scale_amount_max, 0.5)
	var speed := sqrt(2.0 * climb * (FxGrains.MIST_DAMPING + FxGrains.MIST_SINK))
	mist.initial_velocity_min = speed * 0.55
	mist.initial_velocity_max = speed
	mist.color = Color(1.0, 1.0, 1.0, lerpf(SinkingFx.HUSHED_ALPHA, 1.0, shows))
	mist.restart()
	mist.emitting = true


## Foam lying on the sea along the line [param cue] runs along, on a ship drawn at
## [param ship], for its seconds, thinning out.
func froth(cue: FxCue, ship: Transform3D) -> void:
	var index := _next_froth
	_next_froth = (_next_froth + 1) % FROTHS
	_froth_line[index * 2] = cue.position
	_froth_line[index * 2 + 1] = cue.end
	_froth_way[index] = cue.toward
	_froth_strength[index] = cue.strength
	_froth_seconds[index] = maxf(cue.seconds, 0.1)
	_froth_left[index] = cue.seconds
	var foam := _froths[index]
	foam.initial_velocity_min = 0.1
	foam.initial_velocity_max = 0.2 + cue.strength * 0.4
	_lay_froth(index, ship)
	foam.restart()
	foam.emitting = true


## Lets [param delta] seconds go by with the ship drawn at [param ship]: the foam
## stays on the sea where she is and thins out as its time runs down.
func advance(ship: Transform3D, delta: float) -> void:
	for index in FROTHS:
		if not _froths[index].emitting:
			continue
		_froth_left[index] -= delta
		if _froth_left[index] <= 0.0:
			_froths[index].emitting = false
			continue
		_lay_froth(index, ship)


## Nothing going, and nothing asked for.
func clear() -> void:
	for emitter: CPUParticles3D in emitters():
		emitter.emitting = false
		emitter.restart()
		emitter.emitting = false
	_froth_left.fill(0.0)


## Every emitter it has.
func emitters() -> Array[CPUParticles3D]:
	var all: Array[CPUParticles3D] = []
	all.append_array(_strikes)
	all.append_array(_spurts)
	all.append_array(_mists)
	all.append_array(_froths)
	return all


## Puts foam [param index] on the sea along its line, on a ship drawn at
## [param ship], spreading off her side, as thick as the share of its time left.
func _lay_froth(index: int, ship: Transform3D) -> void:
	var foam := _froths[index]
	var from := _on_sea(ship * _froth_line[index * 2])
	var to := _on_sea(ship * _froth_line[index * 2 + 1])
	var length := from.distance_to(to)
	var along := (to - from) / length if length > 0.05 else _on_sea(ship.basis.x).normalized()
	var across := along.cross(Vector3.UP)
	if across.dot(ship.basis * _froth_way[index]) < 0.0:
		along = -along
		across = -across
	var breadth := FROTH_BREADTH * _froth_strength[index] * 0.5
	var middle := (from + to) * 0.5 + across * breadth + Vector3.UP * FROTH_LIFT
	foam.global_transform = Transform3D(Basis(along, Vector3.UP, across), middle)
	foam.emission_box_extents = Vector3(length * 0.5, 0.01, breadth)
	var left := _froth_left[index] / _froth_seconds[index]
	var thick := _froth_strength[index] * sqrt(clampf(left, 0.0, 1.0))
	if absf(foam.color.a - thick) > 0.02:
		foam.color = Color(1.0, 1.0, 1.0, thick)


func _emitter(grains: int, mesh: Mesh, one_shot: bool, called: String) -> CPUParticles3D:
	var emitter := FxGrains.emitter(grains, mesh, one_shot)
	emitter.name = called
	emitter.visibility_range_end = SinkingFx.FAR + 30.0
	add_child(emitter)
	return emitter


## [param point] on the sea plane.
static func _on_sea(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
