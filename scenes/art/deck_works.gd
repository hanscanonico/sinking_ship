class_name DeckWorks
extends RefCounted
## The works standing on her open decks, as ShipArt draws them from their blockers: a
## hatch's coaming under its tarpaulin, the funnel and the smoke from its top, the mast
## with its crosstree and masthead light.

## The funnel's and the mast's sides, in segments round.
const FUNNEL_SEGMENTS := 20
const MAST_SEGMENTS := 10


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
## through one, and smoke from its top, under [param art]: its emitter.
static func funnel(
	mesh: ShipMesh, blocker: ShipBlocker, top: float, art: ShipArt
) -> CPUParticles3D:
	var centre := blocker.centre
	mesh.cylinder(centre, blocker.radius, blocker.bottom, top, FUNNEL_SEGMENTS, ShipPaints.funnel)
	var rim := blocker.radius + 0.04
	mesh.cylinder(centre, rim, top - 0.12, top, FUNNEL_SEGMENTS, ShipPaints.dark, false)
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


## A mast with a crosstree near its head and a masthead light, under [param art].
static func mast(mesh: ShipMesh, blocker: ShipBlocker, top: float, art: ShipArt) -> void:
	var centre := blocker.centre
	mesh.cylinder(centre, blocker.radius, blocker.bottom, top, MAST_SEGMENTS, ShipPaints.mast)
	var yard := top - (top - blocker.bottom) * 0.22
	var crosstree := Rect2(centre.x - 0.08, centre.y - 1.4, 0.16, 2.8)
	mesh.box(crosstree, yard, yard + 0.12, ShipPaints.dark)
	var bulb := SphereMesh.new()
	bulb.radius = 0.08
	bulb.height = 0.16
	bulb.radial_segments = 8
	bulb.rings = 4
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.95, 0.85)
	glow.emission_energy_multiplier = 2.0
	bulb.material = glow
	var light := MeshInstance3D.new()
	light.name = "MastheadLight"
	light.mesh = bulb
	light.position = Vector3(centre.x + blocker.radius + 0.08, yard - 0.4, centre.y)
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.visible = light.position.y < art.cut_above
	art.add_child(light)
