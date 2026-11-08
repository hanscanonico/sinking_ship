extends GutTest
## Pieces that meet hold a body back as one (#566): where two decks, or a deck and a wall,
## meet with their faces flush, the end of one is a seam in their one edge, not a corner, and
## a body beside it is held square off the edge alone. A corner of one inside another holds
## nothing back either. Their edge's true ends, a face stepped back, and the outside of two
## walls meeting in an L still hold a body as corners do. Worked alike in GDScript and by the
## extension.

## A deck a body cannot step onto, its top over the feet; every piece here stands that high.
const HIGH := 1.0
const FEET := Vector3.ZERO

var _rules := SimFixtures.rules()


## [param platforms] as decks HIGH up, [param walls] as box blockers as high.
func _layout(platforms: Array[Rect2], walls: Array[Rect2] = []) -> ShipLayout:
	var layout := ShipLayout.new()
	var decks: Array[ShipPlatform] = []
	for area: Rect2 in platforms:
		var deck := ShipPlatform.new()
		deck.name = &"deck"
		deck.area = area
		deck.height = HIGH
		decks.append(deck)
	layout.platforms = decks
	var blockers: Array[ShipBlocker] = []
	for area: Rect2 in walls:
		var wall := ShipBlocker.new()
		wall.shape = ShipBlocker.Shape.BOX
		wall.area = area
		wall.bottom = 0.0
		wall.top = HIGH
		blockers.append(wall)
	layout.blockers = blockers
	return layout


## What holds back a body at (x, z) on [param layout]'s Surfaces, in GDScript and, where it
## is loaded, by the extension; both must agree.
func _held(layout: ShipLayout, x: float, z: float) -> Array[Surfaces.Contact]:
	var at := FEET + Vector3(x, 0.0, z)
	ContactsNative.off = true
	var reference := Surfaces.new(layout)
	ContactsNative.off = false
	var theirs := reference.obstacle_contacts(
		at, _rules.body_radius, _rules.body_height, _rules.step_height
	)
	var native := Surfaces.new(layout)
	if native.native != null:
		var mine := native.obstacle_contacts(
			at, _rules.body_radius, _rules.body_height, _rules.step_height
		)
		assert_eq(_told(mine), _told(theirs), "the extension holds it alike at %s" % at)
	return theirs


static func _told(contacts: Array[Surfaces.Contact]) -> Array[String]:
	var told: Array[String] = []
	for contact: Surfaces.Contact in contacts:
		told.append("n%s d%.4f" % [contact.normal, contact.depth])
	return told


func _assert_square(contacts: Array[Surfaces.Contact], normal: Vector2, depth: float) -> void:
	assert_eq(contacts.size(), 1, "held once: %s" % [_told(contacts)])
	if contacts.size() == 1:
		assert_true(
			contacts[0].normal.is_equal_approx(normal), "square off: %s" % [_told(contacts)]
		)
		assert_almost_eq(contacts[0].depth, depth, 1e-5, "as deep as the edge")


func after_each() -> void:
	ContactsNative.off = false


func test_two_decks_flush_end_to_end_hold_a_body_square_off_their_one_edge() -> void:
	var layout := _layout([Rect2(-2, -2, 2, 2), Rect2(0, -2, 2, 2)])
	# Beside the seam on either side, its circle over the other deck's end: the edge alone.
	_assert_square(_held(layout, -0.2, 0.3), Vector2(0, 1), 0.1)
	_assert_square(_held(layout, 0.2, 0.3), Vector2(0, 1), 0.1)
	_assert_square(_held(layout, 0.0, 0.3), Vector2(0, 1), 0.1)
	# And from the side the decks meet along, across the seam's other face.
	var beside := _layout([Rect2(-2, -2, 2, 2), Rect2(-2, 0, 2, 2)])
	_assert_square(_held(beside, 0.3, -0.2), Vector2(1, 0), 0.1)


func test_the_ends_of_their_one_edge_still_hold_as_corners() -> void:
	var layout := _layout([Rect2(-2, -2, 2, 2), Rect2(0, -2, 2, 2)])
	var contacts := _held(layout, 2.2, 0.2)
	assert_eq(contacts.size(), 1)
	assert_true(contacts[0].normal.is_equal_approx(Vector2(1, 1).normalized()))
	assert_almost_eq(contacts[0].depth, 0.4 - sqrt(0.08), 1e-5)


func test_a_face_stepped_back_leaves_the_corner_standing() -> void:
	# The second deck's face 2.5 cm back of the first's, as F deck's wall stands under E
	# deck's edge by ramp 52: a real step, its corner a corner.
	var layout := _layout([Rect2(-2, -2, 2, 1.975), Rect2(0, -2, 2, 2)])
	var contacts := _held(layout, -0.2, 0.3)
	assert_eq(contacts.size(), 2, "the stepped face and the corner: %s" % [_told(contacts)])
	# Stepped back within a millimetre, it is one face.
	var flush := _layout([Rect2(-2, -2, 2, 1.9995), Rect2(0, -2, 2, 2)])
	assert_eq(_held(flush, -0.2, 0.3).size(), 1, "within SEAM, one edge")


func test_a_wall_flush_with_a_deck_holds_as_one_edge_with_it() -> void:
	var layout := _layout([Rect2(-2, -2, 2, 2)], [Rect2(0, -0.1, 2, 0.1)])
	_assert_square(_held(layout, -0.2, 0.3), Vector2(0, 1), 0.1)
	_assert_square(_held(layout, 0.2, 0.3), Vector2(0, 1), 0.1)


func test_a_corner_under_a_deck_holds_nothing_back() -> void:
	# A wall's end under a deck's edge, 2.5 cm in from it.
	var layout := _layout([Rect2(-2, -2, 2, 2)], [Rect2(-1.0, -1.0, 0.1, 0.975)])
	_assert_square(_held(layout, -0.7, 0.3), Vector2(0, 1), 0.1)


func test_two_walls_meeting_in_an_l_hold_round_its_outside_corner() -> void:
	var layout := _layout([], [Rect2(0, 0, 3, 0.1), Rect2(0, 0, 0.1, 3)])
	var contacts := _held(layout, -0.2, -0.2)
	assert_eq(contacts.size(), 1, "one corner: %s" % [_told(contacts)])
	assert_true(contacts[0].normal.is_equal_approx(Vector2(-1, -1).normalized()))
	# Inside the L, both walls' faces.
	assert_eq(_held(layout, 0.4, 0.4).size(), 2, "inside, both faces")
