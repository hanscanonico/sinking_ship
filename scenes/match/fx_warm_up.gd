class_name FxWarmUp
extends Node3D
## Every see-through mesh the sinking's effects draw (SinkingFx's pools, the strike's
## and those round the eye among them), drawn once, unseen, as the match starts: the
## renderer builds a material's shader the first time it draws it, a freeze of a tenth
## of a second or more that the iceberg's strike, a burst or a billow would otherwise
## pay the moment it first shows. Each is drawn as its emitter draws it — a multimesh
## laid out as a CPUParticles3D's — as one grain, wholly clear, before the eye for one
## frame; then it is gone. The effects' own shaders take their opacity from the grain's
## colour, so nothing of them shows; the solid, lit boxes of wreckage would, and stay
## out.

## How far before the eye the grains are drawn, in metres.
const AHEAD := 4.0

var _meshes: Array[Mesh] = []
var _frames := 0


## Draws each see-through mesh [param emitters] draw, once.
func _init(emitters: Array[CPUParticles3D]) -> void:
	name = "FxWarmUp"
	visible = false
	# Runs after MatchScene (its process_priority), so the eye stands where this frame
	# draws from.
	process_priority = 2
	for emitter: CPUParticles3D in emitters:
		if _meshes.has(emitter.mesh) or not see_through(emitter.mesh):
			continue
		_meshes.append(emitter.mesh)
		var grains := MultiMesh.new()
		grains.transform_format = MultiMesh.TRANSFORM_3D
		grains.use_colors = true
		grains.use_custom_data = true
		grains.mesh = emitter.mesh
		grains.instance_count = 1
		# Full size: a grain shrunk to nothing is never drawn, and builds nothing.
		grains.set_instance_transform(0, Transform3D.IDENTITY)
		grains.set_instance_color(0, Color(1.0, 1.0, 1.0, 0.0))
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = grains
		drawn.cast_shadow = emitter.cast_shadow
		add_child(drawn)


## Whether [param mesh] is drawn in one of the effects' own shaders, which a clear
## grain leaves unseen.
static func see_through(mesh: Mesh) -> bool:
	return mesh.surface_get_material(0) is ShaderMaterial


## The meshes it draws.
func meshes() -> Array[Mesh]:
	return _meshes.duplicate()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > 1:
		queue_free()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	global_position = camera.global_position - camera.global_basis.z * AHEAD
	visible = true
