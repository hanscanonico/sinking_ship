extends GutTest
## A broken railing's remains (RailingRemains) hang a stub of the cap rail only from a
## post still standing: where the span sharing that post is broken too, the end is a
## stump on the deck, nothing left hanging in the air where the rails were — and the
## remains drawn once are drawn again as their neighbours break and mend.

const RunMatch := preload("res://tools/run_match.gd")
## How far round the shared post the remains are looked for, and the share of the
## railing's height over the deck above which only a cap rail's stub reaches.
const ROUND_POST := 0.5
const CAP_ZONE := 0.75

var _layout: ShipLayout
var _rules: BrawlRules
## Two spans at one height ending at one post, and that post.
var _first := -1
var _second := -1
var _post := Vector2.ZERO


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	for index in _layout.railings.size():
		for other in range(index + 1, _layout.railings.size()):
			var shared: Variant = _shared_post(index, other)
			if shared != null:
				_first = index
				_second = other
				_post = shared
				return


func _shared_post(index: int, other: int) -> Variant:
	var railing := _layout.railings[index]
	var next := _layout.railings[other]
	var height := _layout.platforms[railing.platform].height
	if not is_equal_approx(_layout.platforms[next.platform].height, height):
		return null
	for end: Vector2 in [railing.from, railing.to]:
		if end.is_equal_approx(next.from) or end.is_equal_approx(next.to):
			return end
	return null


func _art() -> ShipArt:
	var art: ShipArt = autofree(ShipArt.new())
	var fails := PackedInt32Array(range(_layout.railings.size()))
	art.build(_layout, _rules.railing_height, _rules.body_radius, [], fails)
	return art


## The highest point of the remains shown round the shared post, over its deck.
func _highest_round_post(art: ShipArt) -> float:
	var deck := _layout.platforms[_layout.railings[_first].platform].height
	var highest := 0.0
	for index: int in [_first, _second]:
		var remains := art.find_child("Railing%dRemains" % index, true, false) as Node3D
		if remains == null or not remains.visible:
			continue
		for child: Node in remains.find_children("*", "MeshInstance3D", true, false):
			var place := (child as Node3D).transform
			for corner: Vector3 in (child as MeshInstance3D).mesh.get_faces():
				var point := place * corner
				if Vector2(point.x, point.z).distance_to(_post) <= ROUND_POST:
					highest = maxf(highest, point.y - deck)
	return highest


func test_the_ship_has_two_spans_sharing_a_post() -> void:
	assert_gt(_second, -1, "two railing spans end at one post")


func test_one_span_broken_hangs_its_stub_from_the_post_still_standing() -> void:
	var art := _art()
	art.show_sinking([], {}, PackedInt32Array([_first]), false)
	assert_gt(
		_highest_round_post(art),
		_rules.railing_height * CAP_ZONE,
		"its cap rail's stub hangs from the other span's post"
	)


func test_both_spans_broken_leave_nothing_hanging_where_their_post_was() -> void:
	var art := _art()
	art.show_sinking([], {}, PackedInt32Array([_first, _second]), false)
	assert_lt(_highest_round_post(art), _rules.railing_height * CAP_ZONE, "drawn at once: stumps")


func test_remains_are_drawn_again_as_the_span_beside_them_breaks_and_mends() -> void:
	var art := _art()
	art.show_sinking([], {}, PackedInt32Array([_first]), false)
	art.show_sinking([], {}, PackedInt32Array([_first, _second]), false)
	assert_lt(
		_highest_round_post(art),
		_rules.railing_height * CAP_ZONE,
		"its neighbour broken after it: no stub left hanging"
	)
	art.show_sinking([], {}, PackedInt32Array([_first]), false)
	assert_gt(
		_highest_round_post(art),
		_rules.railing_height * CAP_ZONE,
		"its neighbour whole again: the stub back on its post"
	)
