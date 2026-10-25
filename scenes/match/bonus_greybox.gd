class_name BonusGreybox
extends Node3D
## The bonuses aboard, drawn in greybox (#307) from a snapshot (D5), in ship space: at each
## one's bonus spot a shape of its kind's size in its kind's colour, standing on the spot's
## floor — until a kind's model is made, inside the same size. None for a bonus no longer
## aboard, nor in a match without bonuses. It never moves: a bonus lies where it came.

## The kinds a match's bonuses may be, and her bonus spots.
var _kinds: Array[BonusKind] = []
var _spots: Array[ShipBonusSpot] = []
## One shape per bonus drawn, kept from snapshot to snapshot; and per kind, by its index,
## the mesh every bonus of it is drawn with.
var _shapes: Array[MeshInstance3D] = []
var _meshes: Dictionary[int, Mesh] = {}


## Draws the bonuses of a match on [param layout] played with [param bonuses]; none for
## null.
func setup(layout: ShipLayout, bonuses: BonusRules) -> void:
	_kinds.clear()
	if bonuses != null:
		_kinds.assign(bonuses.kinds)
	_spots = layout.bonus_spots
	_meshes.clear()
	for shape: MeshInstance3D in _shapes:
		shape.queue_free()
	_shapes.clear()


## Every bonus aboard [param snapshot] has, drawn at its spot; every other shape hidden.
func show_bonuses(snapshot: Dictionary) -> void:
	var aboard: Array = snapshot["bonuses"]
	while _shapes.size() < aboard.size():
		var shape := MeshInstance3D.new()
		shape.name = "Bonus%d" % _shapes.size()
		add_child(shape)
		_shapes.append(shape)
	for index in _shapes.size():
		var shape := _shapes[index]
		shape.visible = index < aboard.size()
		if not shape.visible:
			continue
		var entry: Dictionary = aboard[index]
		var kind: int = entry["kind"]
		shape.mesh = _mesh(kind)
		shape.position = _spots[entry["spot"]].point + Vector3.UP * _kinds[kind].height * 0.5


## The shape every bonus of kind [param kind] is drawn as: an upright cylinder its size, in
## its colour, made the first time.
func _mesh(kind: int) -> Mesh:
	if not _meshes.has(kind):
		var made := _kinds[kind]
		var shape := CylinderMesh.new()
		shape.top_radius = made.radius
		shape.bottom_radius = made.radius
		shape.height = made.height
		var material := StandardMaterial3D.new()
		material.albedo_color = made.mark
		shape.material = material
		_meshes[kind] = shape
	return _meshes[kind]
