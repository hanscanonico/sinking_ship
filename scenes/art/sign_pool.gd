class_name SignPool
extends Node3D
## The letters of the rooms' door signs of one dressed ship (RoomDressing), drawn only
## within READ of the eye that draws the frame (ShipArt.pack): the Titanic has 2,300, and
## every node in her tree moves as she does. Each sign keeps its own Label3D, out of the
## tree until the eye comes within READ of it, nearest first and MOST at once, and taken
## out again once it is further: past READ its letters stand under two pixels high, and its
## enamel plate, drawn with her walls, stays.

## How near the eye a sign's letters are drawn, in metres, and the most drawn at once.
const READ := 24.0
const MOST := 128
## How far the eye moves before the signs drawn are chosen again, and the side of the
## cubes they are filed in to be found, in metres.
const AGAIN := 1.0
const CUBE := 8.0

## Every sign it holds, where it stands, and the cubes they stand in: Vector3i ->
## PackedInt32Array of their indices.
var _signs: Array[Label3D] = []
var _cubes := {}
## The signs drawn now, by index, and the eye they were chosen for (INF before any).
var _drawn := {}
var _eye := Vector3.INF
## The letters drawn, standing apart from her, placed where this node stands (StillGroup);
## null when they follow her as nodes.
var _group: StillGroup


## Holds each of [param labels], taken out of the tree: drawn as the eye nears it — by
## [param still], standing apart from her, when given.
func take(labels: Array[Label3D], still: StillInstances = null) -> void:
	if still != null:
		_group = still.group(self)
	_hold(labels)


func _hold(labels: Array[Label3D]) -> void:
	for label: Label3D in labels:
		if label.get_parent() != null:
			label.get_parent().remove_child(label)
		var index := _signs.size()
		_signs.append(label)
		if not label.visible:
			continue
		var cube := Vector3i((label.position / CUBE).floor())
		var filed: PackedInt32Array = _cubes.get(cube, PackedInt32Array())
		filed.append(index)
		_cubes[cube] = filed


## Every sign it holds, drawn or not: their letters, where they stand under it.
func signs() -> Array[Label3D]:
	return _signs


## How many signs are drawn now.
func drawn() -> int:
	return _drawn.size()


## Draws the signs within READ of [param eye] (its own space), nearest first and MOST at
## most, and none other.
func show_near(eye: Vector3) -> void:
	_eye = eye
	var near: Array[Vector2] = []
	var low := Vector3i(((eye - Vector3.ONE * READ) / CUBE).floor())
	var high := Vector3i(((eye + Vector3.ONE * READ) / CUBE).floor())
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				var held: PackedInt32Array = _cubes.get(Vector3i(x, y, z), PackedInt32Array())
				for index in held:
					var away := _signs[index].position.distance_squared_to(eye)
					if away <= READ * READ:
						near.append(Vector2(away, index))
	near.sort()
	var wanted := {}
	for at in mini(near.size(), MOST):
		wanted[int(near[at].y)] = true
	for index: int in _drawn.keys():
		if not wanted.has(index):
			if _group != null:
				_group.release(_signs[index])
			remove_child(_signs[index])
			_drawn.erase(index)
	for index: int in wanted:
		if not _drawn.has(index):
			add_child(_signs[index])
			if _group != null:
				_group.hold(_signs[index])
			_drawn[index] = true


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := to_local(camera.global_position)
	if eye.distance_squared_to(_eye) >= AGAIN * AGAIN:
		show_near(eye)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for label: Label3D in _signs:
			if label.get_parent() == null:
				label.free()
