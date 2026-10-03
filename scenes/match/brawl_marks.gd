class_name BrawlMarks
extends Node3D
## The brawl's stances, drawn from two snapshots (D5): a glow round every charging
## body, brighter as the charge fills, and a fan on the deck over a bracing body's
## front arc — the arc its brace covers. Never on the seat whose eyes the view is
## in, as MatchView draws no body there (D14). Presentation only (D12): it never
## moves a body, and never reads a live PlayerState.

const GLOW_COLOUR := Color(1.0, 0.62, 0.15)
## The glow's opacity at the threshold and at a full charge.
const GLOW_ALPHA_FROM := 0.25
const GLOW_ALPHA_FULL := 0.7
const GLOW_GROWTH := 1.25
const STANCE_COLOUR := Color(0.35, 0.75, 1.0, 0.5)
## How far past the body's edge the fan reaches, in metres.
const STANCE_REACH := 0.55
const STANCE_SEGMENTS := 16
## Lift off the deck so the fan never fights the planks for depth.
const STANCE_LIFT := 0.03

var _driver: SimDriver
var _view: MatchView
var _schedule: SinkSchedule
var _threshold_ticks: int
var _full_ticks: int
var _marks: Array[Node3D] = []
var _glows: Array[MeshInstance3D] = []
var _glow_materials: Array[StandardMaterial3D] = []
var _stances: Array[MeshInstance3D] = []


func setup(driver: SimDriver, view: MatchView, sim: MatchSim) -> void:
	_driver = driver
	_view = view
	_schedule = sim.schedule
	var rules := sim.config.rules
	_threshold_ticks = Ticks.from_seconds(rules.charge_threshold)
	_full_ticks = Ticks.from_seconds(rules.charge_full)
	for mark: Node3D in _marks:
		mark.queue_free()
	_marks.clear()
	_glows.clear()
	_glow_materials.clear()
	_stances.clear()
	var fan := _fan(rules.body_radius + STANCE_REACH, deg_to_rad(rules.brace_arc_deg))
	for seat in sim.config.seats:
		_add_seat(seat, rules, fan)


func _process(_delta: float) -> void:
	if _driver == null or _driver.current.is_empty():
		return
	var current := _driver.current
	var seats_then: Array = _driver.previous["seats"]
	var seats_now: Array = current["seats"]
	var ship := _schedule.pose_at(current["tick"]).transform.basis
	for index in seats_now.size():
		var now: Dictionary = seats_now[index]
		var seat: int = now["seat"]
		var mark := _marks[seat]
		mark.visible = not now["out"] and seat != _view.eye_seat()
		if not mark.visible:
			continue
		var facing := lerp_angle(seats_then[index]["facing"], now["facing"], _driver.alpha)
		mark.global_transform = Transform3D(
			ship * Basis(Vector3.UP, -facing), _view.seat_world_position(seat)
		)
		var charged: bool = now["charge"] > 0
		_glows[seat].visible = charged
		if charged:
			var filled := clampf(
				float(now["charge"] - _threshold_ticks) / (_full_ticks - _threshold_ticks), 0.0, 1.0
			)
			_glow_materials[seat].albedo_color.a = lerpf(GLOW_ALPHA_FROM, GLOW_ALPHA_FULL, filled)
		_stances[seat].visible = now["bracing"]


func _add_seat(seat: int, rules: BrawlRules, fan: ArrayMesh) -> void:
	var mark := Node3D.new()
	mark.name = "Marks%d" % seat
	add_child(mark)
	_marks.append(mark)

	var shell := CapsuleMesh.new()
	shell.radius = rules.body_radius * GLOW_GROWTH
	shell.height = rules.body_height * GLOW_GROWTH
	var glow_material := _unshaded(GLOW_COLOUR)
	shell.material = glow_material
	var glow := MeshInstance3D.new()
	glow.mesh = shell
	glow.position = Vector3(0.0, rules.body_height * 0.5, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(glow)
	_glows.append(glow)
	_glow_materials.append(glow_material)

	var stance := MeshInstance3D.new()
	stance.mesh = fan
	stance.material_override = _unshaded(STANCE_COLOUR)
	stance.position = Vector3(0.0, STANCE_LIFT, 0.0)
	stance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.add_child(stance)
	_stances.append(stance)


## A flat fan of [param radius] spanning [param half_angle] either side of +x,
## the body's facing in its own frame.
static func _fan(radius: float, half_angle: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for index in STANCE_SEGMENTS:
		var from := -half_angle + 2.0 * half_angle * index / STANCE_SEGMENTS
		var to := -half_angle + 2.0 * half_angle * (index + 1) / STANCE_SEGMENTS
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(cos(to), 0.0, sin(to)) * radius)
		vertices.append(Vector3(cos(from), 0.0, sin(from)) * radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
