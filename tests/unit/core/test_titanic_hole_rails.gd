extends GutTest
## The holes her flights leave in the Titanic's decks are railed round (#486): wherever
## one piece of her deck has a flight's hole along its edge, either side of the flight or
## across its low end, a railing runs along that edge or a wall lines it, so a body walks
## round the hole, not into it. Its high end, where the flight comes up, stays open, and so
## does an edge a flight up from that deck has its foot over. A flight that comes up past a
## deck's end, as her open decks' do (the generator's OPEN_DECK_FLIGHTS), leaves no hole
## in it: no piece of her deck has an edge along it.
##
## Held for the flights her generator rails round (hole_rails): those rising along her,
## onto her decks from F deck up, along an edge one piece of her deck holds whole. Her
## flights across her, those onto her decks under F deck and edges over two pieces: #489.

## The lowest deck held.
const F_DECK := -8.5625
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


## Whether a platform of hers at [param height] holds ship-plane point [param at].
func _deck_at(height: float, at: Vector2) -> bool:
	for platform: ShipPlatform in _layout.platforms:
		if absf(platform.height - height) < SLACK and platform.area.has_point(at):
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


## Whether a flight up from a deck at [param height] has its foot over the edge from
## [param a] to [param b].
func _foot_of_a_flight(height: float, a: Vector2, b: Vector2) -> bool:
	var edge := Rect2(a, Vector2.ZERO).expand(b).grow(SLACK)
	for ramp: ShipRamp in _layout.ramps:
		if absf(ramp.base() - height) < SLACK and ramp.area.intersects(edge):
			return true
	return false


## Whether one platform of hers at [param height] has the whole edge from [param a] to
## [param b] along its own edge.
func _deck_edge(height: float, a: Vector2, b: Vector2) -> bool:
	for platform: ShipPlatform in _layout.platforms:
		if absf(platform.height - height) < SLACK and platform.edge_holds(a, b):
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


## The first point of each edge of [param ramp]'s hole where her deck stands outside
## it and not inside it, and no railing runs nor wall stands: "x, z at height" each.
func _unrailed(ramp: ShipRamp) -> PackedStringArray:
	var top := maxf(ramp.start_height, ramp.end_height)
	var box := ramp.area
	var low := box.position.x if ramp.end_height > ramp.start_height else box.end.x
	var edges: Array = [  # [from, to, outward]
		[box.position, Vector2(box.end.x, box.position.y), Vector2.UP],
		[Vector2(box.position.x, box.end.y), box.end, Vector2.DOWN],
		[
			Vector2(low, box.position.y),
			Vector2(low, box.end.y),
			Vector2.RIGHT if low == box.end.x else Vector2.LEFT
		],
	]
	var found := PackedStringArray()
	for edge: Array in edges:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var outward: Vector2 = edge[2]
		if not _deck_edge(top, a, b) or _foot_of_a_flight(top, a, b):
			continue
		var length := a.distance_to(b)
		var along_x := is_equal_approx(a.y, b.y)
		var steps := maxi(1, floori((length - 2.0 * INSET) / STEP))
		for step in steps + 1:
			var at := a.lerp(b, (INSET + (length - 2.0 * INSET) * step / steps) / length)
			if not _deck_at(top, at + outward * OFF) or _deck_at(top, at - outward * OFF):
				continue
			if _railed(top, at, along_x) or _walled(top, at):
				continue
			found.append("%.2f, %.2f at %.4f" % [at.x, at.y, top])
			break
	return found


func test_every_hole_a_flight_leaves_is_railed_round() -> void:
	var unrailed := PackedStringArray()
	for ramp: ShipRamp in _layout.ramps:
		if ramp.axis == ShipRamp.Axis.X and maxf(ramp.start_height, ramp.end_height) >= F_DECK:
			unrailed.append_array(_unrailed(ramp))
	assert_eq(unrailed, PackedStringArray(), "every flight's hole railed round")
