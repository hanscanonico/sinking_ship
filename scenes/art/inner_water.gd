class_name InnerWater
extends Node3D
## The water inside her (§5b.1, D7), drawn as the sinking has it at the moment drawn:
## each cell's at its own level, level with the world however she leans and drawn only
## inside its cell (CellSurface) — in the sea's colours, lit as the room it stands in is
## (inner_water.gdshader) — the watertight doors the ship slides shut at the hit, water
## pouring through an opening wherever one side's water stands over its bottom and
## higher than the other side's, falling along the world's down (spill.gdshader),
## boiling into froth where it lands, and air blown out of an opening as the water
## reaches its top, bursting the surface in bubbles there (froth.gdshader) — and, from
## SH29, a pocket's air: small bubbles rising to the water over a pocket where it leaks,
## a burst at the opening a pocket's air goes out by as it goes free, and the water under
## a pocket glowing faintly with the sea's light coming up through it — lighting the
## pocket's ceiling round an eye inside it, so a swimmer surfacing there sees air under
## a ceiling over water rather than a black room; from SH31, what is shut until it fails
## pours once the pose has it given way — a thin trickle while it only leaks — and a
## watertight door that burst has no leaf left.
## Presentation only (D5): it reads the poses it is handed and the openings water can
## pass, and moves no water. It lives in ship space, under the drawn ship.

## How far under its highest corner a cell's water is drawn — not in a full cell, which
## has no surface — and how deep over its lowest corner its openings are drawn pouring.
const SHOWS := 0.02
## The least depth over its lowest corner a cell's water is ever drawn at: under it, a
## sheet would fight a dry floor's planks.
const CLEAR_OF_FLOOR := 0.005
## The least difference across an opening that is drawn pouring, in metres, and the
## difference at which a pour is a solid sheet — where the pose has no flow through it.
const POURS := 0.03
const FLOOD := 1.0
## The water through an opening, in m³ a second per metre of its width, at which its pour
## is a solid sheet (ShipPose.flows); and the least strength a pour is drawn at.
const FLOW_FULL := 2.0
const THINNEST := 0.15
## How far into the lower side a pour hangs off its opening, so its sheet is seen
## clear of the wall it pours through: a wall's half thickness and a little, and for an
## opening in her shell, the shell and the room's lining inside it as the art draws them.
const OFF_WALL := 0.12
const OFF_SHELL := 0.4
## The furthest a pour is thrown out from its opening as it falls, in metres.
const MOST_THROW := 1.6
## How much of its width a leaking opening's trickle is drawn.
const TRICKLE := 0.12
## A watertight door's leaf: how thick, of the doorway's wall.
const LEAF := 0.06
## The air a cell blows out through an opening as its water reaches the top: a burst
## of bubbles this wide on the water there, breaking for so many seconds, so many at
## once at most, standing this far into the side it comes out of.
const BURST := 1.4
const BURST_SECONDS := 2.2
const BURSTS := 4
const BURST_IN := 0.4
## A pocket leaking its air (SinkAir): bubbles popping on the water over its cell's top,
## this wide, as many pockets at once at most.
## A pocket gone with at least VENTS metres of air over its water went free — blown out,
## a burst VENT_BURST wide — rather than leaking or being squeezed away.
const LEAK := 1.2
const LEAKS := 6
const VENTS := 0.1
const VENT_BURST := 2.4
## The water under a pocket: how much of the sea's shallow colour it gives off, and the
## light it casts up into the pocket round an eye there — its colour, energy, and reach
## as a share of the cell's longer side, within POCKET_REACH.
const POCKET_GLOW := 0.3
const POCKET_LIGHT := Color(0.42, 0.78, 0.82)
const POCKET_ENERGY := 0.65
const POCKET_SPAN := 0.8
const POCKET_REACH := Vector2(3.0, 8.0)
## The froth where a pour lands: how far out along its fall it spreads, at the least
## and at a full flood, and how much wider than the pour; and how far over the water it
## lies, so the water's own surface never hides it.
const LANDING := Vector2(0.5, 1.1)
const LANDING_WIDER := 0.4
const FROTH_LIFT := 0.015
## How far under both poses' heights an opening's middle may stand on the ship drawn
## between them, whose turn is slerped rather than lerped: far more than a tick's turn
## ever moves it. An opening dry by this much at both poses is dry the whole tick.
const TICK_SLACK := 0.05
## How fast a cell's water must climb her, in metres a second, to churn at its wildest
## (inflow); and the share of the way to the fresh inflow a sheet's churn moves each
## tick, so it swells as the water pours in and calms once it settles. Under INFLOW_CALM
## the churn is none at all, the water drawn as calm as it always was.
const INFLOW_FULL := 0.3
const INFLOW_EASE := 0.2
const INFLOW_CALM := 1e-3
## The sea's colours the water inside her takes.
const COLOURS: Array[StringName] = [&"deep_colour", &"shallow_colour", &"foam_colour"]
const WATER_SHADER := preload("res://scenes/art/inner_water.gdshader")
const SPILL_SHADER := preload("res://scenes/art/spill.gdshader")
const FROTH_SHADER := preload("res://scenes/art/froth.gdshader")

var _structure: ShipStructure
var _sea: ShaderMaterial
## The water's material every cell's surface takes a copy of. Each surface, pour and
## froth keeps its values in its own material, never in instance uniforms: the
## compatibility renderer holds those for about 256 drawn things at most, fewer than a
## ship of many cells and openings draws (the Titanic).
var _water: ShaderMaterial
## The bodies in water its rings are drawn round now (show_waders).
var _waders := PackedVector4Array()
var _boxes: Array[AABB] = []
## Per cell, its surface, or null for a cell whose water is not drawn; and the rest of
## a cell drawn in a stack of boxes (CellBoxes.stacked), each as [cell, box, surface].
var _surfaces: Array[MeshInstance3D] = []
var _stacks: Array = []
## The ship as drawn at the moment last shown — her rotation and place, the poses'
## between them — the world's up in her axes, and a basis that lays a sheet level with
## the world in her space.
var _ship := Transform3D.IDENTITY
var _up := Vector3.UP
var _level := Basis.IDENTITY
## Per watertight door the ship shuts, its leaf, by name, and the width it slides.
var _leaves := {}
var _leaf_widths := {}
## The openings water can pass, and a pour per opening, hidden while it does not —
## and a second across the first, for water falling through a hole in a deck, so it
## is seen from every side; none yet for one shut until it fails (_pour_for). Per
## opening, worked out once: its two sides' cells (-1 for the sea) and floors, its box,
## and whether water through it is drawn pouring and blowing air — never through the
## gash, a deck's gaps or a leak.
var _passages: Array[ShipOpening] = []
var _pours: Array[MeshInstance3D] = []
var _crossings: Array[MeshInstance3D] = []
## Per opening, the froth where its pour lands.
var _landings: Array[MeshInstance3D] = []
var _sides := PackedInt32Array()
var _floors := PackedFloat64Array()
var _spans: Array[AABB] = []
## Per opening, its middle, and half its box's diagonal and TICK_SLACK: however she
## leans, its bottom stands no further under its middle than that, nor its top over it
## (_find_wet); and its two sides' cells as _find_wet reads them, the sea's after hers.
var _centres := PackedVector3Array()
var _reaches := PackedFloat64Array()
var _slots := PackedInt32Array()
var _drawn := PackedByteArray()
## Per opening, 1 where it is shut until it fails (SinkSchedule.failing).
var _shut := PackedByteArray()
## The names of the openings the poses last shown had flows for (ShipPose.passages), and
## per opening where its flow lies among them, -1 for none.
var _flow_names: Array[StringName] = []
var _flow_at := PackedInt32Array()
## Per opening, the world levels of its two sides' water last drawn: a side reaching
## its top blows its air out.
var _last_heads: Array[Vector2] = []
## The openings whose pours may show between the two poses last shown, worked out once
## for that pair — once a tick — rather than every frame (_find_wet).
var _wet := PackedInt32Array()
var _wet_then: ShipPose
var _wet_now: ShipPose
## The bursts of air on the water: each one's froth, the cell it breaks the water of — -1
## for the sea — and
## the point in her it lies over, and its seconds gone, or a negative number while it is
## not bursting.
var _bursts: Array[MeshInstance3D] = []
var _burst_cells := PackedInt32Array()
var _burst_at := PackedVector3Array()
var _burst_ages := PackedFloat32Array()
var _next_burst := 0
## The pockets' leaks' froths; and per cell, how much air stood over its water when last
## drawn, -1 for none.
var _leaks: Array[MeshInstance3D] = []
var _airs := PackedFloat64Array()
## Per cell, the glow its water was last given; and the light cast up into the pocket
## an eye is in.
var _glows := PackedFloat32Array()
var _pocket_light: OmniLight3D
## Per cell, how hard its water churns as it climbs, 0…1, eased tick by tick; and the
## pose it was last worked out to.
var _inflows := PackedFloat64Array()
var _inflow_now: ShipPose
## Per cell, its water's world height as last drawn; a pour's two sides' (_show_pour).
var _levels := PackedFloat64Array()
var _heights := PackedFloat64Array([0.0, 0.0])


## Draws the water in [param structure], round [param rooms] where her cells poke out
## of her (CellBoxes), with [param sea]'s material, pouring through [param passages] — the
## openings water can pass after the hit — and through [param failing] once each has
## given way (SinkSchedule.failing), and its doors' leaves in [param paints]
## (ShipArt.paints), none without them.
func setup(
	structure: ShipStructure,
	rooms: Array[ShipRoom],
	passages: Array[ShipOpening],
	failing: Array[ShipOpening],
	sea: ShaderMaterial,
	paints: Dictionary
) -> void:
	for child: Node in get_children():
		child.queue_free()
	_structure = structure
	_sea = sea
	_water = ShaderMaterial.new()
	_water.shader = WATER_SHADER
	for colour: StringName in COLOURS:
		_water.set_shader_parameter(colour, sea.get_shader_parameter(colour))
	_boxes = CellBoxes.boxes(structure, rooms)
	_surfaces.clear()
	for cell in _boxes.size():
		var box := _boxes[cell]
		var under_sky := structure.cells[cell].kind == FloodCell.Kind.OPEN_WELL
		_surfaces.append(null if box.size == Vector3.ZERO else _surface(box, under_sky))
	_stacks.clear()
	for stack: Array in CellBoxes.stacked(structure, rooms):
		_stacks.append([stack[0], stack[1], _surface(stack[1], false)])
	_leaves.clear()
	_leaf_widths.clear()
	if not paints.is_empty():
		for opening: ShipOpening in structure.openings:
			if opening.shuts_at_hit:
				_leaf(opening, paints)
	_passages = passages.duplicate()
	_passages.append_array(failing)
	_shut.resize(_passages.size())
	_shut.fill(0)
	for index in range(passages.size(), _passages.size()):
		_shut[index] = 1
	_pours.clear()
	_crossings.clear()
	_landings.clear()
	_last_heads.clear()
	_sides.clear()
	_floors.clear()
	_spans.clear()
	_centres.clear()
	_reaches.clear()
	_slots.clear()
	_drawn.clear()
	_wet.clear()
	_wet_then = null
	_wet_now = null
	_flow_names = []
	_flow_at.clear()
	var unseen := [ShipOpening.Kind.GASH, ShipOpening.Kind.FLOOR_GAPS, ShipOpening.Kind.LEAK]
	for opening: ShipOpening in _passages:
		_pours.append(null)
		_crossings.append(null)
		_landings.append(null)
		if _shut[_pours.size() - 1] == 0:
			_pour_for(_pours.size() - 1)
		_last_heads.append(Vector2(-INF, -INF))
		for place: StringName in opening.joins:
			var cell := structure.cell_named(place)
			_sides.append(cell)
			_slots.append(_surfaces.size() if cell == -1 else cell)
			_floors.append(-INF if cell == -1 else structure.cells[cell].low.y)
		_spans.append(AABB(opening.centre - opening.size * 0.5, opening.size))
		_centres.append(opening.centre)
		_reaches.append(opening.size.length() * 0.5 + TICK_SLACK)
		_drawn.append(0 if opening.kind in unseen else 1)
	_bursts.clear()
	_burst_cells.clear()
	_burst_at.clear()
	_burst_ages.clear()
	for _burst in BURSTS:
		_bursts.append(_froth())
		_burst_cells.append(-1)
		_burst_at.append(Vector3.ZERO)
		_burst_ages.append(-1.0)
	_leaks.clear()
	for _leak in LEAKS:
		var leak := _froth()
		_param(leak, &"leaking", true)
		_leaks.append(leak)
	_airs.resize(structure.cells.size())
	_airs.fill(-1.0)
	_glows.resize(structure.cells.size())
	_glows.fill(0.0)
	_inflows.resize(structure.cells.size())
	_inflows.fill(0.0)
	_inflow_now = null
	_pocket_light = OmniLight3D.new()
	_pocket_light.light_color = POCKET_LIGHT
	_pocket_light.light_energy = POCKET_ENERGY
	_pocket_light.light_specular = 0.3
	_pocket_light.omni_attenuation = 1.0
	_pocket_light.shadow_enabled = false
	# Inside her only, as a room's lamps are (ShipLamp): never on her outdoor faces.
	_pocket_light.light_cull_mask &= ~(1 << (ShipMesh.OUTDOOR_LAYER - 1))
	_pocket_light.visible = false
	add_child(_pocket_light)
	set_process(false)


## Draws rings in every cell's water round [param waders], the bodies in water nearest
## the eye (MatchView.waders): each a world foot point on its water and how fast it moves.
func show_waders(waders: PackedVector4Array) -> void:
	if waders == _waders:
		return
	_waders = waders
	var padded := SeaAndSky.padded_waders(waders)
	for surface: MeshInstance3D in _surfaces:
		if surface != null:
			_show_waders_on(surface, padded, waders.size())
	for stack: Array in _stacks:
		_show_waders_on(stack[2], padded, waders.size())


static func _show_waders_on(
	surface: MeshInstance3D, padded: PackedVector4Array, count: int
) -> void:
	_param(surface, &"waders", padded)
	_param(surface, &"wader_count", count)


## Shows the water [param alpha] of the way from [param then] to [param now], on the
## ship drawn between them as MatchView draws her.
func show_water(then: ShipPose, now: ShipPose, alpha: float) -> void:
	if _structure == null:
		return
	_ship = then.transform.interpolate_with(now.transform, alpha)
	_level = _ship.basis.inverse().orthonormalized()
	_up = _level * Vector3.UP
	var to_ship := _ship.affine_inverse()
	_levels.resize(_surfaces.size())
	for cell in _surfaces.size():
		var level := lerpf(_level_of(then, cell), _level_of(now, cell), alpha)
		_levels[cell] = level
		if _surfaces[cell] != null:
			_show_surface(_surfaces[cell], _boxes[cell], level, to_ship)
	for stack: Array in _stacks:
		_show_surface(stack[2], stack[1], _levels[stack[0]], to_ship)
	if now != _inflow_now:
		_show_inflows(then, now)
	for door: StringName in _leaves:
		var shut: float = lerpf(
			then.doors_shut.get(door, 0.0), now.doors_shut.get(door, 0.0), alpha
		)
		var leaf: Node3D = _leaves[door]
		leaf.visible = shut > 0.0 and now.opened.get(door, 0) < 2
		if shut > 0.0:
			leaf.position = _slide(door) * (shut - 1.0)
	if then != _wet_then or now != _wet_now:
		_find_wet(then, now, _levels)
	for index in _wet:
		_show_pour(index, _levels, now)
	_show_pockets(now, _levels)
	for burst in BURSTS:
		if _burst_ages[burst] >= 0.0:
			var under := _burst_cells[burst]
			var level := (0.0 if under == -1 else _levels[under]) + FROTH_LIFT
			_bursts[burst].position = _at_height(_burst_at[burst], level)


## The openings whose pours may show between [param then] and [param now] — every frame
## draws only those — and those whose air may burst out between them. Each one shut
## until it fails is given its pour once the pose has it open; one never drawn pouring is
## left out, hidden as it always is. So is one that pours at no moment between the two
## poses, as their sides' water lerps between them — none over the lowest its bottom can
## stand, or never POURS higher on one side than the other, or neither side under the
## highest its top can stand — and whose top no cell's water crosses between them: it is
## hidden, as _show_pour would leave it every frame, and its air told of the water at
## world heights [param levels] now, as _show_pour would tell it (_blow) — only where a
## side's water may have reached its top since last told. Where an opening stands is
## bounded by its middle and its reach either way (_reaches).
func _find_wet(then: ShipPose, now: ShipPose, levels: PackedFloat64Array) -> void:
	_wet_then = then
	_wet_now = now
	_wet.clear()
	# Each cell's water at either pose, and now, the sea's 0 in the last slot (_slots).
	var sea := _surfaces.size()
	var at_then := PackedFloat64Array()
	var at_now := PackedFloat64Array()
	at_then.resize(sea + 1)
	at_now.resize(sea + 1)
	for cell in sea:
		at_then[cell] = _level_of(then, cell)
		at_now[cell] = _level_of(now, cell)
	var heads := levels.duplicate()
	heads.append(0.0)
	# A point's world height under each pose: its row of the turn, and the rise.
	var basis_then := then.transform.basis
	var basis_now := now.transform.basis
	var row_then := Vector3(basis_then.x.y, basis_then.y.y, basis_then.z.y)
	var row_now := Vector3(basis_now.x.y, basis_now.y.y, basis_now.z.y)
	var rise_then := then.transform.origin.y
	var rise_now := now.transform.origin.y
	for index in _passages.size():
		if _pours[index] == null:
			if now.opened.get(_passages[index].name, 0) == 0:
				continue
			_pour_for(index)
		if _drawn[index] == 0:
			continue
		var first := _slots[index * 2]
		var second := _slots[index * 2 + 1]
		var first_then := at_then[first]
		var first_now := at_now[first]
		var second_then := at_then[second]
		var second_now := at_now[second]
		var centre := _centres[index]
		var middle_then := row_then.dot(centre) + rise_then
		var middle_now := row_now.dot(centre) + rise_now
		var lowest := minf(middle_then, middle_now) - _reaches[index]
		var highest := maxf(middle_then, middle_now) + _reaches[index]
		var pours := (
			maxf(maxf(first_then, second_then), maxf(first_now, second_now)) > lowest + SHOWS
			and maxf(absf(first_then - second_then), absf(first_now - second_now)) >= POURS
			and minf(minf(first_then, second_then), minf(first_now, second_now)) < highest - POURS
		)
		var crosses := (
			(
				first != sea
				and maxf(first_then, first_now) >= lowest
				and minf(first_then, first_now) <= highest
			)
			or (
				second != sea
				and maxf(second_then, second_now) >= lowest
				and minf(second_then, second_now) <= highest
			)
		)
		if pours or crosses:
			_wet.append(index)
			continue
		if _pours[index].visible:
			_hide_pour(index)
		var last := _last_heads[index]
		var head_first := heads[first]
		var head_second := heads[second]
		if (
			is_finite(last.x)
			and (
				(first != sea and last.x < highest and head_first >= lowest)
				or (second != sea and last.y < highest and head_second >= lowest)
			)
		):
			var told := PackedFloat64Array([head_first, head_second])
			_blow(index, told, CellSurface.reach(_ship, _spans[index]).y, _passages[index])
		else:
			_last_heads[index] = Vector2(head_first, head_second)


## Hides opening [param index]'s pour, its froth and its crossing.
func _hide_pour(index: int) -> void:
	var pour := _pours[index]
	if pour.visible:
		pour.visible = false
		_landings[index].visible = false
	var crossing := _crossings[index]
	if crossing != null and crossing.visible:
		crossing.visible = false


## Makes opening [param index]'s pour, its crossing — through a floor or a porthole —
## and its landing: for what is shut until it fails, once it first does, so a ship of
## many panels and ports draws only those that have gone.
func _pour_for(index: int) -> void:
	var opening := _passages[index]
	_pours[index] = _pour()
	if opening.facing() == 1 or opening.kind == ShipOpening.Kind.PORTHOLE:
		_crossings[index] = _pour()
	_landings[index] = _froth()


## The world height cell [param cell]'s water stands at under [param pose]: its box's
## lowest corner's, dry, for a pose that keeps no cells.
func _level_of(pose: ShipPose, cell: int) -> float:
	if pose.levels.is_empty():
		return pose.world_height(_structure.cells[cell].low)
	return pose.levels[cell]


## [param point] in her moved along the world's up to world height [param height] on
## the ship as drawn.
func _at_height(point: Vector3, height: float) -> Vector3:
	return point + _up * (height - (_ship * point).y)


## A cell's surface over [param box] (CellSurface), told the box it is clipped to and
## whether it lies [param under_sky], as an open well's does, lit by the sun.
func _surface(box: AABB, under_sky: bool) -> MeshInstance3D:
	var surface := MeshInstance3D.new()
	surface.mesh = CellSurface.sheet()
	surface.material_override = _water.duplicate()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_param(surface, &"clip_low", box.position)
	_param(surface, &"clip_high", box.end)
	_param(surface, &"outdoor", 1.0 if under_sky else 0.0)
	surface.visible = false
	add_child(surface)
	return surface


## Shows [param surface], drawn in [param box], at world height [param level] while it
## stands between the box's lowest corner and its highest as she leans, else hides it.
func _show_surface(surface: MeshInstance3D, box: AABB, level: float, to_ship: Transform3D) -> void:
	var showing := shows(level, CellSurface.reach(_ship, box))
	if surface.visible != showing:
		surface.visible = showing
	if showing:
		surface.transform = CellSurface.placed(_ship, _level, box, level)
		_param(surface, &"world_to_ship", to_ship)


## Whether a cell's water standing at world height [param level] is drawn in a box whose
## lowest and highest corners stand at [param reach]'s x and y: from its first water
## (SinkTimeline.FIRST_WATER, when the transcript says the cell is flooding) — never so
## near its floor it would fight the planks — to SHOWS under its top.
static func shows(level: float, reach: Vector2) -> bool:
	var first := maxf(SinkTimeline.FIRST_WATER, CLEAR_OF_FLOOR)
	return level >= reach.x + first and level < reach.y - SHOWS


## How hard water climbing from [param prev_level] to [param level] in [param seconds]
## churns, 0…1: its climb a second as a share of [param full_rate], none while it stands
## or falls.
static func inflow(prev_level: float, level: float, seconds: float, full_rate: float) -> float:
	if seconds <= 0.0 or full_rate <= 0.0:
		return 0.0
	return clampf((level - prev_level) / seconds / full_rate, 0.0, 1.0)


## A sheet's churn a tick on from [param churn], INFLOW_EASE of the way to [param fresh]
## — none once under INFLOW_CALM.
static func eased_inflow(churn: float, fresh: float) -> float:
	var eased := lerpf(churn, fresh, INFLOW_EASE)
	return eased if eased >= INFLOW_CALM else 0.0


## Eases each cell's churn a tick on, from [param then] to [param now]: by how fast its
## water climbed her — over her cell's middle, so water standing still while she goes
## down churns as it pours in — and tells its sheets.
func _show_inflows(then: ShipPose, now: ShipPose) -> void:
	_inflow_now = now
	for cell in _inflows.size():
		var middle := _structure.cells[cell].low.lerp(_structure.cells[cell].high, 0.5)
		var was := _level_of(then, cell) - then.world_height(middle)
		var is_now := _level_of(now, cell) - now.world_height(middle)
		var fresh := inflow(was, is_now, Ticks.SECONDS_PER_TICK, INFLOW_FULL)
		var churn := eased_inflow(_inflows[cell], fresh)
		if churn == _inflows[cell]:
			continue
		_inflows[cell] = churn
		if _surfaces[cell] != null:
			_param(_surfaces[cell], &"inflow", churn)
		for stack: Array in _stacks:
			if stack[0] == cell:
				_param(stack[2], &"inflow", churn)


## Sets [param drawn]'s own material's [param parameter] to [param value].
static func _param(drawn: MeshInstance3D, parameter: StringName, value: Variant) -> void:
	(drawn.material_override as ShaderMaterial).set_shader_parameter(parameter, value)


## [param door]'s leaf: a steel plate in the doorway's wall, built shut, slid back into
## the wall beside it by however far it stands open.
func _leaf(door: ShipOpening, paints: Dictionary) -> void:
	var axis := door.facing()
	var along := 2 if axis == 0 else 0
	var width: float = door.size[along]
	var plan := Rect2()
	if axis == 0:
		plan = Rect2(door.centre.x - LEAF * 0.5, door.centre.z - width * 0.5, LEAF, width)
	else:
		plan = Rect2(door.centre.x - width * 0.5, door.centre.z - LEAF * 0.5, width, LEAF)
	var bottom := door.centre.y - door.size.y * 0.5
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return false, no_rooms)
	mesh.box(plan, bottom, bottom + door.size.y, ShipPaints.bulkhead)
	# A dogged handle and the rubber seal round its edge, the art's dark.
	var handle := Vector3(door.centre.x, bottom + 1.0, door.centre.z)
	handle[along] += width * 0.3
	for side: float in [-1.0, 1.0]:
		var at := handle
		at[axis] += side * (LEAF * 0.5 + 0.02)
		mesh.turned_box(Transform3D(Basis.IDENTITY, at), Vector3(0.05, 0.05, 0.05), ShipPaints.dark)
	var leaf := Node3D.new()
	leaf.name = String(door.name)
	add_child(leaf)
	mesh.commit(leaf, paints)
	leaf.visible = false
	_leaves[door.name] = leaf
	var slide := Vector3.ZERO
	slide[along] = width
	_leaf_widths[door.name] = slide


## How far [param door]'s leaf slides from shut to open, along its doorway.
func _slide(door: StringName) -> Vector3:
	return _leaf_widths[door]


## A pour's sheet: upright, a unit square cut across its fall so it can arc.
func _pour() -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = SPILL_SHADER
	material.set_shader_parameter(&"water_colour", _sea.get_shader_parameter(&"shallow_colour"))
	material.set_shader_parameter(&"foam_colour", _sea.get_shader_parameter(&"foam_colour"))
	# Over the water it pours into, whichever is nearer the eye.
	material.render_priority = 1
	var pour := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.orientation = PlaneMesh.FACE_Z
	sheet.size = Vector2.ONE
	sheet.subdivide_depth = 10
	pour.mesh = sheet
	pour.material_override = material
	pour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pour.visible = false
	add_child(pour)
	return pour


## Shows the pour through passage [param index], the cells' water at world heights
## [param levels] and the sea at 0, under [param pose]: a sheet from where the water
## leaves the higher side to where it meets the lower, or the floor there, falling along
## the world's down; and air blown out of the side whose water has just reached the
## opening's top.
func _show_pour(index: int, levels: PackedFloat64Array, pose: ShipPose) -> void:
	var opening := _passages[index]
	var first := _sides[index * 2]
	var second := _sides[index * 2 + 1]
	_heights[0] = 0.0 if first == -1 else levels[first]
	_heights[1] = 0.0 if second == -1 else levels[second]
	var span := CellSurface.reach(_ship, _spans[index])
	var bottom := span.x
	var top := span.y
	if _drawn[index] == 1:
		_blow(index, _heights, top, opening)
	var pour := _pours[index]
	var crossing := _crossings[index]
	var landing := _landings[index]
	if _drawn[index] == 0 or maxf(_heights[0], _heights[1]) <= bottom + SHOWS:
		# Dry, or never drawn pouring: nothing to do but keep it hidden.
		_hide_pour(index)
		return
	pour.visible = false
	landing.visible = false
	if crossing != null:
		crossing.visible = false
	var axis := opening.facing()
	var open := 1.0 - float(pose.doors_shut.get(opening.name, 0.0))
	var failed: int = pose.opened.get(opening.name, 0)
	if failed == 2:
		open = 1.0
	elif failed == 1:
		open = maxf(open if _shut[index] == 0 else 0.0, TRICKLE)
	elif _shut[index] == 1:
		open = 0.0
	var high := 0 if _heights[0] >= _heights[1] else 1
	var low := 1 - high
	var side_high := first if high == 0 else second
	var side_low := second if high == 0 else first
	# The floor of the lower side under the opening, as high as it stands in the world.
	var under := opening.centre
	under.y = _floors[index * 2 + low]
	var floor_under := -INF if side_low == -1 else (_ship * under).y
	var drop := _heights[high] - maxf(_heights[low], floor_under)
	if open <= 0.0 or _heights[high] <= bottom + SHOWS or _heights[high] - _heights[low] < POURS:
		return
	var from := minf(_heights[high], top)
	var to := maxf(_heights[low], floor_under)
	var strength := pour_strength(drop, _flow_of(index, pose), _width_of(opening))
	var centre := opening.centre
	var width := 0.0
	var across := Vector3.ZERO
	var normal := Vector3.ZERO
	if axis == 1:
		# A hole in a deck: water falls through it from over the hole, if the higher
		# side is over it, down the hole's longer way.
		if not _over(side_high, opening.centre.y):
			return
		from = (_ship * centre).y
		var long := 0 if opening.size.x >= opening.size.z else 2
		width = opening.size[long]
		across[long] = 1.0
		normal[2 - long] = 1.0
	else:
		var along := 2 if axis == 0 else 0
		width = opening.size[along] * open
		across[along] = 1.0
		normal[axis] = signf(_middle(side_low, axis) - centre[axis])
		centre += normal * (OFF_SHELL if side_high == -1 else OFF_WALL)
		# A sliding door's opening is what its leaf has not covered.
		centre[along] += opening.size[along] * (1.0 - open) * 0.5
	if from - to < POURS or width <= 0.0:
		return
	var tall := from - to
	# Through a wall it leaves at the speed the head over it drives and arcs on into the
	# lower side as it falls: thrown 2 √(head × fall) out, a jet from a porthole under
	# the sea, barely a lip off a weir. Pouring in through a deck from the open sky, the
	# sky lights it. It falls along the world's down, its sheet and its landing turned
	# level with the world.
	var thrown := 0.0
	if axis != 1:
		var head := maxf(_heights[high] - (from + maxf(bottom, _heights[low])) * 0.5, 0.0)
		thrown = minf(2.0 * sqrt(head * tall), MOST_THROW)
	var short := opening.size[int(normal.abs().max_axis_index())]
	across = _flat(across)
	normal = _flat(normal)
	var outdoor := 1.0 if axis == 1 and side_high == -1 else 0.0
	var middle := _at_height(centre, (from + to) * 0.5)
	var falling := Basis(across * width, _up * tall, normal)
	_hang(pour, falling, middle, strength, Vector3(0.0, 0.0, thrown), outdoor)
	var lands := _at_height(centre + normal * thrown, to + FROTH_LIFT)
	var spread := lerpf(LANDING.x, LANDING.y, strength)
	var patch := Basis(across * (width + LANDING_WIDER), _up, normal * spread)
	if crossing != null and axis == 1:
		var through := Basis(normal * short, _up * tall, across)
		_hang(crossing, through, middle, strength, Vector3.ZERO, outdoor)
		var wide := short + LANDING_WIDER
		patch = Basis(across * (width + LANDING_WIDER), _up, normal * wide)
	elif crossing != null:
		# A round jet: a second sheet edge-on to the first, arcing out the same way, so
		# it has a body seen from beside it too.
		var edge_on := Basis(normal * width, _up * tall, across)
		_hang(crossing, edge_on, middle, strength, Vector3(thrown / width, 0.0, 0.0), outdoor)
	_lay(landing, patch, lands, strength, -1.0)


## How hard a pour is drawn pouring, THINNEST…1: from [param flow], the water passing its
## opening in m³ a second (ShipPose.flows), over [param width], the opening's width; or,
## where [param flow] is below 0 — the pose has none — from [param drop], the height its
## water falls.
static func pour_strength(drop: float, flow: float, width: float) -> float:
	if flow < 0.0:
		return clampf(drop / FLOOD, THINNEST, 1.0)
	return clampf(flow / (maxf(width, 0.1) * FLOW_FULL), THINNEST, 1.0)


## The water passing opening [param index] under [param pose], in m³ a second, or -1 where
## the pose has no flow for it.
func _flow_of(index: int, pose: ShipPose) -> float:
	if pose.flows.is_empty():
		return -1.0
	if not is_same(pose.passages, _flow_names):
		_flow_names = pose.passages
		_flow_at.clear()
		for opening: ShipOpening in _passages:
			_flow_at.append(pose.passages.find(opening.name))
	var at := _flow_at[index]
	return pose.flows[at] if at != -1 else -1.0


## How wide [param opening]'s water pours: across a wall, its width along it; through a
## deck, its longer side.
static func _width_of(opening: ShipOpening) -> float:
	var axis := opening.facing()
	if axis == 1:
		return maxf(opening.size.x, opening.size.z)
	return opening.size[2 if axis == 0 else 0]


## [param direction] in her laid level with the world, a unit long.
func _flat(direction: Vector3) -> Vector3:
	return (direction - _up * direction.dot(_up)).normalized()


## Hangs [param pour] as [param basis] at [param middle], pouring as hard as
## [param strength] says, thrown out of its opening by its foot by [param thrown] in its
## own units (spill.gdshader), lit by the sky by [param outdoor].
func _hang(
	pour: MeshInstance3D,
	basis: Basis,
	middle: Vector3,
	strength: float,
	thrown: Vector3,
	outdoor: float
) -> void:
	pour.transform = Transform3D(basis, middle)
	_param(pour, &"extent", Vector2(basis.x.length(), basis.y.length()))
	_param(pour, &"strength", strength)
	_param(pour, &"thrown", thrown)
	_param(pour, &"outdoor", outdoor)
	pour.visible = true


## Lays [param froth] flat as [param basis] at [param at], boiling as hard as
## [param strength] says — a burst of air [param burst] of the way through, or below 0
## for a pour's landing.
func _lay(froth: MeshInstance3D, basis: Basis, at: Vector3, strength: float, burst: float) -> void:
	froth.transform = Transform3D(basis, at)
	_param(froth, &"extent", Vector2(basis.x.length(), basis.z.length()))
	_param(froth, &"strength", strength)
	_param(froth, &"burst", burst)
	froth.visible = true


## Whether cell [param side] — or the sea, for -1 — stands over height [param at].
func _over(side: int, at: float) -> bool:
	return side == -1 or _structure.cells[side].low.y >= at - 0.01


## The middle of cell [param side] along [param axis]; far out for the sea.
func _middle(side: int, axis: int) -> float:
	if side == -1:
		return 1e3
	var cell := _structure.cells[side]
	return (cell.low[axis] + cell.high[axis]) * 0.5


## Bursts the air out of [param opening] (passage [param index]) on the water of a
## side whose water, at world heights [param levels], has just reached its [param top] since last
## drawn: bubbles breaking its surface beside the opening.
func _blow(index: int, levels: PackedFloat64Array, top: float, opening: ShipOpening) -> void:
	var last := _last_heads[index]
	_last_heads[index] = Vector2(levels[0], levels[1])
	for side in 2:
		var cell := _sides[index * 2 + side]
		if cell == -1 or not (last[side] < top and levels[side] >= top and is_finite(last[side])):
			continue
		var burst := _next_burst
		_next_burst = (_next_burst + 1) % BURSTS
		var at := opening.centre
		var axis := opening.facing()
		if axis != 1:
			at[axis] += signf(_middle(cell, axis) - at[axis]) * BURST_IN
		var flat := _level * Basis.from_scale(Vector3(BURST, 1.0, BURST))
		_lay(_bursts[burst], flat, _at_height(at, levels[side] + FROTH_LIFT), 1.0, 0.0)
		_param(_bursts[burst], &"outdoor", 0.0)
		_burst_cells[burst] = cell
		_burst_at[burst] = at
		_burst_ages[burst] = 0.0
		set_process(true)


## The pockets [param pose] has, its cells' water at world heights [param levels]:
## bubbles over each one that leaks into water standing over the middle of its top, and
## a burst at the opening of each that has just gone free with air to blow out.
func _show_pockets(pose: ShipPose, levels: PackedFloat64Array) -> void:
	var leak := 0
	var lit := -1
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye_cell := pose.cell_at(to_local(camera.global_position)) if camera != null else -1
	for cell in _airs.size():
		var low := _structure.cells[cell].low
		var box := AABB(low, _structure.cells[cell].high - low)
		var held := cell < pose.pockets.size() and pose.pockets[cell] > 0.0
		var glow := POCKET_GLOW if held else 0.0
		if _surfaces[cell] != null and _glows[cell] != glow:
			_param(_surfaces[cell], &"pocket_glow", glow)
			for stack: Array in _stacks:
				if stack[0] == cell:
					_param(stack[2], &"pocket_glow", glow)
			_glows[cell] = glow
		if held and cell == eye_cell:
			lit = cell
		if not held:
			if _airs[cell] >= VENTS:
				_vent(cell, levels, pose)
			_airs[cell] = -1.0
			continue
		_airs[cell] = CellSurface.reach(_ship, box).y - levels[cell]
		var top := box.get_center()
		top.y = box.end.y
		var over := pose.water_level(top + Vector3.UP * CellMap.DRY)
		if leak >= LEAKS or _structure.cells[cell].leak_area <= 0.0 or over <= (_ship * top).y:
			continue
		var flat := _level * Basis.from_scale(Vector3(LEAK, 1.0, LEAK))
		var outside := pose.cell_at(top + Vector3.UP * CellMap.DRY) == CellMap.NONE
		_lay(_leaks[leak], flat, _at_height(top, over + FROTH_LIFT), 1.0, 0.0)
		_param(_leaks[leak], &"outdoor", 1.0 if outside else 0.0)
		leak += 1
	for unused in range(leak, LEAKS):
		_leaks[unused].visible = false
	_pocket_light.visible = lit != -1
	if lit != -1:
		var low := _structure.cells[lit].low
		var box := AABB(low, _structure.cells[lit].high - low)
		var middle := box.get_center()
		middle.y = box.position.y
		_pocket_light.position = _at_height(middle, levels[lit] + FROTH_LIFT)
		var reach := maxf(box.size.x, box.size.z) * POCKET_SPAN
		_pocket_light.omni_range = clampf(reach, POCKET_REACH.x, POCKET_REACH.y)


## Bursts the air of [param cell]'s pocket out as it goes free, its cells' water at world
## heights [param levels] under [param pose]: on the water at the top of the opening of
## its not shut that stands highest, over whichever side's water stands higher there.
func _vent(cell: int, levels: PackedFloat64Array, pose: ShipPose) -> void:
	var best := -1
	var highest := -INF
	for index in _passages.size():
		if _sides[index * 2] != cell and _sides[index * 2 + 1] != cell:
			continue
		var passage := _passages[index].name
		var shut: bool = _shut[index] == 1 or pose.doors_shut.get(passage, 0.0) >= 1.0
		if shut and pose.opened.get(passage, 0) < 2:
			continue
		var top := CellSurface.reach(_ship, _spans[index]).y
		if top > highest:
			best = index
			highest = top
	if best == -1:
		return
	var opening := _passages[best]
	var beyond := _sides[best * 2 + 1] if _sides[best * 2] == cell else _sides[best * 2]
	var beyond_level := 0.0 if beyond == -1 else levels[beyond]
	var under := cell if levels[cell] >= beyond_level else beyond
	var level := maxf(levels[cell], beyond_level)
	# On the water the air comes up through, clear of the wall or the shell it is in.
	var at := opening.centre
	var axis := opening.facing()
	if axis != 1:
		var out := signf(_middle(cell, axis) - at[axis]) * (1.0 if under == cell else -1.0)
		at[axis] += out * VENT_BURST * 0.4
	var burst := _next_burst
	_next_burst = (_next_burst + 1) % BURSTS
	var flat := _level * Basis.from_scale(Vector3(VENT_BURST, 1.0, VENT_BURST))
	_lay(_bursts[burst], flat, _at_height(at, level + FROTH_LIFT), 1.0, 0.0)
	_param(_bursts[burst], &"outdoor", 1.0 if under == -1 else 0.0)
	_burst_cells[burst] = under
	_burst_at[burst] = at
	_burst_ages[burst] = 0.0
	set_process(true)


## A patch of froth lying on the water (froth.gdshader), hidden till laid.
func _froth() -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = FROTH_SHADER
	material.set_shader_parameter(&"water_colour", _sea.get_shader_parameter(&"shallow_colour"))
	material.set_shader_parameter(&"foam_colour", _sea.get_shader_parameter(&"foam_colour"))
	material.render_priority = 1
	var patch := PlaneMesh.new()
	patch.size = Vector2.ONE
	var froth := MeshInstance3D.new()
	froth.mesh = patch
	froth.material_override = material
	froth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	froth.visible = false
	add_child(froth)
	return froth


## Ages the bursts of air on the water, each gone once it has broken; idle while none
## is bursting.
func _process(delta: float) -> void:
	var bursting := false
	for burst in BURSTS:
		if _burst_ages[burst] < 0.0:
			continue
		_burst_ages[burst] += delta
		if _burst_ages[burst] >= BURST_SECONDS:
			_burst_ages[burst] = -1.0
			_bursts[burst].visible = false
			continue
		bursting = true
		var through := _burst_ages[burst] / BURST_SECONDS
		_param(_bursts[burst], &"burst", through)
	set_process(bursting)
