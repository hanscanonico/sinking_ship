class_name Flotsam
extends Node3D
## Wreckage on the sea (SinkingFx): planks, crates, deck chairs and lifebelts, each
## thrown from the ship onto the sea, then floating low in it, rocking, and drifting
## slowly away from the hull. Small and low — a few centimetres of each stand out
## of the water — so none reads as a raft; the rules have none, and nothing here is
## a surface (D6): drawn only. At most CAP pieces: once every one is out, the one
## out longest is thrown again.

signal landed(at: Vector3, strength: float)

const CAP := 18
const GRAVITY := 9.8
## Seconds a piece is in the air, at least and at most.
const FLIGHT_LEAST := 0.45
const FLIGHT_MOST := 1.6
## Metres a second a piece drifts away from the hull as it lands, and at the
## slowest; the share of the difference it loses each second.
const DRIFT := 0.45
const DRIFT_LEAST := 0.08
const DRIFT_EASE := 0.12
## How far a piece rocks on the swell, in degrees, and how often, in hertz.
const ROCK_DEG := 6.0
const ROCK_HZ := 0.3
## How fast a piece turns in the air, and on the water, in radians a second.
const TUMBLE := 6.0
const TURN := 0.25
## A piece landing this fast or faster splashes hardest, in m/s.
const SPLASH_SPEED := 8.0
## Metres from the eye past which a piece is not drawn.
const FAR := 160.0
## A plank, a crate, a deck chair and a lifebelt, as FxCue.Piece numbers them; the
## crate's lid and battens, and how far each kind stands out of the water.
const PLANK := Vector3(1.1, 0.07, 0.16)
const CRATE_SIDE := 0.62
const CRATE_ABOVE := 0.14
const BATTEN := 0.06
const BELT_RADIUS := 0.3
const BELT_THICK := 0.075
const BELT_SEGMENTS := 20
const BELT_SIDES := 8
## A face's darkening toward the ink: a top, a side, an underside.
const TOP_RIM := 0.0
const SIDE_RIM := 0.55
const UNDER_RIM := 1.0

enum State { IDLE, FLYING, AFLOAT }

const SHADER := preload("res://scenes/match/flotsam.gdshader")

var _pieces: Array[MeshInstance3D] = []
var _meshes: Array[ArrayMesh] = []
var _state := PackedInt32Array()
## World: velocity while flying, drift while afloat.
var _velocity := PackedVector3Array()
var _tumble := PackedVector3Array()
var _yaw := PackedFloat32Array()
var _turn := PackedFloat32Array()
## World x/z: the way it drifts once afloat.
var _away := PackedVector2Array()
## Seconds since it was thrown.
var _age := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1912
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("ink", ArtPalette.INK)
	_meshes = [_plank(), _crate(), _chair(), _lifebelt()]
	for index in CAP:
		var piece := MeshInstance3D.new()
		piece.name = "Piece%d" % index
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.visibility_range_end = FAR
		piece.visible = false
		add_child(piece)
		_pieces.append(piece)
	_state.resize(CAP)
	_velocity.resize(CAP)
	_tumble.resize(CAP)
	_yaw.resize(CAP)
	_turn.resize(CAP)
	_away.resize(CAP)
	_age.resize(CAP)


## Throws a [param piece] from [param from] to come down on the sea at
## [param to] — world points — and drift on along [param away] (world x/z).
func throw(piece: FxCue.Piece, from: Vector3, to: Vector3, away: Vector2) -> void:
	var index := _free()
	var drop := maxf(from.y - to.y, 0.1)
	var flight := clampf(sqrt(2.0 * drop / GRAVITY) * 1.15, FLIGHT_LEAST, FLIGHT_MOST)
	var target := Vector3(to.x, 0.0, to.z)
	_state[index] = State.FLYING
	_velocity[index] = (target - from) / flight + Vector3.UP * GRAVITY * flight * 0.5
	_tumble[index] = (
		Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 1.0).normalized()
	)
	_yaw[index] = _rng.randf() * TAU
	_turn[index] = _rng.randf_range(-TURN, TURN)
	_age[index] = 0.0
	var drawn := _pieces[index]
	drawn.mesh = _meshes[piece]
	drawn.transform = Transform3D(Basis(Vector3.UP, _yaw[index]), from)
	drawn.visible = true
	_away[index] = away.normalized() if away != Vector2.ZERO else Vector2.RIGHT


## Every piece gone.
func clear() -> void:
	for index in CAP:
		_state[index] = State.IDLE
		_pieces[index].visible = false


## Moves every piece on by [param delta] seconds.
func advance(delta: float) -> void:
	for index in CAP:
		match _state[index]:
			State.FLYING:
				_fly(index, delta)
			State.AFLOAT:
				_float(index, delta)


## Where every piece afloat is, in the world.
func afloat() -> PackedVector3Array:
	var found := PackedVector3Array()
	for index in CAP:
		if _state[index] == State.AFLOAT:
			found.append(_pieces[index].position)
	return found


## How many pieces are out, flying or afloat.
func count() -> int:
	return CAP - _state.count(State.IDLE)


func _fly(index: int, delta: float) -> void:
	_age[index] += delta
	var drawn := _pieces[index]
	var velocity := _velocity[index]
	var was := drawn.position
	# Exact for a fall under gravity alone, so it comes down where it was sent.
	var at := was + velocity * delta + Vector3.DOWN * GRAVITY * delta * delta * 0.5
	velocity.y -= GRAVITY * delta
	_velocity[index] = velocity
	if at.y > 0.0 or velocity.y > 0.0:
		drawn.transform = Transform3D(
			drawn.basis.rotated(_tumble[index], TUMBLE * delta).orthonormalized(), at
		)
		return
	# Down on the sea where its path crosses it, not a frame past.
	var crossed := was.lerp(at, clampf(was.y / (was.y - at.y), 0.0, 1.0)) if was.y > at.y else at
	_state[index] = State.AFLOAT
	_age[index] = 0.0
	_velocity[index] = Vector3(_away[index].x, 0.0, _away[index].y) * DRIFT
	drawn.position = Vector3(crossed.x, 0.0, crossed.z)
	landed.emit(drawn.position, clampf(-velocity.y / SPLASH_SPEED, 0.2, 1.0))


func _float(index: int, delta: float) -> void:
	_age[index] += delta
	var drift := _velocity[index]
	var least := Vector3(_away[index].x, 0.0, _away[index].y) * DRIFT_LEAST
	drift = least + (drift - least) * (1.0 - DRIFT_EASE * delta)
	_velocity[index] = drift
	_yaw[index] += _turn[index] * delta
	var rock := deg_to_rad(ROCK_DEG)
	var phase := _age[index] * ROCK_HZ * TAU + index * 1.7
	var tilt := (
		Basis(Vector3.RIGHT, sin(phase) * rock) * Basis(Vector3.BACK, cos(phase * 0.8) * rock)
	)
	var drawn := _pieces[index]
	drawn.transform = Transform3D(
		Basis(Vector3.UP, _yaw[index]) * tilt, drawn.position + drift * delta
	)


## A piece not out, or else the one out longest.
func _free() -> int:
	var oldest := 0
	for index in CAP:
		if _state[index] == State.IDLE:
			return index
		if _age[index] > _age[oldest] and _state[index] == State.AFLOAT:
			oldest = index
	return oldest


## A loose plank, its ends darker.
func _plank() -> ArrayMesh:
	var tool := _tool()
	var half := PLANK * 0.5
	_box(tool, Vector3(0.0, half.y - 0.04, 0.0), PLANK, ArtPalette.TEAK)
	return tool.commit()


## A crate riding low, its lid and a batten round it showing.
func _crate() -> ArrayMesh:
	var tool := _tool()
	var side := Vector3(CRATE_SIDE, CRATE_SIDE, CRATE_SIDE)
	_box(tool, Vector3(0.0, CRATE_ABOVE - CRATE_SIDE * 0.5, 0.0), side, ArtPalette.CRATE)
	var batten := Vector3(CRATE_SIDE + 0.03, BATTEN, CRATE_SIDE + 0.03)
	_box(tool, Vector3(0.0, CRATE_ABOVE - BATTEN * 0.5, 0.0), batten, ArtPalette.FRAME)
	return tool.commit()


## A folded deck chair lying flat: two rails, three slats, its canvas between.
func _chair() -> ArrayMesh:
	var tool := _tool()
	for z: float in [-0.2, 0.2]:
		_box(tool, Vector3(0.0, 0.01, z), Vector3(0.8, 0.05, 0.05), ArtPalette.TEAK)
	for x: float in [-0.35, 0.0, 0.35]:
		_box(tool, Vector3(x, 0.035, 0.0), Vector3(0.05, 0.03, 0.44), ArtPalette.TEAK)
	_box(tool, Vector3(0.0, 0.02, 0.0), Vector3(0.64, 0.02, 0.36), ArtPalette.CHAIR_CANVAS)
	return tool.commit()


## A lifebelt half in the water, banded red at four quarters.
func _lifebelt() -> ArrayMesh:
	var tool := _tool()
	for segment in BELT_SEGMENTS:
		var band := segment % (BELT_SEGMENTS / 4) < 2
		var colour := ArtPalette.LIFEBELT_BAND if band else ArtPalette.FLOTSAM_LIFEBELT
		for side in BELT_SIDES:
			var corners: Array[Vector2] = [
				Vector2(segment, side),
				Vector2(segment + 1, side),
				Vector2(segment + 1, side + 1),
				Vector2(segment, side + 1)
			]
			for corner: int in [0, 1, 2, 0, 2, 3]:
				var round_at := corners[corner].x / BELT_SEGMENTS * TAU
				var tube_at := corners[corner].y / BELT_SIDES * TAU
				var out := Vector3(cos(round_at), 0.0, sin(round_at))
				var normal := out * cos(tube_at) + Vector3.UP * sin(tube_at)
				tool.set_color(colour)
				tool.set_normal(normal)
				tool.set_uv(Vector2(SIDE_RIM * (1.0 - maxf(normal.y, 0.0)), 0.0))
				tool.add_vertex(out * BELT_RADIUS + normal * BELT_THICK)
	return tool.commit()


func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## A box of [param size] round [param centre], in [param colour]: its top lit, its
## sides and underside darker toward the ink.
static func _box(tool: SurfaceTool, centre: Vector3, size: Vector3, colour: Color) -> void:
	var half := size * 0.5
	for axis in 3:
		for sign_of: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_of
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := normal.cross(u)
			var rim := SIDE_RIM
			if axis == 1:
				rim = TOP_RIM if sign_of > 0.0 else UNDER_RIM
			var face := centre + normal * half
			var corners: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				corners.append(face + (u * corner.x + v * corner.y) * half)
			for corner: int in [0, 2, 1, 0, 3, 2]:
				tool.set_color(colour)
				tool.set_normal(normal)
				tool.set_uv(Vector2(rim, 0.0))
				tool.add_vertex(corners[corner])
