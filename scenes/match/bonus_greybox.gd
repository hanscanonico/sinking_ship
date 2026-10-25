class_name BonusGreybox
extends Node3D
## The bonuses aboard, drawn in greybox (#307) from a snapshot (D5), in ship space: at each
## one's bonus spot a shape of its kind's size in its kind's colour, lit from within
## (lit_from_within), standing on the spot's floor — until a kind's model is made, inside
## the same size. None for a bonus no longer aboard, nor in a match without bonuses. It
## never moves: a bonus lies where it came.

## The kinds a match's bonuses may be, and her bonus spots.
var _kinds: Array[BonusKind] = []
var _spots: Array[ShipBonusSpot] = []
## One shape per bonus drawn, kept from snapshot to snapshot; and per kind, by its index,
## the mesh every bonus of it is drawn with.
var _shapes: Array[MeshInstance3D] = []
var _meshes: Dictionary[int, Mesh] = {}


## Draws the bonuses of a match on [param layout] played with [param bonus_rules]; none for
## null.
func setup(layout: ShipLayout, bonus_rules: BonusRules) -> void:
	_kinds.clear()
	if bonus_rules != null:
		_kinds.assign(bonus_rules.kinds)
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
		shape.mesh = _mesh_of(kind)
		shape.position = _spots[entry["spot"]].point + Vector3.UP * _kinds[kind].height * 0.5


## What a bonus of [param kind] is drawn in, and the mark a seat that took one wears
## (Brawler.wear_bonus, #313): its kind's colour, given off as well as lit — lit from
## within, so that it shows in a dark room — and depth-tested as any mesh is, with no
## lamp, whose light would reach through a wall: nothing of it shows through one (§13).
static func lit_from_within(kind: BonusKind) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = kind.mark
	material.emission_enabled = true
	material.emission = kind.mark
	return material


## The mesh every bonus of the kind at [param index] is drawn with: an upright cylinder
## its size, lit from within, made the first time.
func _mesh_of(index: int) -> Mesh:
	if not _meshes.has(index):
		var kind := _kinds[index]
		var mesh := CylinderMesh.new()
		mesh.top_radius = kind.radius
		mesh.bottom_radius = kind.radius
		mesh.height = kind.height
		mesh.material = lit_from_within(kind)
		_meshes[index] = mesh
	return _meshes[index]
