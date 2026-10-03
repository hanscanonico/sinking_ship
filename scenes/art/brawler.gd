class_name Brawler
extends Node3D
## One seat, drawn: the mannequin in its seat's colour under its seat's hat, with a
## ring and a facing chevron at its feet. MatchView places and turns it; it poses
## itself from the seat's two snapshot entries and reads nothing else (D5).

## Seats four apart share a shape; ArtPalette orders the colours to keep them apart.
enum Hat { TOP, CAP, BOATER, BOBBLE }

const MODEL := preload("res://assets/characters/quaternius_ual/AnimationLibrary_Godot_Standard.glb")
const OUTLINE := preload("res://scenes/art/outline.gdshader")
## The mannequin is authored facing +z; a seat faces +x.
const MODEL_TURN := PI * 0.5
const HEAD_BONE := &"DEF-head"
## From the head bone up to the crown, in model units.
const CROWN := 0.2
## Hats are oversized so their shape still reads from the follow camera.
const HAT_SCALE := 1.3
## The ring and chevron sit just off the feet so they never fight the deck.
const FEET_LIFT := 0.03
const RING_WIDTH := 0.07
const RING_SEGMENTS := 24
const CHEVRON_LENGTH := 0.28
const CHEVRON_WIDTH := 0.36
const RING_ALPHA := 0.85

var seat: int
var _player: AnimationPlayer
var _model: Node3D
var _colour: Color
var _feet_ring: MeshInstance3D
var _feet_material: StandardMaterial3D
var _move: BrawlerAnimation.Move = BrawlerAnimation.Move.IDLE
## The stagger last drawn, so a renewed stagger replays its flinch once.
var _stagger := 0
## The model's scale at rest, which a hit-stop's squash works from.
var _rest_scale := Vector3.ONE
## Seconds since the last hit-stop drawn ended; INF before the first.
var _unsquashing := INF


## Builds [param seat_id]'s brawler at the rules' body size; [param local] puts a
## marker overhead.
func setup(seat_id: int, rules: BrawlRules, local: bool) -> void:
	seat = seat_id
	_colour = ArtPalette.seat_colour(seat)
	_model = MODEL.instantiate()
	_model.name = "Model"
	add_child(_model)
	var mesh: MeshInstance3D = _model.get_node("Rig/Skeleton3D/Mannequin")
	var crown := mesh.get_aabb().end.y
	_rest_scale = Vector3.ONE * (rules.body_height / crown)
	_model.scale = _rest_scale
	_model.rotation.y = MODEL_TURN
	mesh.set_surface_override_material(0, _skin(_colour))
	mesh.set_surface_override_material(1, _skin(ArtPalette.INK))
	_player = _model.get_node("AnimationPlayer")
	_player.play(BrawlerAnimation.CLIPS[_move])

	var head := BoneAttachment3D.new()
	head.bone_name = HEAD_BONE
	_model.get_node("Rig/Skeleton3D").add_child(head)
	head.add_child(_hat((seat % Hat.size()) as Hat))

	_feet_material = _flat(_colour)
	_feet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_feet_material.albedo_color.a = RING_ALPHA
	_feet_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_feet_ring = MeshInstance3D.new()
	_feet_ring.mesh = _feet(rules.body_radius)
	_feet_ring.material_override = _feet_material
	_feet_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_feet_ring)
	show_ground(Vector3.UP)

	if local:
		var marker := PrismMesh.new()
		marker.size = Vector3(0.4, 0.35, 0.4)
		marker.material = _flat(ArtPalette.MARKER)
		var arrow := MeshInstance3D.new()
		arrow.mesh = marker
		arrow.position.y = rules.body_height + 0.45
		arrow.rotation.z = PI
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arrow)


## The node the mannequin hangs from: its origin is the drawn feet.
func model_root() -> Node3D:
	return _model


## Poses the brawler for the display moment [param alpha] of the way from
## [param then] to [param now], one seat's entries in two snapshots. Frozen in a
## hit-stop, its pose holds, squashed, and springs back as the stop ends.
func show_state(then: Dictionary, now: Dictionary, alpha: float) -> void:
	var vel: Vector3 = (then["vel"] as Vector3).lerp(now["vel"], alpha)
	var speed := Vector2(vel.x, vel.z).length()
	var move := BrawlerAnimation.move_for(now, speed)
	var renewed: bool = now["stagger"] > _stagger
	_stagger = now["stagger"]
	if move != _move or renewed:
		_player.play(BrawlerAnimation.CLIPS[move], BrawlerAnimation.BLEND[move])
		if renewed:
			_player.seek(0.0, true)
		_move = move
	var frozen: bool = now["hitstop"] > 0
	_player.speed_scale = 0.0 if frozen else BrawlerAnimation.rate(move, speed)
	_unsquashing = 0.0 if frozen else _unsquashing + get_process_delta_time()
	_model.scale = _rest_scale * BrawlerAnimation.squash(_unsquashing)
	var shoving: bool = (
		now["action"] == PlayerState.Action.WINDUP or now["action"] == PlayerState.Action.ACTIVE
	)
	var feet_colour := ArtPalette.SHOVE_FLASH if shoving else _colour
	feet_colour.a = RING_ALPHA
	_feet_material.albedo_color = feet_colour


## Lays the ring and chevron on ground whose up is [param normal], in the space the
## brawler is placed in, so they follow a ramp instead of cutting into it.
func show_ground(normal: Vector3) -> void:
	var up := (basis.inverse() * normal).normalized()
	_feet_ring.basis = Basis(Quaternion(Vector3.UP, up))
	_feet_ring.position = up * FEET_LIFT


## The hat for [param style], in head-bone space: its brim sits on the crown.
func _hat(style: Hat) -> Node3D:
	var hat := Node3D.new()
	hat.name = "Hat"
	hat.position.y = CROWN - 0.03
	hat.scale = Vector3.ONE * HAT_SCALE
	match style:
		Hat.TOP:
			_hat_part(hat, _cylinder(0.2, 0.02), 0.01, _colour)
			_hat_part(hat, _cylinder(0.125, 0.24), 0.13, _colour)
			_hat_part(hat, _cylinder(0.128, 0.05), 0.045, ArtPalette.INK)
		Hat.CAP:
			var crown := SphereMesh.new()
			crown.radius = 0.14
			crown.height = 0.15
			crown.is_hemisphere = true
			_hat_part(hat, crown, 0.0, _colour)
			var peak := BoxMesh.new()
			peak.size = Vector3(0.2, 0.02, 0.12)
			_hat_part(hat, peak, 0.01, ArtPalette.INK).position.z = 0.15
		Hat.BOATER:
			_hat_part(hat, _cylinder(0.24, 0.02), 0.01, _colour)
			_hat_part(hat, _cylinder(0.135, 0.1), 0.06, _colour)
			_hat_part(hat, _cylinder(0.138, 0.04), 0.04, ArtPalette.INK)
		Hat.BOBBLE:
			var dome := SphereMesh.new()
			dome.radius = 0.135
			dome.height = 0.2
			dome.is_hemisphere = true
			_hat_part(hat, dome, 0.0, _colour)
			_hat_part(hat, _cylinder(0.14, 0.05), 0.02, ArtPalette.INK)
			var bobble := SphereMesh.new()
			bobble.radius = 0.06
			bobble.height = 0.12
			_hat_part(hat, bobble, 0.21, _colour)
	return hat


func _hat_part(hat: Node3D, mesh: PrimitiveMesh, lift: float, colour: Color) -> MeshInstance3D:
	mesh.material = _skin(colour)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position.y = lift
	hat.add_child(part)
	return part


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 16
	cylinder.rings = 1
	return cylinder


## A ring round a body of [param radius] with a chevron ahead of it, flat on the
## deck plane.
func _feet(radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var outer := radius + RING_WIDTH * 0.5
	var inner := radius - RING_WIDTH * 0.5
	for index in RING_SEGMENTS:
		var a := TAU * index / RING_SEGMENTS
		var b := TAU * (index + 1) / RING_SEGMENTS
		var a_in := Vector3(cos(a), 0.0, sin(a)) * inner
		var a_out := Vector3(cos(a), 0.0, sin(a)) * outer
		var b_in := Vector3(cos(b), 0.0, sin(b)) * inner
		var b_out := Vector3(cos(b), 0.0, sin(b)) * outer
		for corner: Vector3 in [a_in, b_out, a_out, a_in, b_in, b_out]:
			tool.add_vertex(corner)
	var tip := Vector3(outer + CHEVRON_LENGTH, 0.0, 0.0)
	var half := CHEVRON_WIDTH * 0.5
	for corner: Vector3 in [tip, Vector3(outer, 0.0, half), Vector3(outer, 0.0, -half)]:
		tool.add_vertex(corner)
	return tool.commit()


## Lit, flat and matte with a dark edge: the crew's look.
func _skin(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	material.next_pass = outline
	return material


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
