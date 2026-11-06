extends GutTest
## The holes her flights leave in the Titanic's decks are railed round (#486, #489):
## wherever her deck stands along a flight's hole, either side of the flight or across its
## closed end, a railing runs along that edge or a wall lines it, so a body walks round
## the hole, not into it. Every flight, along her or across her, onto every deck she has,
## however many pieces of her deck hold the edge. Its high end, where the flight comes up,
## stays open, and so does an edge a flight up from that deck has its foot over. A flight
## that comes up past a deck's end, as her open decks' do (the generator's
## OPEN_DECK_FLIGHTS), leaves no hole in it: no piece of her deck stands along it.
##
## A hole's closed end is the flight's low end, or, where her deck stays whole over the
## flight's foot (a hole cut only over its head, up_to_f's), that deck's edge across it.

## The least a flight climbs to leave a hole a body falls into: what a body steps up.
const FLIGHT_RISE := 0.35
## How far apart along an edge it is tried, how far in from the edge's corners, and how
## far either side of it.
const STEP := 0.25
const INSET := 0.1
const OFF := 0.05
const SLACK := 0.01
## A wall at least this tall over a deck, standing within LINES of a hole's edge, lines it.
const WALL := 1.0
const LINES := 0.1

var _layout: ShipLayout


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")


## The platforms of hers at [param height].
func _decks(height: float) -> Array[ShipPlatform]:
	var found: Array[ShipPlatform] = []
	for platform: ShipPlatform in _layout.platforms:
		if absf(platform.height - height) < SLACK:
			found.append(platform)
	return found


## Whether one of [param decks] holds ship-plane point [param at].
func _deck_at(decks: Array[ShipPlatform], at: Vector2) -> bool:
	for platform: ShipPlatform in decks:
		if platform.area.has_point(at):
			return true
	return false


## Whether a railing on a deck at [param height] runs through [param at], along x when
## [param along_x], else along z.
func _railed(height: float, at: Vector2, along_x: bool) -> bool:
	for railing: ShipRailing in _layout.railings:
		if absf(_layout.platforms[railing.platform].height - height) >= SLACK:
			continue
		var a := railing.from
		var b := railing.to
		if along_x and absf(a.y - at.y) < SLACK and absf(b.y - at.y) < SLACK:
			if minf(a.x, b.x) - SLACK <= at.x and at.x <= maxf(a.x, b.x) + SLACK:
				return true
		if not along_x and absf(a.x - at.x) < SLACK and absf(b.x - at.x) < SLACK:
			if minf(a.y, b.y) - SLACK <= at.y and at.y <= maxf(a.y, b.y) + SLACK:
				return true
	return false


## Whether a flight up from a deck at [param height] has its foot over [param at].
func _foot_of_a_flight(height: float, at: Vector2) -> bool:
	for ramp: ShipRamp in _layout.ramps:
		if absf(ramp.base() - height) < SLACK and ramp.area.grow(SLACK).has_point(at):
			return true
	return false


## Whether a wall standing on a deck at [param height] lines the edge at [param at].
func _walled(height: float, at: Vector2) -> bool:
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX or blocker.top < height + WALL:
			continue
		if blocker.bottom <= height + SLACK and blocker.area.grow(LINES).has_point(at):
			return true
	return false


## Where along [param ramp] (x for a flight along her, z across) its hole's closed end
## lies: the edge of the deck in [param decks] whole over its foot, if it has one, else
## its low end.
func _closed_end(ramp: ShipRamp, decks: Array[ShipPlatform]) -> float:
	var along := 0 if ramp.axis == ShipRamp.Axis.X else 1
	var across := 1 - along
	var rising := ramp.end_height > ramp.start_height
	var sign := 1.0 if rising else -1.0
	var low := ramp.area.position[along] if rising else ramp.area.end[along]
	var high := ramp.area.end[along] if rising else ramp.area.position[along]
	var closed := low
	for platform: ShipPlatform in decks:
		var area := platform.area
		if (
			area.position[across] >= ramp.area.end[across] - SLACK
			or area.end[across] <= ramp.area.position[across] + SLACK
		):
			continue
		var near := area.end[along] if rising else area.position[along]
		if sign * (near - low) > SLACK and sign * (high - near) > SLACK:
			closed = near if sign * (near - closed) > 0.0 else closed
	return closed


## The first point of each edge of [param ramp]'s hole where her deck stands outside
## it and not inside it, and no railing runs nor wall stands: "x, z at height" each.
func _unrailed(ramp: ShipRamp) -> PackedStringArray:
	var found := PackedStringArray()
	var top := maxf(ramp.start_height, ramp.end_height)
	if top - ramp.base() < FLIGHT_RISE:
		return found
	var decks := _decks(top)
	var box := ramp.area
	var closed := _closed_end(ramp, decks)
	var rising := ramp.end_height > ramp.start_height
	var edges: Array = []  # [from, to, outward]
	if ramp.axis == ShipRamp.Axis.X:
		edges = [
			[box.position, Vector2(box.end.x, box.position.y), Vector2.UP],
			[Vector2(box.position.x, box.end.y), box.end, Vector2.DOWN],
			[
				Vector2(closed, box.position.y),
				Vector2(closed, box.end.y),
				Vector2.LEFT if rising else Vector2.RIGHT
			],
		]
	else:
		edges = [
			[box.position, Vector2(box.position.x, box.end.y), Vector2.LEFT],
			[Vector2(box.end.x, box.position.y), box.end, Vector2.RIGHT],
			[
				Vector2(box.position.x, closed),
				Vector2(box.end.x, closed),
				Vector2.UP if rising else Vector2.DOWN
			],
		]
	for edge: Array in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var outward: Vector2 = edge[2]
		var length := a.distance_to(b)
		var along_x := is_equal_approx(a.y, b.y)
		var steps := maxi(1, floori((length - 2.0 * INSET) / STEP))
		for step in steps + 1:
			var at := a.lerp(b, (INSET + (length - 2.0 * INSET) * step / steps) / length)
			if not _deck_at(decks, at + outward * OFF) or _deck_at(decks, at - outward * OFF):
				continue
			if _foot_of_a_flight(top, at) or _railed(top, at, along_x) or _walled(top, at):
				continue
			found.append("%.2f, %.2f at %.4f" % [at.x, at.y, top])
			break
	return found


func test_every_hole_a_flight_leaves_is_railed_round() -> void:
	var unrailed := PackedStringArray()
	for ramp: ShipRamp in _layout.ramps:
		unrailed.append_array(_unrailed(ramp))
	assert_eq(unrailed, PackedStringArray(), "every flight's hole railed round")
