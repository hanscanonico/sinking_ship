class_name DeckDebris
extends Node3D
## Bits of wreckage on the decks (SinkingFx): splinters a deck giving way throws up
## to rain down on the decks round it — and on the deck before the eye, so a player
## looking away still sees them land and skitter on across the planks — bouncing and
## coming to rest; and loose gear a lurch or the plunge sends sliding down a deck.
## Each lies a moment, then shrinks away. Small and low, gone in a few seconds, and
## nothing here is a surface (D6): drawn only. In ship space — it hangs from what
## follows the ship as drawn — so the decks it lands and slides on are the layout's,
## as ShipSpace answers. At most CAP pieces, one multimesh; once every one is out,
## the one out longest goes again.

const CAP := 24
## Pieces a collapse rains round it, and how many of them come down before the eye,
## this far ahead of it at least and at most, in metres.
const RAIN := 12
const RAIN_ON_EYE := 8
const BEFORE_EYE := Vector2(2.0, 6.0)
## How far round its way the eye's pieces spread, in radians.
const EYE_SPREAD := 0.7
## Pieces a slide sends down the deck, how far ahead of the eye they start at least
## and at most, how far they slide at most and at least, in steps of how far, and for
## how long.
const SLIDES := 6
const SLIDE_AHEAD := Vector2(1.5, 7.0)
const SLIDE_REACH := 2.2
const SLIDE_LEAST := 0.5
const SLIDE_STEP := 0.25
const SLIDE_SECONDS := 1.3
## A piece come down before the eye skitters on the way it flew, this far at most,
## slowing from this fast, in metres and m/s, until it stops.
const SKITTER := 1.8
const SKITTER_SPEED := 3.0
## How high over its start a thrown piece climbs, at least and at most, in metres.
const APEX := Vector2(1.2, 3.0)
## A landing piece keeps this share of its fall speed as it bounces, this many times,
## and this share of its speed across the deck.
const BOUNCE := 0.3
const BOUNCES := 2
const SKID := 0.05
## A piece comes down only where the deck it lands on reaches this far round it.
const FOOTING := 0.4
## Seconds a piece lies still, then takes to shrink away.
const REST := 1.8
const SHRINK := 0.5
## A splinter of plank, and how fast it tumbles in the air, radians a second.
const PIECE := Vector3(0.3, 0.05, 0.11)
const TUMBLE := 9.0
## Tries at finding a clear place for a piece before giving it up.
const TRIES := 6

enum State { IDLE, FLYING, SLIDING, RESTING }

var _space: ShipSpace
var _pieces: MultiMesh
var _state := PackedInt32Array()
## Ship-local: where each piece is, how fast it goes, the deck it comes down on and
## its turn; its tumble axis; seconds in its state; bounces left.
var _at := PackedVector3Array()
var _velocity := PackedVector3Array()
var _floor := PackedFloat32Array()
var _basis: Array[Basis] = []
var _axis := PackedVector3Array()
var _age := PackedFloat32Array()
var _bounces := PackedInt32Array()
## How fast a sliding piece gathers speed down the deck, m/s², and for how long it
## slides, in seconds.
var _pull := PackedVector3Array()
var _sliding_for := PackedFloat32Array()
## Ship plane: the run a piece skitters once down, the way and how far; zero for
## none.
var _skid := PackedVector3Array()
var _out := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1912
	var material := StandardMaterial3D.new()
	material.albedo_color = ArtPalette.SPLINTER
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var box := BoxMesh.new()
	box.size = PIECE
	box.material = material
	_pieces = MultiMesh.new()
	_pieces.transform_format = MultiMesh.TRANSFORM_3D
	_pieces.mesh = box
	_pieces.instance_count = CAP
	var drawn := MultiMeshInstance3D.new()
	drawn.name = "Pieces"
	drawn.multimesh = _pieces
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drawn)
	_state.resize(CAP)
	_at.resize(CAP)
	_velocity.resize(CAP)
	_floor.resize(CAP)
	_basis.resize(CAP)
	_axis.resize(CAP)
	_age.resize(CAP)
	_bounces.resize(CAP)
	_pull.resize(CAP)
	_sliding_for.resize(CAP)
	_skid.resize(CAP)
	clear()


## Lands and slides pieces on the decks of [param layout].
func setup(layout: ShipLayout) -> void:
	_space = ShipSpace.new(layout)
	clear()


## Every piece gone.
func clear() -> void:
	for index in CAP:
		_state[index] = State.IDLE
		_pieces.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO)))
	_out = 0


## How many pieces are out.
func count() -> int:
	return _out


## Where every piece lying still on the planks is, ship-local.
func lying() -> PackedVector3Array:
	var found := PackedVector3Array()
	for index in CAP:
		if _state[index] == State.RESTING:
			found.append(_at[index])
	return found


## Bits of a deck giving way at [param from] thrown up to rain on the open decks
## within [param reach] round it, and some on the deck [param before] — ahead of an
## eye at ship point [param eye] looking along [param looking] (ship plane, unit);
## NAN for no eye. Ship-local throughout.
func rain(from: Vector3, reach: float, eye: Vector3, looking: Vector2) -> void:
	if _space == null:
		return
	for index in RAIN:
		for _try in TRIES:
			var target: Vector3
			var before_eye := index < RAIN_ON_EYE and not is_nan(eye.x)
			if before_eye:
				var ahead := looking.rotated(_rng.randf_range(-EYE_SPREAD, EYE_SPREAD))
				var spot := (
					Vector2(eye.x, eye.z) + ahead * _rng.randf_range(BEFORE_EYE.x, BEFORE_EYE.y)
				)
				target = _open_deck(spot, eye.y - FirstPersonCamera.EYE_HEIGHT + 0.3)
			else:
				var turn := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1.0, reach)
				target = _open_deck(Vector2(from.x, from.z) + turn, from.y)
			if not is_nan(target.y):
				var skid := Vector3.ZERO
				if before_eye:
					var spot := Vector2(target.x, target.z)
					var way := (spot - Vector2(from.x, from.z)).normalized()
					var room := Rect2(spot, Vector2.ZERO).grow(SKITTER)
					var run := _reach(spot, way, room, target.y, SKITTER)
					skid = Vector3(way.x, 0.0, way.y) * maxf(run, 0.0)
				_throw(from, target, skid)
				break


## Loose gear sliding [param downhill] (ship plane, unit) down the deck at
## [param height] over [param area], from ahead of an eye at ship point [param eye]
## looking along [param looking], until it fetches up against whatever stands in its
## way, SLIDE_REACH at most: the longest clear run it found, where it starts in the
## ship plane (x, y) and how long it is (z), 0 long for none.
func slide(
	area: Rect2, height: float, downhill: Vector2, eye: Vector3, looking: Vector2
) -> Vector3:
	var longest := Vector3.ZERO
	if _space == null or downhill == Vector2.ZERO:
		return longest
	for _index in SLIDES:
		var run := _runway(area, height, downhill, eye, looking)
		if run.z < SLIDE_LEAST:
			continue
		if run.z > longest.z:
			longest = run
		var index := _free()
		_at[index] = Vector3(run.x, height + PIECE.y * 0.5, run.y)
		_floor[index] = height
		_basis[index] = Basis(Vector3.UP, _rng.randf() * TAU)
		_axis[index] = Vector3.UP
		# Gathering speed down the deck from a slow start.
		_set_sliding(index, Vector3(downhill.x, 0.0, downhill.y) * run.z, SLIDE_SECONDS, 0.4)
	return longest


## A clear run down the deck at [param height] over [param area] along
## [param downhill] (ship plane, unit), SLIDE_REACH long at most, starting ahead of
## an eye at ship point [param eye] looking along [param looking] — before it first,
## then further round it: where it starts in the ship plane (x, y) and how long it is
## (z), under SLIDE_LEAST where none was found.
func _runway(
	area: Rect2, height: float, downhill: Vector2, eye: Vector3, looking: Vector2
) -> Vector3:
	for attempt in TRIES:
		var spread := EYE_SPREAD * (attempt + 1)
		var ahead := looking.rotated(_rng.randf_range(-spread, spread))
		var start := Vector2(eye.x, eye.z) + ahead * _rng.randf_range(SLIDE_AHEAD.x, SLIDE_AHEAD.y)
		var reach := _reach(start, downhill, area, height, SLIDE_REACH)
		if reach >= SLIDE_LEAST:
			return Vector3(start.x, start.y, reach)
	return Vector3.ZERO


## How far from ship-plane [param start] along [param way] a piece may go over the
## deck at [param height] within [param area], in SLIDE_STEPs and [param most] at
## most, before something stands in its way: negative if it may not lie at the start.
func _reach(start: Vector2, way: Vector2, area: Rect2, height: float, most: float) -> float:
	var reach := 0.0
	while reach < most and _clear_at(start + way * reach, area, height):
		reach += SLIDE_STEP
	return reach - SLIDE_STEP


## Sets piece [param index] sliding [param run] (ship plane) in [param seconds],
## starting at [param start_share] of the run's mean speed: under 1 it gathers speed,
## at 2 it slows to a stop at the run's end.
func _set_sliding(index: int, run: Vector3, seconds: float, start_share: float) -> void:
	var reach := run.length()
	var way := run / reach
	var speed := reach / seconds * start_share
	_state[index] = State.SLIDING
	_velocity[index] = way * speed
	_pull[index] = way * 2.0 * (reach - speed * seconds) / (seconds * seconds)
	_sliding_for[index] = seconds
	_age[index] = 0.0


## Whether a piece may lie at ship-plane [param spot] on the deck at [param height]
## over [param area]: on it, under the open sky, nothing standing there, no step
## down, and the sea not over it.
func _clear_at(spot: Vector2, area: Rect2, height: float) -> bool:
	var room := Rect2(spot, Vector2.ZERO).grow(PIECE.x * 0.5)
	if not area.encloses(room) or not _space.clear(room, height, height + 0.5):
		return false
	if absf(_space.deck_under(spot, height + 0.05) - height) > 0.02:
		return false
	var on := Vector3(spot.x, height, spot.y)
	if is_inside_tree() and (global_transform * on).y < 0.05:
		return false
	return _space.outdoors(on + Vector3.UP * 0.3)


## Moves every piece on by [param delta] seconds.
func advance(delta: float) -> void:
	if _out == 0:
		return
	for index in CAP:
		match _state[index]:
			State.FLYING:
				_fly(index, delta)
			State.SLIDING:
				_slide(index, delta)
			State.RESTING:
				_rest(index, delta)


## Throws a piece from [param from] to come down at [param target], then skitter on
## [param skid] (ship plane; zero for none).
func _throw(from: Vector3, target: Vector3, skid: Vector3) -> void:
	var index := _free()
	var apex := maxf(from.y, target.y) + _rng.randf_range(APEX.x, APEX.y)
	var up := sqrt(2.0 * Flotsam.GRAVITY * (apex - from.y))
	var flight := (up + sqrt(2.0 * Flotsam.GRAVITY * (apex - target.y))) / Flotsam.GRAVITY
	var across := Vector3(target.x - from.x, 0.0, target.z - from.z) / flight
	_state[index] = State.FLYING
	_at[index] = from
	_velocity[index] = across + Vector3.UP * up
	_floor[index] = target.y
	_bounces[index] = BOUNCES
	_skid[index] = skid
	_basis[index] = Basis(Vector3.UP, _rng.randf() * TAU)
	_axis[index] = (
		Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3), 1.0).normalized()
	)
	_age[index] = 0.0


func _fly(index: int, delta: float) -> void:
	_age[index] += delta
	var velocity := _velocity[index]
	velocity.y -= Flotsam.GRAVITY * delta
	var at := _at[index] + velocity * delta
	var lying := _floor[index] + PIECE.y * 0.5
	_basis[index] = _basis[index].rotated(_axis[index], TUMBLE * delta).orthonormalized()
	if at.y <= lying and velocity.y < 0.0:
		at.y = lying
		if _bounces[index] > 0:
			_bounces[index] -= 1
			velocity = Vector3(velocity.x * SKID, -velocity.y * BOUNCE, velocity.z * SKID)
		else:
			_land(index, at)
			return
	_velocity[index] = velocity
	_at[index] = at
	_draw(index, 1.0)


## Piece [param index] down flat on the planks at [param at], skittering on if it
## came down before the eye.
func _land(index: int, at: Vector3) -> void:
	_at[index] = at
	_state[index] = State.RESTING
	_age[index] = 0.0
	_basis[index] = Basis(Vector3.UP, _basis[index].get_euler().y)
	var skid := _skid[index]
	if skid.length() >= SLIDE_LEAST:
		_set_sliding(index, skid, 2.0 * skid.length() / SKITTER_SPEED, 2.0)
	_draw(index, 1.0)


func _slide(index: int, delta: float) -> void:
	_age[index] += delta
	_velocity[index] += _pull[index] * delta
	_at[index] += _velocity[index] * delta
	_basis[index] = _basis[index].rotated(Vector3.UP, 1.5 * delta)
	if _age[index] >= _sliding_for[index]:
		_state[index] = State.RESTING
		_age[index] = 0.0
	_draw(index, 1.0)


func _rest(index: int, delta: float) -> void:
	_age[index] += delta
	var left := 1.0 - (_age[index] - REST) / SHRINK
	if left <= 0.0:
		_state[index] = State.IDLE
		_out -= 1
		_pieces.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO)))
		return
	_draw(index, minf(left, 1.0))


func _draw(index: int, scale: float) -> void:
	_pieces.set_instance_transform(
		index, Transform3D(_basis[index].scaled(Vector3.ONE * scale), _at[index])
	)


## The open deck under ship-plane [param spot] at [param below] or lower, as a ship
## point on its planks; NAN height when there is none, it is roofed, it ends within
## FOOTING, or the sea is over it.
func _open_deck(spot: Vector2, below: float) -> Vector3:
	var deck := _space.deck_under(spot, below)
	var on := Vector3(spot.x, deck, spot.y)
	if is_nan(deck) or not _space.outdoors(on + Vector3.UP * 0.3):
		return Vector3(spot.x, NAN, spot.y)
	var footing := Rect2(spot - Vector2.ONE * FOOTING, Vector2.ONE * FOOTING * 2.0)
	if not _space.clear(footing, deck, deck + 0.3):
		return Vector3(spot.x, NAN, spot.y)
	if is_inside_tree() and (global_transform * on).y < 0.05:
		return Vector3(spot.x, NAN, spot.y)
	return on


## A piece not out, or else the one out longest.
func _free() -> int:
	var oldest := 0
	for index in CAP:
		if _state[index] == State.IDLE:
			_out += 1
			return index
		if _age[index] > _age[oldest]:
			oldest = index
	return oldest
