class_name ShipModel
extends RefCounted
## A modelled prop: a committed .glb under assets/models, made in Blender as
## assets/models/README.md says, gathered into one mesh in the prop's own space — every
## object's surfaces, each keeping the material that names its paint — for
## ShipMesh.model() to draw among the ship's own faces. Never a mesh instance of its
## own: it goes into the ship's batches, chunked under the lamp limit as any face is —
## but a lamp's (ShipLamp), which swings and glows as it burns, so is drawn under its
## lamp in the lamp's own materials.
##
## A model is read once: named() loads each .glb once a process, and a ShipModel holds
## its surfaces' arrays and its verdict, so drawing it a hundred times parses it once.

const MODELS := "res://assets/models"

## Every model named() has gathered, by name.
static var _named := {}

## The gathered mesh, named after its file.
var mesh: ArrayMesh
## Why ShipMesh.model() cannot paint it, as the rest of its error after the model's
## name; empty when nothing keeps it from being drawn.
var unfit := ""
## Its box in its own space.
var bounds: AABB
## How many triangles it carries.
var triangles := 0
## Its surfaces as model() draws them; none when it is unfit.
var surfaces: Array[Surface] = []


## One surface of a model, read once: its paint, its points, normals and ink, and its
## triangles' corners.
class Surface:
	var paint: ShipMesh.Paint
	var points: PackedVector3Array
	var normals: PackedVector3Array
	var inks: PackedColorArray
	var order: PackedInt32Array


func _init(gathered: Mesh) -> void:
	mesh = gathered
	bounds = gathered.get_aabb()
	var read: Array[Surface] = []
	for surface in gathered.get_surface_count():
		if gathered.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			unfit = ": surface %d is not triangles" % surface
			return
		var material := gathered.surface_get_material(surface)
		if material == null:
			unfit = ": surface %d has no material" % surface
			return
		var paint := ShipPaints.named(material.resource_name)
		if paint == null:
			unfit = ": surface %d's material %s names no paint" % [surface, material.resource_name]
			return
		var arrays := gathered.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_COLOR] == null:
			unfit = ": surface %d has no ink layer" % surface
			return
		if arrays[Mesh.ARRAY_NORMAL] == null:
			unfit = ": surface %d has no normals" % surface
			return
		var read_surface := Surface.new()
		read_surface.paint = paint
		read_surface.points = arrays[Mesh.ARRAY_VERTEX]
		read_surface.normals = arrays[Mesh.ARRAY_NORMAL]
		read_surface.inks = arrays[Mesh.ARRAY_COLOR]
		read_surface.order = PackedInt32Array(range(read_surface.points.size()))
		if arrays[Mesh.ARRAY_INDEX] != null:
			read_surface.order = arrays[Mesh.ARRAY_INDEX]
		triangles += read_surface.order.size() / 3
		read.append(read_surface)
	if triangles == 0:
		unfit = " has no triangles"
		return
	surfaces = read


## The model assets/models/[param name]/[param name].glb, gathered and read the first
## time it is asked for and the same ShipModel every time after.
static func named(name: String) -> ShipModel:
	if not _named.has(name):
		var scene: PackedScene = load(MODELS.path_join(name).path_join(name + ".glb"))
		_named[name] = ShipModel.new(mesh_of(scene))
	return _named[name]


## [param scene]'s every mesh, each where it stands in the scene, as one mesh named
## after its file (lifeboat.glb gathers as lifeboat).
static func mesh_of(scene: PackedScene) -> ArrayMesh:
	var root := scene.instantiate()
	var gathered := ArrayMesh.new()
	gathered.resource_name = scene.resource_path.get_file().get_basename()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var place := Transform3D.IDENTITY
		var up: Node = part
		while up != root:
			place = (up as Node3D).transform * place
			up = up.get_parent()
		for surface in part.mesh.get_surface_count():
			var arrays := _placed(part.mesh.surface_get_arrays(surface), place)
			gathered.add_surface_from_arrays(part.mesh.surface_get_primitive_type(surface), arrays)
			var material := part.mesh.surface_get_material(surface)
			gathered.surface_set_material(gathered.get_surface_count() - 1, material)
	root.free()
	return gathered


## A surface's [param arrays] moved by [param place]: its points, its normals turned by
## the inverse transpose, its triangles rewound where the place mirrors them.
static func _placed(arrays: Array, place: Transform3D) -> Array:
	if place == Transform3D.IDENTITY:
		return arrays
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in points.size():
		points[index] = place * points[index]
	arrays[Mesh.ARRAY_VERTEX] = points
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var turn := place.basis.inverse().transposed()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in normals.size():
			normals[index] = (turn * normals[index]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	# A tangent would no longer match its turned normal; the ship's paints read none.
	arrays[Mesh.ARRAY_TANGENT] = null
	if place.basis.determinant() < 0.0:
		var order := PackedInt32Array(range(points.size()))
		if arrays[Mesh.ARRAY_INDEX] != null:
			order = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, order.size(), 3):
			var first := order[index + 1]
			order[index + 1] = order[index + 2]
			order[index + 2] = first
		arrays[Mesh.ARRAY_INDEX] = order
	return arrays
