class_name DeckLights
extends RefCounted
## The lights on her open decks at dusk (ShipArt), placed by rules on the layout, never
## by hand (D6): a lamp over every door out onto an open deck — each door in a
## break's face (ShipFittings.break_doors) and each doorway in a deckhouse wall with a
## room on its one side and the sky over the other — a red sidelight in a screen board
## on the port wall of every helm (RoomDressing.Kind.HELM) and a green one on its
## starboard wall, and a white stern light on her ensign staff. Each glows through a
## mesh of its own, as the masthead light does (DeckWorks.mast): her open decks are on
## ShipMesh.OUTDOOR_LAYER, which no lamp lights, so they glow and light nothing. Each
## goes out with the power of the cell behind it, or once its water reaches it
## (show_power).
## Where a body walks, under HEADROOM (RoomDressing.HEADROOM, 1.85 m over whatever a
## body stands on near it), nothing of a light stands more than
## FurnishingCheck.TOLERANCE (0.12 m) out from its wall: a door lamp, which reaches
## further, hangs wholly over it — where it cannot, a flat bulkhead lamp stands beside
## the door instead — the sidelights are flat, and the stern light hangs over it.

enum Kind { DOOR, BULKHEAD, PORT, STARBOARD, STERN }

## A door lamp, in its own space — its origin on the wall's face (a doorway's, on its
## frame's head) at its back plate's middle, x along the wall, y up, z out of it: the
## back plate, how deep; the arm out from it to the globe's axis, its section; the
## globe's radius and its middle LAMP_DROP under the arm; the cap over the globe; the
## cage's bars round it, their section, meeting LAMP_CAGE under the globe; and its box
## over all there.
const LAMP_PLATE := Vector2(0.1, 0.08)
const LAMP_PLATE_DEPTH := 0.02
const LAMP_REACH := 0.18
const LAMP_ARM := 0.025
const LAMP_GLOBE := 0.055
const LAMP_DROP := 0.1
const LAMP_CAP := Vector3(0.1, 0.03, 0.1)
const LAMP_BAR := 0.012
const LAMP_CAGE := 0.015
const LAMP_BOX := AABB(Vector3(-0.075, -0.18, 0.0), Vector3(0.15, 0.22, 0.26))
## A break door's lamp hangs this far under its face's cap rail
## (ShipFittings.CAP_DEPTH); the deck over the face is found INBOARD in from it.
const UNDER_CAP := 0.02
const INBOARD := 0.05
## A sidelight, in its own space — its origin at its screen board's middle on the
## wall's face, x along it, y up, z out — and all of it within LANTERN_DEPTH of that
## face: the screen board, its size and how deep; the lantern's body on it, its size
## and its middle's height over the origin; its cap; its glass on its face, its size
## and how thick. The stern light is the same lantern without its board, its origin
## on the ensign staff's after side (ShipHull.staff) at its foot's middle, standing on
## a bracket STERN_PLINTH deep, STERN_OVER over HEADROOM above the deck.
const SCREEN := Vector2(0.4, 0.34)
const SCREEN_DEPTH := 0.02
const LANTERN := Vector3(0.16, 0.2, 0.06)
const LANTERN_LIFT := -0.02
const LANTERN_CAP := Vector3(0.2, 0.025, 0.075)
const LANTERN_GLASS := Vector3(0.11, 0.13, 0.01)
const LANTERN_DEPTH := SCREEN_DEPTH + LANTERN.z + LANTERN_GLASS.z
const STERN_PLINTH := 0.04
const STERN_OVER := 0.05
## A sidelight's screen stands with its top SIDELIGHT_UNDER under its wall's head and
## SIDELIGHT_MARGIN clear of the wall's ends and of any glass in it, as far forward as
## it can, tried SIDELIGHT_STEP at a time aft.
const SIDELIGHT_UNDER := 0.1
const SIDELIGHT_MARGIN := 0.15
const SIDELIGHT_STEP := 0.1
## A bulkhead lamp, flat on the wall beside a door with no room for one over it — in
## its own space, its origin on the wall's face at its back plate's middle, x along it,
## y up, z out — and all of it within BULKHEAD_DEPTH of the face: the back plate, its
## size; the half globe of glass on it, its radius; the cage's bars crossing over it,
## their section; BULKHEAD_GAP between its plate and the door's frame (a doorway's,
## ShipArt.FRAME_WIDTH; a break door's box, ShipFittings.BREAK_DOOR_BOX), and its
## middle BULKHEAD_HEIGHT over the deck.
const BULKHEAD_PLATE := Vector2(0.12, 0.16)
const BULKHEAD_GLOBE := 0.05
const BULKHEAD_BAR := 0.012
const BULKHEAD_DEPTH := LAMP_PLATE_DEPTH + BULKHEAD_GLOBE + BULKHEAD_BAR * 1.5
const BULKHEAD_GAP := 0.06
const BULKHEAD_HEIGHT := 1.45
## A hanging door lamp stands clear of every deck whose edge is within DECK_NEAR of it:
## its top DECK_CLEAR under it, more than a step, or its lowest point over it by more
## than a jump — never a ledge past the deck's edge that looks like a step off it
## (art-lint's false floors).
const DECK_NEAR := 1.0
const DECK_CLEAR := 0.4
const DECK_OVER := 1.0
## A door is lit only where the deck before it lies open to the sky SKY_OUT out from
## it: not a door under the decks.
const SKY_OUT := 1.2
## The point a light's power and water are read at (show_power): BEHIND in from its
## wall, BEHIND_UP over the floor behind it — a body's middle — or, for the stern
## light, BEHIND under its deck.
const BEHIND := 0.3
const BEHIND_UP := 1.0
## Its glass's glow on her generator, the share of it on her emergency power
## (ShipLamp.EMERGENCY_GLOW), and the glass unlit: its colour this much darkened.
const GLOW_ENERGY := 2.0
const UNLIT := 0.7

## Per light: what it is, where it stands (its own space's origin and turn, in ship
## space), the middle of its glass, and the point its power is read at.
var kinds: Array[Kind] = []
var places: Array[Transform3D] = []
var glasses := PackedVector3Array()
var behinds := PackedVector3Array()

var _space: ShipSpace
## How near a body's centre comes to a wall: how far round a lamp what a body stands on
## is looked for.
var _reach: float
## Her glass (ShipFittings.panes), which a bulkhead lamp keeps clear of.
var _panes: Array[Array] = []
## Per light, its glass's own material, and the glow it was last shown at.
var _materials: Array[StandardMaterial3D] = []
var _glows := PackedFloat32Array()


## Finds where [param space]'s lights go: a lamp over each of [param break_doors]
## (ShipFittings.break_doors) and each outdoor doorway, clear of the bodies of
## [param body_radius]; the sidelights clear of [param panes] (ShipFittings.panes); the
## stern light on the ensign staff over the after rail [param railing_height] tall.
func _init(
	space: ShipSpace,
	railing_height: float,
	body_radius: float,
	break_doors: Array[Array],
	panes: Array[Array]
) -> void:
	_space = space
	_reach = body_radius
	_panes = panes
	for door: Array in break_doors:
		_break_lamp(door[0], door[1])
	for blocker: ShipBlocker in space.layout.blockers:
		_doorway_lamp(blocker)
	for room: ShipRoom in space.layout.rooms:
		if RoomDressing.kind_of(space, room) == RoomDressing.Kind.HELM:
			_sidelight(room, 0, Kind.PORT, panes)
			_sidelight(room, 2, Kind.STARBOARD, panes)
	_stern_light(railing_height)


## The colour [param kind]'s glass glows.
static func colour_of(kind: Kind) -> Color:
	match kind:
		Kind.PORT:
			return ArtPalette.PORT_LIGHT
		Kind.STARBOARD:
			return ArtPalette.STARBOARD_LIGHT
		Kind.STERN:
			return ArtPalette.STERN_LIGHT
	return ArtPalette.LAMP_GLASS


## Draws every light under a node of its own under [param art], in its
## [param materials] (ShipArt.paints()): none standing off [param span] nor at or over
## [param cut_above].
func build(art: Node3D, materials: Dictionary, cut_above: float, span: Vector2) -> void:
	var node := Node3D.new()
	node.name = "DeckLights"
	art.add_child(node)
	var mesh := ShipMesh.new(func(_point: Vector3) -> bool: return true, _space.room_lines())
	mesh.cut_above = cut_above
	mesh.keep = span
	var globe := SphereMesh.new()
	globe.radius = LAMP_GLOBE
	globe.height = LAMP_GLOBE * 2.0
	globe.radial_segments = 12
	globe.rings = 6
	var dome := SphereMesh.new()
	dome.radius = BULKHEAD_GLOBE
	dome.height = BULKHEAD_GLOBE
	dome.is_hemisphere = true
	dome.radial_segments = 12
	dome.rings = 4
	var pane := BoxMesh.new()
	pane.size = LANTERN_GLASS
	for index in kinds.size():
		var place := places[index]
		if kinds[index] == Kind.DOOR:
			_lamp(mesh, place)
		elif kinds[index] == Kind.BULKHEAD:
			_bulkhead(mesh, place)
		else:
			_lantern(mesh, place, kinds[index])
		var glow := MeshInstance3D.new()
		glow.name = "%s%d" % [Kind.keys()[kinds[index]].capitalize(), index]
		glow.mesh = pane
		var turn := place.basis
		if kinds[index] == Kind.DOOR:
			glow.mesh = globe
		elif kinds[index] == Kind.BULKHEAD:
			# The half globe's dome turned out of the face.
			glow.mesh = dome
			turn = turn * Basis(Vector3.RIGHT, PI * 0.5)
		glow.material_override = _materials[index]
		glow.transform = Transform3D(turn, glasses[index])
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = glasses[index].y < cut_above and PieceClip.holds(span, glasses[index].x)
		node.add_child(glow)
	mesh.commit(node, materials)


## Lights each light as [param pose] has the cell behind it lit — on her generator,
## dimmer on her emergency power, out on nothing (ShipPose.lit) — and puts out each the
## water of that cell has reached. A pose without cells leaves them as they were.
func show_power(pose: ShipPose) -> void:
	if pose.lit.is_empty():
		return
	for index in kinds.size():
		var cell := pose.cell_at(behinds[index])
		if cell == CellMap.NONE:
			continue
		var glow := 0.0
		match pose.lit[cell]:
			ShipPower.Power.MAIN:
				glow = 1.0
			ShipPower.Power.EMERGENCY:
				glow = ShipLamp.EMERGENCY_GLOW
		if pose.levels[cell] >= pose.world_height(glasses[index]):
			glow = 0.0
		_show(index, glow)


## How brightly (0…1) light [param index] glows now.
func glow_of(index: int) -> float:
	return _glows[index]


## Light [param index]'s glass glowing [param glow] (0…1) of its full glow, only as
## that changes.
func _show(index: int, glow: float) -> void:
	if _glows[index] == glow:
		return
	_glows[index] = glow
	var colour := colour_of(kinds[index])
	var material := _materials[index]
	material.albedo_color = colour.darkened(UNLIT).lerp(colour, glow)
	material.emission_energy_multiplier = GLOW_ENERGY * glow


## A lamp over the door at [param sill] (the foot of its sill's middle) in a break's
## face, facing [param normal], under the face's cap rail.
func _break_lamp(sill: Vector3, normal: Vector3) -> void:
	var inboard := Vector2(sill.x - normal.x * INBOARD, sill.z - normal.z * INBOARD)
	var head := INF
	for platform: ShipPlatform in _space.layout.platforms:
		if (
			platform.height > sill.y + ShipFittings.BREAK_LEAST
			and platform.contains(inboard.x, inboard.y)
		):
			head = minf(head, platform.height)
	if head == INF:
		return
	var mount := head - ShipFittings.CAP_DEPTH - UNDER_CAP - LAMP_PLATE.y * 0.5
	mount = minf(mount, head - DECK_CLEAR - LAMP_BOX.end.y - ShipSpace.SLIVER)
	var over := Vector3(sill.x, mount, sill.z)
	var turn := RoomDressing.facing(normal)
	var aside := ShipFittings.BREAK_DOOR_BOX.end.x + BULKHEAD_GAP + BULKHEAD_PLATE.x * 0.5
	var beside := sill + turn.x * aside + Vector3.UP * BULKHEAD_HEIGHT
	var behind := sill - normal * BEHIND + Vector3.UP * BEHIND_UP
	# A break's face is its deck's edge, no wall: the door's own stretch of it.
	_door_lamp(over, beside, normal, sill.y, behind, false)


## A lamp over the doorway under [param lintel], when it heads one as ShipArt frames
## it (ShipArt._door_frame) with a room on its one side and the sky over the other: on
## the frame's head on its outdoor face, or beside the frame.
func _doorway_lamp(lintel: ShipBlocker) -> void:
	if not _space.is_wall(lintel):
		return
	var area := lintel.area
	var middle := area.get_center()
	var deck := _space.deck_under(middle, lintel.bottom)
	if is_nan(deck) or lintel.bottom - deck <= ShipArt.DOOR_FROM:
		return
	var along_x := area.size.x >= area.size.y
	for end: float in [0.0, 1.0]:
		var post := (
			Vector2(lerpf(area.position.x, area.end.x, end), middle.y)
			if along_x
			else Vector2(middle.x, lerpf(area.position.y, area.end.y, end))
		)
		if not is_equal_approx(_space.deck_under(post, lintel.bottom), deck):
			return
	var half := (area.size.y if along_x else area.size.x) * 0.5
	var across := Vector3.BACK if along_x else Vector3.RIGHT
	var centre := Vector3(middle.x, deck + BEHIND_UP, middle.y)
	for side: float in [-1.0, 1.0]:
		var out := across * side
		if not _space.outdoors(centre + out * (half + BEHIND)):
			continue
		if _space.outdoors(centre - out * (half + BEHIND)):
			return
		var head := minf(ShipArt.FRAME_WIDTH, lintel.top - lintel.bottom)
		var face := Vector3(middle.x, lintel.bottom + head * 0.5, middle.y)
		var over := face + out * (half + ShipArt.FRAME_PROUD)
		var length := (area.size.x if along_x else area.size.y) * 0.5
		var aside := length + ShipArt.FRAME_WIDTH * 0.5 + BULKHEAD_GAP + BULKHEAD_PLATE.x * 0.5
		var beside := Vector3(middle.x, deck + BULKHEAD_HEIGHT, middle.y) + out * half
		beside += RoomDressing.facing(out).x * aside
		_door_lamp(over, beside, out, deck, centre - out * (half + BEHIND), true)
		return


## A door's lamp before a deck at [param deck] open to the sky, facing [param out], its
## power read at [param behind]: hung at [param over] where it hangs wholly over
## HEADROOM above all a body stands on near it and clear of the decks (DECK_NEAR), else
## a bulkhead lamp flat on the face at [param beside], or as far the door's other side
## — where it stands clear of her glass, and a wall stands behind it when
## [param on_a_wall].
func _door_lamp(
	over: Vector3, beside: Vector3, out: Vector3, deck: float, behind: Vector3, on_a_wall: bool
) -> void:
	if not _open_to_the_sky(over + out * SKY_OUT, deck):
		return
	var turn := RoomDressing.facing(out)
	var place := Transform3D(turn, over)
	var lowest := over.y + LAMP_BOX.position.y
	var foot := Rect2(Vector2(over.x, over.z), Vector2.ZERO)
	for corner in 8:
		var point := place * LAMP_BOX.get_endpoint(corner)
		foot = foot.expand(Vector2(point.x, point.z))
	var top := over.y + LAMP_BOX.end.y
	if (
		lowest >= _standing(foot.grow(_reach), lowest) + RoomDressing.HEADROOM
		and _clear_of_decks(foot.grow(DECK_NEAR), lowest, top)
	):
		_add(Kind.DOOR, place, place * Vector3(0.0, -LAMP_DROP, LAMP_REACH), behind)
		return
	var out2 := Vector2(out.x, out.z)
	var aside := (beside - over).dot(turn.x)
	for at: Vector3 in [beside, beside - turn.x * aside * 2.0]:
		var face := Vector2(at.x, at.z) + out2 * ShipSpace.SLIVER
		if on_a_wall and not _space.walled(face, -out2, at.y, ShipSpace.WALL_MAX):
			continue
		if not _clear_of_panes(out, at, BULKHEAD_PLATE):
			continue
		# Not where a body stands higher than the door's deck by it: a hatch's cover, a stair.
		var by := Rect2(Vector2(at.x, at.z), Vector2.ZERO).grow(_reach)
		if _standing(by, at.y) > deck + RoomDressing.HEADROOM - BULKHEAD_HEIGHT:
			continue
		place = Transform3D(turn, at)
		_add(Kind.BULKHEAD, place, place * Vector3(0.0, 0.0, LAMP_PLATE_DEPTH), behind)
		return


## Whether a fitting of [param size] at [param at] on a wall facing [param out] stands
## SIDELIGHT_MARGIN clear of every pane of her glass in that wall.
func _clear_of_panes(out: Vector3, at: Vector3, size: Vector2) -> bool:
	var right := RoomDressing.facing(out).x
	for pane: Array in _panes:
		var centre: Vector3 = pane[1]
		if not (pane[2] as Vector3).is_equal_approx(-out):
			continue
		if absf((centre - at).dot(out)) > ShipSpace.WALL_MAX + SIDELIGHT_MARGIN:
			continue
		var apart := Vector2(absf((centre - at).dot(right)), absf(centre.y - at.y))
		var reach := size * 0.5 + (pane[4] as Vector2) + Vector2.ONE * SIDELIGHT_MARGIN
		if apart.x < reach.x and apart.y < reach.y:
			return false
	return true


## Whether no deck over [param area] stands between [param lowest] less DECK_OVER and
## [param top] and DECK_CLEAR.
func _clear_of_decks(area: Rect2, lowest: float, top: float) -> bool:
	for platform: ShipPlatform in _space.layout.platforms:
		var height := platform.height
		if height > lowest - DECK_OVER and height < top + DECK_CLEAR:
			if platform.area.intersects(area):
				return false
	return true


## The highest top under [param height] of anything a body may stand on over
## [param area]: a deck, a stair, a blocker — a door's sill.
func _standing(area: Rect2, height: float) -> float:
	var highest := -INF
	for platform: ShipPlatform in _space.layout.platforms:
		if platform.height < height and platform.area.intersects(area):
			highest = maxf(highest, platform.height)
	for ramp: ShipRamp in _space.layout.ramps:
		var top := maxf(ramp.start_height, ramp.end_height)
		if top < height and ramp.area.intersects(area):
			highest = maxf(highest, top)
	for blocker: ShipBlocker in _space.layout.blockers:
		var reach := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			var radius := Vector2.ONE * blocker.radius
			reach = Rect2(blocker.centre - radius, radius * 2.0)
		if blocker.top < height and reach.intersects(area):
			highest = maxf(highest, blocker.top)
	return highest


## Whether no deck stands over ship point [param point] higher than [param deck].
func _open_to_the_sky(point: Vector3, deck: float) -> bool:
	for platform: ShipPlatform in _space.layout.platforms:
		if platform.height > deck + ShipSpace.SLIVER and platform.contains(point.x, point.z):
			return false
	return true


## [param room]'s sidelight of [param kind] on its wall on [param side] (0 its least
## z, port; 2 its greatest, starboard): on the wall's outside face, its screen's top
## SIDELIGHT_UNDER under the wall's head, as far forward along it as it stands on the
## wall clear of its glass ([param panes]); none where the face looks into a room.
func _sidelight(room: ShipRoom, side: int, kind: Kind, panes: Array[Array]) -> void:
	var out2 := ShipSpace.outward(side)
	var out := Vector3(out2.x, 0.0, out2.y)
	for run: Array in _space.wall_runs(room):
		if run[0] != side:
			continue
		var half: float = run[3]
		var along: float = run[2] - SIDELIGHT_MARGIN - SCREEN.x * 0.5
		while along >= run[1] + SIDELIGHT_MARGIN + SCREEN.x * 0.5:
			var foot := _space.on_side(room, side, along, -half)
			var head := _space.ceiling(room, foot.x, foot.y)
			var middle := head - SIDELIGHT_UNDER - SCREEN.y * 0.5
			var at := Vector3(foot.x, middle, foot.y)
			if _clear_of_glass(room, out, at, panes) and _space.outdoors(at + out * BEHIND):
				var place := Transform3D(RoomDressing.facing(out), at)
				var glass := (
					place * Vector3(0.0, LANTERN_LIFT, LANTERN_DEPTH - LANTERN_GLASS.z * 0.5)
				)
				var behind := Vector3(foot.x, room.floor_height + BEHIND_UP, foot.y)
				_add(kind, place, glass, behind - out * (half + BEHIND))
				return
			along -= SIDELIGHT_STEP


## Whether a screen board at [param at] on [param room]'s wall facing [param out]
## stands SIDELIGHT_MARGIN clear of every pane of [param panes] in that wall.
func _clear_of_glass(room: ShipRoom, out: Vector3, at: Vector3, panes: Array[Array]) -> bool:
	var right := RoomDressing.facing(out).x
	for pane: Array in panes:
		if pane[0] != room or not (pane[2] as Vector3).is_equal_approx(-out):
			continue
		var centre: Vector3 = pane[1]
		var size: Vector2 = pane[4]
		var apart := Vector2(absf((centre - at).dot(right)), absf(centre.y - at.y))
		var reach := SCREEN * 0.5 + size + Vector2.ONE * SIDELIGHT_MARGIN
		if apart.x < reach.x and apart.y < reach.y:
			return false
	return true


## The stern light, white, on the ensign staff over her after rail — the railing
## across her decks' aft end, across her middle line, as ShipHull.staff steps it there
## — on its after side, STERN_OVER over HEADROOM above the deck, facing aft; its power
## read under that deck.
func _stern_light(railing_height: float) -> void:
	var end := INF
	for platform: ShipPlatform in _space.layout.platforms:
		end = minf(end, platform.area.position.x)
	for railing: ShipRailing in _space.layout.railings:
		if not (is_equal_approx(railing.from.x, end) and is_equal_approx(railing.to.x, end)):
			continue
		if minf(railing.from.y, railing.to.y) > 0.0 or maxf(railing.from.y, railing.to.y) <= 0.0:
			continue
		var deck := _space.layout.platforms[railing.platform].height
		var foot := deck + RoomDressing.HEADROOM + STERN_OVER
		var staff := end - ShipArt.POST * 0.5 - ShipHull.STAFF_RADIUS * 2.0
		if foot + LANTERN.y + LANTERN_CAP.y > deck + railing_height + ShipHull.STAFF_HEIGHT:
			return
		var place := Transform3D(RoomDressing.facing(Vector3.LEFT), Vector3(staff, foot, 0.0))
		var glass := place * Vector3(0.0, STERN_PLINTH + LANTERN.y * 0.5, LANTERN.z)
		glass += place.basis.z * LANTERN_GLASS.z * 0.5
		_add(Kind.STERN, place, glass, Vector3(end + BEHIND, deck - BEHIND, 0.0))
		return


func _add(kind: Kind, place: Transform3D, glass: Vector3, behind: Vector3) -> void:
	kinds.append(kind)
	places.append(place)
	glasses.append(glass)
	behinds.append(behind)
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = colour_of(kind)
	_materials.append(material)
	_glows.append(-1.0)
	_show(kinds.size() - 1, 1.0)


## A door lamp's bracket, placed by [param place]: its back plate, its arm, the cap
## over its globe and the cage's bars round it (LAMP_PLATE…).
func _lamp(mesh: ShipMesh, place: Transform3D) -> void:
	var plate := Vector3(LAMP_PLATE.x, LAMP_PLATE.y, LAMP_PLATE_DEPTH)
	mesh.turned_box(
		place.translated_local(Vector3(0.0, 0.0, LAMP_PLATE_DEPTH * 0.5)), plate, ShipPaints.brass
	)
	mesh.beam(
		place * Vector3(0.0, 0.0, LAMP_PLATE_DEPTH),
		place * Vector3(0.0, 0.0, LAMP_REACH + LAMP_ARM * 0.5),
		Vector2.ONE * LAMP_ARM,
		ShipPaints.brass
	)
	var top := -LAMP_DROP + LAMP_GLOBE
	var cap := Vector3(0.0, top + LAMP_CAP.y * 0.5, LAMP_REACH)
	mesh.turned_box(place.translated_local(cap), LAMP_CAP, ShipPaints.brass)
	var foot := place * Vector3(0.0, -LAMP_DROP - LAMP_GLOBE - LAMP_CAGE, LAMP_REACH)
	var drop := place * Vector3(0.0, top + LAMP_CAP.y, LAMP_REACH)
	mesh.beam(drop, place * Vector3(0.0, 0.0, LAMP_REACH), Vector2.ONE * LAMP_BAR, ShipPaints.brass)
	var reach := LAMP_GLOBE + LAMP_BAR
	for corner: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var side := Vector3(corner.x * reach, -LAMP_DROP, LAMP_REACH + corner.y * reach)
		mesh.beam(
			place * Vector3(side.x, top, side.z),
			place * side,
			Vector2.ONE * LAMP_BAR,
			ShipPaints.brass
		)
		mesh.beam(place * side, foot, Vector2.ONE * LAMP_BAR, ShipPaints.brass)


## A bulkhead lamp's plate and cage placed by [param place] (BULKHEAD_PLATE…).
func _bulkhead(mesh: ShipMesh, place: Transform3D) -> void:
	var plate := Vector3(BULKHEAD_PLATE.x, BULKHEAD_PLATE.y, LAMP_PLATE_DEPTH)
	var middle := Vector3(0.0, 0.0, LAMP_PLATE_DEPTH * 0.5)
	mesh.turned_box(place.translated_local(middle), plate, ShipPaints.brass)
	var crown := place * Vector3(0.0, 0.0, LAMP_PLATE_DEPTH + BULKHEAD_GLOBE + BULKHEAD_BAR * 0.5)
	var reach := BULKHEAD_GLOBE + BULKHEAD_BAR
	for end: Vector2 in [
		Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)
	]:
		var foot := place * Vector3(end.x, end.y, LAMP_PLATE_DEPTH)
		mesh.beam(foot, crown, Vector2.ONE * BULKHEAD_BAR, ShipPaints.brass)


## A lantern of [param kind] placed by [param place]: a sidelight on its screen board,
## painted its colour; the stern light on its bracket on the staff.
func _lantern(mesh: ShipMesh, place: Transform3D, kind: Kind) -> void:
	var body := Vector3(0.0, LANTERN_LIFT, SCREEN_DEPTH + LANTERN.z * 0.5)
	if kind == Kind.STERN:
		body = Vector3(0.0, STERN_PLINTH + LANTERN.y * 0.5, LANTERN.z * 0.5)
		var plinth := Vector3(LANTERN_CAP.x, STERN_PLINTH, LANTERN_CAP.z)
		var foot := Vector3(0.0, STERN_PLINTH * 0.5, LANTERN_CAP.z * 0.5)
		mesh.turned_box(place.translated_local(foot), plinth, ShipPaints.dark)
	else:
		var board := ShipMesh.Paint.new(ShipMesh.Finish.PLAIN, colour_of(kind).darkened(0.45))
		var screen := Vector3(SCREEN.x, SCREEN.y, SCREEN_DEPTH)
		var middle := Vector3(0.0, 0.0, SCREEN_DEPTH * 0.5)
		mesh.turned_box(place.translated_local(middle), screen, board)
	mesh.turned_box(place.translated_local(body), LANTERN, ShipPaints.dark)
	var cap := body + Vector3(0.0, (LANTERN.y + LANTERN_CAP.y) * 0.5, 0.0)
	mesh.turned_box(place.translated_local(cap), LANTERN_CAP, ShipPaints.dark)
