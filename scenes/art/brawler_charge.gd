class_name BrawlerCharge
extends MeshInstance3D
## A charge, drawn on the brawler holding it (Brawler): sparks streaming up and back
## off its fists and shoulders — more of them, faster and longer as the charge fills
## — and, once it walks, speed lines trailing behind it. Laid on the posed chest as
## it is shown, so it rides the body. One small mesh that brawler_charge.gdshader
## flies: a shown frame costs one draw, the chest's place and a uniform when the
## charge or the walk changes; a hidden one nothing.

const SHADER := preload("res://scenes/art/brawler_charge.gdshader")
## The bone it rides, and the bones its sparks stream off besides the fists.
const CHEST := &"DEF-spine.003"
const SHOULDERS: Array[StringName] = [&"DEF-upper_arm.L", &"DEF-upper_arm.R"]
## The mannequin faces +z.
const AHEAD := Vector3(0.0, 0.0, 1.0)
const SPARKS_PER_POINT := 4
const LINES := 6
## How far under and over the chest the speed lines run, in metres.
const LINE_LOW := -0.85
const LINE_HIGH := 0.2
## Room round the chest for the streaks the shader flies off the mesh's points.
const ROOM := 1.6

## Built off the first skeleton seen: every brawler is the same mannequin.
static var _mesh: ArrayMesh

var _skeleton: Skeleton3D
var _chest: int
var _material: ShaderMaterial
var _fill := -1.0
var _moving := -1.0


## How full a charge of [param charge] ticks held is, 0…1, from the rules'
## [param threshold] ticks, where a held shove becomes a charge, to [param full].
static func filled(charge: float, threshold: int, full: int) -> float:
	return clampf((charge - threshold) / float(full - threshold), 0.0, 1.0)


## Builds the sparks for a brawler whose skeleton is [param skeleton], to be added
## to it and ride its CHEST bone.
func setup(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	_chest = skeleton.find_bone(CHEST)
	if _mesh == null:
		_mesh = _streaks(skeleton)
	mesh = _mesh
	custom_aabb = AABB(-Vector3.ONE * ROOM, Vector3.ONE * ROOM * 2.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("hot", ArtPalette.CHARGE)
	_material.set_shader_parameter("core", ArtPalette.CHARGE_CORE)
	material_override = _material
	visible = false


## Shows a charge [param fill] full (0…1), its body walking [param moving] of a
## charge's walk (0…1), on the chest as posed now.
func show_charge(fill: float, moving: float) -> void:
	transform = _skeleton.get_bone_global_pose(_chest)
	if fill != _fill:
		_fill = fill
		_material.set_shader_parameter("fill", fill)
	if moving != _moving:
		_moving = moving
		_material.set_shader_parameter("moving", moving)


## The streaks, collapsed on where they start, in the chest bone's space: sparks on
## the fists — where the charge's pose reaches them — and the shoulders, lines on the
## chest; each carries the way the body faces, its seed and its kind (see the shader).
static func _streaks(skeleton: Skeleton3D) -> ArrayMesh:
	var chest := skeleton.get_bone_global_rest(skeleton.find_bone(CHEST))
	var to_chest := chest.basis.inverse()
	var points := PackedVector3Array()
	var pose: Dictionary = BrawlerAnimation.POSES[BrawlerAnimation.Move.CHARGE]
	for reach: StringName in [BrawlerPose.REACH_L, BrawlerPose.REACH_R]:
		points.append(to_chest * (pose[reach] as Vector3))
	for shoulder: StringName in SHOULDERS:
		var at := skeleton.get_bone_global_rest(skeleton.find_bone(shoulder)).origin
		points.append(to_chest * (at - chest.origin))
	var ahead := (to_chest * AHEAD).normalized()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := points.size() * SPARKS_PER_POINT
	for spark in count:
		var seed := (spark + 0.5) / count
		_streak(tool, points[spark % points.size()], ahead, Color(seed, 0.0, 0.0))
	for line in LINES:
		var height := lerpf(LINE_LOW, LINE_HIGH, float(line) / (LINES - 1))
		_streak(tool, Vector3.ZERO, ahead, Color((line + 0.5) / LINES, 1.0, height))
	return tool.commit()


static func _streak(tool: SurfaceTool, at: Vector3, ahead: Vector3, data: Color) -> void:
	var corners: Array[Vector2] = [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]
	for corner: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(data)
		tool.set_normal(ahead)
		tool.set_uv(corners[corner])
		tool.add_vertex(at)
