extends GutTest
## A match's ship is dressed before her match is drawn (ShipDressing) — on a thread, so
## no frame stalls the seconds dressing her takes — and the match draws the very art her
## dressing made rather than dressing her again as it starts. Dressed on a thread she is
## the ship dressed here; a dressing let go before she is dressed frees her once she is;
## and one dressing fits only the match, and the cut, it was made for.

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const TRAWLER := "res://data/ships/trawler.tres"
## How long a dressing on a thread may take here, in seconds.
const PATIENCE := 60.0


## The trawler on a calm sea: dressed as a match draws her, her sinking cheap to build.
func _trawler() -> MatchConfig:
	return SimFixtures.config(2, null, 1, load(TRAWLER))


## [param node] and everything under it, as names — but the numbers the engine names a
## part with, which count every part ever named — kinds and surfaces, in tree order.
func _shape(node: Node) -> PackedStringArray:
	var numbered := RegEx.create_from_string("@[0-9]+")
	var found := PackedStringArray()
	for part: Node in [node] + node.find_children("*", "", true, false):
		var named := numbered.sub(str(node.get_path_to(part)), "@", true)
		var line := "%s %s" % [named, part.get_class()]
		var drawn := part as MeshInstance3D
		if drawn != null and drawn.mesh != null:
			line += " %d surfaces" % drawn.mesh.get_surface_count()
		found.append(line)
	return found


func test_a_ship_dressed_on_a_thread_is_the_one_dressed_here() -> void:
	var config := _trawler()
	var threaded := ShipDressing.new(config).start()
	await wait_until(threaded.done, PATIENCE)
	assert_true(threaded.done(), "dressed on its thread")
	var here := ShipDressing.new(config)
	here.dress_now()
	assert_true(here.done(), "dressed here at once")
	assert_gt(threaded.art.get_child_count(), 0, "she is dressed")
	assert_eq(_shape(threaded.art), _shape(here.art), "the same ship, part for part")
	assert_eq(threaded.art.crates().size(), here.art.crates().size(), "every crate drawn")
	assert_true(threaded.stretches.is_empty(), "a hull that never breaks is one stretch")
	threaded.drop()
	here.drop()


func test_a_match_draws_the_ship_its_dressing_dressed() -> void:
	var config := SimFixtures.config(2)
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	var dressing := ShipDressing.new(config).start()
	await wait_until(dressing.done, PATIENCE)
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	scene.dressing = dressing
	scene.start(config, true)
	var art := scene.get_node("MatchView/Ship/ShipArt") as ShipArt
	assert_same(art, dressing.art, "the dressing's art is the ship drawn, not dressed again")
	assert_null(scene.dressing, "taken")
	assert_same(scene._ship_art, art, "and the one the match's graphics reach")


func test_a_dressing_let_go_as_she_is_dressed_frees_her() -> void:
	var dressing := ShipDressing.new(_trawler()).start()
	var art := dressing.art
	dressing.drop()
	await wait_until(dressing.done, PATIENCE)
	assert_false(is_instance_valid(art), "freed once she was dressed")


func test_a_dressing_fits_its_own_match_and_cut() -> void:
	var config := SimFixtures.config(2)
	var dressing := ShipDressing.new(config, 3.0)
	assert_true(dressing.fits(config, 3.0))
	assert_false(dressing.fits(config), "seen through eyes, nothing is cut away")
	assert_false(dressing.fits(SimFixtures.config(2), 3.0), "another match, the same ship")
	var resting := ShipDressing.at_rest(config.ship, config.rules)
	assert_false(resting.fits(config), "a ship at rest is no match's")
	resting.drop()
	dressing.drop()
