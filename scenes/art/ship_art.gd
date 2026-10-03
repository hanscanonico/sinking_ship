class_name ShipArt
extends Node3D
## The ship, dressed (SH14b): generated from the same ShipLayout the greybox reads
## (D6) and aligned to it — make art-lint holds every platform top, blocker face and
## stair to its data — with nothing placed by hand, so any layout in the format
## dresses itself. A lofted hull (ShipHull); planked decks; walls white outside and
## painted inside under beamed ceilings, with wooden door frames; treads on every
## ramp; railings of stanchions and rails; a ladder down the hull side at every
## boarding ladder; a buff funnel with a black top and smoke, a mast; a tarpaulined
## hatch where a thick box stands outdoors and an engine where one stands in a room;
## glass, furniture and lifeboats (ShipFittings); and a ShipLamp in every room.
## Drawn only — the sim never reads a mesh. The sinking's events are drawn as
## MatchView hands them in (show_sinking): every platform the scenario may collapse
## and every railing it may fail is built as a node of its own, so a deck about to
## give way blinks red, then falls onto the floor beneath with its ceiling, beams,
## railings, ladders and the lamp of the room under it, and a failed railing is gone.
## The walls under it stand.

const SHADER := preload("res://scenes/art/ship.gdshader")
const CUT_SHADER := preload("res://scenes/art/ship_cut.gdshader")
const GLASS_SHADER := preload("res://scenes/art/glass.gdshader")

## A deck's planking: its top is the platform's height.
const PLANK := 0.06
## The boot line, above the waterline of a level, unsunk ship.
const BOOT_ABOVE := 0.35
## The tallest a stair's step rises: the stair's top stands within half of it of
## the ramp's height everywhere.
const STEP_RISE := 0.22
const STRINGER_WIDTH := 0.05
const STRINGER_DEPTH := 0.26
const STRINGER_PROUD := 0.07
## A stringer stops short of each end of its stair by this much.
const STRINGER_SHORT := 0.15
const BEAM_SPACING := 1.0
const BEAM_WIDTH := 0.1
const BEAM_DEPTH := 0.12
## A lintel at least this far over its deck has a doorway under it.
const DOOR_FROM := 0.5
const FRAME_WIDTH := 0.1
const FRAME_PROUD := 0.03
const RAIL_WIDTH := 0.09
const RAIL_DEPTH := 0.06
const MID_RAIL := 0.035
const POST := 0.06
const POST_SPACING := 1.5
## A boarding ladder: its rungs' line stands LADDER_OUT outboard of its deck's edge,
## clear of the hull side and the toe rail; the top rung is flush with the deck, the
## rest RUNG_SPACING apart down to LADDER_BELOW under the waterline at rest.
const LADDER_OUT := 0.12
const LADDER_BELOW := 0.4
const RUNG_SPACING := 0.3
const RUNG := 0.04
const STILE := 0.06
## A cylinder this wide or wider is a funnel; a thinner one is a mast.
const FUNNEL_FROM := 0.5
const FUNNEL_SEGMENTS := 20
const MAST_SEGMENTS := 10
## A collapsed deck comes to rest this far above the floor beneath, tipped this far
## about the ship's length — the greybox's decks fall the same way.
const WRECK_LIFT := 0.35
const WRECK_TILT := 0.25
## The finishes ship.gdshader paints; the glass has its own.
const PAINTS: Array[int] = [
	ShipMesh.Finish.PLAIN,
	ShipMesh.Finish.DECK,
	ShipMesh.Finish.HULL,
	ShipMesh.Finish.HOUSE,
	ShipMesh.Finish.CABIN,
	ShipMesh.Finish.FUNNEL,
]

## Ship-local height: nothing of the ship above it is drawn — the observer's
## cut-away (--observer-cut). INF draws everything. Set it before build().
var cut_above := INF

var _space: ShipSpace
var _smoke: CPUParticles3D
## Per platform, the node its deck hangs from — what falls when it collapses — or
## null when no event can collapse it.
var _wrecks: Array[Node3D] = []
## Per platform, the height of the floor beneath its middle: where it lands.
var _floors := PackedFloat64Array()
## Per railing, the node it hangs from when an event can fail it, or null.
var _rails: Array[Node3D] = []
## Per platform name that can collapse, its own materials: Finish -> Material.
var _flashes := {}


## Draws [param layout]; [param railing_height] and [param body_radius] are the
## rules' — how high every railing stands, and how near a wall a body's centre
## comes. [param falls] names the platforms the scenario can collapse and
## [param fails] the railings, by index, it can fail.
func build(
	layout: ShipLayout,
	railing_height: float,
	body_radius: float,
	falls: Array[StringName] = [],
	fails := PackedInt32Array()
) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_space = ShipSpace.new(layout)
	_smoke = null
	_wrecks.clear()
	_floors.clear()
	_rails.clear()
	_flashes.clear()
	var materials := _materials(layout)
	var mesh := _mesh()
	# Each piece that can fall or fail gathers its faces apart, to commit under its node.
	var pieces := {}
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		_floors.append(_space.floor_beneath(platform))
		_wrecks.append(_piece(pieces, platform.name in falls, "Deck%d" % index, self))
		if _wrecks[index] != null and not _flashes.has(platform.name):
			_flashes[platform.name] = _own_paints(materials)
	ShipHull.new(_space).build(mesh)
	for index in layout.platforms.size():
		_deck(pieces.get(_wrecks[index], mesh), layout.platforms[index])
	for ramp: ShipRamp in layout.ramps:
		_stairs(mesh, ramp)
	for blocker: ShipBlocker in layout.blockers:
		_blocker(mesh, blocker)
	for index in layout.railings.size():
		var railing := layout.railings[index]
		var wreck := _wrecks[railing.platform]
		var on: Node3D = wreck if wreck != null else self
		_rails.append(_piece(pieces, index in fails, "Railing%d" % index, on))
		var into: ShipMesh = pieces.get(_rails[index], pieces.get(wreck, mesh))
		_railing(into, railing, layout.platforms[railing.platform].height, railing_height)
	for ladder: ShipLadder in layout.ladders:
		var into: ShipMesh = pieces.get(_wrecks[ladder.platform], mesh)
		_ladder(into, ladder, layout.platforms[ladder.platform], -layout.freeboard)
	ShipFittings.new(_space, body_radius).build(mesh)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = ArtPalette.BRASS
	brass.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	brass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for index in layout.rooms.size():
		_hang_lamp(layout.rooms[index], index, brass)
	mesh.commit(self, materials)
	for node: Node3D in pieces:
		var deck := _wrecks.find(node)
		if deck == -1:
			deck = _wrecks.find(node.get_parent())
		var paints: Dictionary = materials if deck == -1 else _flashes[layout.platforms[deck].name]
		(pieces[node] as ShipMesh).commit(node, paints)


## Draws what the sinking's events have done, as MatchView hands them in: a
## platform named in [param collapsing] blinks red while [param lit]; one named in
## [param fallen] lies that far (0…1) down toward its wreck on the floor beneath,
## and the lamp it carries is out once it is down; a railing in
## [param broken_railings] is gone.
func show_sinking(
	collapsing: Array[StringName], fallen: Dictionary, broken_railings: PackedInt32Array, lit: bool
) -> void:
	if _space == null:
		return
	for platform_name: StringName in _flashes:
		var flash := 1.0 if lit and platform_name in collapsing else 0.0
		for finish: int in PAINTS:
			(_flashes[platform_name][finish] as ShaderMaterial).set_shader_parameter("flash", flash)
	for index in _wrecks.size():
		var wreck := _wrecks[index]
		if wreck == null:
			continue
		var platform := _space.layout.platforms[index]
		var down: float = fallen.get(platform.name, 0.0)
		wreck.transform = wrecked(platform, _floors[index], down)
		for child: Node in wreck.get_children():
			if child is ShipLamp:
				(child as ShipLamp).burning = down < 1.0
	for index in _rails.size():
		if _rails[index] != null:
			_rails[index].visible = not index in broken_railings


## Where [param platform]'s deck is drawn [param fallen] of the way (0…1) down from
## its place to its wreck: dropped, faster as it goes, to WRECK_LIFT above
## [param floor_height] and tipped about its middle.
static func wrecked(platform: ShipPlatform, floor_height: float, fallen: float) -> Transform3D:
	var middle := platform.area.get_center()
	var pivot := Vector3(middle.x, platform.height, middle.y)
	var drop := (platform.height - floor_height - WRECK_LIFT) * fallen * fallen
	var tilt := Basis(Vector3.RIGHT, WRECK_TILT * fallen)
	return Transform3D(tilt, pivot - tilt * pivot + Vector3.DOWN * drop)


func _process(_delta: float) -> void:
	if _smoke != null:
		_smoke.emitting = _smoke.global_position.y > 0.0


## The faces of the ship, gathered for one commit.
func _mesh() -> ShipMesh:
	var mesh := ShipMesh.new(_space.outdoors, _space.room_lines())
	mesh.cut_above = cut_above
	return mesh


## When [param apart], a node named [param piece_name] under [param parent] with a
## mesh of its own filed under it in [param pieces]; null otherwise.
func _piece(pieces: Dictionary, apart: bool, piece_name: String, parent: Node3D) -> Node3D:
	if not apart:
		return null
	var node := Node3D.new()
	node.name = piece_name
	parent.add_child(node)
	pieces[node] = _mesh()
	return node


## [param materials] with a copy of each ship.gdshader paint, so one platform's
## blink tints nothing else.
func _own_paints(materials: Dictionary) -> Dictionary:
	var own := materials.duplicate()
	for finish: int in PAINTS:
		own[finish] = (materials[finish] as ShaderMaterial).duplicate()
	return own


## Planks on [param platform]; under one that roofs another, a painted ceiling on
## beams. A deck at or above the cut-away is not drawn at all, ceiling and all, so
## the observer looks into the rooms under it (as the greybox).
func _deck(mesh: ShipMesh, platform: ShipPlatform) -> void:
	var area := platform.area
	var height := platform.height
	if height >= cut_above:
		return
	mesh.box(area, height - PLANK, height, ShipPaints.deck, ShipMesh.TOP | ShipMesh.SIDES)
	if not _space.stands_over_a_platform(platform):
		return
	mesh.box(area, height - PLANK, height, ShipPaints.ceiling, ShipMesh.BOTTOM)
	var x := ceilf((area.position.x + BEAM_WIDTH) / BEAM_SPACING) * BEAM_SPACING
	while x < area.end.x - BEAM_WIDTH:
		mesh.box(
			Rect2(x - BEAM_WIDTH * 0.5, area.position.y, BEAM_WIDTH, area.size.y),
			height - PLANK - BEAM_DEPTH,
			height - PLANK,
			ShipPaints.beam,
			ShipMesh.BOTTOM | ShipMesh.POS_X | ShipMesh.NEG_X
		)
		x += BEAM_SPACING


## Treads up [param ramp], each standing at the ramp's height across its middle, so
## the stair's top never strays more than half a riser from the slope the rules
## walk; a stringer along each side.
func _stairs(mesh: ShipMesh, ramp: ShipRamp) -> void:
	var along_x := ramp.axis == ShipRamp.Axis.X
	var area := ramp.area
	var run := area.size.x if along_x else area.size.y
	var climb := ramp.end_height - ramp.start_height
	var steps := maxi(2, ceili(absf(climb) / STEP_RISE - 0.001))
	var base := ramp.base()
	for step in steps:
		var from := run * step / steps
		var length := run / steps
		var tread := (
			Rect2(area.position.x + from, area.position.y, length, area.size.y)
			if along_x
			else Rect2(area.position.x, area.position.y + from, area.size.x, length)
		)
		var middle := tread.get_center()
		var top := ramp.height_at(middle.x, middle.y)
		mesh.box(tread, base, top, ShipPaints.tread, ShipMesh.TOP | ShipMesh.SIDES)
	var long := (Vector3(run, climb, 0.0) if along_x else Vector3(0.0, climb, run)).normalized()
	var across := Vector3.BACK if along_x else Vector3.LEFT
	var turn := Basis(long, across.cross(long), across)
	var size := Vector3(
		Vector2(run, climb).length() - STRINGER_SHORT * 2.0, STRINGER_DEPTH, STRINGER_WIDTH
	)
	var centre := area.get_center()
	var middle := Vector3(centre.x, (ramp.start_height + ramp.end_height) * 0.5, centre.y)
	middle += turn.y * (STRINGER_PROUD - STRINGER_DEPTH * 0.5)
	var width := area.size.y if along_x else area.size.x
	for side: float in [-1.0, 1.0]:
		var offset := (width - STRINGER_WIDTH) * 0.5 * side
		var at := middle + (Vector3(0.0, 0.0, offset) if along_x else Vector3(offset, 0.0, 0.0))
		mesh.turned_box(Transform3D(turn, at), size, ShipPaints.frame)


## Stanchions along [param railing], a teak cap rail at the rules' height and a
## middle rail.
func _railing(mesh: ShipMesh, railing: ShipRailing, deck: float, height: float) -> void:
	var span := railing.to - railing.from
	var posts := maxi(1, ceili(span.length() / POST_SPACING))
	for index in posts + 1:
		var at := railing.from + span * (float(index) / posts)
		mesh.box(
			Rect2(at - Vector2.ONE * POST * 0.5, Vector2.ONE * POST),
			deck,
			deck + height - RAIL_DEPTH,
			ShipPaints.white,
			ShipMesh.SIDES
		)
	var cap := Vector2(RAIL_WIDTH, RAIL_DEPTH)
	_bar(mesh, railing.from, railing.to, deck + height - RAIL_DEPTH * 0.5, cap, ShipPaints.teak)
	var middle := Vector2.ONE * MID_RAIL
	_bar(mesh, railing.from, railing.to, deck + height * 0.5, middle, ShipPaints.white)


## A ladder hung outboard of [param ladder]'s stretch of [param platform]'s edge:
## two steel stiles and teak rungs, from the deck to LADDER_BELOW under
## [param waterline], the sea's height on a level, unsunk ship.
func _ladder(mesh: ShipMesh, ladder: ShipLadder, platform: ShipPlatform, waterline: float) -> void:
	var outward := (ladder.to - ladder.from).normalized().orthogonal()
	if (platform.area.get_center() - ladder.from).dot(outward) > 0.0:
		outward = -outward
	var from := ladder.from + outward * LADDER_OUT
	var to := ladder.to + outward * LADDER_OUT
	var bottom := waterline - LADDER_BELOW
	for end: Vector2 in [from, to]:
		var stile := Rect2(end - Vector2.ONE * STILE * 0.5, Vector2.ONE * STILE)
		mesh.box(stile, bottom, platform.height, ShipPaints.steel)
	var rung := platform.height - RUNG * 0.5
	while rung > bottom:
		_bar(mesh, from, to, rung, Vector2(RUNG, RUNG), ShipPaints.teak)
		rung -= RUNG_SPACING


## A bar from [param from] to [param to] (x/z) centred at [param height], of
## [param section] (width, depth), its ends running past by half its width.
func _bar(
	mesh: ShipMesh,
	from: Vector2,
	to: Vector2,
	height: float,
	section: Vector2,
	paint: ShipMesh.Paint
) -> void:
	var span := to - from
	var half := section * 0.5
	if is_zero_approx(span.x) or is_zero_approx(span.y):
		var area := Rect2(from, Vector2.ZERO).expand(to).grow(half.x)
		mesh.box(area, height - half.y, height + half.y, paint)
		return
	var middle := (from + to) * 0.5
	mesh.turned_box(
		Transform3D(Basis(Vector3.UP, -span.angle()), Vector3(middle.x, height, middle.y)),
		Vector3(span.length() + section.x, section.y, section.x),
		paint
	)


## A wall, a hatch, an engine, a funnel or a mast, by its shape and where it stands.
## A blocker a deck rests on stops a plank short of its top, so the deck shows.
func _blocker(mesh: ShipMesh, blocker: ShipBlocker) -> void:
	var top := blocker.top - (PLANK if _space.deck_on(blocker) else 0.0)
	if blocker.shape == ShipBlocker.Shape.CYLINDER:
		if blocker.radius >= FUNNEL_FROM:
			_funnel(mesh, blocker, top)
		else:
			_mast(mesh, blocker, top)
		return
	var area := blocker.area
	var centre := area.get_center()
	if _space.is_wall(blocker):
		var deck := _space.deck_under(centre, blocker.bottom)
		var foot := blocker.bottom if is_nan(deck) else deck
		mesh.box(area, blocker.bottom, top, ShipPaints.wall, ShipMesh.ALL_FACES, foot, blocker.top)
		if not is_nan(deck) and blocker.bottom - deck > DOOR_FROM:
			_door_frame(mesh, blocker, deck)
	elif _space.outdoors(Vector3(centre.x, (blocker.bottom + top) * 0.5, centre.y)):
		_hatch(mesh, area, blocker.bottom, top)
	else:
		_engine(mesh, area, blocker.bottom, top)


## Posts either side of the doorway under [param lintel], from the deck to its
## underside, and a head across it on both faces of the wall.
func _door_frame(mesh: ShipMesh, lintel: ShipBlocker, deck: float) -> void:
	var area := lintel.area
	var middle := area.get_center()
	var along_x := area.size.x >= area.size.y
	var wall := area.size.y if along_x else area.size.x
	var thickness := wall + FRAME_PROUD * 2.0
	var head := lintel.bottom + FRAME_WIDTH
	for end: float in [0.0, 1.0]:
		var post := Rect2()
		if along_x:
			var x := lerpf(area.position.x, area.end.x, end)
			post = Rect2(x - FRAME_WIDTH * 0.5, middle.y - thickness * 0.5, FRAME_WIDTH, thickness)
		else:
			var z := lerpf(area.position.y, area.end.y, end)
			post = Rect2(middle.x - thickness * 0.5, z - FRAME_WIDTH * 0.5, thickness, FRAME_WIDTH)
		mesh.box(post, deck, head, ShipPaints.frame, ShipMesh.SIDES)
	for side: float in [-1.0, 1.0]:
		var face := (wall + FRAME_PROUD) * 0.5 * side - FRAME_PROUD * 0.5
		var strip := (
			Rect2(
				area.position.x - FRAME_WIDTH * 0.5,
				middle.y + face,
				area.size.x + FRAME_WIDTH,
				FRAME_PROUD
			)
			if along_x
			else Rect2(
				middle.x + face,
				area.position.y - FRAME_WIDTH * 0.5,
				FRAME_PROUD,
				area.size.y + FRAME_WIDTH
			)
		)
		mesh.box(strip, lintel.bottom, head, ShipPaints.frame)


## A wooden coaming under a tarpaulin drawn over its top and lashed with battens.
func _hatch(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
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


## An engine block: a plinth, a crankcase with a brass band, a row of cylinder heads,
## and a steam pipe from them up to the deckhead and along it.
func _engine(mesh: ShipMesh, area: Rect2, bottom: float, top: float) -> void:
	mesh.box(area, bottom, top, ShipPaints.machine, ShipMesh.SIDES | ShipMesh.TOP)
	mesh.box(area.grow(0.03), bottom, bottom + 0.18, ShipPaints.steel, ShipMesh.SIDES)
	mesh.box(area.grow(0.02), top - 0.08, top, ShipPaints.brass, ShipMesh.SIDES)
	var along_x := area.size.x >= area.size.y
	var long := area.size.x if along_x else area.size.y
	var short := area.size.y if along_x else area.size.x
	var heads := maxi(1, floori(long / 0.8))
	var radius := minf(0.28, short * 0.25)
	var middle := area.get_center()
	for head in heads:
		var at := long * (head + 0.5) / heads
		var centre := (
			Vector2(area.position.x + at, middle.y)
			if along_x
			else Vector2(middle.x, area.position.y + at)
		)
		mesh.cylinder(centre, radius, top, top + 0.25, 12, ShipPaints.steel)
		mesh.cylinder(centre, radius + 0.02, top + 0.08, top + 0.13, 12, ShipPaints.brass, false)
	var deck := INF
	for platform: ShipPlatform in _space.layout.platforms:
		if platform.height > top and platform.contains(middle.x, middle.y):
			deck = minf(deck, platform.height)
	if deck == INF:
		return
	var pipe := deck - PLANK - BEAM_DEPTH - 0.08
	var offset := short * 0.35
	var run := (
		Rect2(area.position.x, middle.y + offset - 0.05, area.size.x, 0.1)
		if along_x
		else Rect2(middle.x + offset - 0.05, area.position.y, 0.1, area.size.y)
	)
	mesh.box(run, pipe - 0.05, pipe + 0.05, ShipPaints.steel)
	var riser := (
		Rect2(area.position.x + long * 0.5 - 0.04, middle.y + offset - 0.04, 0.08, 0.08)
		if along_x
		else Rect2(middle.x + offset - 0.04, area.position.y + long * 0.5 - 0.04, 0.08, 0.08)
	)
	mesh.box(riser, top, pipe, ShipPaints.brass, ShipMesh.SIDES)


## A buff funnel with a black top and a rim, painted like the cabins where it passes
## through one, and smoke from its top.
func _funnel(mesh: ShipMesh, blocker: ShipBlocker, top: float) -> void:
	var centre := blocker.centre
	mesh.cylinder(centre, blocker.radius, blocker.bottom, top, FUNNEL_SEGMENTS, ShipPaints.funnel)
	var rim := blocker.radius + 0.04
	mesh.cylinder(centre, rim, top - 0.12, top, FUNNEL_SEGMENTS, ShipPaints.dark, false)
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.position = Vector3(centre.x, top + 0.1, centre.y)
	_smoke.amount = 26
	_smoke.lifetime = 5.0
	_smoke.preprocess = 5.0
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = blocker.radius * 0.5
	_smoke.direction = Vector3.UP
	_smoke.spread = 10.0
	_smoke.initial_velocity_min = 1.2
	_smoke.initial_velocity_max = 1.8
	_smoke.gravity = Vector3(-0.45, 0.1, 0.12)
	_smoke.damping_min = 0.2
	_smoke.damping_max = 0.3
	_smoke.scale_amount_min = 0.8
	_smoke.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.6))
	_smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(ArtPalette.SMOKE, 0.0))
	fade.set_color(1, Color(ArtPalette.SMOKE, 0.0))
	fade.add_point(0.15, ArtPalette.SMOKE)
	_smoke.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * blocker.radius * 1.4
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _puff_texture()
	puff.material = material
	_smoke.mesh = puff
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke.visible = not is_finite(cut_above)
	add_child(_smoke)


## A soft round puff, white at its heart and clear at its edge.
func _puff_texture() -> GradientTexture2D:
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


## A mast with a crosstree near its head and a masthead light.
func _mast(mesh: ShipMesh, blocker: ShipBlocker, top: float) -> void:
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
	light.visible = light.position.y < cut_above
	add_child(light)


## [param room]'s lamp, hung under the middle of its ceiling (the greybox's marker)
## — from the deck above when that deck can fall.
func _hang_lamp(room: ShipRoom, index: int, brass: Material) -> void:
	var middle := room.area.get_center()
	var lamp := ShipLamp.new()
	lamp.name = "Lamp%d" % index
	lamp.position = Vector3(middle.x, _space.ceiling(room, middle.x, middle.y) - PLANK, middle.y)
	lamp.visible = room.floor_height < cut_above
	var roof := _space.roof(room, middle.x, middle.y)
	var wreck: Node3D = _wrecks[roof] if roof != -1 else null
	(wreck if wreck != null else self).add_child(lamp)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = ArtPalette.LAMP_GLASS
	glass.emission_enabled = true
	glass.emission = ArtPalette.LAMP_GLASS
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.setup(Vector3(middle.x, room.floor_height, middle.y), index * 1.7, glass, brass)


## One material per finish: ship.gdshader, or its cut-away variant while
## [member cut_above] is finite, and the glass.
func _materials(layout: ShipLayout) -> Dictionary:
	var cut := is_finite(cut_above)
	var materials := {}
	for paint: int in PAINTS:
		var material := ShaderMaterial.new()
		material.shader = CUT_SHADER if cut else SHADER
		material.set_shader_parameter("finish", paint)
		material.set_shader_parameter("ink", ArtPalette.INK)
		material.set_shader_parameter("seam_colour", ArtPalette.DECK_SEAM)
		material.set_shader_parameter("bottom_colour", ArtPalette.HULL_BOTTOM)
		material.set_shader_parameter("riband_colour", ArtPalette.RIBAND)
		material.set_shader_parameter("boot_height", BOOT_ABOVE - layout.freeboard)
		material.set_shader_parameter("top_colour", ArtPalette.FUNNEL_TOP)
		material.set_shader_parameter("flash_colour", ArtPalette.COLLAPSE_FLASH)
		var cabin := paint == ShipMesh.Finish.CABIN
		material.set_shader_parameter("trim_colour", ArtPalette.FRAME if cabin else ArtPalette.TEAK)
		material.set_shader_parameter(
			"foot_colour", ArtPalette.DADO if cabin else ArtPalette.HOUSE_FOOT
		)
		if cut:
			material.set_shader_parameter("cut_above", cut_above)
		materials[paint] = material
	materials[ShipMesh.Finish.GLASS_IN] = _glass(false)
	materials[ShipMesh.Finish.GLASS_OUT] = _glass(true)
	return materials


## Glass seen from inside shows the sky; from outside it glows with the lamp.
func _glass(outside: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GLASS_SHADER
	if outside:
		material.set_shader_parameter("above_colour", ArtPalette.LAMP_LIGHT)
		material.set_shader_parameter("high_colour", ArtPalette.LAMP_LIGHT)
		material.set_shader_parameter("strength", 1.1)
	if is_finite(cut_above):
		material.set_shader_parameter("cut_above", cut_above)
	return material
