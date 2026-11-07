extends GutTest
## The flights up onto the Titanic's boat deck come up clear of the boats stowed on it
## (#502). A flight's head is where a body climbing it stands up through the deck it
## comes up to: from where its top first reaches over that deck, on to a body's breadth
## of deck past the flight's high end, across the flight's breadth. No boat stands over
## any of it. Her boats are what DeckFurniture draws as boats on chocks: each a box on
## her boat deck at one of her boat stations (her LIFEBOAT fittings) on its side, out to
## the deck's edge there.

## Her boat deck's height, where her boats are stowed.
const BOAT_DECK := 8.375
const SLACK := 0.01

var _rules: BrawlRules = load("res://data/rules/brawl.tres")
var _layout: ShipLayout


func before_all() -> void:
	_layout = Fleet.layout(&"titanic")


## Whether [param blocker] stands at one of her boat stations on the side its middle lies.
func _at_a_station(blocker: ShipBlocker) -> bool:
	var side := int(signf(blocker.area.get_center().y))
	for fitting: ShipFitting in _layout.structure.fittings:
		if fitting.kind != ShipFitting.Kind.LIFEBOAT or fitting.side != side:
			continue
		if blocker.area.position.x <= fitting.x and fitting.x <= blocker.area.end.x:
			return true
	return false


## Whether [param blocker] reaches out to the edge of the boat deck under its middle.
func _out_to_the_edge(blocker: ShipBlocker) -> bool:
	var middle := blocker.area.get_center()
	var outer := blocker.area.end.y if middle.y > 0.0 else blocker.area.position.y
	for platform: ShipPlatform in _layout.platforms:
		if absf(platform.height - BOAT_DECK) > SLACK or not platform.area.has_point(middle):
			continue
		var edge := platform.area.end.y if middle.y > 0.0 else platform.area.position.y
		if absf(edge - outer) < SLACK:
			return true
	return false


## Her boats stowed on her boat deck.
func _boats() -> Array[ShipBlocker]:
	var found: Array[ShipBlocker] = []
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX or absf(blocker.bottom - BOAT_DECK) > SLACK:
			continue
		if _at_a_station(blocker) and _out_to_the_edge(blocker):
			found.append(blocker)
	return found


## The head of [param ramp], a flight up onto a deck at its high end: from where a body
## standing on it first reaches over that deck to a body's breadth past its high end,
## across its breadth.
func _head(ramp: ShipRamp) -> Rect2:
	var low := ramp.base()
	var rise := maxf(ramp.start_height, ramp.end_height) - low
	var through := clampf((rise - _rules.body_height) / rise, 0.0, 1.0)
	var past := _rules.body_radius * 2.0
	var rising := ramp.end_height > ramp.start_height
	var along := 0 if ramp.axis == ShipRamp.Axis.X else 1
	var start := ramp.area.position[along]
	var length := ramp.area.size[along]
	var from := start + length * through if rising else start - past
	var to := start + length + past if rising else start + length * (1.0 - through)
	var head := ramp.area
	head.position[along] = from
	head.size[along] = to - from
	return head


func test_her_boats_on_chocks_are_found() -> void:
	assert_eq(_boats().size(), 16, "fourteen lifeboats and two cutters on chocks")


func test_every_flight_up_onto_her_boat_deck_comes_up_clear_of_her_boats() -> void:
	var boats := _boats()
	var flights := 0
	var under := PackedStringArray()
	for ramp: ShipRamp in _layout.ramps:
		var top := maxf(ramp.start_height, ramp.end_height)
		if absf(top - BOAT_DECK) > SLACK or top - ramp.base() < SLACK:
			continue
		flights += 1
		var head := _head(ramp)
		for boat: ShipBlocker in boats:
			if head.intersects(boat.area):
				under.append("the boat at %s over the head at %s" % [boat.area, head])
	assert_gt(flights, 0, "flights up onto her boat deck")
	assert_eq(under, PackedStringArray(), "every flight's head clear of her boats")
