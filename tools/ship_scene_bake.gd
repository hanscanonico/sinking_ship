class_name ShipSceneBake
extends RefCounted
## A ship drawn as a scene of marked pieces, read back into the ShipLayout — her layout
## and her structure — that a generator writes (SH17, D6). The scene is an authoring
## aid: `make bake-ship` saves what this reads as the .tres the sim loads, and nothing
## in a match ever opens the scene. Collision never comes from a mesh: the bake reads
## each piece's own box, wedge, line or point, never a collider.
##
## A piece is a node whose metadata `ship` says what it is; every node without it — a
## folder, a camera, a light — is passed over, and pieces of a kind are read in the
## scene's order. A piece's shape comes from the node: its place in ship space (the
## root's own transform aside) and its size, snapped to PLACES decimals of a metre, the
## generators' own grain. Every other field is the node's metadata of that field's name
## — an enum by its key ("VOID", "SHUT") — and a field with no metadata keeps its
## default. Boxes stand square to the ship, unturned:
##
##   layout     the scene's root: freeboard, deck_thickness, the seats, dressed
##   platform   a CSGBox3D, its top the deck
##   ramp       a MeshInstance3D with a PrismMesh, its apex at one end (left_to_right 0 or
##              1): the wedge rises toward it, turned about y by quarter turns
##   blocker    a CSGBox3D, or a CSGCylinder3D for an upright cylinder, bottom to top
##   railing    a CSGBox3D line along its platform's edge, from its local -x end to its +x
##   ladder     end, turned about y; metadata platform names its platform's node. An edge
##              with no railing is open: a gap is where no span is drawn
##   spawn      any Node3D, standing where a seat starts
##   prop       a CSGCylinder3D, its underside where the crate stands
##   room       a CSGBox3D, its bottom the room's floor; its top is not data
##   structure  any node: the structure's numbers; her pieces below need one
##   section    a CSGPolygon3D extruded toward the bow from the aft end of its stretch:
##              its polygon the outline in (z, y), its depth the stretch's length
##   cell       a CSGBox3D: the cell's box
##   wall       a CSGBox3D flat across x (a wall across her) or z (one along her)
##   opening    a CSGBox3D flat across one axis: the opening's rectangle
##   mass       any Node3D at the item's centre
##   fitting    any Node3D at the fitting's base
##   strength   any node: her girder's strength; a weak_spot, any Node3D at its x
##   sure_hit   any node: the must-sink rule's last rung

## The metadata that tags a piece.
const TAG := &"ship"
## Decimals of a metre a shape is read to.
const PLACES := 4
## Per kind, the fields its node's shape, or the pieces read with it, give: never
## metadata.
const SHAPED := {
	&"layout":
	[
		&"platforms",
		&"ramps",
		&"blockers",
		&"railings",
		&"ladders",
		&"spawns",
		&"props",
		&"rooms",
		&"structure",
	],
	&"platform": [&"area", &"height"],
	&"ramp": [&"area", &"axis", &"start_height", &"end_height"],
	&"blocker": [&"shape", &"area", &"centre", &"radius", &"bottom", &"top"],
	&"railing": [&"platform", &"from", &"to"],
	&"ladder": [&"platform", &"from", &"to"],
	&"spawn": [],
	&"prop": [&"pos", &"radius", &"height"],
	&"room": [&"area", &"floor_height"],
	&"structure":
	[&"sections", &"cells", &"walls", &"openings", &"mass", &"fittings", &"strength", &"sure_hit"],
	&"section": [&"x", &"length", &"outline"],
	&"cell": [&"low", &"high"],
	&"wall": [&"axis", &"at", &"span", &"bottom", &"top"],
	&"opening": [&"centre", &"size"],
	&"mass": [&"centre"],
	&"fitting": [&"base"],
	&"strength": [&"weak"],
	&"weak_spot": [&"x"],
	&"sure_hit": [],
}
## The kinds that are part of a structure.
const STRUCTURE_KINDS: Array[StringName] = [
	&"structure",
	&"section",
	&"cell",
	&"wall",
	&"opening",
	&"mass",
	&"fitting",
	&"strength",
	&"weak_spot",
	&"sure_hit",
]
## A quarter turn about y — local x along her z, local -z toward her bow: how a section
## stands, and a ramp rising along her z.
const QUARTER_TURN := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))

## The ship the scene draws, as far as it could be read.
var layout := ShipLayout.new()
## Every reason the scene is not a ship; empty when it is.
var problems := PackedStringArray()
var _root: Node


## Reads the scene whose root is [param root].
func _init(root: Node) -> void:
	_root = root
	var pieces := {}
	_gather(root, pieces)
	if root.get_meta(TAG, &"") != &"layout":
		problems.append("the scene's root must be tagged %s = layout" % TAG)
	_fields(layout, root, &"layout")
	var platforms := {}
	for node: Node in pieces.get(&"platform", []):
		platforms[node.name] = layout.platforms.size()
		layout.platforms.append(_platform(node))
	for node: Node in pieces.get(&"ramp", []):
		layout.ramps.append(_ramp(node))
	for node: Node in pieces.get(&"blocker", []):
		layout.blockers.append(_blocker(node))
	for node: Node in pieces.get(&"railing", []):
		layout.railings.append(_line(ShipRailing.new(), node, platforms) as ShipRailing)
	for node: Node in pieces.get(&"ladder", []):
		layout.ladders.append(_line(ShipLadder.new(), node, platforms) as ShipLadder)
	for node: Node in pieces.get(&"spawn", []):
		if _point(node):
			layout.spawns.append(_snapped(_placed(node).origin))
	for node: Node in pieces.get(&"prop", []):
		layout.props.append(_prop(node))
	for node: Node in pieces.get(&"room", []):
		layout.rooms.append(_room(node))
	_structure(pieces)


## The ship the scene saved at [param path] draws.
static func of_scene(path: String) -> ShipSceneBake:
	var root := (load(path) as PackedScene).instantiate()
	var baked := ShipSceneBake.new(root)
	root.free()
	return baked


## Every field, by its path under [param path], where [param baked] differs from
## [param wanted] — exactly, floats and all; empty when the two are the same field for
## field.
static func differences(baked: Variant, wanted: Variant, path: String) -> PackedStringArray:
	var found := PackedStringArray()
	if baked is Resource and wanted is Resource:
		if (baked as Resource).get_script() != (wanted as Resource).get_script():
			found.append("%s: a %s, not a %s" % [path, _class_of(baked), _class_of(wanted)])
			return found
		for property: Dictionary in stored(wanted):
			var field: String = property["name"]
			found.append_array(
				differences(baked.get(field), wanted.get(field), "%s.%s" % [path, field])
			)
	elif baked is Array and wanted is Array:
		var have: Array = baked
		var want: Array = wanted
		if have.size() != want.size():
			found.append("%s: %d items, not %d" % [path, have.size(), want.size()])
		for index in mini(have.size(), want.size()):
			found.append_array(differences(have[index], want[index], "%s[%d]" % [path, index]))
	elif typeof(baked) != typeof(wanted) or baked != wanted:
		found.append("%s: %s, not %s" % [path, var_to_str(baked), var_to_str(wanted)])
	return found


## The fields [param resource] stores: its script's exported variables.
static func stored(resource: Resource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for property: Dictionary in resource.get_property_list():
		var usage: int = property["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			found.append(property)
	return found


## The enum [param resource]'s field [param property] takes, by key; empty for a field
## that takes none.
static func enum_of(resource: Resource, property: Dictionary) -> Dictionary:
	if not property["usage"] & PROPERTY_USAGE_CLASS_IS_ENUM:
		return {}
	var named: String = property["class_name"]
	var constants := (resource.get_script() as Script).get_script_constant_map()
	return constants.get(named.get_slice(".", 1), {})


static func _class_of(resource: Resource) -> String:
	var script: Script = resource.get_script()
	return script.get_global_name() if script != null else resource.get_class()


## [param value] to PLACES decimals, read as the generators' text is.
static func _snap(value: float) -> float:
	return ("%.*f" % [PLACES, value]).to_float()


static func _snapped(value: Vector3) -> Vector3:
	return Vector3(_snap(value.x), _snap(value.y), _snap(value.z))


func _gather(node: Node, pieces: Dictionary) -> void:
	var kind: StringName = node.get_meta(TAG, &"")
	if not kind.is_empty() and node != _root:
		if not SHAPED.has(kind) or kind == &"layout":
			problems.append("%s: no piece is a %s" % [_label(node), kind])
		else:
			if not pieces.has(kind):
				pieces[kind] = []
			(pieces[kind] as Array).append(node)
	for child: Node in node.get_children():
		_gather(child, pieces)


func _label(node: Node) -> String:
	return "%s %s" % [node.get_meta(TAG, &"node"), _root.get_path_to(node)]


## Where [param node] stands in ship space: its transform up to the scene's root.
func _placed(node: Node) -> Transform3D:
	var place := Transform3D.IDENTITY
	var at := node
	while at != _root:
		if at is Node3D:
			place = (at as Node3D).transform * place
		at = at.get_parent()
	return place


## Sets the fields of [param resource], a [param kind], from [param node]'s metadata.
func _fields(resource: Resource, node: Node, kind: StringName) -> void:
	var fields := {}
	for property: Dictionary in stored(resource):
		fields[property["name"]] = property
	for key: StringName in node.get_meta_list():
		if key == TAG or (key == &"platform" and kind in [&"railing", &"ladder"]):
			continue
		if not fields.has(key) or key in SHAPED[kind]:
			problems.append("%s: %s is no field its metadata sets" % [_label(node), key])
			continue
		var property: Dictionary = fields[key]
		var value: Variant = node.get_meta(key)
		var keys := enum_of(resource, property)
		if not keys.is_empty() and value is String:
			value = keys.get(value)
			if value == null:
				problems.append("%s: %s has no key %s" % [_label(node), key, node.get_meta(key)])
				continue
		if value is String and property["type"] == TYPE_STRING_NAME:
			value = StringName(value)
		elif value is int and property["type"] == TYPE_FLOAT:
			value = float(value)
		if typeof(value) != property["type"]:
			problems.append("%s: %s is a %s" % [_label(node), key, type_string(property["type"])])
		elif value is Array:
			(resource.get(key) as Array).assign(value)
		else:
			resource.set(key, value)


## The box [param node] draws in ship space — its least and most x, y and z — or empty,
## with the reason said, when it is not a CSGBox3D standing square to the ship.
func _box(node: Node) -> PackedFloat64Array:
	var found := PackedFloat64Array()
	var box := node as CSGBox3D
	var place := _placed(node)
	if box == null:
		problems.append("%s: must be a CSGBox3D" % _label(node))
	elif not place.basis.is_equal_approx(Basis.IDENTITY):
		problems.append("%s: must stand square to the ship, unturned" % _label(node))
	else:
		for axis in 3:
			found.append(place.origin[axis] - box.size[axis] * 0.5)
			found.append(place.origin[axis] + box.size[axis] * 0.5)
	return found


## The plan of [param box], a _box(): its rectangle in the ship's x/z plane.
func _plan(box: PackedFloat64Array) -> Rect2:
	return Rect2(_snap(box[0]), _snap(box[4]), _snap(box[1] - box[0]), _snap(box[5] - box[4]))


## Whether [param node] can stand for a point: a Node3D, said when not.
func _point(node: Node) -> bool:
	if not node is Node3D:
		problems.append("%s: must be a Node3D" % _label(node))
	return node is Node3D


func _platform(node: Node) -> ShipPlatform:
	var platform := ShipPlatform.new()
	_fields(platform, node, &"platform")
	var box := _box(node)
	if not box.is_empty():
		platform.area = _plan(box)
		platform.height = _snap(box[3])
	return platform


func _ramp(node: Node) -> ShipRamp:
	var ramp := ShipRamp.new()
	_fields(ramp, node, &"ramp")
	var wedge: PrismMesh = null
	if node is MeshInstance3D:
		wedge = (node as MeshInstance3D).mesh as PrismMesh
	var place := _placed(node)
	var turn := place.basis
	if wedge == null or not wedge.left_to_right in [0.0, 1.0]:
		problems.append("%s: must be a PrismMesh wedge, its apex at one end" % _label(node))
		return ramp
	var rises := turn.x * (1.0 if wedge.left_to_right == 1.0 else -1.0)
	var square := is_equal_approx(absf(rises.x), 1.0) or is_equal_approx(absf(rises.z), 1.0)
	if not turn.y.is_equal_approx(Vector3.UP) or not square:
		problems.append("%s: must be turned about y by quarter turns" % _label(node))
		return ramp
	var size := wedge.size
	var run_x := absf(turn.x.x) * size.x + absf(turn.z.x) * size.z
	var run_z := absf(turn.x.z) * size.x + absf(turn.z.z) * size.z
	var at := place.origin
	ramp.area = Rect2(
		_snap(at.x - run_x * 0.5), _snap(at.z - run_z * 0.5), _snap(run_x), _snap(run_z)
	)
	ramp.axis = ShipRamp.Axis.X if absf(rises.x) > absf(rises.z) else ShipRamp.Axis.Z
	var low := _snap(at.y - size.y * 0.5)
	var high := _snap(at.y + size.y * 0.5)
	var upward := (rises.x if ramp.axis == ShipRamp.Axis.X else rises.z) > 0.0
	ramp.start_height = low if upward else high
	ramp.end_height = high if upward else low
	return ramp


func _blocker(node: Node) -> ShipBlocker:
	var blocker := ShipBlocker.new()
	_fields(blocker, node, &"blocker")
	if node is CSGCylinder3D:
		var cylinder := node as CSGCylinder3D
		var place := _placed(node)
		if not place.basis.is_equal_approx(Basis.IDENTITY):
			problems.append("%s: must stand upright, unturned" % _label(node))
			return blocker
		blocker.shape = ShipBlocker.Shape.CYLINDER
		blocker.centre = Vector2(_snap(place.origin.x), _snap(place.origin.z))
		blocker.radius = _snap(cylinder.radius)
		blocker.bottom = _snap(place.origin.y - cylinder.height * 0.5)
		blocker.top = _snap(place.origin.y + cylinder.height * 0.5)
		return blocker
	var box := _box(node)
	if not box.is_empty():
		blocker.area = _plan(box)
		blocker.bottom = _snap(box[2])
		blocker.top = _snap(box[3])
	return blocker


## A railing span's or a boarding ladder's [param line], from [param node]: the edge of
## the platform its metadata names, among [param platforms] by node name.
func _line(line: Resource, node: Node, platforms: Dictionary) -> Resource:
	var kind: StringName = node.get_meta(TAG)
	_fields(line, node, kind)
	var named: StringName = node.get_meta(&"platform", &"")
	if not platforms.has(named):
		problems.append("%s: names no platform %s" % [_label(node), named])
	else:
		line.set(&"platform", platforms[named])
	var place := _placed(node)
	if not node is CSGBox3D or not place.basis.y.is_equal_approx(Vector3.UP):
		problems.append("%s: must be a CSGBox3D lying level" % _label(node))
		return line
	var half := place.basis.x * ((node as CSGBox3D).size.x * 0.5)
	var ends: Array[Vector3] = [place.origin - half, place.origin + half]
	line.set(&"from", Vector2(_snap(ends[0].x), _snap(ends[0].z)))
	line.set(&"to", Vector2(_snap(ends[1].x), _snap(ends[1].z)))
	return line


func _prop(node: Node) -> ShipProp:
	var prop := ShipProp.new()
	_fields(prop, node, &"prop")
	var place := _placed(node)
	if not node is CSGCylinder3D or not place.basis.is_equal_approx(Basis.IDENTITY):
		problems.append("%s: must be a CSGCylinder3D standing upright" % _label(node))
		return prop
	var crate := node as CSGCylinder3D
	prop.pos = _snapped(place.origin - Vector3(0, crate.height * 0.5, 0))
	prop.radius = _snap(crate.radius)
	prop.height = _snap(crate.height)
	return prop


func _room(node: Node) -> ShipRoom:
	var room := ShipRoom.new()
	_fields(room, node, &"room")
	var box := _box(node)
	if not box.is_empty():
		room.area = _plan(box)
		room.floor_height = _snap(box[2])
	return room


## The structure, from the piece tagged structure and the pieces of her kinds in
## [param pieces]; none when the scene draws neither.
func _structure(pieces: Dictionary) -> void:
	if not STRUCTURE_KINDS.any(func(kind: StringName) -> bool: return pieces.has(kind)):
		return
	var tops: Array = pieces.get(&"structure", [])
	if tops.size() != 1:
		problems.append("a ship with a structure needs one piece tagged structure")
		return
	var structure := ShipStructure.new()
	layout.structure = structure
	_fields(structure, tops[0], &"structure")
	for node: Node in pieces.get(&"section", []):
		structure.sections.append(_section(node))
	for node: Node in pieces.get(&"cell", []):
		structure.cells.append(_cell(node))
	for node: Node in pieces.get(&"wall", []):
		structure.walls.append(_wall(node))
	for node: Node in pieces.get(&"opening", []):
		structure.openings.append(_opening(node))
	for node: Node in pieces.get(&"mass", []):
		var item := MassItem.new()
		_fields(item, node, &"mass")
		if _point(node):
			item.centre = _snapped(_placed(node).origin)
		structure.mass.append(item)
	for node: Node in pieces.get(&"fitting", []):
		var fitting := ShipFitting.new()
		_fields(fitting, node, &"fitting")
		if _point(node):
			fitting.base = _snapped(_placed(node).origin)
		structure.fittings.append(fitting)
	structure.strength = _single(pieces, &"strength", GirderStrength.new()) as GirderStrength
	structure.sure_hit = _single(pieces, &"sure_hit", IcebergHit.new()) as IcebergHit
	var spots: Array = pieces.get(&"weak_spot", [])
	if structure.strength == null and not spots.is_empty():
		problems.append("weak spots need a piece tagged strength")
	for node: Node in spots:
		var spot := WeakSpot.new()
		_fields(spot, node, &"weak_spot")
		if _point(node):
			spot.x = _snap(_placed(node).origin.x)
		if structure.strength != null:
			structure.strength.weak.append(spot)


## [param blank], its fields read from the one piece of [param kind]; null when the
## scene has none.
func _single(pieces: Dictionary, kind: StringName, blank: Resource) -> Resource:
	var found: Array = pieces.get(kind, [])
	if found.size() > 1:
		problems.append("a structure has one %s, not %d" % [kind, found.size()])
	if found.is_empty():
		return null
	_fields(blank, found[0], kind)
	return blank


func _section(node: Node) -> HullSection:
	var section := HullSection.new()
	_fields(section, node, &"section")
	var place := _placed(node)
	var loft := node as CSGPolygon3D
	if loft == null or loft.mode != CSGPolygon3D.MODE_DEPTH:
		problems.append("%s: must be a CSGPolygon3D extruded to a depth" % _label(node))
	elif not place.basis.is_equal_approx(QUARTER_TURN):
		problems.append("%s: must be extruded toward the bow, its x along z" % _label(node))
	else:
		section.x = _snap(place.origin.x + loft.depth * 0.5)
		section.length = _snap(loft.depth)
		var offset := Vector2(place.origin.z, place.origin.y)
		for corner: Vector2 in loft.polygon:
			section.outline.append(Vector2(_snap(offset.x + corner.x), _snap(offset.y + corner.y)))
	return section


func _cell(node: Node) -> FloodCell:
	var cell := FloodCell.new()
	_fields(cell, node, &"cell")
	var box := _box(node)
	if not box.is_empty():
		cell.low = Vector3(_snap(box[0]), _snap(box[2]), _snap(box[4]))
		cell.high = Vector3(_snap(box[1]), _snap(box[3]), _snap(box[5]))
	return cell


func _wall(node: Node) -> ShipWall:
	var wall := ShipWall.new()
	_fields(wall, node, &"wall")
	var box := _box(node)
	if box.is_empty():
		return wall
	if box[0] == box[1]:
		wall.axis = ShipWall.Axis.ACROSS
		wall.at = _snap(box[0])
		wall.span = Vector2(_snap(box[4]), _snap(box[5]))
	elif box[4] == box[5]:
		wall.axis = ShipWall.Axis.ALONG
		wall.at = _snap(box[4])
		wall.span = Vector2(_snap(box[0]), _snap(box[1]))
	else:
		problems.append("%s: must be flat across x or z" % _label(node))
	wall.bottom = _snap(box[2])
	wall.top = _snap(box[3])
	return wall


func _opening(node: Node) -> ShipOpening:
	var opening := ShipOpening.new()
	_fields(opening, node, &"opening")
	var box := _box(node)
	if not box.is_empty():
		opening.centre = _snapped(_placed(node).origin)
		opening.size = _snapped((node as CSGBox3D).size)
	return opening
