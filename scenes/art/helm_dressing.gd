class_name HelmDressing
extends RefCounted
## A wheelhouse's own (RoomDressing.Kind.HELM), against its walls: the wheel on its
## steering box in the forward wall between a binnacle and an engine-order telegraph, a
## clock over it and voice pipes in the corners; a chart over its chart case on the after
## wall, between the windows; and a teak surround and sill at each window. Each modelled
## fitting stands flat on its wall within a wall fitting's depth (RoomDressing.WHEEL_STAND,
## RoomDressing.CHART_CASE), on a wall as long as it is wide: a stub of wall left at a
## door's corner takes none.

var _space: ShipSpace


func _init(space: ShipSpace) -> void:
	_space = space


## [param room]'s own, into [param mesh]; [param glass] its panes (RoomDressing.build()).
func build(mesh: ShipMesh, room: ShipRoom, glass: Array[Array]) -> void:
	for wall: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if wall.side == 1 and wall.length() >= RoomDressing.WHEEL_STAND.size.x:
			_wheel_wall(mesh, wall)
		elif wall.side == 3 and wall.length() >= RoomDressing.CHART_CASE.size.x:
			_chart_wall(mesh, wall)
	for pane: Array in glass:
		if pane[3]:
			continue
		var half: Vector2 = pane[4] + Vector2.ONE * (ShipFittings.WINDOW_FRAME + 0.05)
		var centre: Vector3 = pane[1]
		var normal: Vector3 = pane[2]
		var right := normal.cross(Vector3.UP).normalized()
		for bar: Rect2 in [
			Rect2(-half.x, half.y - 0.05, half.x * 2.0, 0.05),
			Rect2(-half.x, -half.y, 0.05, half.y * 2.0),
			Rect2(half.x - 0.05, -half.y, 0.05, half.y * 2.0),
		]:
			var middle := centre + right * bar.get_center().x + Vector3.UP * bar.get_center().y
			var at := middle + normal * 0.02
			RoomDressing.panel(mesh, at, right, bar.size * 0.5, normal, ShipPaints.frame)
		var sill := centre - Vector3.UP * (half.y + 0.02)
		var at := Vector2(sill.x, sill.z)
		var across := Vector2(right.x, right.z) * half.x
		var ledge := Rect2(at - across, Vector2.ZERO).expand(
			at + across + Vector2(normal.x, normal.z) * 0.08
		)
		RoomDressing.block(mesh, ledge, sill.y - 0.03, sill.y + 0.02, ShipPaints.frame)


## The wheelhouse's forward wall: the wheel on its pedestal between the binnacle and
## the telegraph (RoomDressing.WHEEL_STAND_MODEL), a clock over the wheel and voice pipes
## either side of it, clear of the windows by the corners.
func _wheel_wall(mesh: ShipMesh, wall: RoomDressing.Wall) -> void:
	var middle := wall.middle()
	var stand := ShipModel.named(RoomDressing.WHEEL_STAND_MODEL)
	mesh.model(stand, wall.place(wall.at(middle, 0.0)))
	var clock := wall.at(middle, 1.75, 0.02)
	RoomDressing.disc(mesh, clock, wall.normal, 0.11, ShipPaints.enamel, 12)
	var rim := clock + wall.normal * 0.004
	RoomDressing.ring(mesh, rim, wall.normal, 0.1, 0.13, ShipPaints.brass, 12)
	for beside: float in [middle - 0.2, middle + 0.2]:
		var pipe := wall.at(beside, 1.3, 0.04)
		var ceiling := _space.ceiling(wall.room, pipe.x, pipe.z) - ShipArt.PLANK
		RoomDressing.pipe(mesh, pipe, Vector3(pipe.x, ceiling, pipe.z), 0.025, ShipPaints.brass)
		var mouth := Vector2(pipe.x, pipe.z)
		mesh.cylinder(mouth, 0.045, pipe.y - 0.08, pipe.y, 8, ShipPaints.brass)


## The wheelhouse's after wall: a chart pinned in a frame between its windows, over a
## shallow chart case of two drawers (RoomDressing.CHART_CASE_MODEL).
func _chart_wall(mesh: ShipMesh, wall: RoomDressing.Wall) -> void:
	var case := ShipModel.named(RoomDressing.CHART_CASE_MODEL)
	mesh.model(case, wall.place(wall.at(wall.middle(), 0.0)))
