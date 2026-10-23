class_name DeckWorks
extends RefCounted
## The works standing on her open decks, as ShipArt draws them from their blockers: a
## hatch's coaming under its tarpaulin, the funnel with its whistle and its waste pipe
## and the smoke from its top, the mast with its crosstree, masthead light and cleats.
## The funnel and the mast are drawn to their blockers' size; what is fixed to them is
## modelled (ShipModel.named). Over them, the rigging: the masts' halyards, stays and
## derricks, drawn from the layout where no body can reach them (rigging).

## The funnel's and the mast's sides, in segments round.
const FUNNEL_SEGMENTS := 20
const MAST_SEGMENTS := 10
## The funnel's black rim: how far proud of its side and how deep under its top.
const FUNNEL_RIM := Vector2(0.04, 0.12)
## The sizes a funnel's fittings are made in — its whistle, its waste pipe's head and
## its pipe clamps, each named with its size after it (whistle_330) — by the radius of
## funnel each is made for, and the scale each is made at. RoomDressing.variant()
## picks the largest no bigger than the funnel. The measures below are at scale 1, but
## FUNNEL_RIM, which is the same on every funnel.
const FUNNEL_FITTINGS := {0.9: "90", 3.3: "330"}
const FUNNEL_FITTING_SCALE := {"90": 1.0, "330": 2.0}
## The pipes up a funnel's faces, the whistle's steam pipe up its fore face and the
## waste steam pipe up its after face: their radius, their axes' distance out from the
## funnel's side, and their sides in segments round.
const FUNNEL_PIPE := 0.06
const FUNNEL_PIPE_OUT := 0.16
const PIPE_SEGMENTS := 8
## The whistle (WHISTLE_MODEL): its origin on the funnel's fore face where its steam
## pipe ends, that share of the funnel's standing height up it; its box.
const WHISTLE_MODEL := "whistle"
const WHISTLE_AT := 0.7
const WHISTLE_BOX := AABB(Vector3(-0.01, -0.35, -0.2), Vector3(0.245, 1.03, 0.5))
## The waste pipe's head (WASTE_PIPE_HEAD_MODEL): its origin on the pipe's axis at the
## funnel's top, the funnel toward +x, its mouth WASTE_PIPE_RISE over the top and its
## stay meeting the rim.
const WASTE_PIPE_HEAD_MODEL := "waste_pipe_head"
const WASTE_PIPE_RISE := 0.5
## A clamp holding a pipe to the funnel (PIPE_CLAMP_MODEL), its origin on the funnel's
## face, the pipe along +x; one every CLAMP_SPACING, times the scale, up each pipe;
## its box.
const PIPE_CLAMP_MODEL := "pipe_clamp"
const CLAMP_SPACING := 2.5
const PIPE_CLAMP_BOX := AABB(Vector3(-0.01, -0.035, -0.072), Vector3(0.24, 0.07, 0.144))
## The crosstree, one model for each mast radius it is made for: its origin on the
## mast's axis CROSSTREE_DOWN of the mast's height under its top; its arms reaching
## CROSSTREE_REACH past the mast's side, nothing of it more than CROSSTREE_RISE over
## its origin or CROSSTREE_DROP under it. RoomDressing.variant() picks the largest no
## bigger than the mast.
const CROSSTREES := {0.15: "crosstree_15", 0.2: "crosstree_20", 0.6: "crosstree_60"}
const CROSSTREE_DOWN := 0.22
const CROSSTREE_REACH := 1.1
const CROSSTREE_RISE := 0.36
const CROSSTREE_DROP := 0.6
## The steaming light (MASTHEAD_LIGHT_MODEL): its origin on the mast's fore face at its
## shelf's top, its lens's middle MASTHEAD_LENS from it and MASTHEAD_UNDER under the
## crosstree, the lens MASTHEAD_LENS_SIZE round (its radius) and tall, where its glow
## is hung; its box.
const MASTHEAD_LIGHT_MODEL := "masthead_light"
const MASTHEAD_LENS := Vector3(0.15, 0.13, 0.0)
const MASTHEAD_UNDER := 0.4
const MASTHEAD_LENS_SIZE := Vector2(0.1, 0.14)
const MASTHEAD_LIGHT_BOX := AABB(Vector3(-0.01, -0.2, -0.122), Vector3(0.282, 0.701, 0.244))
## A belaying cleat on each side of the mast (CLEAT_MODEL), its origin on the mast's
## face CLEAT over the mast's foot, out along +z; its box.
const CLEAT_MODEL := "mast_cleat"
const CLEAT := 1.3
const CLEAT_BOX := AABB(Vector3(-0.032, -0.15, -0.01), Vector3(0.064, 0.3, 0.104))
## Her rigging (rigging), each line a square section that thick: a signal halyard's
## rope, a stay's wire, an aerial's wire and the spreader that holds its wires apart.
const HALYARD := 0.025
const STAY := 0.04
const AERIAL_WIRE := 0.02
const AERIAL_SPREADER := 0.08
## A halyard is rove through the crosstree's arm HALYARD_INBOARD in from its end and
## leads down the mast HALYARD_OFF off its face to the cleat.
const HALYARD_INBOARD := 0.05
const HALYARD_OFF := 0.06
## A stay is made fast STAY_UNDER under the top of each mast it joins, on its face; on a
## funnel, at the foot of its rim (FUNNEL_RIM).
const STAY_UNDER := 0.3
## The wireless aerial between two mastheads: each spreader AERIAL_UNDER under its
## mast's top, the wires hung from it so far either side of her centreline.
const AERIAL_UNDER := 0.8
const AERIAL_WIRES: Array[float] = [-0.6, -0.2, 0.2, 0.6]
## How near a rig line may come to the face of a spar it is fixed to — as near as
## art-lint lets a fitting stand into a body (FurnishingCheck.TOLERANCE) — and how far
## apart along it its points are tried for their clearance (rigging).
const RIG_TOLERANCE := 0.12
const RIG_STEP := 0.1
## A cargo derrick on a mast (_derrick) works the hatch whose middle stands on her
## centreline DERRICK_REACH fore or aft of the mast, the nearest mast's: its boom
## DERRICK thick, heeled on a gooseneck band GOOSENECK proud of the mast and tall, and
## topped up DERRICK_TOPPED degrees toward the hatch's middle; its topping lift up to
## the mast LIFT_UNDER under its top, LIFT thick; its cargo runner, RUNNER thick, down
## to a hook block HOOK_BLOCK thick and tall.
const DERRICK_REACH := Vector2(3.0, 12.0)
const DERRICK := 0.14
const GOOSENECK := Vector2(0.05, 0.16)
const DERRICK_TOPPED := 25.0
const LIFT_UNDER := 0.6
const LIFT := 0.03
const RUNNER := 0.025
const HOOK_BLOCK := Vector2(0.12, 0.25)


## One line of her rigging, in ship space: from [member from] to [member to], a square
## section [member thickness] thick, in [member paint]; [member funnel] the funnel it is
## fixed to, which it goes with if it falls, or null; [member spars] the spars it is
## fixed to.
class RigLine:
	var from: Vector3
	var to: Vector3
	var thickness: float
	var paint: ShipMesh.Paint
	var funnel: ShipBlocker
	var spars: Array[ShipBlocker] = []
	## What it is: &"halyard", &"stay", &"aerial" or &"spreader".
	var kind: StringName

	func _init(
		start: Vector3,
		end: Vector3,
		thick: float,
		painted: ShipMesh.Paint,
		what: StringName,
		fixed_to: Array[ShipBlocker]
	) -> void:
		from = start
		to = end
		thickness = thick
		paint = painted
		kind = what
		spars = fixed_to


## A wooden coaming under a tarpaulin drawn over its top and lashed with battens.
static func hatch(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom, top - 0.1, ShipPaints.teak, ShipMesh.SIDES | ShipMesh.TOP)
	mesh.box(area.grow(0.03), top - 0.16, top, ShipPaints.canvas, ShipMesh.SIDES | ShipMesh.TOP)
	mesh.box(area.grow(0.05), top - 0.15, top - 0.11, ShipPaints.beam, ShipMesh.SIDES)
	var along_x := area.size.x >= area.size.y
	var long := area.size.x if along_x else area.size.y
	var bands := maxi(2, floori(long / 1.2))
	for band in bands:
		var at := long * (band + 0.5) / bands
		var strap := (
			Rect2(area.position.x + at - 0.03, area.position.y - 0.04, 0.06, area.size.y + 0.08)
			if along_x
			else Rect2(
				area.position.x - 0.04, area.position.y + at - 0.03, area.size.x + 0.08, 0.06
			)
		)
		mesh.box(strap, top - 0.15, top + 0.01, ShipPaints.beam, ShipMesh.SIDES | ShipMesh.TOP)


## A buff funnel with a black top and a rim, painted like the cabins where it passes
## through one, its pipes and its whistle on it (_funnel_pipes), and smoke from its
## top, under [param art]: its emitter. Everything on it is drawn into [param mesh], so
## a funnel that falls (FunnelArt) carries them.
static func funnel(
	mesh: ShipMesh, blocker: ShipBlocker, top: float, art: ShipArt
) -> CPUParticles3D:
	var centre := blocker.centre
	mesh.cylinder(centre, blocker.radius, blocker.bottom, top, FUNNEL_SEGMENTS, ShipPaints.funnel)
	var rim := blocker.radius + FUNNEL_RIM.x
	mesh.cylinder(centre, rim, top - FUNNEL_RIM.y, top, FUNNEL_SEGMENTS, ShipPaints.dark, false)
	_funnel_pipes(mesh, blocker, top)
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = Vector3(centre.x, top + 0.1, centre.y)
	smoke.amount = 26
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = blocker.radius * 0.5
	smoke.direction = Vector3.UP
	smoke.spread = 10.0
	smoke.initial_velocity_min = 1.2
	smoke.initial_velocity_max = 1.8
	smoke.gravity = Vector3(-0.45, 0.1, 0.12)
	smoke.damping_min = 0.2
	smoke.damping_max = 0.3
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.6))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(ArtPalette.SMOKE, 0.0))
	fade.set_color(1, Color(ArtPalette.SMOKE, 0.0))
	fade.add_point(0.15, ArtPalette.SMOKE)
	smoke.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * blocker.radius * 1.4
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _puff_texture()
	puff.material = material
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.visible = not is_finite(art.cut_above)
	art.add_child(smoke)
	return smoke


## The pipes up [param blocker]'s faces from its foot, held by clamps: up its fore face
## the steam pipe to the whistle (WHISTLE_MODEL), up its after face the waste steam pipe
## to its head over the top (WASTE_PIPE_HEAD_MODEL); all in the size made for the
## funnel (FUNNEL_FITTINGS).
static func _funnel_pipes(mesh: ShipMesh, blocker: ShipBlocker, top: float) -> void:
	var size := RoomDressing.variant(FUNNEL_FITTINGS, blocker.radius)
	var scale: float = FUNNEL_FITTING_SCALE[size]
	var out := FUNNEL_PIPE_OUT * scale
	var radius := FUNNEL_PIPE * scale
	var centre := blocker.centre
	var fore := centre.x + blocker.radius
	var aft := centre.x - blocker.radius
	var whistle := lerpf(blocker.bottom, top, WHISTLE_AT)
	var pipe := Vector2(fore + out, centre.y)
	mesh.cylinder(pipe, radius, blocker.bottom, whistle, PIPE_SEGMENTS, ShipPaints.steel, false)
	pipe = Vector2(aft - out, centre.y)
	mesh.cylinder(pipe, radius, blocker.bottom, top, PIPE_SEGMENTS, ShipPaints.funnel, false)
	var at := Vector3(fore, whistle, centre.y)
	var model := ShipModel.named("%s_%s" % [WHISTLE_MODEL, size])
	mesh.model(model, Transform3D(Basis.IDENTITY, at))
	at = Vector3(pipe.x, top, pipe.y)
	model = ShipModel.named("%s_%s" % [WASTE_PIPE_HEAD_MODEL, size])
	mesh.model(model, Transform3D(Basis.IDENTITY, at))
	var clamp := ShipModel.named("%s_%s" % [PIPE_CLAMP_MODEL, size])
	var after := Basis(Vector3.UP, PI)
	var spacing := CLAMP_SPACING * scale
	var height := blocker.bottom + spacing * 0.5
	while height < top - FUNNEL_RIM.y - spacing * 0.25:
		mesh.model(clamp, Transform3D(after, Vector3(aft, height, centre.y)))
		if height < whistle - spacing * 0.25:
			mesh.model(clamp, Transform3D(Basis.IDENTITY, Vector3(fore, height, centre.y)))
		height += spacing


## A soft round puff, white at its heart and clear at its edge.
static func _puff_texture() -> GradientTexture2D:
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = falloff
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


## A mast with its crosstree near its head (CROSSTREES), the steaming light on its fore
## side under it (MASTHEAD_LIGHT_MODEL) with its glow under [param art], and a cleat
## either side over its foot (CLEAT_MODEL).
static func mast(mesh: ShipMesh, blocker: ShipBlocker, top: float, art: ShipArt) -> void:
	var centre := blocker.centre
	var radius := blocker.radius
	mesh.cylinder(centre, radius, blocker.bottom, top, MAST_SEGMENTS, ShipPaints.mast)
	var yard := top - (top - blocker.bottom) * CROSSTREE_DOWN
	var crosstree := ShipModel.named(RoomDressing.variant(CROSSTREES, radius))
	mesh.model(crosstree, Transform3D(Basis.IDENTITY, Vector3(centre.x, yard, centre.y)))
	var lens := Vector3(centre.x + radius, yard - MASTHEAD_UNDER, centre.y)
	var shelf := lens - Vector3.UP * MASTHEAD_LENS.y
	mesh.model(ShipModel.named(MASTHEAD_LIGHT_MODEL), Transform3D(Basis.IDENTITY, shelf))
	var cleat := ShipModel.named(CLEAT_MODEL)
	for side: float in [-1.0, 1.0]:
		var turn := Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI)
		var at := Vector3(centre.x, blocker.bottom + CLEAT, centre.y + side * radius)
		mesh.model(cleat, Transform3D(turn, at))
	var glass := CylinderMesh.new()
	glass.top_radius = MASTHEAD_LENS_SIZE.x + 0.004
	glass.bottom_radius = glass.top_radius
	glass.height = MASTHEAD_LENS_SIZE.y
	glass.radial_segments = 12
	glass.rings = 1
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.95, 0.85)
	glow.emission_energy_multiplier = 2.0
	glass.material = glow
	var light := MeshInstance3D.new()
	light.name = "MastheadLight"
	light.mesh = glass
	light.position = lens + Vector3(MASTHEAD_LENS.x, 0.0, 0.0)
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.visible = light.position.y < art.cut_above
	art.add_child(light)


## The rigging over [param layout]'s decks, every line of it clear of the space a body
## of [param rules] can fill (_clears): a signal halyard from each arm of a mast's
## crosstree down to its cleat on that side; a stay from a mast's head to the next
## spar's along her, a mast's or a funnel's, and from mast to mast over what stands
## between; on a ship of two masts, the wireless aerial between their heads; and a
## cargo derrick on a mast over the hatch it works (_derrick). No stay comes down to
## her deck: one would pass through a body at her railing.
static func rigging(layout: ShipLayout, rules: BrawlRules) -> Array[RigLine]:
	var spars: Array[ShipBlocker] = []
	for blocker: ShipBlocker in layout.blockers:
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			spars.append(blocker)
	spars.sort_custom(func(a: ShipBlocker, b: ShipBlocker) -> bool: return a.centre.x < b.centre.x)
	var masts: Array[ShipBlocker] = []
	for spar in spars:
		if not ShipArt.is_funnel(layout, spar):
			masts.append(spar)
	var lines: Array[RigLine] = []
	for mast in masts:
		for side: float in [-1.0, 1.0]:
			lines.append_array(_halyard(layout, rules, mast, side))
	for index in spars.size() - 1:
		var aft := spars[index]
		var fore := spars[index + 1]
		if masts.has(aft) or masts.has(fore):
			lines.append(_stay(layout, aft, fore))
	for index in masts.size() - 1:
		var aft := masts[index]
		var fore := masts[index + 1]
		if spars.find(fore) - spars.find(aft) > 1:
			lines.append(_stay(layout, aft, fore))
	if masts.size() == 2:
		lines.append_array(_aerial(masts[0], masts[1]))
	var clear: Array[RigLine] = []
	for line in lines:
		if _clears(layout, rules, line):
			clear.append(line)
	var space := ShipSpace.new(layout)
	var worked := {}
	for blocker: ShipBlocker in layout.blockers:
		if not _is_hatch(space, blocker):
			continue
		var middle := blocker.area.get_center()
		var nearest: ShipBlocker = null
		for mast in masts:
			var off := absf(middle.x - mast.centre.x)
			var on_line := (
				blocker.area.position.y <= mast.centre.y and blocker.area.end.y >= mast.centre.y
			)
			if not on_line or off < DERRICK_REACH.x or off > DERRICK_REACH.y:
				continue
			if nearest == null or off < absf(middle.x - nearest.centre.x):
				nearest = mast
		if nearest != null:
			worked[blocker] = nearest
	for hatch: ShipBlocker in worked:
		clear.append_array(_derrick(layout, rules, worked[hatch], hatch))
	return clear


## Draws [param layout]'s rigging (rigging()) by [param rules] into [param mesh], each
## line whose ends both stand in [param span], the stretch drawn (PieceClip): one fixed to
## a funnel the sinking can fell into that funnel's own piece — the node [param funnels]
## holds under its fitting's name, among [param pieces] — so it goes with it as it falls.
static func rig(
	mesh: ShipMesh,
	layout: ShipLayout,
	rules: BrawlRules,
	span: Vector2,
	funnels: Dictionary,
	pieces: Dictionary
) -> void:
	for line in rigging(layout, rules):
		if not (PieceClip.holds(span, line.from.x) and PieceClip.holds(span, line.to.x)):
			continue
		var into := mesh
		if line.funnel != null:
			var felled := FunnelArt.fitting_of(layout, line.funnel)
			if felled != null:
				if not funnels.has(felled.name):
					continue
				into = pieces[funnels[felled.name]]
		into.beam(line.from, line.to, Vector2.ONE * line.thickness, line.paint, 0)


## Whether [param blocker] is a hatch ShipArt draws (hatch): a box no wall, no slab
## roofing a room, its middle outdoors, and a hatch to DeckFurniture, not a skylight, a
## seat locker, a towing post or a casing.
static func _is_hatch(space: ShipSpace, blocker: ShipBlocker) -> bool:
	if blocker.shape != ShipBlocker.Shape.BOX or space.is_wall(blocker):
		return false
	if blocker.top - blocker.bottom <= ShipSpace.WALL_MAX and space.roofs(blocker):
		return false
	var middle := blocker.area.get_center()
	if not space.outdoors(Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y)):
		return false
	return DeckFurniture.piece_of(space, blocker) == DeckFurniture.Piece.HATCH


## The cargo derrick on [param mast] working [param hatch]: its boom heeled on its
## gooseneck band high enough to clear a body under the whole of it and topped up toward
## the hatch's middle, its topping lift from the boom's head up to the mast, its runner
## from the head down to its hook block, hung where a body standing on the hatch clears
## it. None when any of it would not clear one (_clears), or the boom's head would stand
## over the lift's foot on the mast.
static func _derrick(
	layout: ShipLayout, rules: BrawlRules, mast: ShipBlocker, hatch: ShipBlocker
) -> Array[RigLine]:
	var spars: Array[ShipBlocker] = [mast]
	var middle := hatch.area.get_center()
	var toward := (middle - mast.centre).normalized()
	var face := mast.centre + toward * mast.radius
	var headroom := rules.body_height + rules.jump_height
	var under := -INF
	for top in _tops_under(layout, rules, Vector3(face.x, 0.0, face.y), _flat(middle), spars):
		under = maxf(under, top[1])
	var band := under + headroom
	var heel := Vector3(face.x, band + DERRICK * 0.5, face.y)
	var reach := face.distance_to(middle)
	var head := _flat(middle) + Vector3.UP * (heel.y + reach * tan(deg_to_rad(DERRICK_TOPPED)))
	var lift := Vector3(face.x, mast.top - LIFT_UNDER, face.y)
	if head.y >= lift.y:
		return []
	var hook := under + headroom + HOOK_BLOCK.y + HOOK_BLOCK.x
	var round := Vector2.ONE * (mast.radius + GOOSENECK.x) * 2.0
	var axis := _flat(mast.centre)
	var lines: Array[RigLine] = [
		RigLine.new(
			axis + Vector3.UP * band,
			axis + Vector3.UP * (band + GOOSENECK.y),
			round.x,
			ShipPaints.dark,
			&"gooseneck",
			spars
		),
		RigLine.new(heel, head, DERRICK, ShipPaints.mast, &"boom", spars),
		RigLine.new(head, lift, LIFT, ShipPaints.dark, &"lift", spars),
		RigLine.new(head, Vector3(head.x, hook, head.z), RUNNER, ShipPaints.rope, &"runner", spars),
		RigLine.new(
			Vector3(head.x, hook, head.z),
			Vector3(head.x, hook - HOOK_BLOCK.y, head.z),
			HOOK_BLOCK.x,
			ShipPaints.dark,
			&"hook",
			spars
		),
	]
	for line in lines:
		if not _clears(layout, rules, line):
			return []
	return lines


## Ship-plane point [param at] at height 0 in ship space.
static func _flat(at: Vector2) -> Vector3:
	return Vector3(at.x, 0.0, at.y)


## The height of the crosstree on a mast from [param bottom] to [param top] (mast).
static func _yard(bottom: float, top: float) -> float:
	return top - (top - bottom) * CROSSTREE_DOWN


## The signal halyard on [param side] of [param mast] (+1 to starboard): from its
## crosstree's arm in toward the mast, high enough over what stands under it to clear a
## body there, then down the mast's face to its cleat. None where the crosstree stands too
## low for that.
static func _halyard(
	layout: ShipLayout, rules: BrawlRules, mast: ShipBlocker, side: float
) -> Array[RigLine]:
	var centre := mast.centre
	var yard := _yard(mast.bottom, mast.top)
	var arm := Vector3(
		centre.x, yard, centre.y + side * (mast.radius + CROSSTREE_REACH - HALYARD_INBOARD)
	)
	var off := centre.y + side * (mast.radius + HALYARD_OFF)
	var spars: Array[ShipBlocker] = [mast]
	var tops := _tops_under(layout, rules, arm, Vector3(centre.x, arm.y, off), spars)
	var under := -INF
	for top in tops:
		under = maxf(under, top[1])
	var cleat := mast.bottom + CLEAT
	var lead := maxf(under + rules.body_height + rules.jump_height + HALYARD * 0.5, cleat)
	if lead >= yard:
		return []
	var turn := Vector3(centre.x, lead, off)
	return [
		RigLine.new(arm, turn, HALYARD, ShipPaints.rope, &"halyard", spars),
		RigLine.new(
			turn, Vector3(centre.x, cleat, off), HALYARD, ShipPaints.rope, &"halyard", spars
		),
	]


## The stay between the heads of [param aft] and [param fore], fixed on the faces they
## turn to each other: STAY_UNDER under a mast's top, at the foot of a funnel's rim.
static func _stay(layout: ShipLayout, aft: ShipBlocker, fore: ShipBlocker) -> RigLine:
	var spars: Array[ShipBlocker] = [aft, fore]
	var ends: Array[Vector3] = []
	for index in 2:
		var spar := spars[index]
		var out := spar.radius
		var under := STAY_UNDER
		if ShipArt.is_funnel(layout, spar):
			out += FUNNEL_RIM.x
			under = FUNNEL_RIM.y
		var face := spar.centre.x + (out if index == 0 else -out)
		ends.append(Vector3(face, spar.top - under, spar.centre.y))
	var line := RigLine.new(ends[0], ends[1], STAY, ShipPaints.dark, &"stay", spars)
	for spar in spars:
		if ShipArt.is_funnel(layout, spar):
			line.funnel = spar
	return line


## The wireless aerial between [param aft]'s and [param fore]'s heads: a spreader
## athwart each, AERIAL_UNDER under its top on the face it turns to the other, and
## a wire between them at each of AERIAL_WIRES.
static func _aerial(aft: ShipBlocker, fore: ShipBlocker) -> Array[RigLine]:
	var spars: Array[ShipBlocker] = [aft, fore]
	var ends: Array[Vector3] = []
	for index in 2:
		var spar := spars[index]
		var out := spar.radius + AERIAL_SPREADER * 0.5
		var face := spar.centre.x + (out if index == 0 else -out)
		ends.append(Vector3(face, spar.top - AERIAL_UNDER, spar.centre.y))
	var lines: Array[RigLine] = []
	var span := AERIAL_WIRES.back() as float + AERIAL_SPREADER
	for at in ends:
		var across := Vector3(0.0, 0.0, span)
		lines.append(
			RigLine.new(
				at - across, at + across, AERIAL_SPREADER, ShipPaints.mast, &"spreader", spars
			)
		)
	for wire: float in AERIAL_WIRES:
		var across := Vector3(0.0, -AERIAL_SPREADER, wire)
		lines.append(
			RigLine.new(
				ends[0] + across, ends[1] + across, AERIAL_WIRE, ShipPaints.steel, &"aerial", spars
			)
		)
	return lines


## Whether every point of [param line] stands within RIG_TOLERANCE of the face of a spar
## it is fixed to, or a body's height and jump of [param rules] over every top a body
## can stand on under it (_tops_under).
static func _clears(layout: ShipLayout, rules: BrawlRules, line: RigLine) -> bool:
	var half := line.thickness * 0.5
	var headroom := rules.body_height + rules.jump_height
	var tops := _tops_under(layout, rules, line.from, line.to, line.spars)
	var steps := maxi(1, ceili(line.from.distance_to(line.to) / RIG_STEP))
	for step in steps + 1:
		var point := line.from.lerp(line.to, float(step) / steps)
		var at := Vector2(point.x, point.z)
		var held := false
		for spar in line.spars:
			if at.distance_to(spar.centre) + half <= spar.radius + RIG_TOLERANCE:
				held = true
		if not held and point.y - half < _top_at(tops, at) + headroom:
			return false
	return true


## Every top a body of [param rules] can stand on whose round reaches over the ship
## plane between [param from] and [param to] — a platform's, a ramp's, a blocker's
## but [param spars]', a cylinder's by the square round it — each as
## [its area grown by a body's radius, its height].
static func _tops_under(
	layout: ShipLayout, rules: BrawlRules, from: Vector3, to: Vector3, spars: Array[ShipBlocker]
) -> Array[Array]:
	var reach := rules.body_radius
	var low := Vector2(minf(from.x, to.x), minf(from.z, to.z))
	var high := Vector2(maxf(from.x, to.x), maxf(from.z, to.z))
	var under := Rect2(low, high - low).grow(reach)
	var tops: Array[Array] = []
	for platform: ShipPlatform in layout.platforms:
		tops.append([platform.area, platform.height])
	for ramp: ShipRamp in layout.ramps:
		tops.append([ramp.area, maxf(ramp.start_height, ramp.end_height)])
	for blocker: ShipBlocker in layout.blockers:
		if spars.has(blocker):
			continue
		var area := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			var round := Vector2.ONE * blocker.radius
			area = Rect2(blocker.centre - round, round * 2.0)
		tops.append([area, blocker.top])
	var near: Array[Array] = []
	for top in tops:
		var area := (top[0] as Rect2).grow(reach)
		if area.intersects(under, true):
			near.append([area, top[1]])
	return near


## The highest of [param tops] (_tops_under) over ship-plane point [param at], or -INF.
static func _top_at(tops: Array[Array], at: Vector2) -> float:
	var highest := -INF
	for top in tops:
		if top[1] > highest and (top[0] as Rect2).has_point(at):
			highest = top[1]
	return highest
