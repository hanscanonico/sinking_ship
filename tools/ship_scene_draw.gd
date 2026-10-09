class_name ShipSceneDraw
extends RefCounted
## A ShipLayout drawn as the scene of marked pieces ShipSceneBake reads (SH17): the
## bake's inverse, piece for piece in its vocabulary, so baking what this draws gives the
## ship back field for field. `make ship-scene` drew the steamer's authoring scene with
## it from her generated data. Her rooms and her structure are drawn hidden, so the
## scene opens as her greybox decks; show them in the editor to work on them.

## How tall a room's box and a railing's line are drawn, and how thick a line: not data.
const ROOM_HEIGHT := 2.1
const LINE_HEIGHT := 1.0
const LINE_THICKNESS := 0.05
## What each kind is drawn in; translucent where it would hide the decks.
const COLOURS := {
	&"platform": ArtPalette.DECK,
	&"ramp": ArtPalette.TREAD,
	&"blocker": ArtPalette.HOUSE,
	&"railing": ArtPalette.TEAK,
	&"ladder": ArtPalette.STEEL,
	&"prop": ArtPalette.CRATE,
	&"room": Color(0.4, 0.6, 0.9, 0.25),
	&"section": Color(0.13, 0.15, 0.17, 0.35),
	&"cell": Color(0.3, 0.7, 0.8, 0.2),
	&"wall": ArtPalette.BULKHEAD,
	&"opening": ArtPalette.LIFEBELT,
}

var _materials := {}


## [param layout] as a scene whose root is called [param title], every node owned by it
## so it packs whole.
static func scene(layout: ShipLayout, title: String) -> Node3D:
	return ShipSceneDraw.new()._draw(layout, title)


## The node name [param piece] goes by: its id in the file it was loaded from, else its
## [param kind] and [param index].
static func _name_of(piece: Resource, kind: StringName, index: int) -> String:
	if not piece.resource_scene_unique_id.is_empty():
		return piece.resource_scene_unique_id
	return "%s_%d" % [String(kind).to_pascal_case(), index]


## Gives [param node] the tag [param kind] and, as metadata, every field of
## [param resource] its shape does not give and that is not its default.
static func _tag(node: Node, resource: Resource, kind: StringName) -> void:
	node.set_meta(ShipSceneBake.TAG, kind)
	var blank: Resource = (resource.get_script() as Script).new()
	for property: Dictionary in ShipSceneBake.stored(resource):
		var field: StringName = property["name"]
		var value: Variant = resource.get(field)
		if field in ShipSceneBake.SHAPED[kind] or value == blank.get(field):
			continue
		var keys := ShipSceneBake.enum_of(resource, property)
		if not keys.is_empty():
			value = keys.find_key(value)
		elif value is Array:
			value = (value as Array).duplicate()
		node.set_meta(field, value)


func _draw(layout: ShipLayout, title: String) -> Node3D:
	var root := Node3D.new()
	root.name = title.to_pascal_case()
	_tag(root, layout, &"layout")
	var group := _group(root, "Platforms")
	var platform_names := PackedStringArray()
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		var box := _box(group, platform, &"platform", index)
		platform_names.append(box.name)
		box.size = Vector3(platform.area.size.x, layout.deck_thickness, platform.area.size.y)
		var middle := platform.area.get_center()
		box.position = Vector3(middle.x, platform.height - layout.deck_thickness * 0.5, middle.y)
	group = _group(root, "Ramps")
	for index in layout.ramps.size():
		_ramp(group, layout.ramps[index], index)
	group = _group(root, "Blockers")
	for index in layout.blockers.size():
		_blocker(group, layout.blockers[index], index)
	group = _group(root, "Railings")
	for index in layout.railings.size():
		_line(group, layout.railings[index], &"railing", index, layout, platform_names)
	group = _group(root, "Ladders")
	for index in layout.ladders.size():
		_line(group, layout.ladders[index], &"ladder", index, layout, platform_names)
	group = _group(root, "Spawns")
	for index in layout.spawns.size():
		var spawn := Marker3D.new()
		spawn.name = "Spawn_%d" % index
		spawn.set_meta(ShipSceneBake.TAG, &"spawn")
		spawn.position = layout.spawns[index]
		group.add_child(spawn)
	group = _group(root, "Props")
	for index in layout.props.size():
		var prop := layout.props[index]
		var crate := _cylinder(group, prop, &"prop", index, prop.radius, prop.height)
		crate.position = prop.pos + Vector3(0, prop.height * 0.5, 0)
	group = _group(root, "Rooms")
	group.visible = false
	for index in layout.rooms.size():
		var room := layout.rooms[index]
		var box := _box(group, room, &"room", index)
		box.size = Vector3(room.area.size.x, ROOM_HEIGHT, room.area.size.y)
		var middle := room.area.get_center()
		box.position = Vector3(middle.x, room.floor_height + ROOM_HEIGHT * 0.5, middle.y)
	if layout.structure != null:
		_structure(root, layout.structure)
	_own(root, root)
	return root


func _group(parent: Node, title: String) -> Node3D:
	var group := Node3D.new()
	group.name = title
	parent.add_child(group)
	return group


func _material(kind: StringName) -> StandardMaterial3D:
	if not _materials.has(kind):
		var material := StandardMaterial3D.new()
		material.albedo_color = COLOURS[kind]
		if material.albedo_color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[kind] = material
	return _materials[kind]


func _box(parent: Node, piece: Resource, kind: StringName, index: int) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = _name_of(piece, kind, index)
	box.material = _material(kind)
	_tag(box, piece, kind)
	parent.add_child(box)
	return box


func _cylinder(
	parent: Node, piece: Resource, kind: StringName, index: int, radius: float, height: float
) -> CSGCylinder3D:
	var cylinder := CSGCylinder3D.new()
	cylinder.name = _name_of(piece, kind, index)
	cylinder.material = _material(kind)
	cylinder.radius = radius
	cylinder.height = height
	cylinder.sides = 16
	_tag(cylinder, piece, kind)
	parent.add_child(cylinder)
	return cylinder


## A point piece: a marker at [param at].
func _marker(parent: Node, piece: Resource, kind: StringName, index: int, at: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = _name_of(piece, kind, index)
	marker.position = at
	_tag(marker, piece, kind)
	parent.add_child(marker)


func _ramp(parent: Node, ramp: ShipRamp, index: int) -> void:
	var wedge := MeshInstance3D.new()
	wedge.name = _name_of(ramp, &"ramp", index)
	_tag(wedge, ramp, &"ramp")
	var prism := PrismMesh.new()
	prism.material = _material(&"ramp")
	prism.left_to_right = 1.0 if ramp.end_height > ramp.start_height else 0.0
	var rise := absf(ramp.end_height - ramp.start_height)
	if ramp.axis == ShipRamp.Axis.X:
		prism.size = Vector3(ramp.area.size.x, rise, ramp.area.size.y)
	else:
		prism.size = Vector3(ramp.area.size.y, rise, ramp.area.size.x)
		wedge.basis = ShipSceneBake.QUARTER_TURN
	wedge.mesh = prism
	var middle := ramp.area.get_center()
	var height := (ramp.start_height + ramp.end_height) * 0.5
	wedge.position = Vector3(middle.x, height, middle.y)
	parent.add_child(wedge)


func _blocker(parent: Node, blocker: ShipBlocker, index: int) -> void:
	var middle := (blocker.bottom + blocker.top) * 0.5
	var height := blocker.top - blocker.bottom
	if blocker.shape == ShipBlocker.Shape.CYLINDER:
		var cylinder := _cylinder(parent, blocker, &"blocker", index, blocker.radius, height)
		cylinder.position = Vector3(blocker.centre.x, middle, blocker.centre.y)
		return
	var box := _box(parent, blocker, &"blocker", index)
	box.size = Vector3(blocker.area.size.x, height, blocker.area.size.y)
	var centre := blocker.area.get_center()
	box.position = Vector3(centre.x, middle, centre.y)


## A railing span or a boarding ladder: a line along its platform's edge, from → to
## along its local x, standing on the deck.
func _line(
	parent: Node,
	line: Resource,
	kind: StringName,
	index: int,
	layout: ShipLayout,
	platform_names: PackedStringArray
) -> void:
	var from: Vector2 = line.get(&"from")
	var to: Vector2 = line.get(&"to")
	var platform: int = line.get(&"platform")
	var box := _box(parent, line, kind, index)
	box.set_meta(&"platform", StringName(platform_names[platform]))
	var length := from.distance_to(to)
	var along := Vector3(to.x - from.x, 0, to.y - from.y) / length
	box.basis = Basis(along, Vector3.UP, along.cross(Vector3.UP))
	box.size = Vector3(length, LINE_HEIGHT, LINE_THICKNESS)
	var middle := (from + to) * 0.5
	var deck := layout.platforms[platform].height
	box.position = Vector3(middle.x, deck + LINE_HEIGHT * 0.5, middle.y)


func _structure(root: Node, structure: ShipStructure) -> void:
	var top := _group(root, "Structure")
	top.visible = false
	_tag(top, structure, &"structure")
	var group := _group(top, "Sections")
	for index in structure.sections.size():
		var section := structure.sections[index]
		var loft := CSGPolygon3D.new()
		loft.name = _name_of(section, &"section", index)
		loft.material = _material(&"section")
		_tag(loft, section, &"section")
		loft.polygon = section.outline
		loft.depth = section.length
		loft.transform = Transform3D(
			ShipSceneBake.QUARTER_TURN, Vector3(section.x - section.length * 0.5, 0, 0)
		)
		group.add_child(loft)
	group = _group(top, "Cells")
	for index in structure.cells.size():
		var cell := structure.cells[index]
		var box := _box(group, cell, &"cell", index)
		box.size = cell.high - cell.low
		box.position = (cell.low + cell.high) * 0.5
	group = _group(top, "Walls")
	for index in structure.walls.size():
		_wall(group, structure.walls[index], index)
	group = _group(top, "Openings")
	for index in structure.openings.size():
		var opening := structure.openings[index]
		var box := _box(group, opening, &"opening", index)
		box.size = opening.size
		box.position = opening.centre
	group = _group(top, "Mass")
	for index in structure.mass.size():
		_marker(group, structure.mass[index], &"mass", index, structure.mass[index].centre)
	group = _group(top, "Fittings")
	for index in structure.fittings.size():
		var fitting := structure.fittings[index]
		_marker(group, fitting, &"fitting", index, fitting.base)
	if structure.strength != null:
		var strength := _group(top, "Strength")
		_tag(strength, structure.strength, &"strength")
		var weak := structure.strength.weak
		for index in weak.size():
			_marker(strength, weak[index], &"weak_spot", index, Vector3(weak[index].x, 0, 0))
	if structure.sure_hit != null:
		_tag(_group(top, "SureHit"), structure.sure_hit, &"sure_hit")


func _wall(parent: Node, wall: ShipWall, index: int) -> void:
	var box := _box(parent, wall, &"wall", index)
	var middle := (wall.span.x + wall.span.y) * 0.5
	var height := wall.top - wall.bottom
	var up := (wall.bottom + wall.top) * 0.5
	if wall.axis == ShipWall.Axis.ACROSS:
		box.size = Vector3(0, height, wall.span.y - wall.span.x)
		box.position = Vector3(wall.at, up, middle)
	else:
		box.size = Vector3(wall.span.y - wall.span.x, height, 0)
		box.position = Vector3(middle, up, wall.at)


## Makes [param owner] the owner of every node under [param node], so it packs.
func _own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_own(child, owner)
