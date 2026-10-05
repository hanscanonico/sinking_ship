class_name ShipLamp
extends Node3D
## A room's practical lamp (SH14b), hung at the room's lamp marker. It swings as a
## damped pendulum toward the world's down, so a list leaves it plumb and a lurch
## sets it rocking, and it flickers out as the room floods: the sea is the world
## plane y = 0 (D7), so the room's floor and the lamp are wet exactly when their
## drawn world height is below zero. It reads only where the view has put the ship
## — presentation, never a rule (D12). Hung from a deck that has given way, it falls
## with it and goes out once the deck lies wrecked (ShipArt). Its globe glows
## whoever looks, but it lights its room only while ShipArt wants it lit — while the
## eye that draws the frame stands near it on its storey (relevant), in sight of its
## room or within the graphics preset's limit (LampSight) — fading in and out, so a
## frame pays only for the lamps it can see and none shines up or down through a
## deck. A hold's cargo lamp hangs lower under a tin shade, brighter close by and
## fading sooner, so it throws a pool of light on the floor under it; a furnace's
## fire is set in a wall, unswung, and throws its light out of the wall alone, never
## through it, wavering as a fire does. Each is one light, so a mesh still meets few
## enough.

## What the lamp is: a room's pendant globe, a hold's shaded cargo lamp, or a fire.
enum Kind { PENDANT, CARGO, FIRE }

## From the ceiling to the middle of the globe, in metres: a pendant's, and a cargo
## lamp's.
const CORD := 0.3
const CARGO_CORD := 0.5
const GLOBE_RADIUS := 0.09
const RANGE := 4.6
const ENERGY := 1.5
## A cargo lamp's light: how bright, and how fast it fades with distance.
const CARGO_ENERGY := 2.6
const CARGO_ATTENUATION := 2.2
## A fire's light out of its wall: how far, how wide and how bright; and how much it
## wavers, how often.
const FIRE_RANGE := 3.2
const FIRE_ANGLE := 50.0
const FIRE_ENERGY := 3.5
const FIRE_WAVER := 0.3
const FIRE_RATE := 7.0
## A fire's glowing mouth (width, height), standing this far proud of its wall.
const MOUTH := Vector2(0.42, 0.26)
const MOUTH_PROUD := 0.045
## How hard the cord pulls back toward plumb, and how fast a swing dies, per second.
const STIFFNESS := 26.0
const DAMPING := 1.4
## How many times a second a failing lamp may change its mind.
const FLICKER_RATE := 9.0
## The brightness a flicker drops to, rather than out.
const BROWNOUT := 0.12
## The share of moments a failing lamp is dimmed: with the sea at its room's floor,
## and with the sea at the lamp itself.
const FAILING_FROM := 0.15
const FAILING_TO := 0.8
## How far across the ship plane from its room an eye still has the lamp lit, and
## how far above its ceiling or below its floor: a stair's head, never the deck over.
const REACH := 8.0
const STOREY_MARGIN := 0.8
## Seconds a lamp takes to come up or go down as the eye comes and goes.
const FADE := 0.3

## False once the lamp is wrecked: it stays out whatever the water does.
var burning := true
## Whether the lamp lights its room whatever eye draws the frame: the observer's
## cut-away, which looks down into every room at once.
var everywhere := false
## Whether the eye that draws the frame wants the lamp lighting its room (ShipArt
## chooses): it fades up toward lit while it does, and down while it does not.
var wanted := true

var _kind := Kind.PENDANT
## From the lamp's node down to where it burns: what goes under the sea.
var _drop := CORD
## The middle of its room's floor, ship space.
var _floor: Vector3
## How far the lamp has faded up (0…1) toward lighting its room.
var _presence := 1.0
var _hang := Vector3.DOWN
var _swing := Vector3.ZERO
var _clock := 0.0
var _phase := 0.0
var _light: OmniLight3D
## A fire's light out of its wall: null for a lamp.
var _spot: SpotLight3D
var _glass: StandardMaterial3D
## The glow its glass was last given, and the share of its full light its light was,
## so each is set only as it changes.
var _shown := -1.0
var _energy := -1.0


## How bright a lamp burns, 0…1: [param lamp_height] and [param floor_height] are
## the world heights of the lamp and of its room's floor under it, and
## [param clock] a running time in seconds. Lit while the floor is dry, out once
## the lamp is under, and in between flickering — dimmed more of the time the
## nearer the water climbs to it.
static func glow(lamp_height: float, floor_height: float, clock: float) -> float:
	if lamp_height <= 0.0:
		return 0.0
	if floor_height >= 0.0:
		return 1.0
	var risen := clampf(-floor_height / maxf(lamp_height - floor_height, 0.01), 0.0, 1.0)
	var failing := lerpf(FAILING_FROM, FAILING_TO, risen)
	var moment := floorf(clock * FLICKER_RATE)
	var roll := fposmod(sin(moment * 12.9898 + 78.233) * 43758.5453, 1.0)
	return BROWNOUT if roll < failing else 1.0


## Whether a lamp lights [param room] (its box, ship space) for an eye at
## [param eye] (ship space): never once it is wrecked ([param burning] false),
## else while the eye stands within REACH of the room across the ship plane and on
## its storey — up to STOREY_MARGIN over its ceiling or under its floor. A doorway's
## neighbour is lit; a room a deck away is not, whatever lies between.
static func relevant(eye: Vector3, room: AABB, burning: bool) -> bool:
	if not burning:
		return false
	var nearest := eye.clamp(room.position, room.end)
	var across := Vector2(eye.x - nearest.x, eye.z - nearest.z).length()
	return across <= REACH and absf(eye.y - nearest.y) <= STOREY_MARGIN


## How bright a fire burns at [param clock] seconds, 0…1 of its full light: it
## wavers by up to FIRE_WAVER, changing its mind FIRE_RATE times a second.
static func flame(clock: float) -> float:
	var moment := floorf(clock * FIRE_RATE)
	var roll := fposmod(sin(moment * 78.233 + 12.9898) * 43758.5453, 1.0)
	return 1.0 - FIRE_WAVER * roll


## Fades [param material] out near the eye, screen-door, as the rooms' furnishings
## over head height do (RoomDressing.NEAR_FADE): a lamp hangs where a jumping head
## rises.
static func fade_near(material: BaseMaterial3D) -> void:
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	material.distance_fade_min_distance = RoomDressing.NEAR_FADE.x
	material.distance_fade_max_distance = RoomDressing.NEAR_FADE.y


## Hangs the lamp of [param kind] from where it now stands in [param room] (its box,
## ship space) — a fire burns there instead, facing [param facing] out of its wall;
## [param phase] keeps lamps from flickering in step.
func setup(
	room: AABB,
	phase: float,
	glass: StandardMaterial3D,
	brass: Material,
	kind := Kind.PENDANT,
	facing := Vector3.DOWN
) -> void:
	var middle := room.get_center()
	_floor = Vector3(middle.x, room.position.y, middle.z)
	_phase = phase
	_glass = glass
	_kind = kind
	if kind == Kind.FIRE:
		_drop = 0.0
		_burn(facing)
		return
	if kind == Kind.CARGO:
		_drop = CARGO_CORD
		_hang_cargo(brass)
		return
	var cord := CylinderMesh.new()
	cord.top_radius = 0.008
	cord.bottom_radius = 0.008
	cord.height = CORD - GLOBE_RADIUS
	cord.radial_segments = 4
	cord.rings = 1
	cord.material = brass
	_part(cord, -(CORD - GLOBE_RADIUS) * 0.5)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.035
	cap.bottom_radius = 0.075
	cap.height = 0.06
	cap.radial_segments = 10
	cap.rings = 1
	cap.material = brass
	_part(cap, -CORD + GLOBE_RADIUS * 0.6)
	var globe := SphereMesh.new()
	globe.radius = GLOBE_RADIUS
	globe.height = GLOBE_RADIUS * 2.0
	globe.radial_segments = 12
	globe.rings = 6
	globe.material = glass
	_part(globe, -CORD)
	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, -CORD - GLOBE_RADIUS, 0.0)
	_light.light_color = ArtPalette.LAMP_LIGHT
	_light.light_energy = ENERGY
	_light.light_specular = 0.0
	_light.omni_range = RANGE
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_unlit_outdoors(_light)
	add_child(_light)


## A cargo lamp: a brass cord down to a tin shade over its globe and a wire cage
## round it, its light bright under it and soon fading.
func _hang_cargo(brass: Material) -> void:
	var cord := CylinderMesh.new()
	cord.top_radius = 0.008
	cord.bottom_radius = 0.008
	cord.height = CARGO_CORD - GLOBE_RADIUS
	cord.radial_segments = 4
	cord.rings = 1
	cord.material = brass
	_part(cord, -(CARGO_CORD - GLOBE_RADIUS) * 0.5)
	var tin := StandardMaterial3D.new()
	tin.albedo_color = ArtPalette.LAMP_SHADE
	tin.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	tin.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	tin.cull_mode = BaseMaterial3D.CULL_DISABLED
	fade_near(tin)
	var shade := CylinderMesh.new()
	shade.top_radius = 0.05
	shade.bottom_radius = 0.2
	shade.height = 0.12
	shade.radial_segments = 14
	shade.rings = 1
	shade.cap_top = false
	shade.cap_bottom = false
	shade.material = tin
	_part(shade, -CARGO_CORD + GLOBE_RADIUS * 0.4)
	var globe := SphereMesh.new()
	globe.radius = GLOBE_RADIUS
	globe.height = GLOBE_RADIUS * 2.0
	globe.radial_segments = 12
	globe.rings = 6
	globe.material = _glass
	_part(globe, -CARGO_CORD)
	var cage := CylinderMesh.new()
	cage.top_radius = GLOBE_RADIUS + 0.015
	cage.bottom_radius = GLOBE_RADIUS + 0.015
	cage.height = 0.012
	cage.radial_segments = 10
	cage.rings = 1
	cage.material = brass
	_part(cage, -CARGO_CORD - GLOBE_RADIUS * 0.4)
	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, -CARGO_CORD - GLOBE_RADIUS, 0.0)
	_light.light_color = ArtPalette.LAMP_LIGHT
	_light.light_specular = 0.0
	_light.omni_range = RANGE
	_light.omni_attenuation = CARGO_ATTENUATION
	_unlit_outdoors(_light)
	add_child(_light)


## A fire: its glowing mouth proud of its wall and its light thrown out along
## [param facing], which the lamp turns to face; a spot no wider than a half-space
## leaves the wall behind it, and whatever stands beyond, dark.
func _burn(facing: Vector3) -> void:
	basis = Basis.looking_at(facing)
	var mouth := BoxMesh.new()
	mouth.size = Vector3(MOUTH.x, MOUTH.y, 0.01)
	mouth.material = _glass
	var part := _part(mouth, 0.0)
	part.position.z = -MOUTH_PROUD
	_spot = SpotLight3D.new()
	_spot.position = Vector3(0.0, 0.0, -MOUTH_PROUD - 0.05)
	_spot.light_color = ArtPalette.FIRE_LIGHT
	_spot.light_specular = 0.0
	_spot.spot_range = FIRE_RANGE
	_spot.spot_angle = FIRE_ANGLE
	_spot.spot_angle_attenuation = 0.8
	_spot.spot_attenuation = 1.0
	_unlit_outdoors(_spot)
	add_child(_spot)


## Outdoor faces of the ship are lit by the sky alone, so no lamp shows through a wall.
static func _unlit_outdoors(light: Light3D) -> void:
	light.light_cull_mask &= ~(1 << (ShipMesh.OUTDOOR_LAYER - 1))


func _process(delta: float) -> void:
	var ship := get_parent_node_3d()
	if ship == null:
		return
	_clock += delta
	if _kind != Kind.FIRE:
		var down := (ship.global_basis.inverse() * Vector3.DOWN).normalized()
		_swing += ((down - _hang) * STIFFNESS - _swing * DAMPING) * delta
		_hang = (_hang + _swing * delta).normalized()
		basis = Basis(Quaternion(Vector3.DOWN, _hang))
	var lamp_height := (global_transform * Vector3(0.0, -_drop, 0.0)).y
	var level := glow(lamp_height, (ship.global_transform * _floor).y, _clock + _phase)
	if _kind == Kind.FIRE:
		level *= flame(_clock + _phase)
	if not burning:
		level = 0.0
	var lit := burning and (everywhere or wanted)
	_presence = move_toward(_presence, 1.0 if lit else 0.0, delta / FADE)
	var energy := level * smoothstep(0.0, 1.0, _presence)
	if energy != _energy:
		_energy = energy
		if _light != null:
			_light.light_energy = (CARGO_ENERGY if _kind == Kind.CARGO else ENERGY) * energy
			_light.visible = energy > 0.0
		if _spot != null:
			_spot.light_energy = FIRE_ENERGY * energy
			_spot.visible = energy > 0.0
	if level != _shown:
		_shown = level
		_glass.emission_energy_multiplier = level


func _part(mesh: PrimitiveMesh, drop: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position.y = drop
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part
