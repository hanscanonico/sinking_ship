class_name Brawler
extends Node3D
## One seat, drawn: a steamer's passenger or hand, its coat in its seat's colour
## under its seat's hat, over a soft disc at its feet. MatchView places and turns
## it; it poses itself from the seat's two snapshot entries and reads nothing else
## (D5).

## Every seat wears its own hat and coat, so each reads by its shape as well.
enum Hat { CAP, SOUWESTER, BOATER, BARE, BOBBLE, TOP, PEAKED }
enum Coat { JERSEY, JACKET, GREATCOAT }
enum Whiskers { NONE, MOUSTACHE, BEARD }

const MODEL := preload("res://assets/characters/quaternius_ual/AnimationLibrary_Godot_Standard.glb")
const CLOTHES := preload("res://scenes/art/brawler.gdshader")
const OUTLINE := preload("res://scenes/art/outline.gdshader")
## Per seat, eight apart: a hand, an oilskin, a passenger, a steward, a sailor, a
## gentleman, a mate, a skipper.
const HATS: Array[Hat] = [
	Hat.CAP, Hat.SOUWESTER, Hat.BOATER, Hat.BARE, Hat.BOBBLE, Hat.TOP, Hat.PEAKED, Hat.BARE
]
const COATS: Array[Coat] = [
	Coat.JERSEY,
	Coat.GREATCOAT,
	Coat.JACKET,
	Coat.JACKET,
	Coat.JERSEY,
	Coat.GREATCOAT,
	Coat.JACKET,
	Coat.GREATCOAT,
]
const WHISKERS: Array[Whiskers] = [
	Whiskers.NONE,
	Whiskers.NONE,
	Whiskers.MOUSTACHE,
	Whiskers.NONE,
	Whiskers.BEARD,
	Whiskers.MOUSTACHE,
	Whiskers.NONE,
	Whiskers.BEARD,
]
## Indices into ArtPalette.HAIR and ArtPalette.TROUSERS.
const HAIR: Array[int] = [0, 0, 0, 1, 3, 1, 3, 2]
const TROUSERS: Array[int] = [1, 0, 3, 0, 2, 3, 0, 1]
## The mannequin is authored facing +z; a seat faces +x.
const MODEL_TURN := PI * 0.5
const HEAD_BONE := &"DEF-head"
## The outline's width on a seat's own arms, under the eye, in model units.
const OWN_OUTLINE := 0.0035
## The disc sits just off the feet so it never fights the deck.
const FEET_LIFT := 0.03
const DISC_ALPHA := 0.4
const DISC_SHOVING_ALPHA := 0.55
## Clothes hang off the waist this far at most, between these heights, within this
## far of the middle, in model units.
const HANG := 0.024
const HANG_FROM := 0.86
const HANG_TO := 1.38
const HANG_WIDTH := 0.22
## The mannequin's surface of ball joints and the rings between its segments.
const JOINTS := 1
## How many rings of a segment's triangles in from its rim its outline takes to
## grow to full width, so the lip a segment curls in by at its rim inks no seam
## across the cloth.
const OUTLINE_RINGS := 3
## Ironing: rounds of smoothing in and back out, and the head (above IRON_BELOW and
## within IRON_HEAD of the middle), the hands (past IRON_HANDS) and the feet (under
## IRON_ABOVE) left as they are, in model units.
const IRON_ROUNDS := 4
const IRON_IN := 0.5
const IRON_OUT := -0.53
const IRON_BELOW := 1.52
const IRON_HEAD := 0.14
const IRON_HANDS := 0.7
const IRON_ABOVE := 0.16
## The painted front — shirt, tie, lapels, buttons — rides the spine alone, its
## share of each spine bone rising smoothly with height: the mannequin weights its
## breastbone to the collarbones, which a raised arm swings, and its rows to the
## spine bones in uneven shares, both of which shear a narrow painted band into a
## zigzag. The front within STEADY_ACROSS of the middle and between the first and
## last of STEADY_ROWS is weighted so, letting go of it over STEADY_FADE beyond, in
## model units; the spine bones' shares run between STEADY_ROWS' heights.
const STEADY_ACROSS := 0.09
const STEADY_ROWS := {&"DEF-spine.001": 1.1, &"DEF-spine.002": 1.27, &"DEF-spine.003": 1.42}
const STEADY_FADE := 0.05
## A coat's skirt, hanging from the hips: rings from the waist down to its hem, at
## SKIRT_HEMS of each coat that has one, opening at the front by as many radians
## either side of ahead as SKIRT_OPENINGS has from the waist to the hem — a jacket's
## tails are cut away. A ring stands wider and deeper and is held less by the hips
## than by the thighs the lower it hangs (the SKIRT_ rates, per unit of drop).
const SKIRT_SEGMENTS := 14
const SKIRT_RINGS := 3
const SKIRT_HEMS := {Coat.JACKET: 0.78, Coat.GREATCOAT: 0.45}
const SKIRT_OPENINGS := {Coat.JACKET: Vector2(0.3, 0.75), Coat.GREATCOAT: Vector2(0.0, 0.1)}
const SKIRT_WAIST := Vector2(0.158, 0.13)
const SKIRT_FLARE := Vector2(0.15, 0.155)
const SKIRT_BACK := 0.02
const SKIRT_LET_GO := 1.55
const SKIRT_HELD := 0.12
const SKIRT_WAIST_HEIGHT := 1.0
## How sharply the skirt's halves go with their own thigh: past 1/SKIRT_SPLIT of the
## way round from the front, wholly.
const SKIRT_SPLIT := 2.5
## The hands' glow: held through a wind-up, building through a charge, full as
## the shove lands and fading over FLASH_FADE after.
const WINDUP_GLOW := 0.8
const CHARGE_GLOW := 0.2
const CHARGE_PULSE := 14.0
const FLASH_FADE := 0.15
## A seat's own hands glow this much of that, under its eye: enough to feel the
## shove land, not so much that the hands wash out to a blank shape.
const OWN_GLOW := 0.5
## A shove coming, as its heat (brawler.gdshader): a wind-up's — enough to read
## across a deck — rising through a charge to 1 when it is full, and cooling over
## FLASH_FADE once the shove has landed. Its outline turns from ink to the heat's
## colour by a wind-up's heat — a saturated ember that holds against a sunlit deck as
## a paler one would not — widens with the distance by HEAT_REACH a metre at full
## heat, in model units, so the edge stays a line on the screen out to the far side of
## the deck, and throbs as the charge comes full, from BEAT_FROM.
const WINDUP_HEAT := 0.4
const HEAT_REACH := 0.006
const BEAT_FROM := 0.7
## The disc at the feet warms this much toward the heat's colour at full heat.
const DISC_HEAT := 0.85
## Two bodies nearer than CLINCH_RANGE may reach into each other. A hand —
## CLINCH_HAND long past the wrist — reaching toward the other between CLINCH_LOW and
## CLINCH_HIGH over the feet, and within CLINCH_WIDE of the line between them, stops
## at the other's front: its chest, CLINCH_CHEST from its middle, or the fists it
## holds up ahead of it, as far as halfway between them. In metres.
const CLINCH_RANGE := 1.4
## The moves whose arms reach out from the body: a shove, as it eases back, and a brace.
const REACHING: Array[BrawlerAnimation.Move] = [
	BrawlerAnimation.Move.SHOVE, BrawlerAnimation.Move.RECOVER, BrawlerAnimation.Move.BRACE
]
const CLINCH_CHEST := 0.17
const CLINCH_HAND := 0.1
const CLINCH_LOW := 0.75
const CLINCH_HIGH := 1.8
const CLINCH_WIDE := 0.4

## The mannequin's surfaces dressed for clothes, and the mesh for each coat — with
## or without a skirt — built once and shared by every seat wearing it.
static var _dressed: Array[Array] = []
static var _bodies := {}
static var _disc_texture: GradientTexture2D
## The mannequin's crown and the head bone's height at rest, in its units, and per
## hat how high it stands over the soles as a share of the crown: read once.
static var _mannequin := Vector2.ZERO
static var _headgear := {}

var seat: int
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _model: Node3D
var _colour: Color
var _feet_disc: MeshInstance3D
var _hat_node: MeshInstance3D
## The marker over the local seat, or null on any other.
var _marker: MeshInstance3D
var _clothes: ShaderMaterial
## The clothes again on the mannequin's ball joints, with no outline, so the joints
## draw no seams through the cloth.
var _joints: ShaderMaterial
## The clip for each move: the crew's, unless drawn as a seat's own arms.
var _clips: Dictionary = BrawlerAnimation.CLIPS
var _poses: BrawlerPose
var _feet_material: StandardMaterial3D
## The outlines of the body and of the hat, which a shove coming lights.
var _outlines: Array[ShaderMaterial] = []
## A charge's sparks and speed lines, on the chest; null on a seat's own arms.
var _charge: BrawlerCharge
## The rules' ticks at which a held shove becomes a charge and is full, and a
## charge's walk, m/s.
var _charge_from: int
var _charge_full: int
var _charge_walk: float
var _move: BrawlerAnimation.Move = BrawlerAnimation.Move.IDLE
## Seconds since the move drawn began.
var _since := 0.0
var _glow := 0.0
## The heat drawn now, and at the moment the last shove landed.
var _heat := 0.0
var _landed_heat := 0.0
## Whether the disc shows a shove, as it was last coloured.
var _shoving := false
## The stagger last drawn, so a renewed stagger replays its flinch once.
var _stagger := 0
## The model's scale at rest, which a hit-stop's squash works from.
var _rest_scale := Vector3.ONE
## Seconds since the last hit-stop drawn ended; INF before the first.
var _unsquashing := INF
## Whether a hit-stop squashes the model: never a seat's own arms, held under its eye.
var _squashes := true
## Whether a hit-stop holds the pose: never a seat's own arms, which take a
## stagger's recoil the moment the shove lands.
var _freezes := true
## How much of the glow the hands show: OWN_GLOW on a seat's own arms.
var _glow_scale := 1.0


## Builds [param seat_id]'s brawler at the rules' body size; [param local] puts a
## marker overhead.
func setup(seat_id: int, rules: BrawlRules, local: bool) -> void:
	seat = seat_id
	_colour = ArtPalette.seat_colour(seat)
	_charge_from = Ticks.from_seconds(rules.charge_threshold)
	_charge_full = Ticks.from_seconds(rules.charge_full)
	_charge_walk = rules.charge_walk
	var outfit := seat % HATS.size()
	_model = MODEL.instantiate()
	_model.name = "Model"
	add_child(_model)
	var skeleton: Skeleton3D = _model.get_node("Rig/Skeleton3D")
	_skeleton = skeleton
	var mesh: MeshInstance3D = skeleton.get_node("Mannequin")
	var crown := mesh.get_aabb().end.y
	_rest_scale = Vector3.ONE * (rules.body_height / crown)
	_model.scale = _rest_scale
	_model.rotation.y = MODEL_TURN
	mesh.mesh = _body(mesh.mesh as ArrayMesh, mesh.skin, COATS[outfit])
	_clothes = _dress(outfit)
	_joints = _clothes.duplicate()
	_joints.next_pass = null
	mesh.set_surface_override_material(0, _clothes)
	mesh.set_surface_override_material(JOINTS, _joints)
	_player = _model.get_node("AnimationPlayer")
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.play(_clips[_move])
	_poses = BrawlerPose.new(skeleton, BrawlerAnimation.POSES)

	var head := BoneAttachment3D.new()
	head.bone_name = HEAD_BONE
	skeleton.add_child(head)
	_hat_node = MeshInstance3D.new()
	_hat_node.name = "Hat"
	_hat_node.mesh = BrawlerHat.build(HATS[outfit], _colour, ArtPalette.HAIR[HAIR[outfit]])
	_hat_node.material_override = _painted()
	head.add_child(_hat_node)
	var hat_outline := (_hat_node.material_override as StandardMaterial3D).next_pass
	_outlines = [_clothes.next_pass as ShaderMaterial, hat_outline as ShaderMaterial]

	_charge = BrawlerCharge.new()
	_charge.name = "Charge"
	_charge.setup(skeleton)
	skeleton.add_child(_charge)

	if _disc_texture == null:
		_disc_texture = _soft_disc()
	_feet_material = _flat(_colour)
	_feet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_feet_material.albedo_texture = _disc_texture
	_feet_material.albedo_color.a = DISC_ALPHA
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * rules.body_radius * 2.0
	_feet_disc = MeshInstance3D.new()
	_feet_disc.mesh = disc
	_feet_disc.material_override = _feet_material
	_feet_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_feet_disc)
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
		_marker = arrow


## How high [param seat]'s brawler stands, hat and all, at rest, in metres: the
## rules' body height, or the top of a hat standing taller than the crown.
static func headgear(seat: int, rules: BrawlRules) -> float:
	var hat := HATS[seat % HATS.size()]
	if not _headgear.has(hat):
		if _mannequin == Vector2.ZERO:
			var model := MODEL.instantiate()
			var skeleton: Skeleton3D = model.get_node("Rig/Skeleton3D")
			var crown := (skeleton.get_node("Mannequin") as MeshInstance3D).get_aabb().end.y
			var head := skeleton.get_bone_global_rest(skeleton.find_bone(HEAD_BONE)).origin.y
			_mannequin = Vector2(crown, head)
			model.free()
		var top := BrawlerHat.build(hat, Color.WHITE, Color.WHITE).get_aabb().end.y
		_headgear[hat] = maxf(_mannequin.y + top, _mannequin.x) / _mannequin.x
	return rules.body_height * _headgear[hat]


## Shows the marker overhead, on the local seat, or hides it.
func show_marker(shown: bool) -> void:
	if _marker != null:
		_marker.visible = shown


## Draws only what a seat sees of itself (FirstPersonArms): no hat, no disc at its
## feet, no sparks, no shadow, no hit-stop squash or hold, a dimmer glow, a finer
## outline, and [param clips] and [param poses] (as BrawlerAnimation.POSES, the
## elbows bending as [param elbows] has) for its moves.
func show_as_own_arms(clips: Dictionary, poses: Dictionary, elbows: Array[Vector3]) -> void:
	_clips = clips
	_poses = BrawlerPose.new(_skeleton, poses, elbows)
	_squashes = false
	_freezes = false
	_glow_scale = OWN_GLOW
	_hat_node.visible = false
	_feet_disc.visible = false
	_charge.queue_free()
	_charge = null
	(_clothes.next_pass as ShaderMaterial).set_shader_parameter("width", OWN_OUTLINE)
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Where the mannequin's [param bone] is drawn, in the world.
func bone_position(bone: StringName) -> Vector3:
	var pose := _skeleton.get_bone_global_pose(_skeleton.find_bone(bone))
	return _skeleton.global_transform * pose.origin


## Lands the hands of each of [param bodies] that is drawn on any other standing
## within CLINCH_RANGE of it — the seat [param eye_seat] looks out of among them,
## though it is not drawn — rather than through it, once every one is posed for the
## frame: an arm reaching past the other's front, its chest or its raised guard, is
## bent to stop the wrist there; two guards meet halfway.
static func keep_apart(bodies: Array[Brawler], eye_seat: int) -> void:
	for body: Brawler in bodies:
		if not body.visible or body._move not in REACHING:
			continue
		for other: Brawler in bodies:
			if other == body or not (other.visible or other.seat == eye_seat):
				continue
			var apart := other.position - body.position
			if absf(apart.y) < CLINCH_HIGH and Vector2(apart.x, apart.z).length() < CLINCH_RANGE:
				body._keep_hands_off(other)


## Shrinks the mannequin's [param bone] to nothing in this frame's pose, so what it
## carries is not drawn.
func collapse_bone(bone: StringName) -> void:
	_skeleton.set_bone_pose_scale(_skeleton.find_bone(bone), Vector3.ONE * 0.001)


## The node the mannequin hangs from: its origin is the drawn feet.
func model_root() -> Node3D:
	return _model


## Poses the brawler for the display moment [param alpha] of the way from
## [param then] to [param now], one seat's entries in two snapshots: the move's
## clip, advanced here, with the move's pose over it. Frozen in a hit-stop, its pose
## holds, squashed, and springs back as the stop ends.
func show_state(then: Dictionary, now: Dictionary, alpha: float) -> void:
	var delta := get_process_delta_time()
	var vel: Vector3 = (then["vel"] as Vector3).lerp(now["vel"], alpha)
	var speed := Vector2(vel.x, vel.z).length()
	var move := BrawlerAnimation.move_for(now, speed)
	var renewed: bool = now["stagger"] > _stagger
	_stagger = now["stagger"]
	if move != _move or renewed:
		_player.play(_clips[move], BrawlerAnimation.BLEND[move])
		if renewed:
			_player.seek(0.0, true)
		_move = move
		_since = 0.0
	var frozen: bool = now["hitstop"] > 0
	var held := 0.0 if frozen and _freezes else delta
	_since += held
	_player.speed_scale = 0.0 if frozen else BrawlerAnimation.rate(move, speed)
	_player.advance(delta)
	_poses.take(_pose_id(move), BrawlerAnimation.BLEND[move])
	_poses.apply(held)
	_unsquashing = 0.0 if frozen else _unsquashing + delta
	if _squashes:
		_model.scale = _rest_scale * BrawlerAnimation.squash(_unsquashing)
	_show_hands(move)
	var charge: float = lerpf(then["charge"], now["charge"], alpha)
	_show_heat(move, BrawlerCharge.filled(charge, _charge_from, _charge_full), now, speed)
	var shoving: bool = (
		now["action"] == PlayerState.Action.WINDUP or now["action"] == PlayerState.Action.ACTIVE
	)
	if shoving != _shoving:
		_shoving = shoving
		_colour_disc()


## Lays the disc on ground whose up is [param normal], in the space the brawler is
## placed in, so it follows a ramp instead of cutting into it.
func show_ground(normal: Vector3) -> void:
	var up := (basis.inverse() * normal).normalized()
	_feet_disc.basis = Basis(Quaternion(Vector3.UP, up))
	_feet_disc.position = up * FEET_LIFT


## The pose over [param move]'s clip, or -1 for none; a stroke of several poses
## steps through them with the clip.
func _pose_id(move: BrawlerAnimation.Move) -> int:
	var strokes := _poses.strokes(move)
	if strokes <= 1:
		return BrawlerPose.id(move, 0) if strokes == 1 else -1
	var length := _player.current_animation_length
	var through := fposmod(_player.current_animation_position, length) / length
	return BrawlerPose.id(move, floori(through * strokes) % strokes)


## Lights the hands as a shove winds up, charges and lands.
func _show_hands(move: BrawlerAnimation.Move) -> void:
	var glow := 0.0
	match move:
		BrawlerAnimation.Move.WINDUP:
			glow = WINDUP_GLOW
		BrawlerAnimation.Move.CHARGE:
			glow = WINDUP_GLOW + CHARGE_GLOW * (0.5 + 0.5 * sin(_since * CHARGE_PULSE))
		BrawlerAnimation.Move.SHOVE:
			glow = 1.0
		BrawlerAnimation.Move.RECOVER:
			glow = maxf(0.0, 1.0 - _since / FLASH_FADE)
	glow *= _glow_scale
	if glow != _glow:
		_glow = glow
		_clothes.set_shader_parameter("flash", glow)
		_joints.set_shader_parameter("flash", glow)


## Lights the body's edge, its outline, its forearms and the disc at its feet as a
## shove comes — held at a wind-up's heat, rising as a charge fills to [param fill]
## (of the seat's snapshot entry [param now]), cooling once the shove lands — and
## streams a charge's sparks, with speed lines once it walks at [param speed].
func _show_heat(move: BrawlerAnimation.Move, fill: float, now: Dictionary, speed: float) -> void:
	var charged: bool = now["charge"] > 0
	var heat := 0.0
	match move:
		BrawlerAnimation.Move.WINDUP:
			heat = WINDUP_HEAT
		BrawlerAnimation.Move.CHARGE, BrawlerAnimation.Move.SHOVE:
			heat = lerpf(WINDUP_HEAT, 1.0, fill) if charged else WINDUP_HEAT
			_landed_heat = heat
		BrawlerAnimation.Move.RECOVER:
			heat = _landed_heat * maxf(0.0, 1.0 - _since / FLASH_FADE)
	heat *= _glow_scale
	if _charge != null:
		var charging := move == BrawlerAnimation.Move.CHARGE
		_charge.visible = charging or move == BrawlerAnimation.Move.SHOVE and charged
		if _charge.visible:
			_charge.show_charge(fill, clampf(speed / _charge_walk, 0.0, 1.0) if charging else 0.0)
	if heat == _heat:
		return
	_heat = heat
	_clothes.set_shader_parameter("heat", heat)
	_joints.set_shader_parameter("heat", heat)
	var edge := ArtPalette.INK.lerp(ArtPalette.CHARGE, minf(heat / WINDUP_HEAT, 1.0))
	for outline: ShaderMaterial in _outlines:
		outline.set_shader_parameter("ink", edge)
		outline.set_shader_parameter("reach", HEAT_REACH * heat)
		outline.set_shader_parameter("beat", smoothstep(BEAT_FROM, 1.0, heat))
	_colour_disc()


## The disc at the feet: the seat's colour, white while a shove winds up and lands,
## warming with the heat.
func _colour_disc() -> void:
	var colour := ArtPalette.SHOVE_FLASH if _shoving else _colour
	colour = colour.lerp(ArtPalette.CHARGE, _heat * DISC_HEAT)
	colour.a = DISC_SHOVING_ALPHA if _shoving or _heat > 0.0 else DISC_ALPHA
	_feet_material.albedo_color = colour


## Bends each arm reaching past [param other]'s front so the wrist stops at it,
## along the arm's reach from the shoulder.
func _keep_hands_off(other: Brawler) -> void:
	var up := global_basis.y.normalized()
	var toward := other.global_position - global_position
	toward -= up * toward.dot(up)
	var apart := toward.length()
	if apart <= 0.0:
		return
	toward /= apart
	var front := maxf(minf(other._guard(-toward) + CLINCH_HAND, apart * 0.5), CLINCH_CHEST)
	var to_world := _skeleton.global_transform
	for arm in BrawlerPose.ARM_LIMBS:
		var shoulder := to_world * _poses.shoulder(arm)
		var wrist := to_world * _poses.wrist(arm)
		var landing := _landing(
			shoulder - global_position,
			wrist - global_position,
			toward,
			up,
			apart - front - CLINCH_HAND
		)
		if landing < 1.0:
			_poses.reach_arm(arm, to_world.affine_inverse() * shoulder.lerp(wrist, landing))


## How far ahead of the middle of the body, along [param toward], its wrists reach.
func _guard(toward: Vector3) -> float:
	var reach := 0.0
	for arm in BrawlerPose.ARM_LIMBS:
		var wrist := _skeleton.global_transform * _poses.wrist(arm) - global_position
		reach = maxf(reach, wrist.dot(toward))
	return reach


## How far along a reach from [param from] to [param to] — both from the body's
## feet, [param up] its up — the wrist comes to [param limit] along [param toward],
## when the reach ends past it in the band CLINCH_LOW to CLINCH_HIGH high and within
## CLINCH_WIDE across; 1 when it ends short of it or out of the band.
static func _landing(
	from: Vector3, to: Vector3, toward: Vector3, up: Vector3, limit: float
) -> float:
	var depth := to.dot(toward)
	var height := to.dot(up)
	var across := (to - toward * depth - up * height).length()
	if depth <= limit or height < CLINCH_LOW or height > CLINCH_HIGH or across > CLINCH_WIDE:
		return 1.0
	var start := from.dot(toward)
	if start >= limit:
		return 0.0
	return (limit - start) / (depth - start)


## The clothes for outfit [param outfit], its coat in the seat's colour.
func _dress(outfit: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CLOTHES
	material.set_shader_parameter("coat", _colour)
	material.set_shader_parameter("trousers", ArtPalette.TROUSERS[TROUSERS[outfit]])
	material.set_shader_parameter("skin", ArtPalette.SKIN)
	material.set_shader_parameter("hair", ArtPalette.HAIR[HAIR[outfit]])
	material.set_shader_parameter("shirt", ArtPalette.SHIRT)
	material.set_shader_parameter("leather", ArtPalette.LEATHER)
	material.set_shader_parameter("ink", ArtPalette.INK)
	material.set_shader_parameter("trim", ArtPalette.BRASS)
	material.set_shader_parameter("garment", COATS[outfit])
	material.set_shader_parameter("skirt_hem", SKIRT_HEMS.get(COATS[outfit], SKIRT_WAIST_HEIGHT))
	material.set_shader_parameter("whiskers", WHISKERS[outfit])
	material.set_shader_parameter("flash_colour", ArtPalette.HAND_FLASH)
	material.set_shader_parameter("heat_colour", ArtPalette.CHARGE)
	material.set_shader_parameter("heat_core", ArtPalette.CHARGE_CORE)
	material.next_pass = _outline()
	return material


## Lit, flat and matte with a dark edge, coloured by its vertices: the hats.
func _painted() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.8
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.next_pass = _outline()
	return material


func _outline() -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	return outline


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## A disc, full in the middle, darker toward its edge so it reads on a light deck
## too, and fading out to nothing at its rim.
static func _soft_disc() -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	fade.add_point(0.6, Color(1.0, 1.0, 1.0, 0.85))
	fade.add_point(0.8, Color(0.3, 0.3, 0.3, 1.0))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


## [param source], the mannequin, dressed (_dress_body) — and under a coat, with
## its skirt — shared by every seat wearing [param coat]. [param skin] names its
## bones.
static func _body(source: ArrayMesh, skin: Skin, coat: Coat) -> ArrayMesh:
	if _bodies.has(coat):
		return _bodies[coat]
	if _dressed.is_empty():
		_dressed = _dress_body(source, skin)
	var mesh := ArrayMesh.new()
	for surface in _dressed.size():
		var arrays: Array = _dressed[surface].duplicate(true)
		if surface == 0 and SKIRT_HEMS.has(coat):
			_add_skirt(arrays, skin, coat)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_bodies[coat] = mesh
	return mesh


## The surfaces of [param source], the mannequin, ironed and hung for clothes, with
## where each point sits at rest written into their UVs for the clothes shader and
## its painted front steadied on the spine; [param skin] names its bones.
## The mannequin is jointed: its segments and the joint rings between them meet at
## rims, which stay put so no crack opens, and whose outline (in COLOR's alpha, as
## outline.gdshader reads it) grows in from nothing over OUTLINE_RINGS so no seam
## is inked across the cloth.
static func _dress_body(source: ArrayMesh, skin: Skin) -> Array[Array]:
	var surfaces: Array[Array] = []
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var weld := _weld(arrays[Mesh.ARRAY_VERTEX])
		var rims := _rims(arrays[Mesh.ARRAY_INDEX], weld)
		var inked := _inked(arrays[Mesh.ARRAY_INDEX], weld, rims)
		_iron(arrays, weld, rims)
		_steady_front(arrays, skin)
		# Rest is read off the ironed body, so a painted edge runs straight across
		# the triangles drawn instead of tearing along them.
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var rest := PackedVector2Array()
		var depth := PackedVector2Array()
		var outline := PackedColorArray()
		for index in vertices.size():
			var vertex := vertices[index]
			rest.append(Vector2(vertex.x, vertex.y))
			depth.append(Vector2(vertex.z, 0.0))
			vertices[index] += Vector3(vertex.x, 0.0, vertex.z).normalized() * _hang(vertex)
			outline.append(Color(1.0, 1.0, 1.0, inked[index]))
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = outline
		arrays[Mesh.ARRAY_TEX_UV] = rest
		arrays[Mesh.ARRAY_TEX_UV2] = depth
		surfaces.append(arrays)
	return surfaces


## For each of [param vertices], the first one standing at the same point: where
## the mesh is split, the vertex it shares.
static func _weld(vertices: PackedVector3Array) -> PackedInt32Array:
	var weld := PackedInt32Array()
	weld.resize(vertices.size())
	var first := {}
	for index in vertices.size():
		var key := vertices[index].snappedf(0.00001)
		if not first.has(key):
			first[key] = index
		weld[index] = first[key]
	return weld


## 1 for each vertex on an edge of only one of [param indices]' triangles — a rim
## where a surface stops — and 0 otherwise; [param weld] as _weld has it.
static func _rims(indices: PackedInt32Array, weld: PackedInt32Array) -> PackedByteArray:
	var edges := {}
	for corner in range(0, indices.size(), 3):
		for side in 3:
			var a := weld[indices[corner + side]]
			var b := weld[indices[corner + (side + 1) % 3]]
			var edge := Vector2i(mini(a, b), maxi(a, b))
			edges[edge] = edges.get(edge, 0) + 1
	var shared := PackedByteArray()
	shared.resize(weld.size())
	for edge: Vector2i in edges:
		if edges[edge] == 1:
			shared[edge.x] = 1
			shared[edge.y] = 1
	var rims := PackedByteArray()
	rims.resize(weld.size())
	for index in weld.size():
		rims[index] = shared[weld[index]]
	return rims


## How much outline each vertex of [param indices]' triangles grows: none on the
## [param rims], and more the more rings of triangles away from one, full at
## OUTLINE_RINGS; [param weld] as _weld has it.
static func _inked(
	indices: PackedInt32Array, weld: PackedInt32Array, rims: PackedByteArray
) -> PackedFloat32Array:
	var rings := PackedInt32Array()
	rings.resize(weld.size())
	rings.fill(OUTLINE_RINGS)
	for index in weld.size():
		if rims[index] == 1:
			rings[weld[index]] = 0
	for ring in OUTLINE_RINGS - 1:
		for corner in range(0, indices.size(), 3):
			var a := weld[indices[corner]]
			var b := weld[indices[corner + 1]]
			var c := weld[indices[corner + 2]]
			var nearest := mini(rings[a], mini(rings[b], rings[c]))
			if nearest == ring:
				for point: int in [a, b, c]:
					rings[point] = mini(rings[point], ring + 1)
	var inked := PackedFloat32Array()
	inked.resize(weld.size())
	for index in weld.size():
		inked[index] = float(rings[weld[index]]) / OUTLINE_RINGS
	return inked


## Irons the mannequin's muscles out of [param arrays], a surface's, below the head
## and above the hands and feet, so cloth seems to lie over the body: rounds of
## Taubin smoothing — in, then back out so the body keeps its size — of its points,
## then of its normals; [param weld] as _weld has it, and the [param rims] held still.
static func _iron(arrays: Array, weld: PackedInt32Array, rims: PackedByteArray) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := vertices.size()
	var ironed := PackedByteArray()
	ironed.resize(count)
	for index in count:
		var point := vertices[index]
		var head := point.y > IRON_BELOW and absf(point.x) < IRON_HEAD
		var kept := head or absf(point.x) > IRON_HANDS or point.y < IRON_ABOVE
		ironed[index] = 0 if kept or rims[index] == 1 else 1
	for _round in IRON_ROUNDS:
		_blur(vertices, indices, weld, ironed, IRON_IN)
		_blur(vertices, indices, weld, ironed, IRON_OUT)
	for _round in IRON_ROUNDS:
		_blur(normals, indices, weld, ironed, 1.0)
	for index in count:
		normals[index] = normals[index].normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals


## Weights [param arrays]' front, a surface's, on the spine as STEADY_ROWS has it;
## [param skin] names its bones. Every point is weighted by where it stands, so the
## points two surfaces share keep moving together.
static func _steady_front(arrays: Array, skin: Skin) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / vertices.size()
	var spine := PackedInt32Array()
	var heights := PackedFloat32Array()
	for bone: StringName in STEADY_ROWS:
		spine.append(_bind(skin, bone))
		heights.append(STEADY_ROWS[bone])
	var low := heights[0]
	var high := heights[heights.size() - 1]
	for index in vertices.size():
		var point := vertices[index]
		var steady := (
			(1.0 - smoothstep(STEADY_ACROSS, STEADY_ACROSS + STEADY_FADE, absf(point.x)))
			* smoothstep(low - STEADY_FADE, low, point.y)
			* (1.0 - smoothstep(high, high + STEADY_FADE, point.y))
			* smoothstep(0.0, STEADY_FADE, point.z)
		)
		if steady <= 0.0:
			continue
		var shares := {}
		for slot in per:
			var bone := bones[index * per + slot]
			shares[bone] = shares.get(bone, 0.0) + weights[index * per + slot] * (1.0 - steady)
		for row in spine.size():
			var below := heights[row - 1] if row > 0 else -INF
			var above := heights[row + 1] if row < spine.size() - 1 else INF
			var share := minf(
				inverse_lerp(below, heights[row], point.y) if row > 0 else 1.0,
				inverse_lerp(above, heights[row], point.y) if row < spine.size() - 1 else 1.0
			)
			shares[spine[row]] = shares.get(spine[row], 0.0) + clampf(share, 0.0, 1.0) * steady
		var kept: Array = shares.keys()
		kept.sort_custom(func(a: int, b: int) -> bool: return shares[a] > shares[b])
		var total := 0.0
		for slot in mini(per, kept.size()):
			total += shares[kept[slot]]
		for slot in per:
			var held := slot < kept.size()
			bones[index * per + slot] = kept[slot] if held else 0
			weights[index * per + slot] = shares[kept[slot]] / total if held else 0.0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights


## Moves each of [param values] marked in [param ironed] [param amount] of the way to
## the mean of its neighbours across [param indices]' triangles; [param weld] names
## the vertex each one shares its point with.
static func _blur(
	values: PackedVector3Array,
	indices: PackedInt32Array,
	weld: PackedInt32Array,
	ironed: PackedByteArray,
	amount: float
) -> void:
	var count := values.size()
	var sums := PackedVector3Array()
	sums.resize(count)
	var links := PackedInt32Array()
	links.resize(count)
	for corner in range(0, indices.size(), 3):
		var a := weld[indices[corner]]
		var b := weld[indices[corner + 1]]
		var c := weld[indices[corner + 2]]
		sums[a] += values[b] + values[c]
		sums[b] += values[c] + values[a]
		sums[c] += values[a] + values[b]
		links[a] += 2
		links[b] += 2
		links[c] += 2
	for index in count:
		if weld[index] == index and ironed[index] == 1 and links[index] > 0:
			sums[index] = values[index].lerp(sums[index] / links[index], amount)
		else:
			sums[index] = values[index]
	for index in count:
		values[index] = sums[weld[index]]


## How far clothes stand off the mannequin's skin at [param point], at rest: a
## coat hangs straight down from the chest rather than hugging the waist.
static func _hang(point: Vector3) -> float:
	if absf(point.x) > HANG_WIDTH or point.y < HANG_FROM or point.y > HANG_TO:
		return 0.0
	return HANG * sin(PI * (point.y - HANG_FROM) / (HANG_TO - HANG_FROM))


## Adds [param coat]'s skirt to [param arrays], a skinned surface's: an
## open-fronted tube from the waist, held by the hips and pulled along by the thighs
## below, faced inside and out.
static func _add_skirt(arrays: Array, skin: Skin, coat: Coat) -> void:
	var hips := _bind(skin, &"DEF-hips")
	var thighs := PackedInt32Array([_bind(skin, &"DEF-thigh.L"), _bind(skin, &"DEF-thigh.R")])
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var rest: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var depth: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var outline: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var hem: float = SKIRT_HEMS[coat]
	var openings: Vector2 = SKIRT_OPENINGS[coat]
	for side: float in [1.0, -1.0]:
		var first := vertices.size()
		for ring in SKIRT_RINGS:
			var down := float(ring) / (SKIRT_RINGS - 1)
			var height := lerpf(SKIRT_WAIST_HEIGHT, hem, down)
			var drop := SKIRT_WAIST_HEIGHT - height
			var size := SKIRT_WAIST + SKIRT_FLARE * drop
			var opening := lerpf(openings.x, openings.y, down)
			var held := maxf(1.0 - drop * SKIRT_LET_GO, SKIRT_HELD)
			for step in SKIRT_SEGMENTS + 1:
				var angle := lerpf(opening, TAU - opening, float(step) / SKIRT_SEGMENTS)
				var across := sin(angle)
				var ahead := cos(angle)
				var point := Vector3(across * size.x, height, ahead * size.y - SKIRT_BACK * drop)
				vertices.append(point)
				normals.append(Vector3(across, -0.12, ahead).normalized() * side)
				tangents.append_array(PackedFloat32Array([ahead, 0.0, -across, 1.0]))
				rest.append(Vector2(point.x, point.y))
				depth.append(Vector2(point.z, 1.0 + down + (0.0 if side > 0.0 else 2.0)))
				outline.append(Color.WHITE)
				var left := (1.0 - held) * (0.5 + 0.5 * clampf(across * SKIRT_SPLIT, -1.0, 1.0))
				bones.append_array(PackedInt32Array([hips, thighs[0], thighs[1], 0]))
				weights.append_array(PackedFloat32Array([held, left, 1.0 - held - left, 0.0]))
		for ring in SKIRT_RINGS - 1:
			for step in SKIRT_SEGMENTS:
				var a := first + ring * (SKIRT_SEGMENTS + 1) + step
				var b := a + SKIRT_SEGMENTS + 1
				var quad := PackedInt32Array([a, a + 1, b, a + 1, b + 1, b])
				if side < 0.0:
					quad.reverse()
				indices.append_array(quad)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = rest
	arrays[Mesh.ARRAY_TEX_UV2] = depth
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = outline


static func _bind(skin: Skin, bone: StringName) -> int:
	for index in skin.get_bind_count():
		if skin.get_bind_name(index) == bone:
			return index
	push_error("brawler: the mannequin has no bone %s" % bone)
	return 0
