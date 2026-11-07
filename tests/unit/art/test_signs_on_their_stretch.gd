extends GutTest
## A broken hull's art is drawn a stretch at a time, each riding its piece (ShipArt.span,
## PieceClip): a door sign's letters are drawn by the stretch whose span holds its enamel
## plate, as that stretch's paints draw the plate, and by no other; a sign whose plate
## stands on the cut itself by both, as both draw its plate; and as a stretch's span moves
## (show_span) its letters are filed again, so none rides a piece its plate is not on (#530).

const RunMatch := preload("res://tools/run_match.gd")

var _layout: ShipLayout
var _rules: BrawlRules
## Her whole art, the sign on the cut (its place in every pool's signs()), the cut, and
## the two stretches either side of it, every one packed as a match draws her.
var _whole: ShipArt
var _on_cut := -1
var _cut := 0.0
var _aft: ShipArt
var _fore: ShipArt


func before_all() -> void:
	var config := RunMatch.default_config(1701)
	_layout = config.ship
	_rules = config.rules
	_whole = _built(Vector2(-INF, INF))
	# The cut runs through the plate of the sign on a bulkhead nearest her middle: its
	# letters stand off its plate along her, so they lie a hair off the cut on one side.
	var signs := _pool(_whole).signs()
	var middle := 0.0
	for label: Label3D in signs:
		middle += _plate(label).x / signs.size()
	for index in signs.size():
		if absf(signs[index].basis.z.x) < 0.5:
			continue
		var off := absf(_plate(signs[index]).x - middle)
		if _on_cut == -1 or off < absf(_cut - middle):
			_on_cut = index
			_cut = _plate(signs[index]).x
	_aft = _built(Vector2(-INF, _cut))
	_fore = _built(Vector2(_cut, INF))


func after_all() -> void:
	_whole.free()
	_aft.free()
	_fore.free()


func _built(span: Vector2) -> ShipArt:
	var art := ShipArt.new()
	art.rules = _rules
	art.pack = true
	art.span = span
	art.build(_layout, _rules.railing_height, _rules.body_radius)
	return art


static func _pool(art: ShipArt) -> SignPool:
	return art.get_node("Dressing/Signs") as SignPool


static func _plate(label: Label3D) -> Vector3:
	return label.get_meta(SignPool.PLATE) as Vector3


## Whether [param art] draws the letters of its [param index]th sign with the eye at them.
static func _draws(art: ShipArt, index: int) -> bool:
	var pool := _pool(art)
	var label := pool.signs()[index]
	pool.show_near(label.position)
	return label.get_parent() == pool


func test_each_sign_is_drawn_by_the_stretch_its_plate_stands_on_and_no_other() -> void:
	var signs := _pool(_whole).signs()
	assert_gt(_on_cut, -1, "a sign on a bulkhead to cut at")
	assert_eq(_pool(_aft).signs().size(), signs.size(), "every sign held aft")
	assert_eq(_pool(_fore).signs().size(), signs.size(), "every sign held fore")
	var aft_alone := 0
	var fore_alone := 0
	for index in signs.size():
		var plate := _plate(signs[index]).x
		var aft := _draws(_aft, index)
		var fore := _draws(_fore, index)
		var text := "%s, its plate at %.3f, the cut at %.3f" % [signs[index].text, plate, _cut]
		assert_eq(aft, PieceClip.holds(_aft.span, plate), "aft: " + text)
		assert_eq(fore, PieceClip.holds(_fore.span, plate), "fore: " + text)
		assert_true(aft or fore, "drawn by one: " + text)
		if index != _on_cut:
			assert_false(aft and fore, "not by both: " + text)
		aft_alone += 1 if aft and not fore else 0
		fore_alone += 1 if fore and not aft else 0
	assert_gt(aft_alone, 0, "signs aft of the cut")
	assert_gt(fore_alone, 0, "signs fore of the cut")


func test_a_sign_on_the_cut_is_drawn_wherever_its_plate_is() -> void:
	var label := _pool(_aft).signs()[_on_cut]
	assert_eq(_plate(label).x, _cut, "its plate's middle on the cut")
	var letters := label.position.x
	assert_ne(letters, _cut, "its letters a hair off it")
	assert_false(
		PieceClip.holds(_aft.span, letters) and PieceClip.holds(_fore.span, letters),
		"its letters' own place on one stretch alone"
	)
	assert_true(_draws(_aft, _on_cut), "aft, whose paints draw its plate")
	assert_true(_draws(_fore, _on_cut), "fore, whose paints draw its plate")
	# Torn back from the cut once she parts there (ShipPieces), neither draws its plate.
	_aft.show_span(Vector2(-INF, _cut - 0.5))
	_fore.show_span(Vector2(_cut + 0.5, INF))
	assert_false(_draws(_aft, _on_cut), "torn back aft")
	assert_false(_draws(_fore, _on_cut), "torn back fore")
	_aft.show_span(Vector2(-INF, _cut))
	_fore.show_span(Vector2(_cut, INF))
	assert_true(_draws(_aft, _on_cut) and _draws(_fore, _on_cut), "both again")


func test_letters_are_filed_again_as_her_span_moves() -> void:
	var signs := _pool(_whole).signs()
	# The sign aft of the cut nearest it: the stretch moved aft of it takes it fore.
	var moved := -1
	for index in signs.size():
		var plate := _plate(signs[index]).x
		if plate < _cut and (moved == -1 or plate > _plate(signs[moved]).x):
			moved = index
	assert_gt(moved, -1, "a sign aft of the cut")
	var pool := _pool(_aft)
	assert_true(_draws(_aft, moved), "aft draws it")
	var drawn := pool.drawn()
	var moved_to := Vector2(-INF, _plate(signs[moved]).x - 0.01)
	_aft.show_span(moved_to)
	_fore.show_span(Vector2(moved_to.y, INF))
	assert_null(pool.signs()[moved].get_parent(), "taken out at once, the eye where it was")
	assert_lt(pool.drawn(), drawn, "fewer drawn aft")
	for label: Label3D in pool.signs():
		if label.get_parent() == pool:
			assert_true(PieceClip.holds(moved_to, _plate(label).x), "%s on it" % label.text)
	assert_false(_draws(_aft, moved), "aft no longer draws it")
	assert_true(_draws(_fore, moved), "fore draws it now")
	_aft.show_span(Vector2(-INF, _cut))
	_fore.show_span(Vector2(_cut, INF))
	assert_true(_draws(_aft, moved), "aft again")
	assert_false(_draws(_fore, moved), "fore no longer")


func test_her_whole_art_cut_down_draws_what_her_stretch_built_to_it_does() -> void:
	_whole.show_span(_aft.span)
	var signs := _pool(_whole).signs()
	for index in signs.size():
		assert_eq(_draws(_whole, index), _draws(_aft, index), signs[index].text)
	_whole.show_span(Vector2(-INF, INF))
	for index in signs.size():
		assert_true(_draws(_whole, index), "all of her again: %s" % signs[index].text)
