class_name BotPockets
extends RefCounted
## The air pockets a bot in the water knows of (§5b.3, Q22, D10): the cells it has seen
## holding trapped air over water — from its eye, nothing between — each with the spot
## where a swimmer floats in it, its head in the air; kept until it sees one gone.
## Seen, never foreseen: only the pose its view hands it. Nothing here rolls the bot's
## stream.

var _surfaces: Surfaces
var _rules: BrawlRules
var _eye: float
## The pockets it knows, in the order it first saw them: their cells, and where in
## each a swimmer's feet float.
var _cells := PackedInt32Array()
var _spots := PackedVector3Array()


func _init(surfaces: Surfaces, rules: BrawlRules, eye_height: float) -> void:
	_surfaces = surfaces
	_rules = rules
	_eye = eye_height


## Looks round from a swimmer's feet at [param feet] under [param pose]: each pocket in
## sight it now knows, where it floats in it as near it as the cell allows; each it
## knew that it sees gone, it forgets.
func look(feet: Vector3, pose: ShipPose) -> void:
	var eye := feet + Vector3.UP * _eye
	for cell in pose.pockets.size():
		var known := _cells.find(cell)
		var spot := _spot(cell, feet, pose)
		if spot == Vector3.INF:
			if known != -1 and _surfaces.line_of_sight(eye, _head(_spots[known]), pose):
				_cells.remove_at(known)
				_spots.remove_at(known)
			continue
		if not _surfaces.line_of_sight(eye, _head(spot), pose):
			continue
		if known == -1:
			_cells.append(cell)
			_spots.append(spot)
		else:
			_spots[known] = spot


## The nearest spot of a pocket it knows that a swim of [param reach] from [param feet]
## reaches — none it floats in already — or INF.
func nearest(feet: Vector3, reach: float, pose: ShipPose) -> Vector3:
	var here := pose.cell_at(_head(feet))
	var best := Vector3.INF
	var best_distance := reach
	for index in _cells.size():
		var distance := feet.distance_to(_spots[index])
		if _cells[index] != here and distance <= best_distance:
			best = _spots[index]
			best_distance = distance
	return best


## Where in [param cell] a swimmer coming from [param feet] floats with its head in its
## trapped air under [param pose]: at the water's surface, over the point of its box
## nearest, a body's radius in from its sides; INF where it holds no pocket over water.
func _spot(cell: int, feet: Vector3, pose: ShipPose) -> Vector3:
	if pose.pockets[cell] <= 0.0:
		return Vector3.INF
	var box := pose.cells.box_of(cell)
	var radius := _rules.body_radius
	if box.size.x <= radius * 2.0 or box.size.z <= radius * 2.0:
		return Vector3.INF
	var at := Vector3(
		clampf(feet.x, box.position.x + radius, box.end.x - radius),
		box.position.y,
		clampf(feet.z, box.position.z + radius, box.end.z - radius)
	)
	var floor_height := pose.world_height(at)
	if pose.levels[cell] <= floor_height + CellMap.DRY:
		return Vector3.INF
	at.y = pose.water_height(at) - _rules.swim_depth
	return at if pose.in_pocket(_head(at)) else Vector3.INF


## The head of a swimmer whose feet are at [param feet].
func _head(feet: Vector3) -> Vector3:
	return feet + Vector3.UP * _rules.head_height()
