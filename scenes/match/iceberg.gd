class_name Iceberg
extends Node3D
## The iceberg she strikes, drawn where IcebergPlanner has it at the drawn tick: on the
## sea, level, whatever she does — in the frame she lay in as it struck. Nothing for a
## match without a hit. Presentation only: no collision, nothing it does reaches the
## sim (D12).

var _planner: IcebergPlanner
## From the sea's frame (IcebergPlanner) to the world: her ship-local x and z as she
## lay when it struck, level, the sea at y = 0.
var _sea_to_world := Transform3D()
var _mesh := MeshInstance3D.new()
var _material := ShaderMaterial.new()
var _sky: ShaderMaterial
var _water: ShaderMaterial
var _dusk: Environment


func _init() -> void:
	name = "Iceberg"
	_material.shader = preload("res://scenes/match/iceberg.gdshader")
	_mesh.name = "Ice"
	_mesh.material_override = _material
	add_child(_mesh)
	visible = false


## Draws the berg of [param schedule]'s hit on [param layout] in the match of
## [param match_seed], lit and hazed as [param sea_and_sky]'s dusk and sea are.
func setup(
	schedule: SinkSchedule, layout: ShipLayout, match_seed: int, sea_and_sky: SeaAndSky
) -> void:
	_planner = IcebergPlanner.for_match(schedule, layout, match_seed)
	visible = _planner != null
	if _planner == null:
		return
	var struck := schedule.pose_at(schedule.hit_tick()).transform
	var bow := Vector3(struck.basis.x.x, 0.0, struck.basis.x.z).normalized()
	var at_sea := struck * Vector3(0.0, layout.structure.waterline_y, 0.0)
	_sea_to_world = Transform3D(
		Basis(bow, Vector3.UP, bow.cross(Vector3.UP)), Vector3(at_sea.x, 0.0, at_sea.z)
	)
	_mesh.mesh = mesh_of(_planner)
	_dusk = sea_and_sky.dusk()
	_sky = _dusk.sky.sky_material
	_material.set_shader_parameter(&"fog_begin", _dusk.fog_depth_begin)
	_material.set_shader_parameter(&"fog_end", _dusk.fog_depth_end)
	_material.set_shader_parameter(&"fog_curve", _dusk.fog_depth_curve)
	_water = sea_and_sky.water()
	_material.set_shader_parameter(&"sun_direction", sea_and_sky.sun())
	_take(_water, [&"haze_begin", &"haze_end"])


## Stands it where it is at [param tick] — a fraction between two ticks for a frame
## drawn between them — dims it with the dusk, and fogs it as the view under the sea
## is while the eye is [param under] it.
func show_at(tick: float, under: bool) -> void:
	if _planner == null:
		return
	global_transform = _sea_to_world * _planner.pose_at(tick)
	_material.set_shader_parameter(&"under", under)
	_take(_sky, [&"gloom"])
	_material.set_shader_parameter(&"fog_colour", _dusk.fog_light_color)
	_take(_water, [&"under_fog_colour", &"under_fog_end", &"under_fog_curve"])


## Takes [param parameters] from [param material], those it has been given.
func _take(material: ShaderMaterial, parameters: Array[StringName]) -> void:
	for parameter in parameters:
		var value: Variant = material.get_shader_parameter(parameter)
		if value != null:
			_material.set_shader_parameter(parameter, value)


## [param planner]'s berg as a mesh: shaded as modelled, each face its own colour.
static func mesh_of(planner: IcebergPlanner) -> ArrayMesh:
	var corners := planner.shape()
	var shades := planner.shades()
	var colours := PackedColorArray()
	for face in corners.size() / 3:
		for corner in 3:
			colours.append(shades[face])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = corners
	arrays[Mesh.ARRAY_NORMAL] = planner.normals()
	arrays[Mesh.ARRAY_COLOR] = colours
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
