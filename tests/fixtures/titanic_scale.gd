class_name TitanicScale
extends RefCounted
## A layout at the Titanic's scale for the spatial index's bench and tests (SH18): 270 m
## by 28 m, nine decks 2.8 m apart, each cut into nine bays. Below the top deck every bay
## of a deck has a corridor down her middle between walls with a door into each room,
## rooms 5 m long either side, her hull's sides as walls, and a stair up out of the
## corridor's port half into a hole in the deck above; the top deck is open, railed along
## both sides and her ends, with four funnels. Built the same every time, here — never in
## the menu or the Fleet — and floated high and level: nothing of her is ever wet.

const LENGTH := 270.0
const BEAM := 28.0
const DECKS := 9
## The deck at height 0, her main deck: those under it stand at negative heights.
const MAIN := 5
const DECK_SPACING := 2.8
const BAYS := 9
const ROOM := 5.0
const CORRIDOR := 1.0
const WALL := 0.2
const DOOR := 1.1
## A stair's run along her from a bay's aft end, and its stretch across the corridor.
const STAIR_FROM := 2.0
const STAIR_TO := 6.0
const FUNNELS: Array[float] = [-55.0, -25.0, 5.0, 35.0]
const FUNNEL_RADIUS := 3.0
const FUNNEL_HEIGHT := 15.0


## The layout: platforms, ramps, walls, railings and a spawn in every bay of every deck.
static func layout() -> ShipLayout:
	var made := ShipLayout.new()
	made.freeboard = DECK_SPACING * MAIN + 2.0
	made.deck_thickness = 0.3
	made.dressed = false
	for deck in DECKS:
		for bay in BAYS:
			_bay(made, deck, bay)
	var half := BEAM * 0.5
	for deck in DECKS - 1:
		var floor_height := _height(deck)
		for end: float in [-LENGTH * 0.5, LENGTH * 0.5 - WALL]:
			_wall(made, Rect2(end, -half, WALL, BEAM), floor_height)
	var top := _height(DECKS - 1)
	for x: float in FUNNELS:
		var funnel := ShipBlocker.new()
		funnel.shape = ShipBlocker.Shape.CYLINDER
		funnel.centre = Vector2(x, 0.0)
		funnel.radius = FUNNEL_RADIUS
		funnel.bottom = top
		funnel.top = top + FUNNEL_HEIGHT
		made.blockers.append(funnel)
	made.min_seats = 1
	made.max_seats = made.spawns.size()
	return made


## A sinking that never comes: she floats level for as long as a match runs.
static func scenario() -> SinkScenario:
	var made := SinkScenario.new()
	made.keyframes = [SinkKeyframe.new()]
	return made


static func _height(deck: int) -> float:
	return (deck - MAIN) * DECK_SPACING


## Bay [param bay] of deck [param deck]: its four platforms around the hole over the stair
## from the deck under it — on the bottom deck a fifth over the hole — and the rest as the
## class says.
static func _bay(made: ShipLayout, deck: int, bay: int) -> void:
	var x0 := -LENGTH * 0.5 + bay * LENGTH / BAYS
	var bay_length := LENGTH / BAYS
	var half := BEAM * 0.5
	var height := _height(deck)
	var first := made.platforms.size()
	for area: Rect2 in [
		Rect2(x0, -half, STAIR_FROM, BEAM),
		Rect2(x0 + STAIR_TO, -half, bay_length - STAIR_TO, BEAM),
		Rect2(x0 + STAIR_FROM, -half, STAIR_TO - STAIR_FROM, half - CORRIDOR),
		Rect2(x0 + STAIR_FROM, 0.0, STAIR_TO - STAIR_FROM, half),
	]:
		var platform := ShipPlatform.new()
		platform.name = StringName("d%d_b%d_%d" % [deck, bay, made.platforms.size() - first])
		platform.area = area
		platform.height = height
		made.platforms.append(platform)
	if deck == 0:
		var under_stair := ShipPlatform.new()
		under_stair.name = StringName("d0_b%d_4" % bay)
		under_stair.area = Rect2(x0 + STAIR_FROM, -CORRIDOR, STAIR_TO - STAIR_FROM, CORRIDOR)
		under_stair.height = height
		made.platforms.append(under_stair)
	if deck == DECKS - 1:
		for index: int in [0, 2, 1]:
			var area := made.platforms[first + index].area
			_railing(made, first + index, area.position, Vector2(area.end.x, area.position.y))
		for index: int in [0, 3, 1]:
			var area := made.platforms[first + index].area
			_railing(made, first + index, Vector2(area.position.x, area.end.y), area.end)
		if bay == 0:
			_railing(made, first, Vector2(x0, -half), Vector2(x0, half))
		if bay == BAYS - 1:
			_railing(
				made, first + 1, Vector2(x0 + bay_length, -half), Vector2(x0 + bay_length, half)
			)
		made.spawns.append(Vector3(x0 + bay_length * 0.5, height, half * 0.5))
		return
	var stair := ShipRamp.new()
	stair.area = Rect2(x0 + STAIR_FROM, -CORRIDOR, STAIR_TO - STAIR_FROM, CORRIDOR)
	stair.axis = ShipRamp.Axis.X
	stair.start_height = height
	stair.end_height = _height(deck + 1)
	made.ramps.append(stair)
	for side: float in [-1.0, 1.0]:
		var wall_z := CORRIDOR if side > 0.0 else -CORRIDOR - WALL
		var from := x0
		for room in roundi(bay_length / ROOM):
			var door := x0 + (room + 0.5) * ROOM
			_wall(made, Rect2(from, wall_z, door - DOOR * 0.5 - from, WALL), height)
			from = door + DOOR * 0.5
		_wall(made, Rect2(from, wall_z, x0 + bay_length - from, WALL), height)
		var room_z := CORRIDOR + WALL if side > 0.0 else -half + WALL
		var room_width := half - CORRIDOR - WALL * 2.0
		for room in roundi(bay_length / ROOM):
			var x := x0 + room * ROOM
			_wall(made, Rect2(x - WALL * 0.5, room_z, WALL, room_width), height)
		var hull_z := half - WALL if side > 0.0 else -half
		_wall(made, Rect2(x0, hull_z, bay_length, WALL), height)
	made.spawns.append(Vector3(x0 + bay_length * 0.5, height, CORRIDOR * 0.5))


## A wall over [param area] from the deck at [param floor_height] to the deck above.
static func _wall(made: ShipLayout, area: Rect2, floor_height: float) -> void:
	var wall := ShipBlocker.new()
	wall.shape = ShipBlocker.Shape.BOX
	wall.area = area
	wall.bottom = floor_height
	wall.top = floor_height + DECK_SPACING
	made.blockers.append(wall)


static func _railing(made: ShipLayout, platform: int, from: Vector2, to: Vector2) -> void:
	var railing := ShipRailing.new()
	railing.platform = platform
	railing.from = from
	railing.to = to
	made.railings.append(railing)
