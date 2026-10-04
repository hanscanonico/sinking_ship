class_name FxAroundEye
extends Node3D
## What the sinking shows round a first-person eye wherever it looks (SinkingFx), so
## a player turned away from the bow or the bridge still sees it happen: spray blown
## over the ship raining down before the eye in the plunge; the grit of a deck giving
## way blowing past from behind; water streaming down the planks before it. Each is
## one emitter of fixed size, told where every step that wants it and falling quiet
## once none does. Near the eye they are specks or lie flat on the planks.

## Grains each draws at most.
const RAIN_GRAINS := 80
const DRIFT_GRAINS := 40
const RUNNEL_GRAINS := 32
## Every grain the three can draw at once.
const GRAINS := RAIN_GRAINS + DRIFT_GRAINS + RUNNEL_GRAINS
## A raindrop of spray, as big as a square this many metres across, this many times
## as long as it is wide; a speck of drifting grit; a runnel of water, across and
## along.
const RAINDROP := 0.2
const RAIN_ASPECT := 8.0
const GRIT := 0.2
const RUNNEL := Vector2(0.22, 0.9)
## Spray rains out of a box this far ahead of the eye, over it and upwind of it,
## this big either way (across, up, ahead), in metres, blown along the wind and
## falling this steeply; this opaque at the plunge's start and once it has gathered,
## no more than a speck of white water near the eye may be.
const RAIN_AHEAD := 6.0
const RAIN_OVER := 3.5
const RAIN_UPWIND := 4.0
const RAIN_BOX := Vector3(6.0, 1.5, 5.0)
const RAIN_FALL := 0.7
const RAIN_ALPHA := Vector2(0.4, SinkingFx.SPECK_ALPHA)
## Grit blows past overhead from a box this far behind the eye and over it, this
## big, for this long, settling into view ahead: specks, as anything this near the
## eye must be, and gone nearer the eye than GRIT_CLEAR.
const DRIFT_BEHIND := 1.0
const DRIFT_OVER := 2.4
const DRIFT_BOX := Vector3(1.0, 0.4, 3.0)
const DRIFT_SECONDS := 2.5
const GRIT_CLEAR := 3.0
## A runnel streams from the first share of its run, over the rest, this wide
## either side of its line, in metres.
const RUNNEL_START := 0.25
const RUNNEL_HALF := 0.25

var _rain: CPUParticles3D
var _drift: CPUParticles3D
var _runnel: CPUParticles3D
## Seconds each goes on without being told again.
var _rain_left := 0.0
var _drift_left := 0.0
var _runnel_left := 0.0


## Draws its spray in [param streak]'s shape and its runnels in [param lace]'s
## (FxGrains.streak, FxGrains.lace).
func _init(streak: Texture2D, lace: Texture2D) -> void:
	var drop := FxGrains.streaks(RAINDROP, RAIN_ASPECT, streak, FxGrains.SPECK_CLEAR)
	_rain = _emitter(RAIN_GRAINS, drop, "Rain")
	FxGrains.spray_rain(_rain)
	_rain.emission_box_extents = RAIN_BOX
	var speck := FxGrains.billboard(GRIT, FxGrains.blob(), GRIT_CLEAR, FxGrains.GRIT_GLOW)
	_drift = _emitter(DRIFT_GRAINS, speck, "Drift")
	FxGrains.drift(_drift)
	_drift.emission_box_extents = DRIFT_BOX
	_runnel = _emitter(RUNNEL_GRAINS, FxGrains.laces(RUNNEL, lace), "Runnel")
	FxGrains.runnel(_runnel)


## Spray raining down before [param camera]'s eye, its share of the plunge's worst
## [param strength], 0…1, for [param seconds] more.
func rain(camera: Camera3D, strength: float, seconds: float) -> void:
	var ahead := _level(-camera.global_basis.z)
	var wind := FxGrains.downwind().normalized()
	var middle := (
		camera.global_position + ahead * RAIN_AHEAD + Vector3.UP * RAIN_OVER - wind * RAIN_UPWIND
	)
	var basis := Basis(Vector3.UP.cross(ahead).normalized(), Vector3.UP, ahead)
	_rain.global_transform = Transform3D(basis, middle)
	_rain.direction = basis.transposed() * (wind + Vector3.DOWN * RAIN_FALL).normalized()
	var alpha := lerpf(RAIN_ALPHA.x, RAIN_ALPHA.y, strength)
	if absf(_rain.color.a - alpha) > 0.02:
		_rain.color = Color(1.0, 1.0, 1.0, alpha)
	_rain_left = seconds
	_rain.emitting = true


## The dust of a deck giving way at [param from] (world) blowing on past
## [param camera]'s eye, the way from it to the eye, for DRIFT_SECONDS.
func drift(from: Vector3, camera: Camera3D) -> void:
	var eye := camera.global_position
	var away := _level(eye - from)
	var middle := eye - away * DRIFT_BEHIND + Vector3.UP * DRIFT_OVER
	_drift.global_transform = Transform3D(
		Basis(away, Vector3.UP, away.cross(Vector3.UP).normalized()), middle
	)
	_drift_left = DRIFT_SECONDS
	_drift.emitting = true


## Water streaming down a deck from [param start] (world) [param length] metres
## along [param downhill] (world, unit, in the deck's plane), whose up is
## [param planks], for [param seconds] more.
func runnel(
	start: Vector3, downhill: Vector3, planks: Vector3, length: float, seconds: float
) -> void:
	var across := planks.cross(downhill).normalized()
	var spring := length * RUNNEL_START
	_runnel.global_transform = Transform3D(
		Basis(across, planks, downhill), start + downhill * spring * 0.5
	)
	_runnel.emission_box_extents = Vector3(RUNNEL_HALF, 0.01, spring * 0.5)
	# Down the rest of the run within a grain's life, and no further.
	var speed := (length - spring) / _runnel.lifetime
	_runnel.initial_velocity_min = speed * 0.6
	_runnel.initial_velocity_max = speed
	_runnel_left = seconds
	_runnel.emitting = true


## Nothing going, and nothing asked for.
func clear() -> void:
	_rain_left = 0.0
	_drift_left = 0.0
	_runnel_left = 0.0


## Lets the time go by: whatever no step has asked for again falls quiet.
func advance(delta: float) -> void:
	_rain_left = _quieten(_rain, _rain_left, delta)
	_drift_left = _quieten(_drift, _drift_left, delta)
	_runnel_left = _quieten(_runnel, _runnel_left, delta)


## Every emitter it has.
func emitters() -> Array[CPUParticles3D]:
	var all: Array[CPUParticles3D] = [_rain, _drift, _runnel]
	return all


func _emitter(grains: int, mesh: Mesh, called: String) -> CPUParticles3D:
	var emitter := FxGrains.emitter(grains, mesh, false)
	emitter.name = called
	add_child(emitter)
	return emitter


static func _quieten(emitter: CPUParticles3D, left: float, delta: float) -> float:
	if left > 0.0 and left - delta <= 0.0:
		emitter.emitting = false
	return left - delta


## [param way] laid level and made unit; the world's forward if it has no level
## part.
static func _level(way: Vector3) -> Vector3:
	var level := Vector3(way.x, 0.0, way.z)
	return level.normalized() if level.length_squared() > 0.0001 else Vector3.FORWARD
