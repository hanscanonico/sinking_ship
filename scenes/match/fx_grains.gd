class_name FxGrains
extends RefCounted
## The grains the sinking's effects draw (SinkingFx), and how each pool of them
## moves: their pictures, cartoon clumps of white water and soft puffs; their
## materials, facing the eye, drawn over the sea and fading out near the eye
## (fx_grain.gdshader), or boxes lit like the ship; and every emitter's motion and
## colour over its life.

## The clump white water is drawn with: pixels a side, and its blobs as the middle
## (x, y) and radius (z), in shares of the side.
const CLUMP_SIZE := 48
const CLUMP_BLOBS: Array[Vector3] = [
	Vector3(0.5, 0.56, 0.27),
	Vector3(0.3, 0.42, 0.17),
	Vector3(0.68, 0.38, 0.19),
	Vector3(0.46, 0.25, 0.14),
	Vector3(0.78, 0.66, 0.12),
	Vector3(0.22, 0.7, 0.1),
]
## How much a grain of white water grows over its life, and a fleck of foam; how far
## a fleck strays off the planks' plane as it slides, in degrees.
const WATER_GROWN := 1.5
const FLECK_GROWN := 1.3
const FOAM_SPREAD := 5.0
## Where the funnel's smoke drifts, as ShipArt's does.
const WIND := Vector3(-0.45, 0.1, 0.12)
## A grain fades out from this far from the eye to a third of it; a puff of steam,
## which is big and soft, from further; a fleck of foam or a mote of dust, which are
## small, from nearer.
const CLEAR := 6.0
const STEAM_CLEAR := 9.0
const SPECK_CLEAR := 2.0
## Particles are drawn after the sea, which otherwise covers what stands on it.
const OVER_THE_SEA := 1

const GRAIN_SHADER := preload("res://scenes/match/fx_grain.gdshader")


## White water, thrown and falling back, its grains living [param lifetime] seconds.
static func water(emitter: CPUParticles3D, lifetime: float) -> void:
	emitter.lifetime = lifetime
	emitter.angle_max = 360.0
	emitter.gravity = Vector3.DOWN * Flotsam.GRAVITY
	emitter.damping_min = 0.3
	emitter.damping_max = 0.8
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_curve = growth(0.6, WATER_GROWN)
	emitter.color_ramp = fade(ArtPalette.SPRAY, 0.05)


## Foam: flecks sliding over the planks along the emitter's z, low and short-lived.
static func foam(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 1.1
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.direction = Vector3.BACK
	emitter.spread = FOAM_SPREAD
	emitter.gravity = Vector3.ZERO
	emitter.damping_min = 0.4
	emitter.damping_max = 0.9
	emitter.angle_max = 360.0
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.0
	emitter.scale_amount_curve = growth(0.7, FLECK_GROWN)
	emitter.color_ramp = fade(Color(ArtPalette.SPRAY, 0.75), 0.1)


## The dust of a deck giving way: billowing up past heads, swelling, drifting off on
## the wind for seconds.
static func cloud(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 8.0
	emitter.explosiveness = 0.8
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.direction = Vector3.UP
	emitter.spread = 30.0
	emitter.gravity = WIND * 1.5 + Vector3.UP * 0.25
	# Bursting up past the funnel's top in a second or two, then hanging there.
	emitter.damping_min = 1.5
	emitter.damping_max = 2.0
	emitter.initial_velocity_min = 3.0
	emitter.initial_velocity_max = 6.0
	emitter.angle_max = 360.0
	emitter.scale_amount_min = 0.8
	emitter.scale_amount_max = 1.5
	emitter.scale_amount_curve = growth(0.8, 3.0)
	emitter.color_ramp = fade(ArtPalette.DUST_CLOUD, 0.05)


## Dust sifting down from a ceiling in thin shafts that spread as they fall: upright
## streaks, overlapping down each shaft.
static func sifting(emitter: CPUParticles3D) -> void:
	emitter.explosiveness = 0.0
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	emitter.spread = 4.0
	emitter.gravity = Vector3.DOWN * 0.3
	emitter.damping_min = 0.2
	emitter.damping_max = 0.4
	emitter.initial_velocity_min = 0.2
	emitter.initial_velocity_max = 0.5
	emitter.scale_amount_min = 0.8
	emitter.scale_amount_max = 1.0
	emitter.scale_amount_curve = growth(1.0, 2.2)
	emitter.color_ramp = fade(ArtPalette.SIFTING_DUST, 0.15)


## Steam: rising fast, swelling and thinning as it drifts off.
static func plume(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 2.4
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.3
	emitter.direction = Vector3.UP
	emitter.spread = 9.0
	emitter.gravity = Vector3(WIND.x, 0.4, WIND.z)
	emitter.damping_min = 0.6
	emitter.damping_max = 1.0
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_curve = growth(0.4, 3.0)
	emitter.color_ramp = fade(ArtPalette.STEAM, 0.1)


## Bubbles breaking on the sea over a ring.
static func boil(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 0.9
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	emitter.emission_ring_axis = Vector3.UP
	emitter.emission_ring_height = 0.0
	emitter.emission_ring_inner_radius = 0.0
	emitter.direction = Vector3.UP
	emitter.spread = 15.0
	emitter.initial_velocity_min = 0.05
	emitter.gravity = Vector3.ZERO
	emitter.scale_amount_min = 0.5
	emitter.scale_amount_curve = growth(0.3, 1.4)
	emitter.color_ramp = fade(ArtPalette.BUBBLE, 0.2)


## The funnel's smoke, dark and drifting off on the wind.
static func funnel_smoke(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 5.5
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.45
	emitter.direction = Vector3.UP
	emitter.spread = 12.0
	emitter.gravity = WIND
	emitter.damping_min = 0.2
	emitter.damping_max = 0.3
	emitter.initial_velocity_min = 4.0
	emitter.initial_velocity_max = 7.0
	emitter.scale_amount_min = 1.0
	emitter.scale_amount_max = 1.8
	emitter.scale_amount_curve = growth(0.5, 3.2)
	emitter.color_ramp = fade(ArtPalette.SMOKE_HEAVY, 0.15)
	if emitter.one_shot:
		# A belch: a ragged cough of it, not one ball.
		emitter.explosiveness = 0.5
		emitter.emission_sphere_radius = 0.8
		emitter.spread = 28.0
		emitter.initial_velocity_min = 3.0
		emitter.scale_amount_min = 0.7


## Grains [param size] across, facing the eye, drawn over the sea, and gone within
## [param clear] metres of the eye.
static func billboard(size: float, texture: Texture2D, clear: float = CLEAR) -> QuadMesh:
	var material := ShaderMaterial.new()
	material.shader = GRAIN_SHADER
	material.set_shader_parameter(&"grain", texture)
	# Nothing an effect draws stands in the eye's face: it fades out as it nears.
	material.set_shader_parameter(&"clear_from", clear * 0.3)
	material.set_shader_parameter(&"clear_to", clear)
	material.render_priority = OVER_THE_SEA
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	return quad


## A box of [param size], lit like the ship, in [param colour].
static func shaded(size: Vector3, colour: Color) -> BoxMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	return box


## A cartoon blob: solid to most of its radius, then a short soft edge.
static func blob() -> GradientTexture2D:
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.62, 0.8])
	falloff.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	return _radial(falloff)


## White water as a cartoon draws it: a clump of round blobs with crisp edges,
## turned at random grain by grain so no two read alike.
static func clump() -> ImageTexture:
	var size := CLUMP_SIZE
	var picture := Image.create_empty(size, size, false, Image.FORMAT_LA8)
	for y in size:
		for x in size:
			var cover := 0.0
			for blob: Vector3 in CLUMP_BLOBS:
				var gap := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(blob.x, blob.y) * size)
				cover = maxf(cover, clampf(blob.z * size - gap + 0.5, 0.0, 1.0))
			picture.set_pixel(x, y, Color(1.0, 1.0, 1.0, cover))
	return ImageTexture.create_from_image(picture)


## A soft puff, white at its heart and clear at its edge.
static func puff() -> GradientTexture2D:
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	falloff.colors = PackedColorArray(
		[Color.WHITE, Color(1.0, 1.0, 1.0, 0.8), Color(1.0, 1.0, 1.0, 0.0)]
	)
	return _radial(falloff)


static func _radial(falloff: Gradient) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.gradient = falloff
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


## A grain's scale over its life, from [param born] to [param grown].
static func growth(born: float, grown: float) -> Curve:
	var curve := Curve.new()
	curve.max_value = maxf(grown, 1.0)
	curve.add_point(Vector2(0.0, born))
	curve.add_point(Vector2(1.0, grown))
	return curve


## [param colour] fading in over the first [param rise] of a grain's life and out
## over the rest.
static func fade(colour: Color, rise: float) -> Gradient:
	var fade := Gradient.new()
	fade.set_color(0, Color(colour, 0.0))
	fade.set_color(1, Color(colour, 0.0))
	fade.add_point(rise, colour)
	fade.add_point(0.6, Color(colour, colour.a * 0.8))
	return fade
