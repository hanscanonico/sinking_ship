class_name Falls
extends RefCounted
## Water falling and air going free hit the bodies under and beside them (#631, D12): one
## per piece of her, beside its currents (Currents), read under that piece's pose, its
## points that piece's ship space. Movement asks it of every body.
##
## A pour: water through a hole in a floor (Currents.pours) lands on the deck below under
## the hole — its footprint carried along the world's down to the body's height. It lands
## at v = √(u0² + 2 g drop), the drop from the hole to the body's surface or the water over
## it, and pushes a body under it with F = ρ Q v × share, the share of the footprint the
## body's circle covers (taken as the square of its area). A grounded body pushed
## pour_topple or harder is knocked down; a swimmer under it is dunked as if it had dived
## from the hole and thrown outward from the footprint's middle (Movement).
##
## A blast: as a pocket's air goes free (SinkTimeline.Kind.VENTED) it bursts out of the
## opening it leaves by (AirVents, InnerWater's burst's too). For blast_time from then a
## swimmer within blast_reach of that opening, on its outer side, is pushed away from it
## and up at blast_speed × (1 − r / blast_reach), scaled by the pocket's air at its last
## state as a share of blast_full_air, at most 1.
##
## All of it is the timeline's and the point's: nothing here is match state, so a snapshot
## and the digest hold none of it (D5), and it replays and runs online alike (D4, D11).

## How near flat a hole's water must fall for a footprint to be carried: past this the
## world's down runs too far along her decks for a hole to be over anything.
const STEEPEST := 0.2
## How far over a point its cell is looked for (Currents.LIFT).
const LIFT := 0.05

var _rules: BrawlRules
var _currents: Currents
var _sea: SeaPhysics
var _schedule: SinkSchedule
var _structure: ShipStructure
var _piece: int
var _vents: AirVents
## The pockets of this piece that go free, each once: the tick, the cell, and — found the
## first time a tick of its blast asks — the opening it goes out by (-1 for none) and how
## hard it blows, 0…1.
var _blast_ticks := PackedInt32Array()
var _blast_cells := PackedInt32Array()
var _blast_ways := PackedInt32Array()
var _blast_scales := PackedFloat64Array()
var _blast_found := PackedByteArray()
var _blast_lasts := 1
## The pose the world's down was last found under, and that down in its ship space.
var _downed: ShipPose
var _down := Vector3.DOWN


## What a pour does to a body under it (pour_on).
class Hit:
	## The push, in newtons; how fast its water lands, in m/s; the height it fell, in
	## metres; and the way out of its footprint's middle the body stands, x/z, a unit long
	## (none at the middle).
	var force: float
	var speed: float
	var drop: float
	var out := Vector2.ZERO


## The falls of the piece whose structure is [param structure], its holes' water as
## [param currents] finds it, its pockets' air as [param schedule]'s timeline has it go
## free — piece [param piece]'s events — out by [param passages] and [param failing], under
## [param rules] and [param sea].
func _init(
	rules: BrawlRules,
	currents: Currents,
	structure: ShipStructure,
	schedule: SinkSchedule,
	piece: int,
	sea: SeaPhysics
) -> void:
	_rules = rules
	_currents = currents
	_sea = sea
	_schedule = schedule
	_structure = structure
	_piece = piece
	_blast_lasts = maxi(Ticks.from_seconds(rules.blast_time), 1)
	var timeline := schedule.timeline()
	if timeline == null:
		return
	# Its ways out as InnerWater's draw them: the whole ship's, or once she breaks, the
	# piece's own (ShipPieces).
	var passages := schedule.passages()
	var failing := schedule.failing()
	if piece != 0:
		passages = AirVents.kept(passages, structure, schedule.span_of(piece))
		failing = AirVents.kept(failing, structure, schedule.span_of(piece))
	_vents = AirVents.new(structure, passages, failing)
	for event: SinkTimeline.Event in timeline.events:
		if event.kind != SinkTimeline.Kind.VENTED or event.piece != piece:
			continue
		var cell := structure.cell_named(event.name)
		if cell == -1:
			continue
		_blast_ticks.append(schedule.physics_tick(event.seconds))
		_blast_cells.append(cell)
		_blast_ways.append(-1)
		_blast_scales.append(0.0)
		_blast_found.append(0)


## The falls of piece [param piece] of [param config]'s match, under [param schedule], its
## holes' water as [param currents] finds it: null without currents.
static func of_piece(
	config: MatchConfig, schedule: SinkSchedule, piece: int, currents: Currents
) -> Falls:
	if currents == null:
		return null
	var structure := config.ship.structure if piece == 0 else schedule.structure_of(piece)
	return Falls.new(config.rules, currents, structure, schedule, piece, SeaPhysics.load_default())


## What the water pouring through the holes over it does to a body with its feet at
## [param feet], in a circle body_radius round, under [param pose]: the hardest-hitting pour
## whose footprint it stands under, or null for none.
func pour_on(pose: ShipPose, feet: Vector3) -> Hit:
	var pours := _currents.pours(pose)
	if pours.is_empty():
		return null
	var down := _down_of(pose)
	if -down.y < STEEPEST:
		return null
	var cell := pose.cell_at(feet + Vector3.UP * LIFT)
	var surface := pose.world_height(feet)
	var water := pose.water_height(feet)
	if water > feet.y:
		surface = pose.world_height(Vector3(feet.x, water, feet.z))
	var side := _rules.body_radius * sqrt(PI) * 0.5
	var found: Hit = null
	for pour: Currents.Pour in pours:
		var opening := pour.opening
		if pour.lower == -1 or cell != pour.lower or opening.centre.y <= feet.y:
			continue
		var middle := opening.centre + down * ((opening.centre.y - feet.y) / -down.y)
		var half := Vector2(opening.size.x, opening.size.z) * 0.5
		var across := maxf(
			minf(middle.x + half.x, feet.x + side) - maxf(middle.x - half.x, feet.x - side), 0.0
		)
		var along := maxf(
			minf(middle.z + half.y, feet.z + side) - maxf(middle.z - half.y, feet.z - side), 0.0
		)
		var share := across * along / (4.0 * half.x * half.y)
		var drop := pose.world_height(opening.centre) - surface
		if share <= 0.0 or drop <= 0.0:
			continue
		var speed := sqrt(pour.speed * pour.speed + 2.0 * _sea.gravity * drop)
		var force := _sea.sea_density * pour.flow * speed * share
		if found != null and force <= found.force:
			continue
		found = Hit.new()
		found.force = force
		found.speed = speed
		found.drop = drop
		found.out = Vector2(feet.x - middle.x, feet.z - middle.z).normalized()
	return found


## The push, in m/s, the air going free blows a swimmer at [param point] with at
## [param tick] under [param pose]: away from the opening it goes out by and up, the sum of
## every blast under way; none outside them.
func blast_on(pose: ShipPose, tick: int, point: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for blast in _blast_ticks.size():
		var since := tick - _blast_ticks[blast]
		if since < 0 or since >= _blast_lasts:
			continue
		if _blast_found[blast] == 0:
			_find(blast)
		var way := _blast_ways[blast]
		if way == -1 or _blast_scales[blast] <= 0.0:
			continue
		var cell := _blast_cells[blast]
		if pose.cell_at(point + Vector3.UP * LIFT) == cell:
			continue
		var opening := _vents.openings()[way]
		var half := opening.size * 0.5
		var near := opening.centre + (point - opening.centre).clamp(-half, half)
		var r := point.distance_to(near)
		if r >= _rules.blast_reach or not _outside(opening, cell, point):
			continue
		var speed := _rules.blast_speed * (1.0 - r / _rules.blast_reach) * _blast_scales[blast]
		var away := point - near
		var up := -_down_of(pose)
		var flat := away - up * away.dot(up)
		var heading := up if flat.length() <= Currents.AT else (flat.normalized() + up).normalized()
		push += heading * speed
	return push


## Whether [param point] lies on the side of [param opening] away from [param cell].
func _outside(opening: ShipOpening, cell: int, point: Vector3) -> bool:
	var axis := opening.facing()
	if axis == -1:
		return true
	var box := _structure.cells[cell]
	var inward := signf((box.low[axis] + box.high[axis]) * 0.5 - opening.centre[axis])
	return (point[axis] - opening.centre[axis]) * inward < 0.0


## Finds the way blast [param blast]'s air goes out (AirVents.way_out) as its pocket goes
## free, and how hard it blows: the pocket's air the tick before, as the m³ it would fill
## at the atmosphere's pressure, over blast_full_air.
func _find(blast: int) -> void:
	_blast_found[blast] = 1
	var tick := _blast_ticks[blast]
	var cell := _blast_cells[blast]
	_blast_ways[blast] = _vents.way_out(cell, _schedule.pose_at(tick).of_piece(_piece))
	var before := _schedule.pose_at(maxi(tick - 1, 0)).of_piece(_piece)
	if before.levels.size() <= cell:
		return
	var box := TiltedBox.of(_structure.cells[cell], _sea)
	var basis := before.transform.basis
	box.turn(basis.x.y, basis.y.y, basis.z.y)
	var room := box.capacity() - box.volume(before.levels[cell] - before.transform.origin.y)
	var atmosphere := _sea.air_pressure / (_sea.sea_density * _sea.gravity)
	var pressure := before.pockets[cell] if before.pockets.size() > cell else 0.0
	var air := maxf(room, 0.0) * maxf(pressure, atmosphere) / atmosphere
	_blast_scales[blast] = minf(air / _rules.blast_full_air, 1.0)


## The world's down in [param pose]'s ship space.
func _down_of(pose: ShipPose) -> Vector3:
	if not is_same(pose, _downed):
		_downed = pose
		var basis := pose.transform.basis
		_down = -Vector3(basis.x.y, basis.y.y, basis.z.y).normalized()
	return _down


## How many times a pocket of the piece goes free, each a blast (blast_at, way_out_of).
func blasts() -> int:
	return _blast_ticks.size()


## The tick blast [param blast]'s pocket goes free at, and its cell.
func blast_at(blast: int) -> Vector2i:
	return Vector2i(_blast_ticks[blast], _blast_cells[blast])


## The opening blast [param blast]'s air goes out by (AirVents.way_out), or null for none.
func way_out_of(blast: int) -> ShipOpening:
	if _blast_found[blast] == 0:
		_find(blast)
	var way := _blast_ways[blast]
	return null if way == -1 else _vents.openings()[way]
