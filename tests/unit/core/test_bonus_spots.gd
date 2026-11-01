extends GutTest
## Bonus spots (#307): where a bonus can come aboard — a point on a floor in a room below
## her main deck, naming its room, put there by her layout; the bonus plan brings bonuses
## to them (test_bonus_plan.gd).


func test_a_layout_with_no_bonus_spots_loads_as_before() -> void:
	var deck := SimFixtures.deck()
	assert_eq(deck.bonus_spots.size(), 0, "the flat deck's file names none")
	assert_eq(deck.problems(1), PackedStringArray())


## Every ship of the fleet has her bonus spots, written by her generator (#312): one in
## each room below her main deck, as the layout lint holds, so many of them ship by ship —
## so a bonus comes aboard whichever ship is picked.
func test_every_ship_of_the_fleet_has_her_bonus_spots() -> void:
	var spots := {
		&"barque": 5,
		&"ferry": 2,
		&"freighter": 1,
		&"small_titanic": 88,
		&"steamer": 25,
		&"titanic": 1334,
		&"trawler": 8,
		&"tug": 2,
	}
	for ship_name: StringName in spots:
		assert_eq(Fleet.layout(ship_name).bonus_spots.size(), spots[ship_name], String(ship_name))


## A spot names its room by its index among hers, as a railing names its platform: one
## that is not hers, or none at all, is a problem, and so is a spot that is missing.
func test_a_bonus_spot_names_one_of_her_rooms() -> void:
	var layout: ShipLayout = SimFixtures.deck().duplicate()
	var hold := ShipRoom.new()
	hold.name = &"hold"
	hold.area = Rect2(-4.0, -3.0, 8.0, 6.0)
	hold.floor_height = -2.0
	var rooms: Array[ShipRoom] = [hold]
	layout.rooms = rooms
	var spots: Array[ShipBonusSpot] = []
	for room: int in [0, 1, -1]:
		var spot := ShipBonusSpot.new()
		spot.point = Vector3(0.0, -2.0, 0.0)
		spot.room = room
		spots.append(spot)
	spots.append(null)
	layout.bonus_spots = spots
	assert_eq(
		layout.problems(1),
		PackedStringArray(
			[
				"ship: a bonus spot names room 1",
				"ship: a bonus spot names room -1",
				"ship: a bonus spot is missing",
			]
		)
	)
