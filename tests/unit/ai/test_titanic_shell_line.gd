extends GutTest
## No body walks out through the line of the Titanic's shell (#573), and none walks off a
## flight's side further down than a step (#574). Where her plates draw shell plating or a
## bulwark along a deck's edge, it holds a body; where they draw an open rail, a railing
## stands. A body walked into the sea off B deck forward of its house, off C deck under her
## poop and her forecastle and off the outboard sides of the A deck ladders down to the
## forward well, and off No. 2 hold's ladders into the void past the tank top's floor: walks
## a bot reaches. Her stairs and ladders were railed along every open side, and an escape
## ladder ran in its own cased way: a body stepped off the side of 34 of her flights and
## fell as far as 7.2 m, off her boiler rooms' escape ladders onto the stokehold floor. So
## every walk a body sets out on along her — off each side of each of her floors a metre
## apart, off each side of each of her flights at its quarters, half a metre in from the
## edge, straight out of it — from where the walk graph reaches from her first spawn ends
## out of the sea, and none off a flight falls further than a step: on her and on her
## sisters. Within a body's breadth of a flight's end, where it meets a floor or another
## flight, the way off it there stays a body wide: a walk off its side there may come down
## further than a step, never further than a metre.

const SHIPS: Array[String] = [
	"res://data/ships/titanic.tres",
	"res://tests/fixtures/ships/titanic_britannic.tres",
	"res://tests/fixtures/ships/titanic_olympic_1913.tres",
]
## Per ship of SHIPS, by its path: what went wrong on its walks (ShipWalks.gone_wrong).
var _walked_on := {}
var _walks := ShipWalks.new()


func before_all() -> void:
	for path: String in SHIPS:
		_walked_on[path] = _walks.gone_wrong(load(path))


func test_no_walk_on_her_leaves_her_shell() -> void:
	for path: String in SHIPS:
		assert_eq(
			ShipWalks.ending(_walked_on[path], "", " ends swimming "), PackedStringArray(), path
		)


func test_no_walk_off_her_flights_sides_falls_past_a_step() -> void:
	for path: String in SHIPS:
		assert_eq(ShipWalks.off_sides_past_a_step(_walked_on[path]), PackedStringArray(), path)


func test_no_walk_off_her_flights_sides_falls_past_a_metre() -> void:
	for path: String in SHIPS:
		assert_eq(ShipWalks.off_sides_past_a_metre(_walked_on[path]), PackedStringArray(), path)


func test_a_walk_into_the_sea_is_found() -> void:
	# The steamer with her railings taken away (test data): a body walks off her decks' edges.
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	layout.railings = []
	layout.props = []
	var found := ShipWalks.ending(_walks.gone_wrong(layout), "", " ends swimming ")
	assert_gt(found.size(), 0, "walks off her open edges")


func test_a_fall_off_a_flights_side_is_found() -> void:
	# The steamer's hull round a bare deck railed along her sides and a flight up onto a
	# deck 3 m over it, nothing along its sides (test data): a body walks off them onto the
	# deck under them, wide enough that none carries on over its railings.
	var layout: ShipLayout = SimFixtures.steamer().duplicate()
	var railings: Array[ShipRailing] = []
	for z: float in [-3.6, 3.6]:
		var railing := ShipRailing.new()
		railing.from = Vector2(-12.0, z)
		railing.to = Vector2(8.0, z)
		railings.append(railing)
	var deck := ShipPlatform.new()
	deck.name = &"main deck"
	deck.area = Rect2(-12.0, -3.6, 20.0, 7.2)
	var upper := ShipPlatform.new()
	upper.name = &"upper deck"
	upper.area = Rect2(4.0, -1.5, 4.0, 3.0)
	upper.height = 3.0
	var flight := ShipRamp.new()
	flight.area = Rect2(-2.0, -0.6, 6.0, 1.2)
	flight.end_height = 3.0
	var platforms: Array[ShipPlatform] = [deck, upper]
	var ramps: Array[ShipRamp] = [flight]
	layout.platforms = platforms
	layout.ramps = ramps
	layout.blockers = []
	layout.railings = railings
	layout.ladders = []
	layout.props = []
	layout.rooms = []
	layout.bonus_spots = []
	layout.spawns = [Vector3(-10.0, 0.0, 0.0)]
	var found := ShipWalks.ending(_walks.gone_wrong(layout), "ramp ", " falls ")
	assert_eq(found.size(), 6, "off both its sides at each of its quarters")
