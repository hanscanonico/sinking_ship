class_name HitMapper
extends RefCounted
## Maps an iceberg hit onto a ship (§5b.1): the gash, a straight line along her shell
## within her hit zone, becomes one thin opening to the sea for each cell it crosses
## within its bite — a gash biting less deep than a side void is wide opens only the
## void — each bigger or smaller than its share of the gash by a factor from the bands,
## as real damage is uneven; the watertight walls next to its ends are weakened; then,
## from the same stream and in a fixed order, the watertight doors that will jam open
## and the openings that were left open. Pure in (hit, ship, bands, stream), and only
## +, −, ×, ÷ run on 64-bit floats here (D4, R21).

## A stretch of the gash shorter than this is nothing, in metres.
const SLIVER := 1e-6


## What [param hit] does to [param structure], drawing from [param sink_stream] each
## crossed cell's unevenness in her cells' order, then the doors that jam, then the
## openings left open, each in her openings' order.
static func map(
	hit: IcebergHit, structure: ShipStructure, bands: HitBands, sink_stream: RandomNumberGenerator
) -> HitDamage:
	var damage := HitDamage.new()
	damage.from_x = maxf(hit.start_x, structure.hit_zone_x.x)
	damage.to_x = minf(hit.end_x(), structure.hit_zone_x.y)
	damage.weakened_to = bands.weakened_to
	if damage.to_x - damage.from_x > SLIVER:
		var ends := _gash(hit, structure, bands, sink_stream, damage)
		_weaken(structure, bands.weakens_within, ends, damage)
	_fittings(structure, sink_stream, damage)
	return damage


## Walks the gash aft to fore in stretches that each lie in one section and cross no
## cell's face, opening every cell a stretch's middle lies in within the bite of her
## shell there. Returns the gash's ends on her shell, x, y and z of each, or nothing
## where it misses her hull.
static func _gash(
	hit: IcebergHit,
	structure: ShipStructure,
	bands: HitBands,
	sink_stream: RandomNumberGenerator,
	damage: HitDamage
) -> PackedFloat64Array:
	var cuts := PackedFloat64Array([damage.from_x, damage.to_x])
	for section: HullSection in structure.sections:
		_cut(cuts, section.x - section.length * 0.5, damage)
		_cut(cuts, section.x + section.length * 0.5, damage)
	var levels := PackedFloat64Array([structure.hit_zone_y.x, structure.hit_zone_y.y])
	for cell: FloodCell in structure.cells:
		_cut(cuts, cell.low.x, damage)
		_cut(cuts, cell.high.x, damage)
		levels.append(cell.low.y)
		levels.append(cell.high.y)
	if hit.depth_end != hit.depth_start:
		# Where the gash's line passes each height.
		for level: float in levels:
			var under := structure.waterline_y - level - hit.depth_start
			_cut(cuts, hit.start_x + under * hit.length / (hit.depth_end - hit.depth_start), damage)
	cuts.sort()
	var count := structure.cells.size()
	var runs := PackedFloat64Array()
	runs.resize(count)
	# Per cell, the least and the most x, y and z of the gash in it.
	var reach: Array[PackedFloat64Array] = []
	for _cell in count:
		reach.append(PackedFloat64Array([INF, INF, INF, -INF, -INF, -INF]))
	var ends := PackedFloat64Array()
	for index in cuts.size() - 1:
		var a := cuts[index]
		var b := cuts[index + 1]
		var middle := (a + b) * 0.5
		var section := structure.section_at(middle)
		if b - a <= SLIVER or section == null:
			continue
		var y := _height(hit, structure, middle)
		var shell := section.shell_at(y, hit.side)
		if is_nan(shell):
			continue
		var y_a := _height(hit, structure, a)
		var y_b := _height(hit, structure, b)
		if ends.is_empty():
			ends = PackedFloat64Array([a, y_a, shell, 0.0, 0.0, 0.0])
			damage.trace.append(Vector3(a, y_a, shell))
		damage.trace.append(Vector3(middle, y, shell))
		ends[3] = b
		ends[4] = y_b
		ends[5] = shell
		var inner := shell - hit.side * hit.bite
		for cell_index in count:
			var cell := structure.cells[cell_index]
			var inside := middle > cell.low.x and middle < cell.high.x
			inside = inside and y > cell.low.y and y < cell.high.y
			if not inside or maxf(shell, inner) < cell.low.z or minf(shell, inner) > cell.high.z:
				continue
			runs[cell_index] += b - a
			# Where the gash breaks into the cell: her shell, or the cell's side nearest it.
			var z := clampf(shell, cell.low.z, cell.high.z)
			_extend(reach[cell_index], a, y_a, z)
			_extend(reach[cell_index], b, y_b, z)
	if not ends.is_empty():
		damage.trace.append(Vector3(ends[3], ends[4], ends[5]))
	for cell_index in count:
		if runs[cell_index] > SLIVER:
			var unevenness := sink_stream.randf_range(bands.unevenness.x, bands.unevenness.y)
			var share := hit.width * runs[cell_index] * unevenness
			damage.openings.append(
				_opening(
					structure.cells[cell_index].name, reach[cell_index], share, runs[cell_index]
				)
			)
	return ends


## One GASH opening of [param area] from [param cell_name] to the sea, over the stretch
## of shell [param reach] spans: as long as the gash runs in the cell, as tall as its
## line climbs there and the slit it is as wide as.
static func _opening(
	cell_name: StringName, reach: PackedFloat64Array, area: float, run: float
) -> ShipOpening:
	var opening := ShipOpening.new()
	opening.name = StringName("gash_%s" % cell_name)
	opening.kind = ShipOpening.Kind.GASH
	opening.joins = [cell_name, ShipOpening.SEA]
	opening.centre = Vector3(
		(reach[0] + reach[3]) * 0.5, (reach[1] + reach[4]) * 0.5, (reach[2] + reach[5]) * 0.5
	)
	opening.size = Vector3(reach[3] - reach[0], reach[4] - reach[1] + area / run, 0.0)
	opening.area = area
	return opening


## Every watertight wall across her within [param within] of either of the gash's
## [param ends]: its ends lie along her, so a wall along her — a hold's side — runs
## beside the gash, never past an end of it.
static func _weaken(
	structure: ShipStructure, within: float, ends: PackedFloat64Array, damage: HitDamage
) -> void:
	if ends.is_empty():
		return
	for wall: ShipWall in structure.walls:
		if wall.axis != ShipWall.Axis.ACROSS:
			continue
		for end in 2:
			var x := ends[end * 3]
			var y := ends[end * 3 + 1]
			var z := ends[end * 3 + 2]
			if _distance_squared(wall, x, y, z) <= within * within:
				damage.weakened.append(wall.name)
				break


## The doors the ship shuts at the hit that will jam open, then the openings that start
## shut and were left open: one draw for each with a chance of it, in her openings'
## order.
static func _fittings(
	structure: ShipStructure, sink_stream: RandomNumberGenerator, damage: HitDamage
) -> void:
	for opening: ShipOpening in structure.openings:
		if opening.shuts_at_hit and opening.flip_chance > 0.0:
			if sink_stream.randf() < opening.flip_chance:
				damage.jammed.append(opening.name)
	for opening: ShipOpening in structure.openings:
		var shut := opening.starts == ShipOpening.Start.SHUT
		if not opening.shuts_at_hit and shut and opening.flip_chance > 0.0:
			if sink_stream.randf() < opening.flip_chance:
				damage.left_open.append(opening.name)


## The gash's height at [param x]: its line, kept within her hit zone.
static func _height(hit: IcebergHit, structure: ShipStructure, x: float) -> float:
	var y := structure.waterline_y - hit.depth_at(x)
	return clampf(y, structure.hit_zone_y.x, structure.hit_zone_y.y)


## Cuts the gash at [param x] where that falls inside it.
static func _cut(cuts: PackedFloat64Array, x: float, damage: HitDamage) -> void:
	if x > damage.from_x and x < damage.to_x:
		cuts.append(x)


static func _extend(reach: PackedFloat64Array, x: float, y: float, z: float) -> void:
	reach[0] = minf(reach[0], x)
	reach[1] = minf(reach[1], y)
	reach[2] = minf(reach[2], z)
	reach[3] = maxf(reach[3], x)
	reach[4] = maxf(reach[4], y)
	reach[5] = maxf(reach[5], z)


## How far ship point ([param x], [param y], [param z]) stands from [param wall], a
## wall across her, squared.
static func _distance_squared(wall: ShipWall, x: float, y: float, z: float) -> float:
	var off_across := maxf(maxf(wall.span.x - z, z - wall.span.y), 0.0)
	var off_up := maxf(maxf(wall.bottom - y, y - wall.top), 0.0)
	return (x - wall.at) * (x - wall.at) + off_across * off_across + off_up * off_up
