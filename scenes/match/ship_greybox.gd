class_name ShipGreybox
extends Node3D
## Meshes generated from the ShipLayout (D6): a plank top on every platform, its
## underside drawn as a ceiling where it stands over another, a hull block under
## every part of a platform that stands over none, a wedge for every ramp, a box or
## cylinder for every blocker — walls among them — a frame under every lintel, a
## lamp marker in every room, and a top rail on posts along every railing span. Drawn
## only — the sim never reads a mesh — and nothing is placed by hand. Nothing at or
## above [member cut_above] is drawn, so the observer can look inside. The sinking's
## events are drawn as the schedule has them: a deck about to give way flashes, a
## collapsed one falls onto the floor beneath and lies there broken, a failed railing
## is gone.

## How far the hull block reaches below the waterline of a level, unsunk ship.
const HULL_DRAFT := 2.0
const PLANK_THICKNESS := 0.06
const DECK_COLOUR := Color(0.62, 0.5, 0.36)
const HULL_COLOUR := Color(0.32, 0.3, 0.3)
## The underside of a deck that is another's ceiling.
const CEILING_COLOUR := Color(0.42, 0.4, 0.37)
const CEILING_THICKNESS := 0.04
## The forward edge of each platform, so which end is the bow reads at a glance.
const BOW_COLOUR := Color(0.75, 0.2, 0.15)
const BOW_STRIP := 0.6
const RAMP_COLOUR := Color(0.5, 0.36, 0.22)
## Boxes read as houses, walls and hatches, cylinders as funnels and masts.
const BOX_COLOUR := Color(0.86, 0.84, 0.76)
const CYLINDER_COLOUR := Color(0.2, 0.18, 0.18)
## The posts either side of a doorway, under its lintel.
const FRAME_COLOUR := Color(0.36, 0.26, 0.16)
const FRAME_WIDTH := 0.1
## How much thicker than its wall a door frame stands.
const FRAME_PROUD := 0.04
## A room's lamp: a glowing marker hanging under the middle of its ceiling (SH14b
## lights it).
const LAMP_COLOUR := Color(1.0, 0.85, 0.45)
const LAMP_SIZE := 0.25
const LAMP_DROP := 0.3
## A room's ceiling height when no deck stands over its middle.
const OPEN_ROOM_HEIGHT := 2.5
const RAIL_COLOUR := Color(0.85, 0.83, 0.78)
const RAIL_THICKNESS := 0.08
const POST_THICKNESS := 0.07
## Posts stand at both ends of a span and no farther apart than this.
const POST_SPACING := 1.5
## Size below which a leftover rectangle of hull is float noise, not hull.
const SLIVER := 0.01
## A deck about to give way: lit this colour BLINK_TICKS on and off.
const FLASH_COLOUR := Color(1.0, 0.2, 0.1)
const BLINK_TICKS := 6
## A collapsed deck takes this long to fall, and comes to rest this far above the
## floor beneath, tipped this far about the ship's length.
const FALL_SECONDS := 0.5
const WRECK_LIFT := 0.35
const WRECK_TILT := 0.25

## Ship-local height: nothing of the ship at or above it is drawn — the observer's
## cut-away (--observer-cut). INF draws everything.
var cut_above := INF

var _layout: ShipLayout
## Per platform, the node its plank, bow strip and ceiling hang from — what falls when
## it collapses — or null when the cut drew none of it.
var _decks: Array[Node3D] = []
## Per platform, the height of the floor beneath its middle: where it lands.
var _floors := PackedFloat64Array()
## Per railing, the node its rail and posts hang from, or null.
var _rails: Array[Node3D] = []
var _flash: StandardMaterial3D


## [param railing_height] is the rules' — how high every railing stands.
func build(layout: ShipLayout, railing_height: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	_layout = layout
	_decks.clear()
	_floors.clear()
	_rails.clear()
	_flash = _material(FLASH_COLOUR)
	_flash.emission_enabled = true
	_flash.emission = FLASH_COLOUR
	var hull_depth := layout.freeboard + HULL_DRAFT
	for platform: ShipPlatform in layout.platforms:
		var area := platform.area
		var centre := area.get_center()
		_floors.append(_floor_beneath(platform, layout))
		for part: Rect2 in _over_nothing(platform, layout):
			_solid(
				part,
				platform.height - PLANK_THICKNESS - hull_depth,
				platform.height - PLANK_THICKNESS,
				HULL_COLOUR
			)
		if platform.height >= cut_above:
			_decks.append(null)
			continue
		var deck := Node3D.new()
		add_child(deck)
		_decks.append(deck)
		_box(
			Vector3(area.size.x, PLANK_THICKNESS, area.size.y),
			Vector3(centre.x, platform.height - PLANK_THICKNESS * 0.5, centre.y),
			DECK_COLOUR,
			deck
		)
		if not _continues_forward(platform, layout):
			_box(
				Vector3(BOW_STRIP, PLANK_THICKNESS, area.size.y),
				Vector3(
					area.end.x - BOW_STRIP * 0.5, platform.height - PLANK_THICKNESS * 0.4, centre.y
				),
				BOW_COLOUR,
				deck
			)
		if _stands_over_a_platform(platform, layout):
			_box(
				Vector3(area.size.x, CEILING_THICKNESS, area.size.y),
				Vector3(
					centre.x, platform.height - PLANK_THICKNESS - CEILING_THICKNESS * 0.5, centre.y
				),
				CEILING_COLOUR,
				deck
			)
	for ramp: ShipRamp in layout.ramps:
		if ramp.base() < cut_above:
			_ramp(ramp)
	for blocker: ShipBlocker in layout.blockers:
		_blocker(blocker)
		_door_frame(blocker, layout)
	for room: ShipRoom in layout.rooms:
		if room.floor_height < cut_above:
			_lamp(room, layout)
	for railing: ShipRailing in layout.railings:
		var deck_height := layout.platforms[railing.platform].height
		if deck_height < cut_above:
			_rails.append(_railing(railing, deck_height, railing_height))
		else:
			_rails.append(null)


## Draws what [param schedule]'s events have done by [param tick] — fractional, as
## the view interpolates between two snapshots: a deck whose collapse is telegraphed
## flashes, a collapsed one falls FALL_SECONDS onto the floor beneath its middle and
## lies there broken, a failed railing is gone.
func show_sinking(schedule: SinkSchedule, tick: float) -> void:
	if _layout == null:
		return
	var now := floori(tick)
	var pose := schedule.pose_at(now)
	var lit := now / BLINK_TICKS % 2 == 0
	for index in _decks.size():
		var deck := _decks[index]
		if deck == null:
			continue
		deck.transform = Transform3D.IDENTITY
		var flashing := lit and _layout.platforms[index].name in pose.collapsing
		for mesh: Node in deck.get_children():
			(mesh as MeshInstance3D).material_override = _flash if flashing else null
	for scheduled: SinkSchedule.Scheduled in schedule.fired(now):
		if scheduled.event.kind != SinkEvent.Kind.COLLAPSE:
			continue
		var fallen := clampf(Ticks.to_seconds(tick - scheduled.at) / FALL_SECONDS, 0.0, 1.0)
		for index in _decks.size():
			if _decks[index] != null and _layout.platforms[index].name == scheduled.event.platform:
				_decks[index].transform = _wrecked(index, fallen)
	for index in _rails.size():
		if _rails[index] != null:
			_rails[index].visible = not index in pose.broken_railings


## Where platform [param index]'s deck is drawn [param fallen] of the way (0…1) down
## from its place to its wreck: dropped onto the floor beneath, tipped about its
## middle.
func _wrecked(index: int, fallen: float) -> Transform3D:
	var platform := _layout.platforms[index]
	var middle := platform.area.get_center()
	var pivot := Vector3(middle.x, platform.height, middle.y)
	var drop := (platform.height - _floors[index] - WRECK_LIFT) * fallen * fallen
	var tilt := Basis(Vector3.RIGHT, WRECK_TILT * fallen)
	return Transform3D(tilt, pivot - tilt * pivot + Vector3.DOWN * drop)


## The height of the highest platform under [param platform]'s middle, lower than
## it, or its own height when none is.
func _floor_beneath(platform: ShipPlatform, layout: ShipLayout) -> float:
	var middle := platform.area.get_center()
	var beneath := -INF
	for other: ShipPlatform in layout.platforms:
		if other.height < platform.height and other.contains(middle.x, middle.y):
			beneath = maxf(beneath, other.height)
	return beneath if beneath != -INF else platform.height


## Whether some lower platform lies under [param platform] — a deck on a house
## stands on that house, not on a hull of its own.
func _stands_over_a_platform(platform: ShipPlatform, layout: ShipLayout) -> bool:
	for other: ShipPlatform in layout.platforms:
		if other.height < platform.height and other.area.intersects(platform.area):
			return true
	return false


## Whether another platform at [param platform]'s height carries on from its
## forward edge — one deck in several rectangles has one bow strip, at its front.
func _continues_forward(platform: ShipPlatform, layout: ShipLayout) -> bool:
	for other: ShipPlatform in layout.platforms:
		if (
			other != platform
			and is_equal_approx(other.height, platform.height)
			and absf(other.area.position.x - platform.area.end.x) < SLIVER
			and other.area.position.y < platform.area.end.y
			and other.area.end.y > platform.area.position.y
		):
			return true
	return false


## The parts of [param platform]'s area that stand over no lower platform: where
## the hull is solid beneath it.
func _over_nothing(platform: ShipPlatform, layout: ShipLayout) -> Array[Rect2]:
	var parts: Array[Rect2] = [platform.area]
	for other: ShipPlatform in layout.platforms:
		if other.height >= platform.height:
			continue
		var left: Array[Rect2] = []
		for part: Rect2 in parts:
			left.append_array(_without(part, other.area))
		parts = left
	return parts


## [param part] less [param cover], as up to four rectangles.
func _without(part: Rect2, cover: Rect2) -> Array[Rect2]:
	var left: Array[Rect2] = []
	if not part.intersects(cover):
		left.append(part)
		return left
	var cut := part.intersection(cover)
	for piece: Rect2 in [
		Rect2(part.position.x, part.position.y, cut.position.x - part.position.x, part.size.y),
		Rect2(cut.end.x, part.position.y, part.end.x - cut.end.x, part.size.y),
		Rect2(cut.position.x, part.position.y, cut.size.x, cut.position.y - part.position.y),
		Rect2(cut.position.x, cut.end.y, cut.size.x, part.end.y - cut.end.y),
	]:
		if piece.size.x > SLIVER and piece.size.y > SLIVER:
			left.append(piece)
	return left


## A solid wedge from the ramp's lower end height up to its slope.
func _ramp(ramp: ShipRamp) -> void:
	var rise := absf(ramp.end_height - ramp.start_height)
	var along_x := ramp.axis == ShipRamp.Axis.X
	var run := ramp.area.size.x if along_x else ramp.area.size.y
	var width := ramp.area.size.y if along_x else ramp.area.size.x
	var wedge := PrismMesh.new()
	wedge.size = Vector3(run, rise, width)
	# The prism's apex stands over its +x edge at 1, its -x edge at 0.
	wedge.left_to_right = 1.0 if ramp.end_height > ramp.start_height else 0.0
	wedge.material = _material(RAMP_COLOUR)
	var instance := MeshInstance3D.new()
	instance.mesh = wedge
	var centre := ramp.area.get_center()
	instance.position = Vector3(centre.x, ramp.base() + rise * 0.5, centre.y)
	if not along_x:
		instance.rotation.y = -PI * 0.5
	add_child(instance)


## A blocker stops a plank short of its top, so a deck standing on it shows.
func _blocker(blocker: ShipBlocker) -> void:
	var top := blocker.top - PLANK_THICKNESS
	if blocker.shape == ShipBlocker.Shape.BOX:
		_solid(blocker.area, blocker.bottom, top, BOX_COLOUR)
		return
	top = minf(top, cut_above)
	if top <= blocker.bottom:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = blocker.radius
	cylinder.bottom_radius = blocker.radius
	cylinder.height = top - blocker.bottom
	cylinder.material = _material(CYLINDER_COLOUR)
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.position = Vector3(blocker.centre.x, (blocker.bottom + top) * 0.5, blocker.centre.y)
	add_child(instance)


## Under a lintel — a thin box blocker standing clear of the deck beneath it — a
## post at each end of the doorway it spans, from the deck up to it.
func _door_frame(blocker: ShipBlocker, layout: ShipLayout) -> void:
	if blocker.shape != ShipBlocker.Shape.BOX:
		return
	var area := blocker.area
	var middle := area.get_center()
	var deck := -INF
	for platform: ShipPlatform in layout.platforms:
		if platform.height <= blocker.bottom and platform.contains(middle.x, middle.y):
			deck = maxf(deck, platform.height)
	if deck == -INF or blocker.bottom <= deck or deck >= cut_above:
		return
	var along_x := area.size.x >= area.size.y
	var thickness := (area.size.y if along_x else area.size.x) + FRAME_PROUD
	for end: float in [0.0, 1.0]:
		var post := Rect2()
		if along_x:
			var x := lerpf(area.position.x, area.end.x, end)
			post = Rect2(x - FRAME_WIDTH * 0.5, middle.y - thickness * 0.5, FRAME_WIDTH, thickness)
		else:
			var z := lerpf(area.position.y, area.end.y, end)
			post = Rect2(middle.x - thickness * 0.5, z - FRAME_WIDTH * 0.5, thickness, FRAME_WIDTH)
		_solid(post, deck, blocker.bottom, FRAME_COLOUR)


## A glowing marker under the middle of [param room]'s ceiling: the lowest deck over
## its middle, or OPEN_ROOM_HEIGHT above its floor when none is.
func _lamp(room: ShipRoom, layout: ShipLayout) -> void:
	var middle := room.area.get_center()
	var ceiling := room.floor_height + OPEN_ROOM_HEIGHT
	for platform: ShipPlatform in layout.platforms:
		if platform.height > room.floor_height and platform.contains(middle.x, middle.y):
			ceiling = minf(ceiling, platform.height)
	var lamp := _box(
		Vector3(LAMP_SIZE, LAMP_SIZE, LAMP_SIZE),
		Vector3(middle.x, ceiling - LAMP_DROP, middle.y),
		LAMP_COLOUR
	)
	var glow: StandardMaterial3D = (lamp.mesh as BoxMesh).material
	glow.emission_enabled = true
	glow.emission = LAMP_COLOUR


## The top rail along [param railing]'s span and posts under it, standing on a
## deck at [param deck_height], hung from the node returned.
func _railing(railing: ShipRailing, deck_height: float, railing_height: float) -> Node3D:
	var rail := Node3D.new()
	add_child(rail)
	var span := railing.to - railing.from
	var turn := Basis(Vector3.UP, -span.angle())
	var top := deck_height + railing_height - RAIL_THICKNESS * 0.5
	var middle := (railing.from + railing.to) * 0.5
	var bar := _box(
		Vector3(span.length(), RAIL_THICKNESS, RAIL_THICKNESS),
		Vector3(middle.x, top, middle.y),
		RAIL_COLOUR,
		rail
	)
	bar.basis = turn
	var posts := ceili(span.length() / POST_SPACING)
	for index in posts + 1:
		var at := railing.from + span * (float(index) / posts)
		_box(
			Vector3(POST_THICKNESS, railing_height, POST_THICKNESS),
			Vector3(at.x, deck_height + railing_height * 0.5, at.y),
			RAIL_COLOUR,
			rail
		)
	return rail


## A box over [param footprint] (x/z) from [param bottom] to [param top], cut short
## at the cut-away; nothing when the cut leaves none of it.
func _solid(footprint: Rect2, bottom: float, top: float, colour: Color) -> void:
	top = minf(top, cut_above)
	if top <= bottom:
		return
	var centre := footprint.get_center()
	_box(
		Vector3(footprint.size.x, top - bottom, footprint.size.y),
		Vector3(centre.x, (bottom + top) * 0.5, centre.y),
		colour
	)


## A box of [param size] centred [param at], hung from [param parent], or from the
## greybox itself without one.
func _box(size: Vector3, at: Vector3, colour: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(colour)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	(parent if parent != null else self).add_child(instance)
	return instance


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
