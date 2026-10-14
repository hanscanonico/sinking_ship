class_name DeckWorks
extends RefCounted
## The works standing on her open decks, as ShipArt draws them from their blockers: a
## hatch's coaming under its tarpaulin, the funnel with its whistle and its waste pipe
## and the smoke from its top, the mast with its crosstree, masthead light and cleats.
## The funnel and the mast are drawn to their blockers' size; what is fixed to them is
## modelled (ShipModel.named).

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
