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

const MODEL := preload("res://assets/characters/sailor/sailor.glb")
## Every hat, modelled in the head bone's space (assets/characters/sailor/gen_hats.py),
## by name in Hat's order: a seat wears the one its hat names, on HEAD_BONE.
const HAT_MODELS := preload("res://assets/characters/sailor/hats.glb")
const HAT_MESHES: Array[NodePath] = [
	^"Cap", ^"Souwester", ^"Boater", ^"Bare", ^"Bobble", ^"Top", ^"Peaked"
]
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
## The sailor is authored facing +z; a seat faces +x.
const MODEL_TURN := PI * 0.5
## Each coat's outfit, the sailor dressed in it under its skeleton
## (assets/characters/sailor): a seat keeps the one it wears, named BODY, and drops
## the others. And the bone its hat rides.
const OUTFITS: Array[NodePath] = [^"Jersey", ^"Jacket", ^"Greatcoat"]
## Each coat's own arms, modelled apart on the same skeleton and finer, for the seat
## that looks out over them (FirstPersonArms): every body drops them, and a seat's
## own arms draw its coat's in place of its body.
const ARMS: Array[NodePath] = [^"JerseyArms", ^"JacketArms", ^"GreatcoatArms"]
## Everywhere the arms reach from the shoulders, in model units: modelled out level,
## their own box at rest would cull them once they drop under the eye.
const ARMS_REACH := AABB(Vector3(-1.1, 0.45, -1.0), Vector3(2.2, 2.0, 2.0))
const BODY := &"Sailor"
const HEAD_BONE := &"head"
## The outline's width on a seat's own arms, under the eye, in model units.
const OWN_OUTLINE := 0.0035
## The disc sits just off the feet so it never fights the deck.
const FEET_LIFT := 0.03
const DISC_ALPHA := 0.4
const DISC_SHOVING_ALPHA := 0.55
## How low each coat's skirt hangs, in model units, as gen_sailor.py hangs it: the
## clothes shader shades the legs under it.
const SKIRT_HEMS := {Coat.JACKET: 0.78, Coat.GREATCOAT: 0.45}
const SKIRT_WAIST_HEIGHT := 1.0
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
## holds up ahead of it, as far as halfway between them. In metres. The hand meets
## the other only where its chest stands: the band is over the other's feet as well,
## so a body up or down a stair is reached past. However near the other, the arm
## reaches CLINCH_FOLD out from the shoulder at the least, never folded back onto it.
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
const CLINCH_FOLD := 0.18

static var _disc_texture: GradientTexture2D
## The sailor's crown and the head bone's height at rest, in its units, and per
## hat how high it stands over the soles as a share of the crown: read once.
static var _sailor := Vector2.ZERO
static var _headgear := {}
## Each hat's mesh, read from HAT_MODELS once.
static var _hats: Array[Mesh] = []
## Each coat's own arms, their meshes and skins, read from MODEL once.
static var _arm_meshes: Array[Mesh] = []
static var _arm_skins: Array[Skin] = []

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
## The clip for each move: the crew's, unless drawn as a seat's own arms.
var _clips: Dictionary = BrawlerAnimation.CLIPS
var _poses: BrawlerPose
var _feet_material: StandardMaterial3D
## The outline of the body and its hat, which a shove coming lights.
var _outlines: Array[ShaderMaterial] = []
## A charge's sparks and speed lines, on the chest; null on a seat's own arms.
var _charge: BrawlerCharge
## The rules' ticks at which a held shove becomes a charge and is full, and a
## charge's walk, m/s.
var _charge_from: int
var _charge_full: int
var _charge_walk: float
var _move: BrawlerAnimation.Move = BrawlerAnimation.Move.IDLE
## The move its hands and heat show: _move but in a crawl space, where the clip crawls
## and the hands still telegraph the shove the body is making.
var _acting: BrawlerAnimation.Move = BrawlerAnimation.Move.IDLE
## Seconds since the move its hands show began.
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
	var mesh: MeshInstance3D = skeleton.get_node(OUTFITS[COATS[outfit]])
	for coat in OUTFITS.size():
		if coat != COATS[outfit]:
			skeleton.get_node(OUTFITS[coat]).free()
		skeleton.get_node(ARMS[coat]).free()
	mesh.name = BODY
	var crown := mesh.get_aabb().end.y
	_rest_scale = Vector3.ONE * (rules.body_height / crown)
	_model.scale = _rest_scale
	_model.rotation.y = MODEL_TURN
	_clothes = _dress(outfit)
	mesh.set_surface_override_material(0, _clothes)
	_player = _model.get_node("AnimationPlayer")
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.play(_clips[_move])
	_poses = BrawlerPose.new(skeleton, BrawlerAnimation.POSES)

	var head := BoneAttachment3D.new()
	head.bone_name = HEAD_BONE
	skeleton.add_child(head)
	_hat_node = MeshInstance3D.new()
	_hat_node.name = "Hat"
	_hat_node.mesh = hat_mesh(HATS[outfit])
	_hat_node.material_override = _clothes
	head.add_child(_hat_node)
	_outlines = [_clothes.next_pass as ShaderMaterial]

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
		if _sailor == Vector2.ZERO:
			var model := MODEL.instantiate()
			var skeleton: Skeleton3D = model.get_node("Rig/Skeleton3D")
			var body: MeshInstance3D = skeleton.get_node(OUTFITS[Coat.JERSEY])
			var crown := body.get_aabb().end.y
			var head := skeleton.get_bone_global_rest(skeleton.find_bone(HEAD_BONE)).origin.y
			_sailor = Vector2(crown, head)
			model.free()
		var top := hat_mesh(hat).get_aabb().end.y
		_headgear[hat] = maxf(_sailor.y + top, _sailor.x) / _sailor.x
	return rules.body_height * _headgear[hat]


## [param hat] as modelled, in the head bone's space.
static func hat_mesh(hat: Hat) -> Mesh:
	if _hats.is_empty():
		var hats := HAT_MODELS.instantiate()
		for path: NodePath in HAT_MESHES:
			_hats.append((hats.get_node(path) as MeshInstance3D).mesh)
		hats.free()
	return _hats[hat]


## [param coat]'s own arms, as modelled, to hang under a skeleton.
static func own_arms(coat: Coat) -> MeshInstance3D:
	if _arm_meshes.is_empty():
		var model := MODEL.instantiate()
		for path: NodePath in ARMS:
			var modelled: MeshInstance3D = model.get_node("Rig/Skeleton3D").get_node(path)
			_arm_meshes.append(modelled.mesh)
			_arm_skins.append(modelled.skin)
		model.free()
	var arms := MeshInstance3D.new()
	arms.mesh = _arm_meshes[coat]
	arms.skin = _arm_skins[coat]
	arms.skeleton = ^".."
	arms.custom_aabb = ARMS_REACH
	return arms


## Shows the marker overhead, on the local seat, or hides it.
func show_marker(shown: bool) -> void:
	if _marker != null:
		_marker.visible = shown


## Draws only what a seat sees of itself (FirstPersonArms): its coat's own arms in
## place of its body, no hat, no disc at its feet, no sparks, no shadow, no hit-stop
## squash or hold, a dimmer glow, a finer outline, and [param clips] and
## [param poses] (as BrawlerAnimation.POSES, the elbows bending as [param elbows]
## has) for its moves.
func show_as_own_arms(clips: Dictionary, poses: Dictionary, elbows: Array[Vector3]) -> void:
	_skeleton.get_node(NodePath(BODY)).free()
	var arms := own_arms(COATS[seat % COATS.size()])
	arms.name = BODY
	arms.set_surface_override_material(0, _clothes)
	_skeleton.add_child(arms)
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


## Where the sailor's [param bone] is drawn, in the world.
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


## The node the sailor hangs from: its origin is the drawn feet.
func model_root() -> Node3D:
	return _model


## Poses the brawler for the display moment [param alpha] of the way from
## [param then] to [param now], one seat's entries in two snapshots — [param crawling]
## where MatchView finds it in a crawl space: the move's clip, advanced here, with the
## move's pose over it. Frozen in a hit-stop, its pose holds, squashed, and springs back
## as the stop ends.
func show_state(then: Dictionary, now: Dictionary, alpha: float, crawling := false) -> void:
	var delta := get_process_delta_time()
	var vel: Vector3 = (then["vel"] as Vector3).lerp(now["vel"], alpha)
	var speed := Vector2(vel.x, vel.z).length()
	var move := BrawlerAnimation.move_for(now, speed, crawling)
	var acting := BrawlerAnimation.move_for(now, speed)
	var renewed: bool = now["stagger"] > _stagger
	_stagger = now["stagger"]
	if move != _move or renewed:
		_player.play(_clips[move], BrawlerAnimation.BLEND[move])
		if renewed:
			_player.seek(0.0, true)
		_move = move
	if acting != _acting or renewed:
		_acting = acting
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
	_show_hands(acting)
	var charge: float = lerpf(then["charge"], now["charge"], alpha)
	_show_heat(acting, BrawlerCharge.filled(charge, _charge_from, _charge_full), now, speed)
	var shoving: bool = (
		now["action"] == PlayerState.Action.WINDUP or now["action"] == PlayerState.Action.ACTIVE
	)
	if shoving != _shoving:
		_shoving = shoving
		_colour_disc()


## Reaches the hands to either side of a ring carried at [param ring] — its middle, its
## face along z, in the world — [param radius] across, over whatever the clip and the
## pose drew: the carry (#273). Its x is the holder's left, as RoomDressing.facing turns
## a face toward where the holder looks.
func carry(ring: Transform3D, radius: float) -> void:
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var left := ring.basis.x.normalized() * radius
	for arm in BrawlerPose.ARM_LIMBS:
		var side := left if arm == 0 else -left
		_poses.reach_arm(arm, to_skeleton * (ring.origin + side))


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
	var rise := toward.dot(up)
	toward -= up * rise
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
			apart - front - CLINCH_HAND,
			rise
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
## when the reach ends past it in the band CLINCH_LOW to CLINCH_HIGH high, over these
## feet and over the other's, [param rise] higher, and within CLINCH_WIDE across; 1
## when it ends short of it or out of the band; never nearer the shoulder than
## CLINCH_FOLD.
static func _landing(
	from: Vector3, to: Vector3, toward: Vector3, up: Vector3, limit: float, rise: float
) -> float:
	var depth := to.dot(toward)
	var height := to.dot(up)
	var across := (to - toward * depth - up * height).length()
	if depth <= limit or across > CLINCH_WIDE or not _in_clinch_band(height):
		return 1.0
	if not _in_clinch_band(height - rise):
		return 1.0
	var least := minf(CLINCH_FOLD / from.distance_to(to), 1.0)
	var start := from.dot(toward)
	if start >= limit:
		return least
	return maxf((limit - start) / (depth - start), least)


## Whether a wrist [param height] over a body's feet is in the band a clinch meets.
static func _in_clinch_band(height: float) -> bool:
	return height >= CLINCH_LOW and height <= CLINCH_HIGH


## The clothes for outfit [param outfit], its coat in the seat's colour.
func _dress(outfit: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CLOTHES
	material.set_shader_parameter("coat", _colour)
	material.set_shader_parameter("trousers", ArtPalette.TROUSERS[TROUSERS[outfit]])
	material.set_shader_parameter("skin", ArtPalette.SKIN)
	material.set_shader_parameter("hair", ArtPalette.HAIR[HAIR[outfit]])
	material.set_shader_parameter("shirt", ArtPalette.SHIRT)
	material.set_shader_parameter("straw", ArtPalette.STRAW)
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
