class_name GreyboxHull
extends Node3D
## The greybox's hull, drawn from her data (D6, SH30): the shell her structure's
## sections enclose — each cut across her from her keel up either side to her sheer —
## lofted from section to section along each run of one sheer, flat across her stern
## and closed onto her centreline at her stem,
## in the dressed hull's paint (ship.gdshader's HULL: red oxide under the boot line, a
## pale riband under the sheer, the sea's lap along her waterline); the inside of a
## bulwark standing over a deck as a house's side; her deck plating out to the shell
## where her decks' rectangles stop short of it, open over each stair up through a hole
## in a deck; and a dark mark at each freeing port and porthole of hers. ShipGreybox
## draws it under a ship with a structure, in place of its hull blocks. Drawn only — the
## sim never reads a mesh — and nothing at or above [member cut_above] is.

## How thick a freeing port's or a porthole's mark is, across the shell.
const MARK := 0.08
const PORT_COLOUR := ArtPalette.STEEL
const GLASS_COLOUR := ArtPalette.MIRROR

## Ship-local height: nothing of her at or above it is drawn — the observer's cut-away.
var cut_above := INF

var _mesh: ShipMesh
var _hull := ShipMesh.Paint.new(ShipMesh.Finish.HULL, ArtPalette.HULL)
var _bulwark := ShipMesh.Paint.new(ShipMesh.Finish.HOUSE, ArtPalette.HOUSE)
var _plating := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, ArtPalette.DECK)


## Draws [param layout]'s hull from her structure.
func build(layout: ShipLayout) -> void:
	for child: Node in get_children():
		child.queue_free()
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	_mesh = ShipMesh.new(func(_point: Vector3) -> bool: return true, no_rooms)
	_mesh.cut_above = cut_above
	var sides := SectionHull.shell_sides(layout.structure.sections)
	SectionHull.shell(layout, _mesh, _hull, _bulwark, _plating, sides)
	_mesh.commit(self, _materials(layout))
	_mark_openings(layout.structure)


## A dark mark through her shell at each freeing port and porthole of [param structure].
func _mark_openings(structure: ShipStructure) -> void:
	for opening: ShipOpening in structure.openings:
		var colour := PORT_COLOUR
		if opening.kind == ShipOpening.Kind.PORTHOLE:
			colour = GLASS_COLOUR
		elif opening.kind != ShipOpening.Kind.FREEING_PORT:
			continue
		if opening.centre.y >= cut_above:
			continue
		var size := opening.size
		size[opening.facing()] = MARK
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		box.material = material
		mark.mesh = box
		mark.position = opening.centre
		add_child(mark)


## The hull's paints: ship.gdshader's, with the dressed ship's colours and her boot line
## (ShipArt), cut away as the observer's view is.
func _materials(layout: ShipLayout) -> Dictionary:
	var materials := {}
	for finish: int in [ShipMesh.Finish.HULL, ShipMesh.Finish.HOUSE, ShipMesh.Finish.PLAIN]:
		var material := ShaderMaterial.new()
		material.shader = ShipArt.CUT_SHADER if is_finite(cut_above) else ShipArt.SHADER
		material.set_shader_parameter("finish", finish)
		material.set_shader_parameter("ink", ArtPalette.INK)
		material.set_shader_parameter("bottom_colour", ArtPalette.HULL_BOTTOM)
		material.set_shader_parameter("riband_colour", ArtPalette.RIBAND)
		material.set_shader_parameter("boot_height", ShipArt.BOOT_ABOVE - layout.freeboard)
		material.set_shader_parameter("trim_colour", ArtPalette.TEAK)
		material.set_shader_parameter("foot_colour", ArtPalette.HOUSE_FOOT)
		if is_finite(cut_above):
			material.set_shader_parameter("cut_above", cut_above)
		materials[finish] = material
	return materials
