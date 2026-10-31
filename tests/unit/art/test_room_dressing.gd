extends GutTest
## RoomDressing on the steamer: what each room is, what it is lit by, and art-lint's
## furnishing check — a table in the middle of a cabin stands in a body's way, a plate
## flat on its wall does not, and nothing the dressing draws does.

const FurnishingCheck := preload("res://tools/furnishing_check.gd")
const RunMatch := preload("res://tools/run_match.gd")

## The Titanic's boat deck and A deck as her plates draw them (#360), B deck as her 1912
## plan does (#367), and C and D decks as Plate IV does (#368, #369), each room's kind by
## its name: a liner's small rooms of service tiled, her bridge's and her wireless's
## rooms offices, an officer's cabin a cabin with no "office" in it, and no helm on her
## top deck but her wheelhouse.
## Her E and F decks' rooms, as her plate draws them, kept beside this script.
const TRACED_E_F: Dictionary = preload("res://tests/unit/art/titanic_ef_room_kinds.gd").KINDS
const TRACED := {
	&"wheelhouse": RoomDressing.Kind.HELM,
	&"chart room": RoomDressing.Kind.SERVICE,
	&"navigating room": RoomDressing.Kind.SERVICE,
	&"Marconi room": RoomDressing.Kind.SERVICE,
	&"silent room": RoomDressing.Kind.SERVICE,
	&"Marconi passage": RoomDressing.Kind.PASSAGE,
	&"Marconi operators' bedroom": RoomDressing.Kind.CABIN,
	&"captain's sitting room": RoomDressing.Kind.SALOON,
	&"captain's bathroom": RoomDressing.Kind.BATH,
	&"captain's lavatory": RoomDressing.Kind.SERVICE,
	&"pilot's cabin": RoomDressing.Kind.CABIN,
	&"chief officer's cabin": RoomDressing.Kind.CABIN,
	&"first officer's cabin": RoomDressing.Kind.CABIN,
	&"second officer's cabin": RoomDressing.Kind.CABIN,
	&"extra second officer's cabin": RoomDressing.Kind.CABIN,
	&"third officer's cabin": RoomDressing.Kind.CABIN,
	&"fourth officer's cabin": RoomDressing.Kind.CABIN,
	&"fifth officer's cabin": RoomDressing.Kind.CABIN,
	&"sixth officer's cabin": RoomDressing.Kind.CABIN,
	&"officers' corridor": RoomDressing.Kind.PASSAGE,
	&"officers' mess": RoomDressing.Kind.SALOON,
	&"officers' pantry": RoomDressing.Kind.SERVICE,
	&"officers' smoking room": RoomDressing.Kind.PUBLIC,
	&"officers' lavatory": RoomDressing.Kind.SERVICE,
	&"officers' store": RoomDressing.Kind.HOLD,
	&"stewards' cabin": RoomDressing.Kind.CABIN,
	&"mess pantry": RoomDressing.Kind.SERVICE,
	&"bathroom": RoomDressing.Kind.BATH,
	&"officers' bathroom": RoomDressing.Kind.BATH,
	&"lavatory": RoomDressing.Kind.SERVICE,
	&"passage": RoomDressing.Kind.PASSAGE,
	&"officers' passage": RoomDressing.Kind.PASSAGE,
	&"vestibule": RoomDressing.Kind.PASSAGE,
	&"vestibule, boat deck": RoomDressing.Kind.PASSAGE,
	&"lift machinery room": RoomDressing.Kind.TANK,
	&"tank room, port": RoomDressing.Kind.TANK,
	&"tank room, starboard": RoomDressing.Kind.TANK,
	&"deck chair store": RoomDressing.Kind.HOLD,
	&"gymnasium": RoomDressing.Kind.SERVICE,
	&"grand staircase, boat deck": RoomDressing.Kind.STAIRCASE,
	&"second-class entrance, boat deck": RoomDressing.Kind.PUBLIC,
	&"second-class entrance, A deck": RoomDressing.Kind.PUBLIC,
	&"verandah café and palm court": RoomDressing.Kind.PUBLIC,
	&"first-class smoking room": RoomDressing.Kind.PUBLIC,
	&"smoking room lavatory": RoomDressing.Kind.SERVICE,
	&"bar": RoomDressing.Kind.SALOON,
	&"after grand staircase, A deck": RoomDressing.Kind.STAIRCASE,
	&"lounge pantry and bar": RoomDressing.Kind.SERVICE,
	&"cloak room": RoomDressing.Kind.SERVICE,
	&"darkroom": RoomDressing.Kind.SERVICE,
	&"first-class lounge": RoomDressing.Kind.PUBLIC,
	&"reading and writing room": RoomDressing.Kind.PUBLIC,
	&"A deck corridor": RoomDressing.Kind.FIRST_CORRIDOR,
	&"grand staircase, A deck": RoomDressing.Kind.STAIRCASE,
	&"first-class stateroom": RoomDressing.Kind.CABIN,
	&"three-berth first-class stateroom": RoomDressing.Kind.CABIN,
	&"stewardesses' room": RoomDressing.Kind.CABIN,
	&"pantry": RoomDressing.Kind.SERVICE,
	&"servery": RoomDressing.Kind.SERVICE,
	&"ladies' lavatory": RoomDressing.Kind.SERVICE,
	&"gentlemen's lavatory": RoomDressing.Kind.SERVICE,
	# B deck as she sailed in 1912 (#367): a name another deck's cell holds too takes the
	# deck's, as a cell names its rooms.
	&"second-class entrance, B deck, aft": RoomDressing.Kind.PUBLIC,
	&"second-class smoking room": RoomDressing.Kind.PUBLIC,
	&"second-class smoking room bar": RoomDressing.Kind.PUBLIC,
	&"second-class smoking room lavatory": RoomDressing.Kind.SERVICE,
	&"second-class entrance, B deck": RoomDressing.Kind.PUBLIC,
	&"second-class staircase, B deck": RoomDressing.Kind.STAIRCASE,
	&"Café Parisien": RoomDressing.Kind.PUBLIC,
	&"restaurant galley": RoomDressing.Kind.SERVICE,
	&"restaurant pantry": RoomDressing.Kind.SERVICE,
	&"restaurant vestibule": RoomDressing.Kind.PASSAGE,
	&"reception room, B deck": RoomDressing.Kind.PUBLIC,
	&"first-class stateroom, B deck": RoomDressing.Kind.CABIN,
	&"three-berth first-class stateroom, B deck": RoomDressing.Kind.CABIN,
	&"single-berth first-class stateroom, B deck": RoomDressing.Kind.CABIN,
	&"passage, B deck": RoomDressing.Kind.PASSAGE,
	&"bathroom, B deck": RoomDressing.Kind.BATH,
	&"lavatory, B deck": RoomDressing.Kind.SERVICE,
	&"gentlemen's lavatory, B deck": RoomDressing.Kind.SERVICE,
	&"ladies' lavatory, B deck": RoomDressing.Kind.SERVICE,
	&"stewardesses' room, B deck": RoomDressing.Kind.CABIN,
	&"stewards' pantry": RoomDressing.Kind.SERVICE,
	&"parlour suite stateroom": RoomDressing.Kind.CABIN,
	&"parlour suite sitting room": RoomDressing.Kind.SALOON,
	&"private promenade": RoomDressing.Kind.SALOON,
	&"first-class entrance, B deck": RoomDressing.Kind.PUBLIC,
	# C and D decks as Plate IV draws them (#368, #369): a name more than one of her
	# cells would hold told apart by where it stands; her crew's rooms, her hospitals,
	# workrooms and messes, and her third class's each a kind of its own; her stores
	# holds, but for her cold store.
	&"Marconi operators' saloon": RoomDressing.Kind.SALOON,
	&"T.R.S.": RoomDressing.Kind.SERVICE,
	&"after grand staircase, C deck": RoomDressing.Kind.STAIRCASE,
	&"assistant doctor's room": RoomDressing.Kind.CABIN,
	&"bake house": RoomDressing.Kind.SERVICE,
	&"baker's shop": RoomDressing.Kind.SERVICE,
	&"bar, D deck": RoomDressing.Kind.SALOON,
	&"bar, poop": RoomDressing.Kind.SALOON,
	&"barber's shop": RoomDressing.Kind.SERVICE,
	&"bathroom, C deck": RoomDressing.Kind.BATH,
	&"bathroom, D deck": RoomDressing.Kind.BATH,
	&"bathroom, D deck aft of O": RoomDressing.Kind.BATH,
	&"bathroom, D deck aft of P": RoomDressing.Kind.BATH,
	&"bread room": RoomDressing.Kind.SERVICE,
	&"butcher's shop": RoomDressing.Kind.SERVICE,
	&"carpenter's shop": RoomDressing.Kind.SERVICE,
	&"chef's office": RoomDressing.Kind.SERVICE,
	&"chief steward's room": RoomDressing.Kind.CABIN,
	&"china pantry": RoomDressing.Kind.SERVICE,
	&"cloak room, C deck": RoomDressing.Kind.SERVICE,
	&"coal": RoomDressing.Kind.HOLD,
	&"coke": RoomDressing.Kind.HOLD,
	&"cold store": RoomDressing.Kind.SERVICE,
	&"corridor, D deck": RoomDressing.Kind.PASSAGE,
	&"corridor, D deck aft of N": RoomDressing.Kind.PASSAGE,
	&"corridor, D deck aft of O": RoomDressing.Kind.PASSAGE,
	&"crew's galley": RoomDressing.Kind.SERVICE,
	&"crew's stair": RoomDressing.Kind.PASSAGE,
	&"deck men's berths": RoomDressing.Kind.BERTHS,
	&"doctor's room": RoomDressing.Kind.CABIN,
	&"emergency dynamos": RoomDressing.Kind.ENGINE,
	&"enquiry office": RoomDressing.Kind.SERVICE,
	&"firemen's W.C.s": RoomDressing.Kind.SERVICE,
	&"firemen's W.C.s, D deck forward of B": RoomDressing.Kind.SERVICE,
	&"firemen's mess": RoomDressing.Kind.SALOON,
	&"firemen's quarters, D deck forward of A": RoomDressing.Kind.BERTHS,
	&"firemen's wash place": RoomDressing.Kind.SERVICE,
	&"firemen's wash place, D deck forward of B": RoomDressing.Kind.SERVICE,
	&"first-class entrance, D deck": RoomDressing.Kind.PUBLIC,
	&"first-class galley scullery": RoomDressing.Kind.SERVICE,
	&"first-class pantry": RoomDressing.Kind.SERVICE,
	&"first-class pantry scullery": RoomDressing.Kind.SERVICE,
	&"four-berth second-class stateroom, D deck": RoomDressing.Kind.CABIN,
	&"four-berth second-class stateroom, D deck aft of O": RoomDressing.Kind.CABIN,
	&"galley store": RoomDressing.Kind.SERVICE,
	&"gentlemen's lavatory, C deck": RoomDressing.Kind.SERVICE,
	&"gentlemen's lavatory, D deck": RoomDressing.Kind.SERVICE,
	&"gentlemen's lavatory, D deck aft of O": RoomDressing.Kind.SERVICE,
	&"glass pantry": RoomDressing.Kind.SERVICE,
	&"grand staircase, D deck": RoomDressing.Kind.STAIRCASE,
	&"greasers' mess": RoomDressing.Kind.SALOON,
	&"hospital": RoomDressing.Kind.BERTHS,
	&"hospital attendants' room": RoomDressing.Kind.CABIN,
	&"hospital, D deck": RoomDressing.Kind.BERTHS,
	&"infectious hospital": RoomDressing.Kind.BERTHS,
	&"knives": RoomDressing.Kind.SERVICE,
	&"ladies' lavatory, C deck": RoomDressing.Kind.SERVICE,
	&"ladies' lavatory, D deck": RoomDressing.Kind.SERVICE,
	&"ladies' lavatory, D deck aft of O": RoomDressing.Kind.SERVICE,
	&"lamp room": RoomDressing.Kind.SERVICE,
	&"lamp trimmer's and storekeeper's berths": RoomDressing.Kind.BERTHS,
	&"larder": RoomDressing.Kind.SERVICE,
	&"lavatory, C deck": RoomDressing.Kind.SERVICE,
	&"linen room": RoomDressing.Kind.SERVICE,
	&"maids' and valets' pantry": RoomDressing.Kind.SERVICE,
	&"maids' and valets' saloon": RoomDressing.Kind.SALOON,
	&"mess stewards' room": RoomDressing.Kind.CABIN,
	&"one-berth first-class stateroom": RoomDressing.Kind.CABIN,
	&"one-berth first-class stateroom, D deck": RoomDressing.Kind.CABIN,
	&"pantry, C deck": RoomDressing.Kind.SERVICE,
	&"pantry, D deck": RoomDressing.Kind.SERVICE,
	&"passage, C deck": RoomDressing.Kind.PASSAGE,
	&"passage, D deck": RoomDressing.Kind.PASSAGE,
	&"passage, D deck aft of B": RoomDressing.Kind.PASSAGE,
	&"passage, D deck aft of N": RoomDressing.Kind.PASSAGE,
	&"passage, D deck aft of O": RoomDressing.Kind.PASSAGE,
	&"passage, D deck aft of P": RoomDressing.Kind.PASSAGE,
	&"passage, D deck forward of B": RoomDressing.Kind.PASSAGE,
	&"passage, forecastle": RoomDressing.Kind.PASSAGE,
	&"plate pantry": RoomDressing.Kind.SERVICE,
	&"printer's room": RoomDressing.Kind.SERVICE,
	&"purser's room": RoomDressing.Kind.CABIN,
	&"restaurant manager's quarters": RoomDressing.Kind.BERTHS,
	&"room marked L": RoomDressing.Kind.SERVICE,
	&"salad pantry": RoomDressing.Kind.SERVICE,
	&"saloon bar": RoomDressing.Kind.SALOON,
	&"seamen's mess": RoomDressing.Kind.SALOON,
	&"second steward's room": RoomDressing.Kind.CABIN,
	&"second-class dining saloon, D deck aft of N": RoomDressing.Kind.DINING,
	&"second-class entrance, C deck": RoomDressing.Kind.PUBLIC,
	&"second-class entrance, C deck, aft": RoomDressing.Kind.PUBLIC,
	&"second-class entrance, C deck, aft, after end": RoomDressing.Kind.PUBLIC,
	&"second-class entrance, D deck": RoomDressing.Kind.PUBLIC,
	&"second-class entrance, D deck, aft": RoomDressing.Kind.PUBLIC,
	&"second-class library": RoomDressing.Kind.PUBLIC,
	&"second-class pantry": RoomDressing.Kind.SERVICE,
	&"servery, C deck": RoomDressing.Kind.SERVICE,
	&"servery, D deck": RoomDressing.Kind.SERVICE,
	&"servery, D deck aft of M": RoomDressing.Kind.SERVICE,
	&"silver pantry": RoomDressing.Kind.SERVICE,
	&"sitting room": RoomDressing.Kind.SALOON,
	&"six-berth third-class room, D deck": RoomDressing.Kind.CABIN,
	&"steering gear room": RoomDressing.Kind.STEERING,
	&"stewardesses' room, C deck": RoomDressing.Kind.CABIN,
	&"stewardesses' room, D deck": RoomDressing.Kind.CABIN,
	&"stewards' office": RoomDressing.Kind.SERVICE,
	&"store": RoomDressing.Kind.HOLD,
	&"store, C deck, after end": RoomDressing.Kind.HOLD,
	&"store, D deck": RoomDressing.Kind.HOLD,
	&"store, D deck aft of P": RoomDressing.Kind.HOLD,
	&"store, D deck forward of A": RoomDressing.Kind.HOLD,
	&"store, forecastle": RoomDressing.Kind.HOLD,
	&"store, poop": RoomDressing.Kind.HOLD,
	&"surgery": RoomDressing.Kind.SERVICE,
	&"surgery, forecastle": RoomDressing.Kind.SERVICE,
	&"third-class entrance": RoomDressing.Kind.PUBLIC,
	&"third-class entrance, C deck": RoomDressing.Kind.PUBLIC,
	&"third-class ladderway": RoomDressing.Kind.PASSAGE,
	&"third-class matron's room": RoomDressing.Kind.CABIN,
	&"third-class men's lavatory": RoomDressing.Kind.SERVICE,
	&"third-class men's lavatory, D deck aft of O": RoomDressing.Kind.SERVICE,
	&"third-class smoking room": RoomDressing.Kind.PUBLIC,
	&"third-class surgery": RoomDressing.Kind.SERVICE,
	&"third-class women's lavatory": RoomDressing.Kind.SERVICE,
	&"third-class women's lavatory, D deck aft of O": RoomDressing.Kind.SERVICE,
	&"three-berth first-class stateroom, C deck": RoomDressing.Kind.CABIN,
	&"three-berth first-class stateroom, D deck": RoomDressing.Kind.CABIN,
	&"two-berth first-class stateroom": RoomDressing.Kind.CABIN,
	&"two-berth first-class stateroom, D deck": RoomDressing.Kind.CABIN,
	&"two-berth second-class stateroom, D deck": RoomDressing.Kind.CABIN,
	&"two-berth second-class stateroom, D deck aft of O": RoomDressing.Kind.CABIN,
	&"two-berth third-class room, D deck": RoomDressing.Kind.CABIN,
	&"vegetable preparing room": RoomDressing.Kind.SERVICE,
	&"wardrobe room": RoomDressing.Kind.SERVICE,
	&"windlass machinery room": RoomDressing.Kind.TANK,
}
## The small Titanic's rooms on those decks that the Titanic's plates have no more.
const UNTRACED: Array[StringName] = [
	&"Scotland Road, boiler room 1",
	&"Scotland Road, boiler rooms 2 and 3",
	&"Scotland Road, boiler room 4",
	&"Scotland Road, boiler room 5",
	&"third-class dining saloon, aft",
	&"third-class dining saloon, forward",
	&"third-class berths",
	&"crew quarters",
	&"F deck working corridor, boiler room 4",
	&"F deck working corridor, boiler room 5",
	&"Turkish bath",
	&"squash court",
	&"squash court gallery",
	&"F deck landing corridor",
	&"F deck working corridor, boiler room 6",
	&"F deck working corridor, boiler room 1",
	&"E deck working passage, engine room",
	&"E deck working passage, turbine room",
	&"E deck working passage, electric room",
	&"E deck working passage, after hold, forward",
	&"E deck working passage, after hold, aft",
	&"E deck working passage, after hold, after end",
	&"first-class stair, E deck",
	&"stewards\' stair, E deck",
	&"officers' quarters",
	&"verandah café",
	&"after entrance",
	&"D deck corridor, forward",
	&"seamen's quarters",
	&"forecastle stores",
	&"forecastle stores, forward",
]

var _layout: ShipLayout
var _rules: BrawlRules
var _space: ShipSpace


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_space = ShipSpace.new(_layout)


func _room(room_name: StringName) -> ShipRoom:
	for room: ShipRoom in _layout.rooms:
		if room.name == room_name:
			return room
	return null


## The ship data/ships/[param ship_name].tres lays out.
func _ship(ship_name: String) -> ShipLayout:
	return load("res://data/ships/%s.tres" % ship_name)


## The twelve triangles of a box over [param area] from [param bottom] to [param top].
func _box(area: Rect2, bottom: float, top: float) -> PackedVector3Array:
	var mesh := BoxMesh.new()
	var size := Vector3(area.size.x, top - bottom, area.size.y)
	mesh.size = size
	var middle := Vector3(area.get_center().x, (bottom + top) * 0.5, area.get_center().y)
	var faces := PackedVector3Array()
	for corner: Vector3 in mesh.get_faces():
		faces.append(corner + middle)
	return faces


func test_each_room_of_the_steamer_is_what_its_shape_says() -> void:
	var kinds := {
		&"stokehold": RoomDressing.Kind.ENGINE,
		&"engine room": RoomDressing.Kind.ENGINE,
		&"forward hold": RoomDressing.Kind.HOLD,
		&"cabin corridor": RoomDressing.Kind.PASSAGE,
		&"aft port cabin": RoomDressing.Kind.STEERAGE,
		&"forward starboard cabin": RoomDressing.Kind.STEERAGE,
		&"saloon": RoomDressing.Kind.SALOON,
		&"deckhouse hall": RoomDressing.Kind.SALOON,
		&"deckhouse cabin 2": RoomDressing.Kind.CUDDY,
		&"wheelhouse": RoomDressing.Kind.HELM,
	}
	for room_name: StringName in kinds:
		assert_eq(RoomDressing.kind_of(_space, _room(room_name)), kinds[room_name], room_name)


func test_a_room_whose_name_says_what_it_is_is_that() -> void:
	# The small Titanic's rooms (#362), and the Titanic's: hers but on her traced decks.
	var kinds := {
		&"officers' quarters": RoomDressing.Kind.BERTHS,
		&"wheelhouse": RoomDressing.Kind.HELM,
		&"gymnasium": RoomDressing.Kind.SERVICE,
		&"grand staircase, boat deck": RoomDressing.Kind.STAIRCASE,
		&"verandah café": RoomDressing.Kind.PUBLIC,
		&"first-class smoking room": RoomDressing.Kind.PUBLIC,
		&"after entrance": RoomDressing.Kind.PUBLIC,
		&"first-class lounge": RoomDressing.Kind.PUBLIC,
		&"reading and writing room": RoomDressing.Kind.PUBLIC,
		&"grand staircase, A deck": RoomDressing.Kind.STAIRCASE,
		&"à la carte restaurant": RoomDressing.Kind.PUBLIC,
		&"B deck corridor": RoomDressing.Kind.FIRST_CORRIDOR,
		&"grand staircase, B deck": RoomDressing.Kind.STAIRCASE,
		&"C deck corridor": RoomDressing.Kind.FIRST_CORRIDOR,
		&"grand staircase, C deck": RoomDressing.Kind.STAIRCASE,
		&"purser's office": RoomDressing.Kind.SERVICE,
		&"third-class general room": RoomDressing.Kind.PUBLIC,
		&"second-class dining saloon": RoomDressing.Kind.DINING,
		&"D deck corridor": RoomDressing.Kind.FIRST_CORRIDOR,
		&"galley": RoomDressing.Kind.SERVICE,
		&"first-class dining saloon": RoomDressing.Kind.DINING,
		&"reception room": RoomDressing.Kind.PUBLIC,
		&"D deck corridor, forward": RoomDressing.Kind.FIRST_CORRIDOR,
		&"third-class open space": RoomDressing.Kind.PUBLIC,
		&"Scotland Road, boiler room 1": RoomDressing.Kind.PASSAGE,
		&"Scotland Road, boiler rooms 2 and 3": RoomDressing.Kind.PASSAGE,
		&"Scotland Road, boiler room 4": RoomDressing.Kind.PASSAGE,
		&"Scotland Road, boiler room 5": RoomDressing.Kind.PASSAGE,
		&"grand staircase, E deck": RoomDressing.Kind.STAIRCASE,
		&"third-class dining saloon, aft": RoomDressing.Kind.DINING,
		&"third-class dining saloon, forward": RoomDressing.Kind.DINING,
		&"post office": RoomDressing.Kind.SERVICE,
		&"third-class berths": RoomDressing.Kind.BERTHS,
		&"crew quarters": RoomDressing.Kind.BERTHS,
		# A working corridor is a plain passage, no first-class "deck corridor"; its
		# "corridor" stands ahead of the "boiler" its name ends on.
		&"F deck working corridor, boiler room 4": RoomDressing.Kind.PASSAGE,
		&"F deck working corridor, boiler room 5": RoomDressing.Kind.PASSAGE,
		&"Turkish bath": RoomDressing.Kind.BATH,
		&"swimming bath": RoomDressing.Kind.BATH,
		&"squash court": RoomDressing.Kind.SQUASH,
		&"squash court gallery": RoomDressing.Kind.SQUASH,
		&"F deck landing corridor": RoomDressing.Kind.PASSAGE,
		&"boiler room 2": RoomDressing.Kind.BOILER,
		&"boiler room 3": RoomDressing.Kind.BOILER,
		&"boiler room 4": RoomDressing.Kind.BOILER,
		&"boiler room 5": RoomDressing.Kind.BOILER,
		# Her old voids and empty spaces made places (#148): the bow.
		&"boiler room 6": RoomDressing.Kind.BOILER,
		&"coal bunker 6": RoomDressing.Kind.HOLD,
		&"F deck working corridor, boiler room 6": RoomDressing.Kind.PASSAGE,
		&"firemen's passage": RoomDressing.Kind.PASSAGE,
		&"No. 3 hold, port": RoomDressing.Kind.HOLD,
		&"No. 3 hold, starboard": RoomDressing.Kind.HOLD,
		&"No. 2 hold, port": RoomDressing.Kind.HOLD,
		&"No. 3 hold": RoomDressing.Kind.HOLD,
		&"No. 2 hold": RoomDressing.Kind.HOLD,
		&"boiler room 6 double bottom": RoomDressing.Kind.TANK,
		&"No. 3 hold double bottom": RoomDressing.Kind.TANK,
		&"No. 2 hold double bottom": RoomDressing.Kind.TANK,
		&"No. 1 hold double bottom": RoomDressing.Kind.TANK,
		&"No. 1 hold double bottom, forward": RoomDressing.Kind.TANK,
		&"No. 1 hold": RoomDressing.Kind.HOLD,
		&"No. 1 hold, forward": RoomDressing.Kind.HOLD,
		&"No. 1 hold, orlop": RoomDressing.Kind.HOLD,
		&"No. 1 hold, orlop, forward": RoomDressing.Kind.HOLD,
		&"G deck passage, No. 1 hold": RoomDressing.Kind.PASSAGE,
		&"G deck passage, No. 1 hold, forward": RoomDressing.Kind.PASSAGE,
		&"firemen's quarters": RoomDressing.Kind.BERTHS,
		&"seamen's quarters": RoomDressing.Kind.BERTHS,
		&"forecastle stores": RoomDressing.Kind.HOLD,
		&"forecastle stores, forward": RoomDressing.Kind.HOLD,
		&"forepeak tank": RoomDressing.Kind.TANK,
		&"forepeak stores": RoomDressing.Kind.HOLD,
		# And the stern.
		&"boiler room 1": RoomDressing.Kind.BOILER,
		&"coal bunker 1": RoomDressing.Kind.HOLD,
		&"F deck working corridor, boiler room 1": RoomDressing.Kind.PASSAGE,
		&"engine room": RoomDressing.Kind.ENGINE,
		&"turbine engine room": RoomDressing.Kind.ENGINE,
		&"electric engine room": RoomDressing.Kind.ENGINE,
		&"G deck stores, electric room": RoomDressing.Kind.HOLD,
		&"after hold, forward": RoomDressing.Kind.HOLD,
		&"after hold, forward, orlop": RoomDressing.Kind.HOLD,
		&"after hold, forward, G deck": RoomDressing.Kind.HOLD,
		&"after hold, aft": RoomDressing.Kind.HOLD,
		&"after hold, aft, orlop": RoomDressing.Kind.HOLD,
		&"after hold, aft, G deck": RoomDressing.Kind.HOLD,
		&"boiler room 1 double bottom": RoomDressing.Kind.TANK,
		&"engine room double bottom": RoomDressing.Kind.TANK,
		&"turbine room double bottom": RoomDressing.Kind.TANK,
		&"electric room double bottom": RoomDressing.Kind.TANK,
		&"after hold, forward, double bottom": RoomDressing.Kind.TANK,
		&"after hold, aft, double bottom": RoomDressing.Kind.TANK,
		&"after hold, aft, after end": RoomDressing.Kind.HOLD,
		&"after hold, aft, orlop, after end": RoomDressing.Kind.HOLD,
		&"after hold, aft, G deck, after end": RoomDressing.Kind.HOLD,
		&"after peak tank": RoomDressing.Kind.TANK,
		&"after peak stores": RoomDressing.Kind.HOLD,
		# And amidships.
		&"coal bunker 2": RoomDressing.Kind.HOLD,
		&"coal bunker 3": RoomDressing.Kind.HOLD,
		&"coal bunker 4": RoomDressing.Kind.HOLD,
		&"coal bunker 5": RoomDressing.Kind.HOLD,
		&"boiler room 2 double bottom": RoomDressing.Kind.TANK,
		&"boiler room 3 double bottom": RoomDressing.Kind.TANK,
		&"boiler room 4 double bottom": RoomDressing.Kind.TANK,
		&"boiler room 5 double bottom": RoomDressing.Kind.TANK,
		# A working passage along E deck is a plain passage, ahead of the engine room it
		# runs over.
		&"E deck working passage, engine room": RoomDressing.Kind.PASSAGE,
		&"E deck working passage, turbine room": RoomDressing.Kind.PASSAGE,
		&"E deck working passage, electric room": RoomDressing.Kind.PASSAGE,
		&"E deck working passage, after hold, forward": RoomDressing.Kind.PASSAGE,
		&"E deck working passage, after hold, aft": RoomDressing.Kind.PASSAGE,
	}
	_pinned(_ship("small_titanic"), kinds)
	for gone: StringName in UNTRACED:
		kinds.erase(gone)
	kinds.merge(TRACED, true)
	kinds.merge(TRACED_E_F, true)
	_pinned(_ship("titanic"), kinds)


## Each room of [param ship] is the kind [param kinds] pins its name to, and each name
## pinned is one of her rooms'.
func _pinned(ship: ShipLayout, kinds: Dictionary) -> void:
	var space := ShipSpace.new(ship)
	var named := ship.resource_path.get_file().get_basename()
	var unseen := kinds.duplicate()
	for room: ShipRoom in ship.rooms:
		assert_true(kinds.has(room.name), "%s pinned: %s" % [named, room.name])
		if kinds.has(room.name):
			var kind := RoomDressing.kind_of(space, room)
			assert_eq(kind, kinds[room.name], "%s: %s" % [named, room.name])
			unseen.erase(room.name)
	assert_true(unseen.is_empty(), "%s has each: %s" % [named, unseen.keys()])


func test_the_trawler_s_rooms_keep_their_dressing() -> void:
	var trawler := _ship("trawler")
	var space := ShipSpace.new(trawler)
	# Her galley is a room of service, and not an office: dressed as the saloon it was.
	var kinds := {
		&"engine room": RoomDressing.Kind.ENGINE,
		&"fish hold": RoomDressing.Kind.HOLD,
		&"galley": RoomDressing.Kind.SERVICE,
		&"wheelhouse": RoomDressing.Kind.HELM,
		&"crew mess": RoomDressing.Kind.SALOON,
		# Her old voids made places (#148).
		&"engine room double bottom": RoomDressing.Kind.TANK,
		&"fish hold double bottom": RoomDressing.Kind.TANK,
		&"steering gear": RoomDressing.Kind.STEERING,
		&"port side passage": RoomDressing.Kind.TANK,
		&"starboard side passage": RoomDressing.Kind.TANK,
		&"fore stores": RoomDressing.Kind.HOLD,
	}
	for room: ShipRoom in trawler.rooms:
		assert_eq(RoomDressing.kind_of(space, room), kinds.get(room.name), String(room.name))
		if room.name == &"galley":
			assert_false(LinerService.office(room))


func test_a_liner_s_office_is_one_and_her_officers_quarters_are_not() -> void:
	var offices := {
		&"gymnasium": false,
		&"purser's office": true,
		&"galley": false,
		&"post office": true,
	}
	assert_eq(_offices(_ship("small_titanic")), offices)
	# Her traced decks' (#360): her wireless's and her bridge's rooms are offices, and C
	# and D decks' enquiry office and chef's and stewards' offices (#368, #369); no
	# officers' room is one for its name.
	var traced_offices: Array[StringName] = [
		&"Marconi room",
		&"silent room",
		&"chart room",
		&"navigating room",
		&"enquiry office",
		&"chef's office",
		&"stewards' office",
		&"engineers' office, E deck",
		&"assistant purser's office, E deck",
	]
	for office: StringName in traced_offices:
		offices[office] = true
	var traced := TRACED.duplicate()
	traced.merge(TRACED_E_F)
	for room_name: StringName in traced:
		if traced[room_name] == RoomDressing.Kind.SERVICE and not offices.has(room_name):
			offices[room_name] = false
	assert_eq(_offices(_ship("titanic")), offices)


## Per name of a room of service of [param ship], whether it is an office.
func _offices(ship: ShipLayout) -> Dictionary:
	var space := ShipSpace.new(ship)
	var offices := {}
	for room: ShipRoom in ship.rooms:
		if RoomDressing.kind_of(space, room) == RoomDressing.Kind.SERVICE:
			offices[room.name] = LinerService.office(room)
	return offices


# A room of service lines itself in tile (test_liner_service.gd).
func test_the_liner_s_kinds_keep_the_ship_s_own_lining() -> void:
	# A dining saloon lines its own (LinerDining, test_liner_dining.gd), and so does a
	# first-class corridor (LinerCorridor, test_liner_corridor.gd).
	for kind: RoomDressing.Kind in [
		RoomDressing.Kind.PUBLIC,
		RoomDressing.Kind.STAIRCASE,
		RoomDressing.Kind.BERTHS,
	]:
		assert_true(RoomDressing._linings(kind).is_empty(), RoomDressing.Kind.keys()[kind])


func test_the_stokehold_is_lit_over_its_lanes_and_by_its_boilers_fires() -> void:
	var lights := RoomDressing.new(_space).lights(_room(&"stokehold"))
	var pendants := 0
	var fires := 0
	for light: RoomDressing.Light in lights:
		if light.kind == ShipLamp.Kind.PENDANT:
			pendants += 1
			assert_gt(absf(light.at.z), 1.2, "a lamp hangs over a lane, clear of the engine")
		elif light.kind == ShipLamp.Kind.FIRE:
			fires += 1
			assert_almost_eq(light.facing, Vector3.LEFT, Vector3.ONE * 0.001, "into the room")
	assert_eq(pendants, 2)
	assert_eq(fires, 2)


func test_the_hold_hangs_cargo_lamps_clear_of_its_stairs() -> void:
	var lights := RoomDressing.new(_space).lights(_room(&"forward hold"))
	assert_eq(lights.size(), 2)
	for light: RoomDressing.Light in lights:
		assert_eq(light.kind, ShipLamp.Kind.CARGO)
		var spot := Rect2(Vector2(light.at.x, light.at.z), Vector2.ZERO).grow(0.6)
		assert_false(RoomDressing.over_a_ramp(_layout, spot, -2.6, light.at.y))


func test_a_passenger_room_keeps_its_one_pendant_under_its_middle() -> void:
	var saloon := _room(&"saloon")
	var lights := RoomDressing.new(_space).lights(saloon)
	assert_eq(lights.size(), 1)
	assert_eq(lights[0].kind, ShipLamp.Kind.PENDANT)
	var middle := saloon.area.get_center()
	assert_almost_eq(Vector2(lights[0].at.x, lights[0].at.z), middle, Vector2.ONE * 0.001)


func test_a_table_in_the_middle_of_a_cabin_stands_in_a_body_s_way() -> void:
	var cabin := _room(&"aft port cabin")
	var table := Rect2(cabin.area.get_center() - Vector2.ONE * 0.4, Vector2.ONE * 0.8)
	var faces := _box(table, cabin.floor_height, cabin.floor_height + 0.75)
	assert_false(FurnishingCheck.intrusions(_layout, _rules, faces).is_empty())


func test_a_plate_flat_on_a_cabin_wall_stands_in_nobody_s_way() -> void:
	var cabin := _room(&"aft port cabin")
	# The wall between it and the middle cabin, x -8.4, faces it at x -8.5.
	var plate := Rect2(-8.58, -3.0, 0.08, 1.0)
	var faces := _box(plate, cabin.floor_height + 0.4, cabin.floor_height + 1.6)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, faces), PackedStringArray())


func test_a_face_by_a_box_s_far_corner_is_inside_it_squares_from_its_own() -> void:
	# A table metres across the saloon's floor, filed by every square its footprint
	# covers (FurnishingCheck.CELL): a face by its far corner, squares from where its
	# footprint starts, is inside it, and the same face reaching past its side is not.
	var saloon := _room(&"saloon")
	var table := Rect2(saloon.area.get_center() - Vector2(1.0, 2.2), Vector2(2.0, 4.4))
	var layout := _with_a_box(saloon, table, 0.75)
	var boxes: Dictionary = FurnishingCheck._boxes_by_cell(layout)
	var corner := table.end - Vector2.ONE * 0.3
	var squares := (corner / FurnishingCheck.CELL).floor()
	squares -= (table.position / FurnishingCheck.CELL).floor()
	assert_true(squares.x >= 1.0 and squares.y >= 3.0, "squares from its own: %s" % squares)
	var low := saloon.floor_height + 0.3
	var face := PackedVector3Array(
		[
			Vector3(corner.x, low, corner.y),
			Vector3(corner.x + 0.2, low, corner.y),
			Vector3(corner.x, low + 0.4, corner.y + 0.2),
		]
	)
	assert_true(FurnishingCheck._inside_a_blocker(layout, boxes, face), "by its far corner")
	face[1].x = table.end.x + 0.05
	assert_false(FurnishingCheck._inside_a_blocker(layout, boxes, face), "past its side")


func test_a_shelf_over_head_height_stands_in_nobody_s_way() -> void:
	var cabin := _room(&"aft port cabin")
	var shelf := Rect2(-9.1, -3.0, 0.6, 1.0)
	var faces := _box(shelf, cabin.floor_height + 1.85, cabin.floor_height + 2.1)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, faces), PackedStringArray())


func test_nothing_the_dressing_draws_on_the_steamer_stands_in_a_body_s_way() -> void:
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	var faces := FurnishingCheck.furnishings(art)
	art.free()
	assert_gt(faces.size(), 0)
	assert_eq(FurnishingCheck.intrusions(_layout, _rules, faces), PackedStringArray())


## The steamer laid out again with a box over [param area] of [param room], from its
## floor to [param height] over it.
func _with_a_box(room: ShipRoom, area: Rect2, height: float) -> ShipLayout:
	var layout: ShipLayout = _layout.duplicate(true)
	var box := ShipBlocker.new()
	box.shape = ShipBlocker.Shape.BOX
	box.area = area
	box.bottom = room.floor_height
	box.top = room.floor_height + height
	layout.blockers.append(box)
	return layout


## A room of [param room_name] over [param area] on the steamer's main deck.
func _named(room_name: StringName, area: Rect2) -> ShipRoom:
	var room := ShipRoom.new()
	room.name = room_name
	room.area = area
	room.floor_height = _room(&"saloon").floor_height
	return room


func test_a_table_on_a_saloon_s_floor_leaves_it_a_saloon() -> void:
	var saloon := _room(&"saloon")
	var table := Rect2(saloon.area.get_center() - Vector2.ONE * 0.6, Vector2.ONE * 1.2)
	var layout := _with_a_box(saloon, table, 0.75)
	var space := ShipSpace.new(layout)
	var room := layout.rooms[_layout.rooms.find(saloon)]
	assert_eq(RoomDressing.kind_of(space, room), RoomDressing.Kind.SALOON)
	assert_eq(space.furniture(room).size(), 1)
	assert_eq(space.furniture(room)[0].area, table)
	assert_true(space.machinery(room).is_empty(), "a table is no engine")


func test_the_steamer_s_engine_is_machinery_not_furniture() -> void:
	# Her engine stands on the stokehold's floor.
	var stokehold := _room(&"stokehold")
	assert_eq(_space.machinery(stokehold).size(), 1)
	assert_true(_space.furniture(stokehold).is_empty())


func test_drawn_in_its_footprint_a_table_stands_in_nobody_s_way() -> void:
	var saloon := _room(&"saloon")
	var table := Rect2(saloon.area.get_center() - Vector2.ONE * 0.6, Vector2.ONE * 1.2)
	var layout := _with_a_box(saloon, table, 0.75)
	var art := ShipArt.new()
	art.build(layout, _rules.railing_height, _rules.body_radius)
	var faces := FurnishingCheck.furnishings(art)
	art.free()
	# Over its footprint, clear of the floor's own faces and under its top: the table.
	var in_it := 0
	for corner: Vector3 in faces:
		if table.grow(0.002).has_point(Vector2(corner.x, corner.z)):
			var over := corner.y - saloon.floor_height
			in_it += 1 if over > 0.05 and over < 0.76 else 0
	assert_gt(in_it, 0, "the table is drawn")
	assert_eq(FurnishingCheck.intrusions(layout, _rules, faces), PackedStringArray())


func test_a_piece_of_furniture_is_what_its_box_says() -> void:
	var pieces := [
		[Vector2(1.2, 1.2), 0.75, FurnitureDressing.Piece.TABLE],
		[Vector2(4.0, 0.9), 0.75, FurnitureDressing.Piece.TABLE],
		[Vector2(9.0, 0.5), 0.45, FurnitureDressing.Piece.BENCH],
		[Vector2(0.8, 0.8), 0.45, FurnitureDressing.Piece.ARMCHAIR],
		[Vector2(2.0, 0.8), 0.45, FurnitureDressing.Piece.SETTEE],
		[Vector2(0.8, 2.0), 0.45, FurnitureDressing.Piece.SETTEE],
		[Vector2(0.6, 3.6), 1.0, FurnitureDressing.Piece.COUNTER],
		[Vector2(8.0, 1.2), 0.9, FurnitureDressing.Piece.RANGE],
		[Vector2(0.7, 1.5), 1.0, FurnitureDressing.Piece.APPARATUS],
	]
	# On the Titanic's D deck, 0.9 m over -3.1875 is a hair under 0.9 in single precision.
	var deck := -3.1875
	for piece: Array in pieces:
		var box := ShipBlocker.new()
		box.shape = ShipBlocker.Shape.BOX
		box.area = Rect2(Vector2.ZERO, piece[0])
		box.top = piece[1]
		assert_eq(FurnitureDressing.piece_of(box), piece[2], str(piece))
		box.bottom = deck
		box.top = deck + piece[1]
		assert_eq(FurnitureDressing.piece_of(box), piece[2], "on D deck: %s" % [piece])


func test_a_name_says_what_a_room_is_ahead_of_its_machinery() -> void:
	var stokehold := _room(&"stokehold")
	var boiler_room := ShipRoom.new()
	boiler_room.name = &"boiler room 6"
	boiler_room.area = stokehold.area
	boiler_room.floor_height = stokehold.floor_height
	assert_true(_space.machinery_in(boiler_room), "the steamer's engine stands in it")
	assert_eq(RoomDressing.kind_of(_space, boiler_room), RoomDressing.Kind.BOILER)


func test_a_room_named_for_a_boiler_a_bath_or_a_court_is_that() -> void:
	var area := Rect2(-2.0, -2.0, 4.0, 4.0)
	var kinds := {
		&"boiler room 6": RoomDressing.Kind.BOILER,
		&"Turkish bath": RoomDressing.Kind.BATH,
		&"swimming bath": RoomDressing.Kind.BATH,
		&"squash court": RoomDressing.Kind.SQUASH,
		&"engine room": RoomDressing.Kind.ENGINE,
	}
	for room_name: StringName in kinds:
		var kind := RoomDressing.kind_of(_space, _named(room_name, area))
		assert_eq(kind, kinds[room_name], String(room_name))


func test_a_boiler_room_is_lined_as_an_engine_room() -> void:
	assert_eq(
		RoomDressing._linings(RoomDressing.Kind.BOILER),
		RoomDressing._linings(RoomDressing.Kind.ENGINE)
	)
	# A bath and a squash court line their own (test_liner_bath.gd,
	# test_liner_squash.gd).


## The binnacle's two spheres on the wheelhouse's forward wall, as (along, height over
## the floor, radius): from the dark discs the dressed ship draws in front of it.
func _spheres(art: ShipArt, wall: RoomDressing.Wall) -> Array[Vector3]:
	var points := PackedVector3Array()
	for child: Node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh := (child as MeshInstance3D).mesh
		if not mesh is ArrayMesh:
			continue
		var arrays := mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_COLOR] == null:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for index in vertices.size():
			var point := vertices[index]
			var out := (point - wall.at(0.0, 0.0)).dot(wall.normal)
			var along := point.dot(wall.right)
			var high := point.y - wall.floor
			if not colours[index].is_equal_approx(ArtPalette.FUNNEL_TOP):
				continue
			if out > 0.0 and out < 0.15 and along > wall.from and along < wall.to and high < 2.0:
				points.append(Vector3(along, high, 0.0))
	var alongs: Array[float] = []
	for point: Vector3 in points:
		alongs.append(point.x)
	alongs.sort()
	var split := 0.0
	var widest := 0.0
	for index in alongs.size() - 1:
		if alongs[index + 1] - alongs[index] > widest:
			widest = alongs[index + 1] - alongs[index]
			split = (alongs[index] + alongs[index + 1]) * 0.5
	var found: Array[Vector3] = []
	for left: bool in [true, false]:
		var box := Rect2()
		var first := true
		for point: Vector3 in points:
			if (point.x < split) == left:
				box = (
					Rect2(point.x, point.y, 0.0, 0.0)
					if first
					else box.expand(Vector2(point.x, point.y))
				)
				first = false
		found.append(Vector3(box.get_center().x, box.get_center().y, box.size.x * 0.5))
	return found


## Whether a disc at [param centre] of [param radius] keeps [param gap] clear of the
## segment [param a]…[param b].
func _clear_of(centre: Vector2, radius: float, a: Vector2, b: Vector2, gap: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(centre, a, b).distance_to(centre) > radius + gap


func test_the_binnacle_s_spheres_stand_clear_of_rail_windows_and_wheel() -> void:
	var room := _room(&"wheelhouse")
	var wall: RoomDressing.Wall = null
	for each: RoomDressing.Wall in RoomDressing.walls(_space, room):
		if each.side == 1:
			wall = each
	var art := ShipArt.new()
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	var spheres := _spheres(art, wall)
	art.free()
	var fittings := ShipFittings.new(_space, ShipHull.new(_space, _rules.railing_height), 0.3)
	fittings.build(ShipMesh.new(_space.outdoors, _space.room_lines()))
	# The cabin finish's dado rail (ship.gdshaderinc), 0.95 m up and 0.07 deep; the wheel
	# (the wheel_stand model) round its hub 1 m up, handles 0.09 past a 0.32 rim, 0.022
	# thick.
	var rail := Vector2(0.915, 0.985)
	var hub := Vector2(wall.middle(), 1.0)
	for sphere: Vector3 in spheres:
		var centre := Vector2(sphere.x, sphere.y)
		var radius := sphere.z
		assert_almost_eq(radius, 0.05, 0.02, "a sphere, not stray dark faces")
		var low := centre.y - radius
		var high := centre.y + radius
		assert_true(low > rail.y or high < rail.x, "clear of the dado rail: %s" % centre)
		for pane: Array in fittings.panes:
			if pane[0] != room or not (pane[2] as Vector3).is_equal_approx(wall.normal):
				continue
			var half: Vector2 = pane[4] + Vector2.ONE * (ShipFittings.WINDOW_FRAME + 0.05)
			var middle := Vector2((pane[1] as Vector3).dot(wall.right), pane[1].y - wall.floor)
			# Its surround, and the sill under it.
			var surround := Rect2(middle - half, half * 2.0).grow_individual(0.0, 0.05, 0.0, 0.0)
			var near := Rect2(centre - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
			assert_false(surround.intersects(near), "clear of the window at %s" % middle)
		var from_hub := centre.distance_to(hub)
		assert_true(
			from_hub + radius < 0.32 - 0.033 or from_hub - radius > 0.32 + 0.011,
			"clear of the wheel's rim: %s" % centre
		)
		for spoke in 8:
			var out := Vector2(cos(PI * spoke / 8), sin(PI * spoke / 8)) * 0.41
			assert_true(_clear_of(centre, radius, hub - out, hub + out, 0.011), "of a handle")
	assert_eq(spheres.size(), 2, "two spheres")


func test_a_gauge_or_handwheel_is_the_largest_variant_no_bigger_than_asked() -> void:
	var gauges := RoomDressing.GAUGES
	assert_eq(RoomDressing.variant(gauges, 0.085), "gauge_small", "the size it is made for")
	assert_eq(RoomDressing.variant(gauges, 0.09), "gauge_small", "the engine room's board")
	assert_eq(RoomDressing.variant(gauges, 0.3), "gauge_small", "none bigger: the largest")
	assert_eq(RoomDressing.variant(gauges, 0.05), "gauge_small", "none so small: the smallest")
	var wheels := RoomDressing.HANDWHEELS
	assert_eq(RoomDressing.variant(wheels, 0.15), "handwheel_large", "an engine's")
	assert_eq(RoomDressing.variant(wheels, 0.11), "handwheel_large", "none so small: the smallest")


func test_a_stowed_crate_is_the_largest_variant_that_fits_its_spot() -> void:
	# A bottom crate of each stack size is drawn its own size, so the next sits on it.
	assert_eq(CargoHold.stowed_crate(0.8, 0.68), "stowed_crate_80", "a 0.8 stack's foot")
	assert_eq(CargoHold.stowed_crate(0.7, 0.595), "stowed_crate_70", "a 0.7 stack's foot")
	assert_eq(CargoHold.stowed_crate(0.74, 0.68), "stowed_crate_70", "up a 0.8 stack")
	assert_eq(CargoHold.stowed_crate(0.72, 0.56), "stowed_crate_62", "on a barrel: low")
	assert_eq(CargoHold.stowed_crate(0.64, 0.595), "stowed_crate_62", "up a 0.7 stack")
	assert_eq(CargoHold.stowed_crate(0.5, 0.3), "stowed_crate_62", "none fits: the smallest")


func test_a_deck_pipe_is_the_largest_variant_no_bigger_than_asked() -> void:
	var pipes := ShipFittings.DECK_PIPES
	assert_eq(RoomDressing.variant(pipes, 0.2), "deck_pipe_20", "a hawse pipe's")
	assert_eq(RoomDressing.variant(pipes, 0.13), "deck_pipe_13", "a spurling pipe's")


func test_a_gauge_or_handwheel_faces_out_along_its_normal_upright() -> void:
	for normal: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
		var turn := RoomDressing.facing(normal)
		assert_almost_eq(turn.z, normal, Vector3.ONE * 0.001, "its face out along %s" % normal)
		assert_almost_eq(turn.determinant(), 1.0, 0.001, "turned, not mirrored: %s" % normal)
		if is_zero_approx(normal.y):
			assert_almost_eq(turn.y, Vector3.UP, Vector3.ONE * 0.001, "upright: %s" % normal)
