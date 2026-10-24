class_name PropArt
extends Node3D
## Her props drawn (#273), each where MatchView shows it (place) as its snapshots have it
## (PropPlacing). A crate or a ring hangs under a node of its own, built outdoors, in
## paints of its own that are taken indoors as it moves (_light) — lamp-lit and out of
## the sun in a room, as the room's faces are — so it goes from the one light to the other
## as it crosses a doorway. Her furniture — every dining table and chair (FURNITURE) — is
## drawn by kind as instances of one mesh: a MultiMesh to each GROUP square of her decks a
## piece starts in, lit as indoors as that square's first piece stands, so a laid saloon
## costs a few draw calls, each lit by the lamps near it, and a piece that drifts on is
## still drawn with them.

## The kinds drawn as furniture, by their model (ShipModel.named): its origin the middle
## of the prop's underside, its front along +z (ShipProp.facing_deg).
const FURNITURE := {&"dining_table": "dining_table", &"dining_chair": "dining_chair"}
## How wide a square of her decks the furniture starting in it shares a MultiMesh, in
## metres: a few laid tables, under the lamps of one stretch of a saloon.
const GROUP := 8.0
## How far past its circle and its height a piece of furniture rocking afloat may lean
## (PropPlacing.ROCK_DEG): what its group's box holds besides.
const ROCKING := 0.2
## Where a lost piece of furniture is drawn: nowhere, its instance shrunk to nothing.
const NOWHERE := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

var _space: ShipSpace
## Per prop: its node, or null for a piece of furniture; its node's paints; where it
## stood and how far indoors it was when its paints were last told (_light).
var _nodes: Array[Node3D] = []
var _paints: Array[Dictionary] = []
var _at := PackedVector3Array()
var _indoors := PackedFloat32Array()
## Per prop: a piece of furniture's MultiMesh, or null, and its instance in it.
var _multimeshes: Array[MultiMesh] = []
var _slots := PackedInt32Array()


## Draws [param space]'s props in [param materials]' paints — the ship's — each where its
## layout entry starts it.
func build(space: ShipSpace, materials: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_space = space
	_nodes.clear()
	_paints.clear()
	_multimeshes.clear()
	_slots.clear()
	var props := space.layout.props
	_at.resize(props.size())
	_at.fill(Vector3(NAN, NAN, NAN))
	_indoors.resize(props.size())
	_indoors.fill(NAN)
	_multimeshes.resize(props.size())
	_slots.resize(props.size())
	_slots.fill(-1)
	var groups := {}
	for index in props.size():
		var prop := props[index]
		if FURNITURE.has(prop.kind):
			var cell := Vector3i(
				floori(prop.pos.x / GROUP), roundi(prop.pos.y), floori(prop.pos.z / GROUP)
			)
			var key := "%s %d %d %d" % [prop.kind, cell.x, cell.y, cell.z]
			if not groups.has(key):
				groups[key] = PackedInt32Array()
			groups[key].append(index)
			_nodes.append(null)
			_paints.append({})
		else:
			_nodes.append(_prop(prop, materials))
	var meshes := {}
	for key: String in groups:
		_furnish(groups[key], materials, meshes)


## Draws prop [param index] at [param placed] (ship space, PropPlacing), or nowhere when
## not [param shown].
func place(index: int, placed: Transform3D, shown: bool) -> void:
	var multimesh := _multimeshes[index]
	if multimesh != null:
		multimesh.set_instance_transform(_slots[index], placed if shown else NOWHERE)
		if shown:
			_hold(multimesh, _space.layout.props[index], placed.origin)
		return
	_nodes[index].visible = shown
	if shown:
		_nodes[index].transform = placed


## How many props it draws: every one of the layout's.
func count() -> int:
	return _nodes.size()


## Whether prop [param index] is drawn now: placed, not lost.
func shown(index: int) -> bool:
	var multimesh := _multimeshes[index]
	if multimesh != null:
		return multimesh.get_instance_transform(_slots[index]) != NOWHERE
	return _nodes[index].visible


## Prop [param index]'s node — a crate's, a ring's — or null for a piece of furniture.
func node(index: int) -> Node3D:
	return _nodes[index]


## Where prop [param index] is drawn now, in the world.
func drawn(index: int) -> Transform3D:
	var multimesh := _multimeshes[index]
	if multimesh != null:
		return global_transform * multimesh.get_instance_transform(_slots[index])
	return _nodes[index].global_transform


func _process(_delta: float) -> void:
	for index in _nodes.size():
		if _nodes[index] != null:
			_light(index)


## Takes prop [param index]'s paints as far indoors as the prop stands where MatchView
## has put it — only as it moves, and only as far as that changes it.
func _light(index: int) -> void:
	var at := _nodes[index].position
	if at == _at[index]:
		return
	_at[index] = at
	var indoors := _indoors_at(_space.layout.props[index], at)
	if indoors == _indoors[index]:
		return
	_indoors[index] = indoors
	for finish: int in ShipArt.PAINTS:
		(_paints[index][finish] as ShaderMaterial).set_shader_parameter("indoors", indoors)


## How far indoors [param prop] stands at [param at]: by the square its crate is drawn.
func _indoors_at(prop: ShipProp, at: Vector3) -> float:
	var half := prop.radius * ShipArt.CRATE_SIDE
	var foot := Rect2(at.x - half, at.z - half, half * 2.0, half * 2.0)
	return _space.indoors(foot, at.y + prop.height * 0.5)


## [param prop] under a node of its own, where it starts, in paints of its own that
## _light() takes indoors: a crate its model (ShipArt.CRATE_MODEL) — planked sides and lid,
## battens round its foot and its lid, posts and braces, stencils and lashing — at its
## underside; a lifebuoy the lifebelt about its middle, its face along z.
func _prop(prop: ShipProp, materials: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "%s%d" % [String(prop.kind).to_pascal_case(), _nodes.size()]
	add_child(node)
	node.position = prop.pos
	var model := RoomDressing.LIFEBELT_MODEL if prop.kind == &"lifebuoy" else ShipArt.CRATE_MODEL
	var paints := ShipArt.own_paints(materials)
	_model_mesh(model, paints, node)
	# Off the outdoor layer, so a lamp reaches it once it slides into a room; the
	# paints take no lamp while it stands outdoors.
	for part: Node in node.get_children():
		(part as MeshInstance3D).layers = 1
	_paints.append(paints)
	return node


## The furniture props [param group] — of one kind, starting in one GROUP square — as one
## MultiMesh, each instance where its prop starts; its mesh the kind's in paints as far
## indoors as the first of them stands, made once for each kind and indoors into
## [param meshes].
func _furnish(group: PackedInt32Array, materials: Dictionary, meshes: Dictionary) -> void:
	var props := _space.layout.props
	var first := props[group[0]]
	var indoors := _indoors_at(first, first.pos)
	var key := "%s %s" % [first.kind, indoors]
	if not meshes.has(key):
		var paints := ShipArt.own_paints(materials)
		for finish: int in ShipArt.PAINTS:
			(paints[finish] as ShaderMaterial).set_shader_parameter("indoors", indoors)
		var holder := Node3D.new()
		_model_mesh(FURNITURE[first.kind], paints, holder)
		meshes[key] = (holder.get_child(0) as MeshInstance3D).mesh
		holder.free()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = meshes[key]
	multimesh.instance_count = group.size()
	var instance := MultiMeshInstance3D.new()
	instance.name = "%s%d" % [String(first.kind).to_pascal_case(), group[0]]
	instance.multimesh = multimesh
	instance.layers = 1
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	multimesh.custom_aabb = AABB(first.pos, Vector3.ZERO)
	for slot in group.size():
		var index := group[slot]
		_multimeshes[index] = multimesh
		_slots[index] = slot
		multimesh.set_instance_transform(
			slot, PropPlacing.placed_at(props[index], props[index].pos)
		)
		_hold(multimesh, props[index], props[index].pos)


## Grows [param multimesh]'s box to hold [param prop] standing at [param at], however it
## rocks afloat (ROCKING) — what it is culled and lit by: its own box, grown only as a
## piece drifts out of it, never the box the engine would make of instances it has not
## yet been told of.
static func _hold(multimesh: MultiMesh, prop: ShipProp, at: Vector3) -> void:
	var reach := Vector3(prop.radius + ROCKING, ROCKING, prop.radius + ROCKING)
	var box := AABB(at - reach, reach * 2.0 + Vector3.UP * prop.height)
	if not multimesh.custom_aabb.encloses(box):
		multimesh.custom_aabb = multimesh.custom_aabb.merge(box)


## [param model]'s faces, built outdoors in [param paints], as mesh instances under
## [param parent].
static func _model_mesh(model: String, paints: Dictionary, parent: Node3D) -> void:
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, no_rooms)
	mesh.model(ShipModel.named(model), Transform3D.IDENTITY)
	mesh.commit(parent, paints)
