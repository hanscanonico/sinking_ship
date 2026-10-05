class_name FxGrains
extends RefCounted
## The grains the sinking's effects draw (SinkingFx), and how each pool of them
## moves: their pictures — hard-edged toon shapes (a streak of spray, a patch of
## lace, a billow) and soft puffs of dust; their materials, drawn over the sea and
## fading out near the eye (fx_grain.gdshaderinc), or boxes lit like the ship; and
## every emitter's motion and colour over its life.

## A shape's picture holds, in alpha, the distance to its edge: 0.5 on it, a
## FIELD_SPREAD pixels further in or out to 1 or 0.
const FIELD_SPREAD := 4.0
## A streak of spray, on a picture of STREAK_SIZE pixels: a small round head (x, y,
## radius, in pixels) drawn out to the tip of a long tail.
const STREAK_SIZE := Vector2i(16, 64)
const STREAK_HEAD := Vector3(8.0, 6.0, 3.6)
const STREAK_TIP := Vector3(8.3, 60.0, 1.1)
## A sheet of lace foam, LACE_SIZE pixels, that tiles: white threads where the
## cells of a jittered grid LACE_GRID cells a side meet, from LACE_THREAD.x to .y
## pixels thick, swelling and thinning along them, as LACE_SEED lays them; its field
## LACE_SPREAD pixels deep either side of a thread's edge, sharper than a shape's, so
## a grain can wear its threads away by degrees; the broad noise a grain's ragged
## outline follows, LACE_NOISE cells a side.
const LACE_SIZE := Vector2i(64, 64)
const LACE_GRID := 7
const LACE_THREAD := Vector2(0.3, 1.2)
const LACE_SPREAD := 2.0
const LACE_SEED := 4817
const LACE_NOISE := 4
## How many metres of foam the whole sheet of lace spans, either way, on the planks.
const LACE_SHEET := 1.0
## A billow: bumps heaped on a broad foot, as blobs — the middle (x, y) and radius
## (z), in pixels — on a picture of BILLOW_SIZE pixels.
const BILLOW_SIZE := Vector2i(32, 32)
const BILLOW_BLOBS: Array[Vector3] = [
	Vector3(16.0, 20.0, 9.0),
	Vector3(8.5, 19.0, 6.5),
	Vector3(23.5, 18.0, 7.0),
	Vector3(12.5, 11.0, 6.0),
	Vector3(20.5, 9.5, 6.5),
	Vector3(26.5, 24.0, 4.8),
	Vector3(6.5, 25.0, 4.8),
]
## How much a grain of white water grows over its life, and a patch of foam; how
## far foam strays off its way across the planks, in degrees.
const WATER_GROWN := 1.2
const FLECK_GROWN := 1.15
const FOAM_SPREAD := 5.0
## A drop of white water out of the gash is this much of its first size by the
## time it slows over the top of its arc, STRUCK_TOP of the way through its life, and
## this much at its end.
const STRUCK_SLOWED := 0.4
const STRUCK_TOP := 0.45
const STRUCK_FALLEN := 0.25
## Spray mist is thrown up hard and brought to a stop, slowing this hard, in m/s²,
## over the first MIST_STOPS of its life; then it hangs, settling this hard and
## drifting off downwind this hard. Its billows swell from this much of their size to
## this much as it stops, then shrink away to this much, this opaque all the while.
const MIST_OPACITY := 0.9
const MIST_DAMPING := 24.0
const MIST_STOPS := 0.5
const MIST_SINK := 0.3
const MIST_DRIFT := 2.0
const MIST_GROWN := Vector3(0.8, 1.6, 0.5)
## Foam spreading on the sea grows this much over its life.
const FROTH_GROWN := Vector2(0.7, 1.8)
## Where the funnel's smoke drifts, as ShipArt's does; white water flies downwind
## with this much of a push, in m/s².
const WIND := Vector3(-0.45, 0.1, 0.12)
const SPRAY_WIND := 3.0
## A grain fades out from this far from the eye to a third of it; a billow of steam,
## which is big, from further; a fleck of foam or a mote of dust, which are small,
## from nearer.
const CLEAR := 6.0
const STEAM_CLEAR := 9.0
const SPECK_CLEAR := 2.0
## White water drawn this much brighter than its colour, so it stays
## white through the tonemap as the sea's foam does; foam lying on the planks, in
## their light and shade, a little less; bubbles breaking on the sea, as its foam.
const WHITE_GLOW := 3.2
## Steam, a little brighter than its colour: its sunlit side white, its shade side
## the dusk's lilac, never both blown out to one white.
const STEAM_GLOW := 1.3
const LACE_GLOW := 1.7
const BUBBLE_GLOW := 2.4
## Grit blown off a falling deck a little brighter than its colour, so its warm tan
## holds against the dusk.
const GRIT_GLOW := 1.4
## How opaque foam on the planks is, and water streaming down them: see-through
## enough that the patches overlapping run together into one band; foam on the sea a
## little more, to stand out on it from the deck.
const FOAM_OPACITY := 0.42
const RUNNEL_OPACITY := 0.38
const FROTH_OPACITY := 0.6
## How opaque the funnel's smoke is: dark, darker than the sky behind it.
const SMOKE_OPACITY := 0.9
## Particles are drawn after the sea, which otherwise covers what stands on it.
const OVER_THE_SEA := 1

const GRAIN_SHADER := preload("res://scenes/match/fx_grain.gdshader")
const STREAK_SHADER := preload("res://scenes/match/fx_streak.gdshader")
const LACE_SHADER := preload("res://scenes/match/fx_lace.gdshader")
const BILLOW_SHADER := preload("res://scenes/match/fx_billow.gdshader")

## The sheets of lace built so far, by how far their cells are drawn out.
static var _laces := {}


## White water thrown up and falling back, blown downwind, its grains living
## [param lifetime] seconds: streaks along their flight.
static func water(emitter: CPUParticles3D, lifetime: float) -> void:
	emitter.lifetime = lifetime
	emitter.particle_flag_align_y = true
	emitter.gravity = Vector3.DOWN * Flotsam.GRAVITY + downwind()
	emitter.damping_min = 0.3
	emitter.damping_max = 0.8
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_curve = growth(0.8, WATER_GROWN)
	emitter.color_ramp = held(ArtPalette.SPRAY)


## White water burst up out of the gash: round drops shrinking as they slow over the
## top of their arc, thinning out as they fall back.
static func struck(emitter: CPUParticles3D) -> void:
	water(emitter, 1.0)
	emitter.particle_flag_align_y = false
	emitter.angle_max = 360.0
	var dwindling := Curve.new()
	dwindling.add_point(Vector2(0.0, 1.0))
	dwindling.add_point(Vector2(STRUCK_TOP, STRUCK_SLOWED))
	dwindling.add_point(Vector2(1.0, STRUCK_FALLEN))
	emitter.scale_amount_curve = dwindling
	var thinning := Gradient.new()
	thinning.set_color(0, Color(ArtPalette.SPRAY, 0.0))
	thinning.set_color(1, Color(ArtPalette.SPRAY, 0.0))
	thinning.add_point(0.03, ArtPalette.SPRAY)
	thinning.add_point(STRUCK_TOP, Color(ArtPalette.SPRAY, ArtPalette.SPRAY.a * 0.75))
	emitter.color_ramp = thinning


## Spray mist: billows thrown up along the emitter's direction and brought to a stop,
## then hanging and drifting off downwind as they shrink away.
static func mist(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 2.2
	emitter.explosiveness = 0.9
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.spread = 14.0
	emitter.gravity = downwind().normalized() * MIST_DRIFT + Vector3.DOWN * MIST_SINK
	emitter.damping_min = MIST_DAMPING
	emitter.damping_max = MIST_DAMPING
	var stopping := Curve.new()
	stopping.add_point(Vector2(0.0, 1.0))
	stopping.add_point(Vector2(MIST_STOPS, 1.0))
	stopping.add_point(Vector2(MIST_STOPS + 0.05, 0.0))
	emitter.damping_curve = stopping
	emitter.angle_max = 360.0
	emitter.scale_amount_min = 0.6
	var swelling := Curve.new()
	swelling.max_value = MIST_GROWN.y
	swelling.add_point(Vector2(0.0, MIST_GROWN.x))
	swelling.add_point(Vector2(MIST_STOPS, MIST_GROWN.y))
	swelling.add_point(Vector2(1.0, MIST_GROWN.z))
	emitter.scale_amount_curve = swelling
	emitter.color_ramp = held(Color(Color.WHITE, MIST_OPACITY))


## Foam: patches of lace sliding over the planks along the emitter's z, lying in
## its plane, turned every way.
static func foam(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 1.6
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.direction = Vector3.BACK
	emitter.spread = FOAM_SPREAD
	emitter.gravity = Vector3.ZERO
	emitter.damping_min = 0.4
	emitter.damping_max = 0.9
	emitter.particle_flag_rotate_y = true
	emitter.angle_max = 360.0
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.0
	emitter.scale_amount_curve = growth(0.7, FLECK_GROWN)
	emitter.color_ramp = held(Color(ArtPalette.SPRAY, FOAM_OPACITY))


## Foam on the sea: patches of lace drifting off along the emitter's z, lying on it,
## spreading as they go.
static func froth(emitter: CPUParticles3D) -> void:
	foam(emitter)
	emitter.lifetime = 2.8
	emitter.scale_amount_curve = growth(FROTH_GROWN.x, FROTH_GROWN.y)
	emitter.color_ramp = held(Color(ArtPalette.SPRAY, FROTH_OPACITY))


## Water streaming down the planks along the emitter's z: runnels of lace drawn out
## along their way, lying in its plane.
static func runnel(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 1.4
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.direction = Vector3.BACK
	emitter.spread = 6.0
	emitter.gravity = Vector3.ZERO
	emitter.initial_velocity_min = 1.4
	emitter.initial_velocity_max = 2.8
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.0
	emitter.scale_amount_curve = growth(0.8, 1.1)
	emitter.color_ramp = held(Color(ArtPalette.SPRAY, RUNNEL_OPACITY))


## Spray blown across the sky and falling: fine streaks driven down the wind.
static func spray_rain(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 1.6
	emitter.explosiveness = 0.0
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.particle_flag_align_y = true
	emitter.spread = 10.0
	emitter.initial_velocity_min = 4.0
	emitter.initial_velocity_max = 7.0
	emitter.gravity = Vector3.DOWN * 4.0 + downwind()
	emitter.scale_amount_min = 0.7
	emitter.scale_amount_max = 1.0
	emitter.color_ramp = held(ArtPalette.SPRAY)


## The grit of a deck giving way blowing past an eye looking away: warm specks
## carried on along the way the emitter's x points, settling.
static func drift(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 2.6
	emitter.explosiveness = 0.0
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.direction = Vector3.RIGHT
	emitter.spread = 18.0
	emitter.initial_velocity_min = 2.5
	emitter.initial_velocity_max = 4.5
	emitter.gravity = WIND + Vector3.DOWN * 1.2
	emitter.damping_min = 0.3
	emitter.damping_max = 0.6
	emitter.angle_max = 360.0
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.0
	emitter.scale_amount_curve = growth(0.8, 1.1)
	emitter.color_ramp = held(ArtPalette.DUST_CLOUD)


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


## Steam: a few big billows rising slowly, swelling and leaning off on the wind.
static func plume(emitter: CPUParticles3D) -> void:
	emitter.lifetime = 6.0
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.4
	emitter.direction = Vector3.UP
	emitter.spread = 12.0
	emitter.gravity = WIND * 1.4 + Vector3.UP * 0.1
	emitter.damping_min = 0.25
	emitter.damping_max = 0.45
	emitter.angle_max = 360.0
	emitter.scale_amount_min = 0.7
	emitter.scale_amount_curve = growth(0.45, 2.2)
	emitter.color_ramp = held(Color.WHITE)


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
	emitter.color_ramp = held(ArtPalette.BUBBLE)


## The funnel's smoke, dark billows rolling off on the wind.
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
	emitter.angle_max = 360.0
	emitter.scale_amount_min = 1.0
	emitter.scale_amount_max = 1.8
	emitter.scale_amount_curve = growth(0.9, 3.0)
	emitter.color_ramp = held(Color(Color.WHITE, SMOKE_OPACITY))
	if emitter.one_shot:
		# A belch: a ragged cough of it, not one ball.
		emitter.explosiveness = 0.5
		emitter.emission_sphere_radius = 0.8
		emitter.spread = 28.0
		emitter.initial_velocity_min = 3.0
		emitter.scale_amount_min = 0.7


## An emitter of [param grains] grains of [param mesh], in the world, idle: one
## burst at a time if [param one_shot], else a stream while it is told to go.
static func emitter(grains: int, mesh: Mesh, one_shot: bool) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.amount = grains
	emitter.mesh = mesh
	emitter.one_shot = one_shot
	emitter.explosiveness = 0.9 if one_shot else 0.0
	emitter.randomness = 0.5
	emitter.local_coords = false
	emitter.emitting = false
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return emitter


## Which way and how hard the wind pushes what flies, in m/s².
static func downwind() -> Vector3:
	return Vector3(WIND.x, 0.0, WIND.z).normalized() * SPRAY_WIND


## Grains [param size] across, facing the eye, drawn over the sea, and gone within
## [param clear] metres of the eye; [param glow] times as bright as their colour.
static func billboard(
	size: float, texture: Texture2D, clear: float = CLEAR, glow: float = 1.0
) -> QuadMesh:
	return _quad(Vector2.ONE * size, _material(GRAIN_SHADER, texture, clear, glow))


## Streaks of white water as big as a square [param side] across, [param aspect]
## times as long as they are wide, along their flight.
static func streaks(
	side: float, aspect: float, picture: Texture2D, clear: float = CLEAR
) -> QuadMesh:
	var size := Vector2(side / sqrt(aspect), side * sqrt(aspect))
	return _quad(size, _material(STREAK_SHADER, picture, clear, WHITE_GLOW))


## Lace foam lying flat in its emitter's x–z plane, [param size] along x and z, each
## grain its own piece of the sheet [param picture] (lace()), as much of it as
## [param sheet] metres of it hold.
static func laces(size: Vector2, picture: Texture2D, sheet: float = LACE_SHEET) -> QuadMesh:
	var material := _material(LACE_SHADER, picture, SPECK_CLEAR, LACE_GLOW)
	material.set_shader_parameter(&"window", size / sheet)
	var quad := _quad(size, material)
	quad.orientation = PlaneMesh.FACE_Y
	return quad


## Billows [param size] across, lit [param lit] on their sunward bumps and
## [param shaded] on the rest, [param glow] times as bright.
static func billows(
	size: float, picture: Texture2D, lit: Color, shaded: Color, glow: float, clear: float
) -> QuadMesh:
	var material := _material(BILLOW_SHADER, picture, clear, glow)
	material.set_shader_parameter(&"lit", lit)
	material.set_shader_parameter(&"shade", shaded)
	return _quad(Vector2.ONE * size, material)


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


## A soft puff, white at its heart and clear at its edge.
static func puff() -> GradientTexture2D:
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	falloff.colors = PackedColorArray(
		[Color.WHITE, Color(1.0, 1.0, 1.0, 0.8), Color(1.0, 1.0, 1.0, 0.0)]
	)
	return _radial(falloff)


## The picture of a shape of [param size] pixels: the union of [param blobs], each
## the middle and radius of a disc, in pixels. Alpha holds the distance to its edge
## (FIELD_SPREAD); red and green, which way the blob nearest its surface faces there,
## right and up, from -1 at 0 to 1 at 1.
static func shape(size: Vector2i, blobs: Array[Vector3]) -> ImageTexture:
	var picture := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var at := Vector2(x + 0.5, y + 0.5)
			var inside := -INF
			var bump := Vector2.ZERO
			for disc: Vector3 in blobs:
				var off := at - Vector2(disc.x, disc.y)
				if disc.z - off.length() > inside:
					inside = disc.z - off.length()
					bump = (off / disc.z).limit_length(1.0) * Vector2(1.0, -1.0)
			picture.set_pixel(
				x,
				y,
				Color(
					bump.x * 0.5 + 0.5,
					bump.y * 0.5 + 0.5,
					1.0,
					clampf(0.5 + inside / FIELD_SPREAD * 0.5, 0.0, 1.0)
				)
			)
	picture.generate_mipmaps()
	return ImageTexture.create_from_image(picture)


## The picture of a streak of spray, its distance field in alpha, as shape() holds
## it: the head and the tail tapering from it, a cone capped round at both ends.
static func streak() -> ImageTexture:
	var size := STREAK_SIZE
	var head := Vector2(STREAK_HEAD.x, STREAK_HEAD.y)
	var tip := Vector2(STREAK_TIP.x, STREAK_TIP.y)
	var picture := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var at := Vector2(x + 0.5, y + 0.5)
			var along := clampf(
				(at - head).dot(tip - head) / head.distance_squared_to(tip), 0.0, 1.0
			)
			var radius := lerpf(STREAK_HEAD.z, STREAK_TIP.z, along)
			var inside := radius - at.distance_to(head.lerp(tip, along))
			picture.set_pixel(
				x, y, Color(0.5, 0.5, 1.0, clampf(0.5 + inside / FIELD_SPREAD * 0.5, 0.0, 1.0))
			)
	picture.generate_mipmaps()
	return ImageTexture.create_from_image(picture)


## The sheet of lace foam a grain shows a piece of (fx_lace.gdshader), its cells
## drawn out [param drawn] times along its height — water streaming that way pulls
## its threads out along its flow. Alpha holds the threads' distance field
## (LACE_SPREAD); red, the broad noise a grain's ragged outline follows. Built once
## for each [param drawn].
static func lace(drawn: float = 1.0) -> ImageTexture:
	if _laces.has(drawn):
		return _laces[drawn]
	var rng := RandomNumberGenerator.new()
	rng.seed = LACE_SEED
	var size := LACE_SIZE
	# Laid out on a sheet [param drawn] times shorter, then drawn out to its height.
	var laid := Vector2(size.x, size.y / drawn)
	var grid := Vector2i(LACE_GRID, maxi(roundi(LACE_GRID / drawn), 2))
	var cell := laid / Vector2(grid)
	# One point a cell, anywhere in it but its very rim.
	var points := PackedVector2Array()
	for row in grid.y:
		for column in grid.x:
			var jitter := Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9))
			points.append((Vector2(column, row) + jitter) * cell)
	var outline := _noise(rng)
	var swell := _noise(rng)
	var picture := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var at := Vector2(x + 0.5, (y + 0.5) / drawn)
			var home := Vector2i(floori(at.x / cell.x), floori(at.y / cell.y))
			var nearest := INF
			var next := INF
			for row in range(-2, 3):
				for column in range(-2, 3):
					var over := home + Vector2i(column, row)
					var wrapped := Vector2i(posmod(over.x, grid.x), posmod(over.y, grid.y))
					var shift := Vector2(over - wrapped) * cell
					var gap := at.distance_to(points[wrapped.y * grid.x + wrapped.x] + shift)
					if gap < nearest:
						next = nearest
						nearest = gap
					elif gap < next:
						next = gap
			var uv := at / laid
			var thread := lerpf(LACE_THREAD.x, LACE_THREAD.y, _sample(swell, uv))
			# A thread runs where two cells meet: half their difference is how far off it.
			var inside := thread - (next - nearest) * 0.5
			picture.set_pixel(
				x,
				y,
				Color(
					_sample(outline, uv),
					0.5,
					1.0,
					clampf(0.5 + inside / LACE_SPREAD * 0.5, 0.0, 1.0)
				)
			)
	picture.generate_mipmaps()
	var sheet := ImageTexture.create_from_image(picture)
	_laces[drawn] = sheet
	return sheet


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


## [param colour] at full almost from a grain's start to near its end: a shaped
## grain shrinks or wears away rather than thinning to a film.
static func held(colour: Color) -> Gradient:
	var held := Gradient.new()
	held.set_color(0, Color(colour, 0.0))
	held.set_color(1, Color(colour, 0.0))
	held.add_point(0.04, colour)
	held.add_point(0.85, colour)
	return held


static func _material(
	shader: Shader, picture: Texture2D, clear: float, glow: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"grain", picture)
	# Nothing an effect draws stands in the eye's face: it fades out as it nears.
	material.set_shader_parameter(&"clear_from", clear * 0.3)
	material.set_shader_parameter(&"clear_to", clear)
	material.set_shader_parameter(&"glow", glow)
	material.render_priority = OVER_THE_SEA
	return material


static func _quad(size: Vector2, material: ShaderMaterial) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	return quad


## A broad noise that tiles: LACE_NOISE cells a side of [param rng]'s values, 0…1.
static func _noise(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for index in LACE_NOISE * LACE_NOISE:
		values.append(rng.randf())
	return values


## [param noise] (_noise) at [param uv], 0…1 either way, eased between its cells and
## wrapping round.
static func _sample(noise: PackedFloat32Array, uv: Vector2) -> float:
	var at := uv * LACE_NOISE - Vector2(0.5, 0.5)
	var corner := Vector2i(floori(at.x), floori(at.y))
	var part := at - Vector2(corner)
	part = part * part * (Vector2(3.0, 3.0) - part * 2.0)
	var value := func(column: int, row: int) -> float:
		return noise[posmod(row, LACE_NOISE) * LACE_NOISE + posmod(column, LACE_NOISE)]
	var low := lerpf(value.call(corner.x, corner.y), value.call(corner.x + 1, corner.y), part.x)
	var high := lerpf(
		value.call(corner.x, corner.y + 1), value.call(corner.x + 1, corner.y + 1), part.x
	)
	return lerpf(low, high, part.y)


static func _radial(falloff: Gradient) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.gradient = falloff
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
