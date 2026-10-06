class_name ShipArt
extends Node3D
## The ship, dressed (SH14b): generated from the same ShipLayout the greybox reads
## (D6) and aligned to it — make art-lint holds every platform top, blocker face and
## stair to its data — with nothing placed by hand, so any layout in the format
## dresses itself. A lofted hull (ShipHull); planked decks; walls white outside and
## painted inside under beamed ceilings, with wooden door frames; treads on every
## ramp; railings of stanchions and rails; a ladder down the hull side at every
## boarding ladder; a buff funnel with a black top and smoke, a mast; a tarpaulined
## hatch where a thick box stands outdoors; glass, furniture and lifeboats
## (ShipFittings); and each room's own lining, fittings — an engine where one stands
## in a room — door signs and lamps (RoomDressing), the lamps ShipLamps.
## Drawn only — the sim never reads a mesh. The sinking's events are drawn as
## MatchView hands them in (show_sinking): every platform the scenario may collapse
## and every railing it may fail is built as a node of its own, so a deck about to
## give way blinks red, then falls onto the floor beneath with its ceiling, beams,
## railings, ladders and the lamp of the room under it, and a failed railing is gone.
## The walls under it stand. The match's own hazards are drawn the same way (SH10):
## any railing may break, so each is a node of its own, gone once broken but for its
## remains, built the first time it breaks (few ever do); and every crate of the
## cargo is a wooden box under a node of its own, which MatchView places (crates()),
## lit as the room it stands in or the open deck. Of the rooms' lamps, LampSight
## chooses which light each frame, as the graphics preset allows (show_graphics).

const SHADER := preload("res://scenes/art/ship.gdshader")
const CUT_SHADER := preload("res://scenes/art/ship_cut.gdshader")
const NEAR_SHADER := preload("res://scenes/art/ship_near.gdshader")
const GLASS_SHADER := preload("res://scenes/art/glass.gdshader")

## A deck's planking: its top is the platform's height.
const PLANK := 0.06
## The boot line, above the waterline of a level, unsunk ship.
const BOOT_ABOVE := 0.35
## The tallest a stair's step rises: the stair's top stands within half of it of
## the ramp's height everywhere.
const STEP_RISE := 0.22
## A stringer stands STRINGER_PROUD over the ramp's slope, past the treads' corners
## (half a riser), so it closes the stair's side.
const STRINGER_WIDTH := 0.05
const STRINGER_DEPTH := 0.3
const STRINGER_PROUD := 0.13
## A stringer stops short of each end of its stair by this much; the treads run this
## far into it.
const STRINGER_SHORT := 0.15
const STRINGER_TUCK := 0.015
## A deck stair's side panel, SKIRT_INSET inside its edge; its kick board's height,
## and the battens over it, every SKIRT_BATTEN, SKIRT_PROUD of it.
const SKIRT_INSET := 0.01
const SKIRT_KICK := 0.1
const SKIRT_BATTEN := 0.8
const SKIRT_PROUD := 0.02
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
## A collapsed deck comes to rest with its top this far above the floor beneath — its
## planks' and beams' depth, lying on the floor — tipping up to this far about the
## ship's length as it falls: the greybox's decks fall the same way. Drawn, it breaks
## up as it lands (DeckWreck).
const WRECK_LIFT := PLANK + BEAM_DEPTH
const WRECK_TILT := 0.25
## A crate is drawn a square whose half-side is this share of its circle's radius:
## its corners stand a little proud of the circle, its sides a little inside it.
const CRATE_SIDE := 0.85
## The battens round a crate's foot and its lid: how tall, and how proud.
const CRATE_BATTEN := 0.08
const CRATE_PROUD := 0.015
## The finishes ship.gdshader paints; the glass has its own.
const PAINTS: Array[int] = [
	ShipMesh.Finish.PLAIN,
	ShipMesh.Finish.DECK,
	ShipMesh.Finish.HULL,
	ShipMesh.Finish.HOUSE,
	ShipMesh.Finish.CABIN,
	ShipMesh.Finish.FUNNEL,
	ShipMesh.Finish.PLATE,
	ShipMesh.Finish.ROUGH,
]

## Ship-local height: nothing of the ship above it is drawn — the observer's
## cut-away (--observer-cut). INF draws everything. Set it before build().
var cut_above := INF

var _space: ShipSpace
var _dressing: RoomDressing
var _smoke: CPUParticles3D
## Per platform, the node its deck hangs from — what falls when it collapses — or
## null when no event can collapse it.
var _wrecks: Array[Node3D] = []
## Per platform, how its deck breaks up as it falls (DeckWreck), or null.
var _breakups: Array[DeckWreck] = []
## Per platform, the height of the floor beneath its middle: where it lands.
var _floors := PackedFloat64Array()
## Per railing, the node it hangs from when an event can fail it, or null, and the
## node its remains hang from, shown once it is broken — null until it first is.
var _rails: Array[Node3D] = []
var _remains: Array[Node3D] = []
## What draws a broken span's remains, and the ship's paints they are drawn in:
## Finish -> Material.
var _wreckage: RailingRemains
var _paints := {}
## Per room, a box holding all of it (_rooms_boxed): outside them all is outdoors.
var _room_boxes: Array[AABB] = []
## Per platform name that can collapse, its own materials: Finish -> Material; and
## the blink they were last given, so it is set only as it changes.
var _flashes := {}
var _flashing := {}
## Per crate of the layout's cargo, the node it is drawn under, and its own paints;
## and where it stood and how far indoors it was when they were last told.
var _crates: Array[Node3D] = []
var _crate_paints: Array[Dictionary] = []
var _crate_at := PackedVector3Array()
var _crate_indoors := PackedFloat32Array()
## Which of the rooms' lamps light, and the graphics preset it was last told of.
var _lamp_sight: LampSight
## Every room's lamp, the cell it hangs in — CellMap.NONE for a ship without cells —
## and where it burns: what the sinking's lit state and water reach (show_power).
var _lamps: Array[ShipLamp] = []
var _lamp_cells := PackedInt32Array()
var _lamp_at := PackedVector3Array()
## Per funnel the sinking can fell, by its fitting's name, the node its standing part
## hangs from, turned about its foot as it falls (show_falls).
var _funnels := {}
## Whether a funnel has come down: its smoke has stopped.
var _felled := false
## The glass the sinking can break (BrokenGlass).
var _broken_glass: BrokenGlass
var _graphics := GraphicsQuality.of(GraphicsQuality.Preset.HIGH)


## Draws [param layout]; [param railing_height] and [param body_radius] are the
## rules' — how high every railing stands, and how near a wall a body's centre
## comes. [param falls] names the platforms the scenario can collapse and
## [param fails] the railings, by index, it can fail; [param open_ports] are the middles
## of the portholes the hit left open, drawn open (ShipFittings).
func build(
	layout: ShipLayout,
	railing_height: float,
	body_radius: float,
	falls: Array[StringName] = [],
	fails := PackedInt32Array(),
	open_ports := PackedVector3Array()
) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_space = ShipSpace.new(layout)
	_rooms_boxed()
	_dressing = RoomDressing.new(_space, cut_above)
	_lamp_sight = LampSight.new(_space)
	_lamp_sight.show_graphics(_graphics)
	_smoke = null
	_wrecks.clear()
	_breakups.clear()
	_floors.clear()
	_rails.clear()
	_remains.clear()
	_flashes.clear()
	_flashing.clear()
	_crates.clear()
	_crate_paints.clear()
	_crate_at.clear()
	_crate_indoors.clear()
	_lamps.clear()
	_lamp_cells.clear()
	_lamp_at.clear()
	_funnels.clear()
	_felled = false
	var hull := ShipHull.new(_space, railing_height)
	var materials := _materials(layout, hull.bow_sweep())
	_paints = materials
	var mesh := _mesh()
	# Each piece that can fall or fail gathers its faces apart, to commit under its node.
	var pieces := {}
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		_floors.append(_space.floor_beneath(platform))
		_wrecks.append(_piece(pieces, platform.name in falls, "Deck%d" % index, self))
		if _wrecks[index] != null and not _flashes.has(platform.name):
			_flashes[platform.name] = _own_paints(materials)
	hull.build(mesh)
	for index in layout.platforms.size():
		var platform := layout.platforms[index]
		_breakups.append(null)
		if _wrecks[index] == null:
			_deck(mesh, platform, hull.hidden_faces(platform))
			continue
		_breakups[index] = DeckWreck.new(_space, platform, _dressing)
		_breakups[index].build(_wrecks[index], self, pieces, _mesh)
	for ramp: ShipRamp in layout.ramps:
		_stairs(mesh, ramp)
	for blocker: ShipBlocker in layout.blockers:
		_blocker(mesh, blocker, pieces)
	var cap := Vector2(RAIL_WIDTH, RAIL_DEPTH)
	_wreckage = RailingRemains.new(layout, railing_height, cap, Vector2.ONE * MID_RAIL, POST)
	for index in layout.railings.size():
		var railing := layout.railings[index]
		var wreck := _wrecks[railing.platform]
		var on: Node3D = wreck if wreck != null else self
		_rails.append(_piece(pieces, index in fails, "Railing%d" % index, on))
		var into: ShipMesh = pieces.get(_rails[index], pieces.get(wreck, mesh))
		_railing(into, index, railing_height)
		hull.staff(into, railing)
		_remains.append(null)
	for ladder: ShipLadder in layout.ladders:
		var into: ShipMesh = pieces.get(_wrecks[ladder.platform], mesh)
		_ladder(into, ladder, layout.platforms[ladder.platform], -layout.freeboard)
	var fittings := ShipFittings.new(_space, hull, body_radius, open_ports)
	fittings.build(mesh, self, materials)
	_broken_glass = BrokenGlass.new(layout, fittings.panes, self, materials)
	# Every furnishing stands in a room: its own mesh, which need not ask where it is.
	var furnishings := ShipMesh.new(
		func(_point: Vector3) -> bool: return false, _space.room_lines()
	)
	furnishings.cut_above = cut_above
	furnishings.fading = _dressing.overhead
	var dressed := Node3D.new()
	dressed.name = "Dressing"
	add_child(dressed)
	_dressing.build(furnishings, dressed, fittings.panes)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = ArtPalette.BRASS
	brass.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	brass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ShipLamp.fade_near(brass)
	var cells := CellMap.new(layout.structure) if layout.structure != null else null
	for index in layout.rooms.size():
		_hang_lamps(layout.rooms[index], index, brass, cells)
	mesh.commit(self, materials)
	furnishings.commit(dressed, _near_paints(materials))
	for node: Node3D in pieces:
		var deck := _wrecks.find(node)
		if deck == -1:
			deck = _wrecks.find(node.get_parent())
		var paints: Dictionary = materials if deck == -1 else _flashes[layout.platforms[deck].name]
		(pieces[node] as ShipMesh).commit(node, paints)
	for prop: ShipProp in layout.props:
		_crates.append(_crate(prop, materials))
		_crate_at.append(Vector3(NAN, NAN, NAN))
		_crate_indoors.append(NAN)


## Lets the rooms' lamps light as [param quality] allows: every room in sight, and
## those out of sight within its limit, nearest first (LampSight).
func show_graphics(quality: GraphicsQuality) -> void:
	_graphics = quality
	if _lamp_sight != null:
		_lamp_sight.show_graphics(quality)


## Per crate of the layout's cargo, the node it is drawn under, its origin at the
## crate's underside: where MatchView puts it.
func crates() -> Array[Node3D]:
	return _crates


## Draws what the sinking's events have done, as MatchView hands them in: a
## platform named in [param collapsing] blinks red while [param lit]; one named in
## [param fallen] lies that far (0…1) down toward its wreck on the floor beneath,
## and the lamp it carries is out once it is down; a railing in
## [param broken_railings] is gone, but for its remains (RailingRemains).
func show_sinking(
	collapsing: Array[StringName], fallen: Dictionary, broken_railings: PackedInt32Array, lit: bool
) -> void:
	if _space == null:
		return
	for platform_name: StringName in _flashes:
		var flash := 1.0 if lit and platform_name in collapsing else 0.0
		if _flashing.get(platform_name, -1.0) == flash:
			continue
		_flashing[platform_name] = flash
		for finish: int in PAINTS:
			(_flashes[platform_name][finish] as ShaderMaterial).set_shader_parameter("flash", flash)
	for index in _wrecks.size():
		var wreck := _wrecks[index]
		if wreck == null:
			continue
		var platform := _space.layout.platforms[index]
		var down: float = fallen.get(platform.name, 0.0)
		wreck.transform = wrecked(platform, _floors[index], down)
		_breakups[index].show(down)
		for child: Node in wreck.get_children():
			if child is ShipLamp:
				(child as ShipLamp).burning = down < 1.0
	for index in _rails.size():
		if _rails[index] == null:
			continue
		var broken := index in broken_railings
		_rails[index].visible = not broken
		if broken and _remains[index] == null:
			_remains[index] = _remains_of(index)
		if _remains[index] != null:
			_remains[index].visible = broken


## Lights each room's lamp as [param pose] has its cell lit — on her generator, her
## emergency power or nothing (ShipPose.lit) — and puts out each fire the water of its
## cell has reached; shows the glass the pose has broken (BrokenGlass). A pose without
## cells leaves them lit.
func show_power(pose: ShipPose) -> void:
	if pose.lit.is_empty():
		return
	for index in _lamps.size():
		var cell := _lamp_cells[index]
		if cell == CellMap.NONE:
			continue
		var lamp := _lamps[index]
		lamp.power = pose.lit[cell]
		lamp.drowned = pose.levels[cell] >= pose.world_height(_lamp_at[index])
	if _broken_glass != null:
		_broken_glass.show(pose)


## Turns each funnel [param falls] (ShipPose.falls) names about its foot as far as it has
## gone by [param tick], fractional, as the view interpolates: a lean as it creaks, then
## its fall toward its low side, faster as it goes (FunnelArt).
func show_falls(falls: Array[FunnelFall], tick: float) -> void:
	for fall: FunnelFall in falls:
		var node: Node3D = _funnels.get(fall.fitting.name)
		if node != null:
			node.transform = FunnelArt.turned(fall, tick)
			_felled = _felled or FunnelArt.down(fall, tick)


## Railing [param index]'s remains (RailingRemains) under a node of their own beside
## the span's, in the paints of the deck it stands on.
func _remains_of(index: int) -> Node3D:
	var on := _rails[index].get_parent() as Node3D
	var node := Node3D.new()
	node.name = "Railing%dRemains" % index
	on.add_child(node)
	var mesh := _mesh()
	_wreckage.build(mesh, index)
	var deck := _wrecks.find(on)
	mesh.commit(node, _paints if deck == -1 else _flashes[_space.layout.platforms[deck].name])
	return node


## Where [param platform]'s deck is drawn [param fallen] of the way (0…1) down from
## its place to its wreck: dropped, faster as it goes, to WRECK_LIFT above
## [param floor_height], tipping about its middle on the way and lying level once down.
static func wrecked(platform: ShipPlatform, floor_height: float, fallen: float) -> Transform3D:
	var middle := platform.area.get_center()
	var pivot := Vector3(middle.x, platform.height, middle.y)
	var drop := maxf(platform.height - floor_height - WRECK_LIFT, 0.0) * fallen * fallen
	var tilt := Basis(Vector3.RIGHT, WRECK_TILT * sin(PI * fallen))
	return Transform3D(tilt, pivot - tilt * pivot + Vector3.DOWN * drop)


func _process(_delta: float) -> void:
	if _smoke != null:
		_smoke.emitting = _smoke.global_position.y > 0.0 and not _felled
	for index in _crates.size():
		_light_crate(index)
	var camera := get_viewport().get_camera_3d()
	if camera != null and _lamp_sight != null:
		_lamp_sight.choose(global_transform.affine_inverse() * camera.global_position)


## Takes crate [param index]'s paints as far indoors as the crate stands where
## MatchView has put it — lamp-lit and out of the sun in a room, as the room's faces
## are — so it goes from the one light to the other as it crosses a doorway. Only as
## it moves, and only as far as that changes it.
func _light_crate(index: int) -> void:
	var at := _crates[index].position
	if at == _crate_at[index]:
		return
	_crate_at[index] = at
	var prop := _space.layout.props[index]
	var half := prop.radius * CRATE_SIDE
	var foot := Rect2(at.x - half, at.z - half, half * 2.0, half * 2.0)
	var indoors := _space.indoors(foot, at.y + prop.height * 0.5)
	if indoors == _crate_indoors[index]:
		return
	_crate_indoors[index] = indoors
	for finish: int in PAINTS:
		(_crate_paints[index][finish] as ShaderMaterial).set_shader_parameter("indoors", indoors)


## [param prop] as a crate: planked sides and lid in the crate paint, a batten round
## its foot and its lid, under a node of its own at its underside — built outdoors,
## where the cargo stands, in paints of its own that _light_crate() takes indoors.
func _crate(prop: ShipProp, materials: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Crate%d" % _crates.size()
	add_child(node)
	node.position = prop.pos
	var no_rooms: Array[PackedFloat32Array] = [
		PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array()
	]
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, no_rooms)
	var half := prop.radius * CRATE_SIDE
	var box := Rect2(-half, -half, half * 2.0, half * 2.0)
	mesh.box(box, 0.0, prop.height, ShipPaints.crate, ShipMesh.SIDES | ShipMesh.TOP)
	for band: float in [0.0, prop.height - CRATE_BATTEN]:
		mesh.box(box.grow(CRATE_PROUD), band, band + CRATE_BATTEN, ShipPaints.frame, ShipMesh.SIDES)
	_crate_marks(mesh, half, prop.height)
	var paints := _own_paints(materials)
	mesh.commit(node, paints)
	# Off the outdoor layer, so a lamp reaches it once it slides into a room; the
	# paints take no lamp while it stands outdoors.
	for part: Node in node.get_children():
		(part as MeshInstance3D).layers = 1
	_crate_paints.append(paints)
	return node


## A crate's slats, stencils and lashing, none further out than its battens: two
## slats up each side between them, a stencilled mark on two sides, and a rope
## lashed round it and over its lid, [param half] its half side, [param height] tall.
func _crate_marks(mesh: ShipMesh, half: float, height: float) -> void:
	var low := CRATE_BATTEN
	var high := height - CRATE_BATTEN
	for side in 4:
		var normal := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][side] as Vector3
		var right := normal.cross(Vector3.UP)
		var face := normal * half
		for slat: float in [-0.45, 0.45]:
			var middle := face + right * half * slat + Vector3.UP * (low + high) * 0.5
			var place := Transform3D(
				Basis(right, Vector3.UP, normal), middle + normal * CRATE_PROUD * 0.5
			)
			mesh.turned_box(place, Vector3(0.07, high - low, CRATE_PROUD), ShipPaints.frame, 0)
		if side % 2 == 1:
			var mark := face + normal * 0.002 + Vector3.UP * height * 0.5 - right * half * 0.05
			RoomDressing.panel(
				mesh, mark, right, Vector2(half * 0.3, 0.06), normal, ShipPaints.stencil, 0
			)
			var line := mark - Vector3.UP * 0.11
			RoomDressing.panel(
				mesh, line, right, Vector2(half * 0.2, 0.015), normal, ShipPaints.stencil, 0
			)
	var rope := CRATE_PROUD * 1.4
	for along_x: bool in [true, false]:
		var lash := Rect2(-half - rope, -0.02, (half + rope) * 2.0, 0.04)
		if not along_x:
			lash = Rect2(-0.02, -half - rope, 0.04, (half + rope) * 2.0)
		mesh.box(lash, 0.0, height + 0.012, ShipPaints.rope, ShipMesh.SIDES | ShipMesh.TOP)


## The faces of the ship, gathered for one commit.
func _mesh() -> ShipMesh:
	var mesh := ShipMesh.new(_outdoors, _space.room_lines())
	mesh.cut_above = cut_above
	return mesh


## Whether ship point [param point] stands outdoors, as ShipSpace.outdoors says —
## asked only where the point stands in some room's box; outside every one it does.
func _outdoors(point: Vector3) -> bool:
	for box: AABB in _room_boxes:
		if box.has_point(point):
			return _space.outdoors(point)
	return true


## Per room, a box holding all of it: its area and floor, up to the highest deck over
## any of it or its open height, grown by ShipSpace.INSIDE and a little more.
func _rooms_boxed() -> void:
	_room_boxes.clear()
	for room: ShipRoom in _space.layout.rooms:
		var top := room.floor_height + ShipSpace.OPEN_ROOM_HEIGHT
		for platform: ShipPlatform in _space.layout.platforms:
			if platform.height > room.floor_height and platform.area.intersects(room.area):
				top = maxf(top, platform.height)
		var foot := Vector3(room.area.position.x, room.floor_height, room.area.position.y)
		var size := Vector3(room.area.size.x, top - room.floor_height, room.area.size.y)
		_room_boxes.append(AABB(foot, size).grow(ShipSpace.INSIDE + ShipSpace.SLIVER))


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


## [param materials] with each ship.gdshader paint in its variant that fades a piece
## out near the eye (ship_near.gdshader), for the rooms' furnishings — but in the
## observer's cut-away, which looks from afar.
func _near_paints(materials: Dictionary) -> Dictionary:
	if is_finite(cut_above):
		return materials
	var near := _own_paints(materials)
	for finish: int in PAINTS:
		var material := near[finish] as ShaderMaterial
		material.shader = NEAR_SHADER
		material.set_shader_parameter("near_fade", RoomDressing.NEAR_FADE)
	return near


## Planks on [param platform], but for the edges in [param hidden] that lie on the
## hull's skin; under one that roofs another, a painted ceiling on beams. A deck at
## or above the cut-away is not drawn at all, ceiling and all, so the observer looks
## into the rooms under it (as the greybox).
func _deck(mesh: ShipMesh, platform: ShipPlatform, hidden: int) -> void:
	var area := platform.area
	var height := platform.height
	if height >= cut_above:
		return
	var faces := (ShipMesh.TOP | ShipMesh.SIDES) & ~hidden
	_lined_box(mesh, area, height - PLANK, height, ShipPaints.deck, faces, ShipMesh.TOP)
	if not _space.stands_over_a_platform(platform):
		return
	_lined_box(
		mesh, area, height - PLANK, height, ShipPaints.ceiling, ShipMesh.BOTTOM, ShipMesh.BOTTOM
	)
	var x := ceilf((area.position.x + BEAM_WIDTH) / BEAM_SPACING) * BEAM_SPACING
	var under := height - PLANK - BEAM_DEPTH
	while x < area.end.x - BEAM_WIDTH:
		var probe := Vector3(x, under - ShipMesh.PROBE, area.get_center().y)
		var lining := _dressing.lining(probe, RoomDressing.Part.BEAM)
		mesh.box(
			Rect2(x - BEAM_WIDTH * 0.5, area.position.y, BEAM_WIDTH, area.size.y),
			under,
			height - PLANK,
			ShipPaints.beam if lining == null else lining,
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
	# The treads stop inside the stringers, so no face of theirs shares a stringer's plane.
	var tuck := STRINGER_WIDTH - STRINGER_TUCK
	for step in steps:
		var from := run * step / steps
		var length := run / steps
		var tread := (
			Rect2(area.position.x + from, area.position.y + tuck, length, area.size.y - tuck * 2.0)
			if along_x
			else Rect2(
				area.position.x + tuck, area.position.y + from, area.size.x - tuck * 2.0, length
			)
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
	if _space.outdoors(Vector3(centre.x, base + 0.5, centre.y)):
		for side: float in [-1.0, 1.0]:
			_skirt(mesh, ramp, side)


## The side of [param ramp] on [param side] (-1 its least z or x, 1 its greatest)
## closed under its stringer — the rules hold a stair solid — by a white panel over a
## teak kick board, battened every SKIRT_BATTEN.
func _skirt(mesh: ShipMesh, ramp: ShipRamp, side: float) -> void:
	var along_x := ramp.axis == ShipRamp.Axis.X
	var area := ramp.area
	var base := ramp.base()
	var climb := absf(ramp.end_height - ramp.start_height)
	# From the stair's foot to its head along it.
	var ends := Vector2(area.position.y, area.end.y)
	if along_x:
		ends = Vector2(area.position.x, area.end.x)
	if ramp.start_height > ramp.end_height:
		ends = Vector2(ends.y, ends.x)
	var edge := area.end if side > 0.0 else area.position
	var line := (edge.y if along_x else edge.x) - side * SKIRT_INSET
	var out := Vector3(0.0, 0.0, side) if along_x else Vector3(side, 0.0, 0.0)
	var on_line := func(share: float, height: float) -> Vector3:
		var along := lerpf(ends.x, ends.y, share)
		return Vector3(along, height, line) if along_x else Vector3(line, height, along)
	var under := STRINGER_DEPTH - STRINGER_PROUD
	var ring := PackedVector3Array(
		[
			on_line.call(under / climb, base),
			on_line.call(1.0, base),
			on_line.call(1.0, base + climb - under)
		]
	)
	mesh.polygon(ring, out, ShipPaints.white, base, NAN)
	var lift := out * SKIRT_PROUD * 0.5
	var kick_from: Vector3 = on_line.call((under + SKIRT_KICK) / climb, base + SKIRT_KICK * 0.5)
	var kick_to: Vector3 = on_line.call(1.0, base + SKIRT_KICK * 0.5)
	mesh.beam(kick_from + lift, kick_to + lift, Vector2(SKIRT_PROUD, SKIRT_KICK), ShipPaints.teak)
	var run := absf(ends.y - ends.x)
	var right := Vector3.RIGHT if along_x else Vector3.BACK
	var count := floori(run / SKIRT_BATTEN)
	for index in range(1, count + 1):
		var share := 1.0 - index * SKIRT_BATTEN / run
		var head := share * climb - under
		if head < SKIRT_KICK + 0.15:
			continue
		var middle: Vector3 = on_line.call(share, base + (SKIRT_KICK + head) * 0.5) + lift
		var batten := Vector3(0.05, head - SKIRT_KICK, SKIRT_PROUD)
		mesh.turned_box(
			Transform3D(Basis(right, Vector3.UP, out), middle), batten, ShipPaints.teak, 0
		)


## Stanchions along railing [param index], a teak cap rail at the rules'
## [param height] and a middle rail. Where another span carries the rails on, or
## closes a corner along x, they stop at the post rather than run past it, so no two
## rails overlap in one plane.
func _railing(mesh: ShipMesh, index: int, height: float) -> void:
	var railing := _space.layout.railings[index]
	var deck := _space.layout.platforms[railing.platform].height
	var span := railing.to - railing.from
	var posts := maxi(1, ceili(span.length() / POST_SPACING))
	for post in posts + 1:
		var at := railing.from + span * (float(post) / posts)
		mesh.box(
			Rect2(at - Vector2.ONE * POST * 0.5, Vector2.ONE * POST),
			deck,
			deck + height - RAIL_DEPTH,
			ShipPaints.white,
			ShipMesh.SIDES
		)
	var ends := Vector2(_overhang(index, railing.from), _overhang(index, railing.to))
	var cap := Vector2(RAIL_WIDTH, RAIL_DEPTH)
	var top := deck + height - RAIL_DEPTH * 0.5
	_bar(mesh, railing.from, railing.to, top, cap, ShipPaints.teak, ends)
	var middle := Vector2.ONE * MID_RAIL
	_bar(mesh, railing.from, railing.to, deck + height * 0.5, middle, ShipPaints.white, ends)


## 1 when railing [param index]'s rails run past its end at [param point] by half
## their width — a free end, or the span along x at a corner — 0 when they stop at
## it.
func _overhang(index: int, point: Vector2) -> float:
	var layout := _space.layout
	var railing := layout.railings[index]
	var along_x := is_equal_approx(railing.from.y, railing.to.y)
	for other_index in layout.railings.size():
		var other := layout.railings[other_index]
		var level := layout.platforms[other.platform].height
		if (
			other_index == index
			or not is_equal_approx(level, layout.platforms[railing.platform].height)
		):
			continue
		if not (other.from.is_equal_approx(point) or other.to.is_equal_approx(point)):
			continue
		if along_x == is_equal_approx(other.from.y, other.to.y) or not along_x:
			return 0.0
	return 1.0


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
## [param section] (width, depth), its ends running past by half its width times
## [param ends] (at from, at to).
func _bar(
	mesh: ShipMesh,
	from: Vector2,
	to: Vector2,
	height: float,
	section: Vector2,
	paint: ShipMesh.Paint,
	ends := Vector2.ONE
) -> void:
	var span := to - from
	var half := section * 0.5
	var along := span.normalized()
	var start := from - along * half.x * ends.x
	var end := to + along * half.x * ends.y
	if is_zero_approx(span.x) or is_zero_approx(span.y):
		var area := Rect2(start, Vector2.ZERO).expand(end)
		area = area.grow_individual(
			half.x * absf(along.y),
			half.x * absf(along.x),
			half.x * absf(along.y),
			half.x * absf(along.x)
		)
		mesh.box(area, height - half.y, height + half.y, paint)
		return
	var middle := (start + end) * 0.5
	mesh.turned_box(
		Transform3D(Basis(Vector3.UP, -span.angle()), Vector3(middle.x, height, middle.y)),
		Vector3(start.distance_to(end), section.y, section.x),
		paint
	)


## A wall, a hatch, a funnel or a mast, by its shape and where it stands — an
## engine standing in a room is the room's own (RoomDressing). A blocker a deck rests
## on stops a plank short of its top, so the deck shows. A funnel the sinking can fell
## stands over its foot on a piece of its own among [param pieces], its smoke with it.
func _blocker(mesh: ShipMesh, blocker: ShipBlocker, pieces: Dictionary) -> void:
	var top := blocker.top - (PLANK if _space.deck_on(blocker) else 0.0)
	if blocker.shape == ShipBlocker.Shape.CYLINDER:
		var felled := FunnelArt.fitting_of(_space.layout, blocker)
		if blocker.radius >= FUNNEL_FROM and felled != null:
			var node := _piece(pieces, true, "Funnel_%s" % felled.name, self)
			_funnels[felled.name] = node
			_smoke = FunnelArt.split(mesh, pieces[node], blocker, felled, top, self)
			_smoke.reparent(node, false)
		elif blocker.radius >= FUNNEL_FROM:
			_smoke = DeckWorks.funnel(mesh, blocker, top, self)
		else:
			DeckWorks.mast(mesh, blocker, top, self)
		return
	var area := blocker.area
	var centre := area.get_center()
	if _space.is_wall(blocker):
		var deck := _space.deck_under(centre, blocker.bottom)
		var foot := blocker.bottom if is_nan(deck) else deck
		_lined_box(
			mesh,
			area,
			blocker.bottom,
			top,
			ShipPaints.wall,
			ShipMesh.ALL_FACES,
			ShipMesh.SIDES,
			foot,
			blocker.top
		)
		if not is_nan(deck) and blocker.bottom - deck > DOOR_FROM:
			_door_frame(mesh, blocker, deck)
	elif _space.outdoors(Vector3(centre.x, (blocker.bottom + top) * 0.5, centre.y)):
		DeckWorks.hatch(mesh, area, blocker.bottom, top)


## A box as ShipMesh.box() draws it in [param paint] — [param faces] of it — each
## face cut where a room with a lining of its own (RoomDressing) begins or ends and at
## the chunk lines (_lined_face); a piece of the faces [param lined] names that looks
## into such a room takes its lining for what it is: a top its floor, a bottom its
## ceiling, a side its wall.
func _lined_box(
	mesh: ShipMesh,
	area: Rect2,
	bottom: float,
	top: float,
	paint: ShipMesh.Paint,
	faces: int,
	lined: int,
	foot := NAN,
	head := NAN
) -> void:
	foot = bottom if is_nan(foot) else foot
	head = top if is_nan(head) else head
	var x0 := area.position.x
	var x1 := area.end.x
	var z0 := area.position.y
	var z1 := area.end.y
	var dx := Vector3(area.size.x, 0.0, 0.0)
	var dy := Vector3(0.0, top - bottom, 0.0)
	var dz := Vector3(0.0, 0.0, area.size.y)
	var floor := RoomDressing.Part.FLOOR
	var wall := RoomDressing.Part.WALL
	# The faces as ShipMesh.box() lays them out, each with what it is to a room.
	var sides := [
		[ShipMesh.TOP, Vector3(x0, top, z0), dz, dx, floor],
		[ShipMesh.BOTTOM, Vector3(x0, bottom, z0), dx, dz, RoomDressing.Part.OVERHEAD],
		[ShipMesh.POS_X, Vector3(x1, bottom, z0), dy, dz, wall],
		[ShipMesh.NEG_X, Vector3(x0, bottom, z0), dz, dy, wall],
		[ShipMesh.POS_Z, Vector3(x0, bottom, z1), dx, dy, wall],
		[ShipMesh.NEG_Z, Vector3(x0, bottom, z0), dy, dx, wall],
	]
	for side: Array in sides:
		if faces & side[0]:
			var part: int = side[4] if lined & side[0] else -1
			_lined_face(mesh, side[1], side[2], side[3], paint, part, foot, head)


## A face from [param origin] along [param u] and [param v] in [param paint], cut at
## the lined rooms' edges (RoomDressing.lining_lines) and the chunk lines, each piece
## in the lining for [param part] (-1 for none) of the room it looks into, if any; only
## the whole face's edges rimmed. A face too narrow for ShipMesh to cut — a plank's
## edge, a wall's top — so still lies in one chunk's mesh, never a sliver the length
## of the deck that every lamp along it reaches.
func _lined_face(
	mesh: ShipMesh,
	origin: Vector3,
	u: Vector3,
	v: Vector3,
	paint: ShipMesh.Paint,
	part: int,
	foot: float,
	head: float
) -> void:
	var normal := u.cross(v).normalized()
	var narrow := minf(u.length(), v.length()) < ShipMesh.NARROW
	var box := AABB(origin, Vector3.ZERO).expand(origin + u + v).grow(ShipMesh.PROBE)
	if not narrow and (part == -1 or not _dressing.lined_near(box)):
		mesh.face(origin, u, v, paint, ShipMesh.RIM_ALL, foot, head)
		return
	var u_cuts := _lining_cuts(origin, u)
	var v_cuts := _lining_cuts(origin, v)
	for i in u_cuts.size() - 1:
		for j in v_cuts.size() - 1:
			var at := origin + u * u_cuts[i] + v * v_cuts[j]
			var piece_u := u * (u_cuts[i + 1] - u_cuts[i])
			var piece_v := v * (v_cuts[j + 1] - v_cuts[j])
			var probe := at + (piece_u + piece_v) * 0.5 + normal * ShipMesh.PROBE
			var lining := null if part == -1 else _dressing.lining(probe, part)
			var rims := (
				(ShipMesh.RIM_U0 if i == 0 else 0)
				| (ShipMesh.RIM_U1 if i == u_cuts.size() - 2 else 0)
				| (ShipMesh.RIM_V0 if j == 0 else 0)
				| (ShipMesh.RIM_V1 if j == v_cuts.size() - 2 else 0)
			)
			mesh.face(at, piece_u, piece_v, paint if lining == null else lining, rims, foot, head)


## Where along [param edge] from [param origin] (fractions 0…1) a lined room's edge
## or a chunk line (ShipMesh.CHUNK) crosses it — along x or z alone.
func _lining_cuts(origin: Vector3, edge: Vector3) -> PackedFloat32Array:
	var cuts := PackedFloat32Array([0.0])
	var axis := -1
	if absf(edge.x) > ShipMesh.SLIVER and is_zero_approx(edge.y) and is_zero_approx(edge.z):
		axis = 0
	elif absf(edge.z) > ShipMesh.SLIVER and is_zero_approx(edge.x) and is_zero_approx(edge.y):
		axis = 1
	if axis != -1:
		var start := origin.x if axis == 0 else origin.z
		var length := edge.x if axis == 0 else edge.z
		var lines := _dressing.lining_lines(axis).duplicate()
		var step := ShipMesh.CHUNK.x if axis == 0 else ShipMesh.CHUNK.z
		var line := ceilf(minf(start, start + length) / step) * step
		while line < maxf(start, start + length):
			lines.append(line)
			line += step
		for at: float in lines:
			var fraction := (at - start) / length
			if (
				fraction * absf(length) > ShipMesh.SLIVER
				and (1.0 - fraction) * absf(length) > ShipMesh.SLIVER
			):
				cuts.append(fraction)
	cuts.append(1.0)
	cuts.sort()
	return cuts


## Posts either side of the doorway under [param lintel], from the deck to its
## underside, and a head across it on both faces of the wall.
func _door_frame(mesh: ShipMesh, lintel: ShipBlocker, deck: float) -> void:
	var area := lintel.area
	var middle := area.get_center()
	var along_x := area.size.x >= area.size.y
	var wall := area.size.y if along_x else area.size.x
	var thickness := wall + FRAME_PROUD * 2.0
	var head := lintel.bottom + FRAME_WIDTH
	var posts: Array[Rect2] = []
	for end: float in [0.0, 1.0]:
		if along_x:
			var x := lerpf(area.position.x, area.end.x, end)
			posts.append(
				Rect2(x - FRAME_WIDTH * 0.5, middle.y - thickness * 0.5, FRAME_WIDTH, thickness)
			)
		else:
			var z := lerpf(area.position.y, area.end.y, end)
			posts.append(
				Rect2(middle.x - thickness * 0.5, z - FRAME_WIDTH * 0.5, thickness, FRAME_WIDTH)
			)
	# A lintel whose ends stand past the deck under it heads no doorway: it is a
	# deck's edge over open space, as the forecastle's over the hold.
	for post: Rect2 in posts:
		if not is_equal_approx(_space.deck_under(post.get_center(), lintel.bottom), deck):
			return
	for post: Rect2 in posts:
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


## [param room]'s lamps where RoomDressing.lights() puts them: a pendant hung under
## the middle of its ceiling (the greybox's marker) — from the deck above when that
## deck can fall — and a room's others the same way; a fire in its wall. Each is lit as
## the cell it hangs in, of [param cells] (show_power).
func _hang_lamps(room: ShipRoom, index: int, brass: Material, cells: CellMap) -> void:
	var middle := room.area.get_center()
	var ceiling := _space.ceiling(room, middle.x, middle.y)
	var area := room.area
	var box := AABB(
		Vector3(area.position.x, room.floor_height, area.position.y),
		Vector3(area.size.x, ceiling - room.floor_height, area.size.y)
	)
	var lights := _dressing.lights(room)
	for number in lights.size():
		var light := lights[number]
		var lamp := ShipLamp.new()
		lamp.name = "Lamp%d" % index if number == 0 else "Lamp%d_%d" % [index, number]
		lamp.position = light.at
		lamp.visible = room.floor_height < cut_above
		lamp.everywhere = is_finite(cut_above)
		var roof := _space.roof(room, light.at.x, light.at.z)
		var wreck: Node3D = _wrecks[roof] if roof != -1 else null
		if light.kind == ShipLamp.Kind.FIRE:
			wreck = null
		(wreck if wreck != null else self).add_child(lamp)
		var glass := StandardMaterial3D.new()
		glass.emission_enabled = true
		if light.kind == ShipLamp.Kind.FIRE:
			# Embers dark in their own right, glowing only as the fire burns.
			glass.albedo_color = ArtPalette.EMBERS
			glass.emission = ArtPalette.FIRE_GLOW
			glass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		else:
			glass.albedo_color = ArtPalette.LAMP_GLASS
			glass.emission = ArtPalette.LAMP_GLASS
			glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ShipLamp.fade_near(glass)
		lamp.setup(index * 1.7 + number * 0.61, glass, brass, light.kind, light.facing)
		_lamp_sight.add(lamp, index, box)
		_lamps.append(lamp)
		_lamp_cells.append(cells.cell_at(light.at) if cells != null else CellMap.NONE)
		_lamp_at.append(light.at)


## The materials the ship is drawn with, one per finish, for what is drawn beside it.
func paints() -> Dictionary:
	return _paints


## One material per finish: ship.gdshader, or its cut-away variant while
## [member cut_above] is finite, its deck's planks closing on the stem as [param bow]
## says (ShipHull.bow_sweep), and the glass.
func _materials(layout: ShipLayout, bow: Vector4) -> Dictionary:
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
		material.set_shader_parameter("bow", bow)
		material.set_shader_parameter("bow_plate", ArtPalette.BOW_PLATE)
		var cabin := paint == ShipMesh.Finish.CABIN
		material.set_shader_parameter("trim_colour", ArtPalette.FRAME if cabin else ArtPalette.TEAK)
		material.set_shader_parameter(
			"foot_colour", ArtPalette.DADO if cabin else ArtPalette.HOUSE_FOOT
		)
		if cut:
			material.set_shader_parameter("cut_above", cut_above)
		if paint == ShipMesh.Finish.PLATE:
			material.set_shader_parameter("foot_colour", ArtPalette.BULKHEAD_FOOT)
		materials[paint] = material
	materials[ShipMesh.Finish.GLASS_IN] = _glass(false)
	materials[ShipMesh.Finish.GLASS_OUT] = _glass(true)
	return materials


## Glass seen from inside shows the sky; from outside it reflects the sky over the
## lamp's glow.
func _glass(outside: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GLASS_SHADER
	if outside:
		material.set_shader_parameter("outside", true)
		material.set_shader_parameter("glow_colour", ArtPalette.LAMP_LIGHT)
	if is_finite(cut_above):
		material.set_shader_parameter("cut_above", cut_above)
	return material
