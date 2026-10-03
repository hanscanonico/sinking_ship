class_name ShipLamp
extends Node3D
## A room's practical lamp (SH14b), hung at the room's lamp marker. It swings as a
## damped pendulum toward the world's down, so a list leaves it plumb and a lurch
## sets it rocking, and it flickers out as the room floods: the sea is the world
## plane y = 0 (D7), so the room's floor and the lamp are wet exactly when their
## drawn world height is below zero. It reads only where the view has put the ship
## — presentation, never a rule (D12). Hung from a deck that has given way, it falls
## with it and goes out once the deck lies wrecked (ShipArt).

## From the ceiling to the middle of the globe, in metres.
const CORD := 0.3
const GLOBE_RADIUS := 0.09
const RANGE := 4.6
const ENERGY := 1.5
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

## False once the lamp is wrecked: it stays out whatever the water does.
var burning := true

var _floor: Vector3
var _hang := Vector3.DOWN
var _swing := Vector3.ZERO
var _clock := 0.0
var _phase := 0.0
var _light: OmniLight3D
var _glass: StandardMaterial3D


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


## Hangs the lamp from where it now stands, over [param floor_point] (ship space);
## [param phase] keeps lamps from flickering in step.
func setup(floor_point: Vector3, phase: float, glass: StandardMaterial3D, brass: Material) -> void:
	_floor = floor_point
	_phase = phase
	_glass = glass
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
	# Outdoor faces of the ship are lit by the sky alone, so no lamp shows through a wall.
	_light.light_cull_mask &= ~(1 << (ShipMesh.OUTDOOR_LAYER - 1))
	add_child(_light)


func _process(delta: float) -> void:
	var ship := get_parent_node_3d()
	if ship == null:
		return
	_clock += delta
	var down := (ship.global_basis.inverse() * Vector3.DOWN).normalized()
	_swing += ((down - _hang) * STIFFNESS - _swing * DAMPING) * delta
	_hang = (_hang + _swing * delta).normalized()
	basis = Basis(Quaternion(Vector3.DOWN, _hang))
	var lamp_height := (global_transform * Vector3(0.0, -CORD, 0.0)).y
	var level := glow(lamp_height, (ship.global_transform * _floor).y, _clock + _phase)
	if not burning:
		level = 0.0
	_light.light_energy = ENERGY * level
	_light.visible = level > 0.0
	_glass.emission_energy_multiplier = level


func _part(mesh: PrimitiveMesh, drop: float) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position.y = drop
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
