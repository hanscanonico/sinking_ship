extends GutTest
## A match's ship is dressed before her match is drawn (ShipDressing) — on a thread, so
## no frame stalls the seconds dressing her takes — and the match draws the very art her
## dressing made rather than dressing her again as it starts. Dressed on a thread she is
## the ship dressed here; a dressing let go before she is dressed frees her once she is;
## and one dressing fits only the cut it was made for, and a match on the ship, rules,
## sinking and seed it was made for: the one Play makes on the next match dressed ahead.
## One started ahead of her sinking dresses her as one started after, whether or not her
## sinking draws her as the frame it drew while it waited (ShipArt.build_frame).

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
	assert_eq(threaded.art.prop_art.count(), here.art.prop_art.count(), "every crate drawn")
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


func test_the_next_match_dressed_on_the_menu_fits_the_match_play_makes() -> void:
	var seeds := RandomNumberGenerator.new()
	seeds.seed = 1701
	var upcoming := NextMatch.new(load(MATCH_DATA), seeds)
	var choices := MatchChoices.new()
	upcoming.aim(choices)
	var next := upcoming.config()
	var dressing := ShipDressing.new(next)
	var played := upcoming.chosen(choices)
	assert_ne(played, next, "Play makes a match of its own")
	assert_true(dressing.fits(played), "on the ship, the rules, the sinking and the seed dressed")
	var typed := upcoming.chosen(choices.with_seed(str(next.match_seed + 1)))
	assert_false(dressing.fits(typed), "another seed's sinking is another")
	dressing.drop()


func test_a_dressing_started_ahead_of_her_sinking_dresses_her_as_one_started_after() -> void:
	var config := _trawler()
	var ahead := ShipDressing.new(config).start(true)
	await wait_frames(5)
	assert_false(ahead.done(), "never dressed before her sinking is made")
	assert_false(ahead.schedule_read(), "nor reading her schedule")
	config.sinking()
	ahead.sinking_made()
	await wait_until(ahead.done, PATIENCE)
	assert_true(ahead.schedule_read(), "her schedule read once she is dressed")
	var after := ShipDressing.new(config)
	after.dress_now()
	assert_eq(_shape(ahead.art), _shape(after.art), "the same ship, part for part")
	assert_eq(ahead.art.span, after.art.span, "drawn to the same stretch")
	assert_eq(ahead.art.prop_art.count(), after.art.prop_art.count(), "every crate drawn")
	ahead.drop()
	after.drop()


func test_one_started_ahead_of_a_sinking_felling_a_deck_dresses_her_as_one_after() -> void:
	var fells := SimFixtures.with_events(SimFixtures.calm(), [SimFixtures.collapse(4.0, &"bridge")])
	var config := SimFixtures.config(2, fells, 1, SimFixtures.steamer())
	var ahead := ShipDressing.new(config).start(true)
	await wait_frames(5)
	config.sinking()
	ahead.sinking_made()
	await wait_until(ahead.done, PATIENCE)
	var falls := MatchView.falls_of(config.schedule())
	assert_eq(falls, [&"bridge"] as Array[StringName], "her bridge falls")
	var after := ShipDressing.new(config)
	after.dress_now()
	assert_eq(_shape(ahead.art), _shape(after.art), "the same ship, part for part")
	assert_eq(ahead.art.prop_art.count(), after.art.prop_art.count(), "every crate drawn")
	ahead.drop()
	after.drop()


func test_a_dressing_started_ahead_and_let_go_before_her_sinking_frees_her() -> void:
	var dressing := ShipDressing.new(_trawler()).start(true)
	await wait_frames(5)
	var art := dressing.art
	dressing.drop()
	await wait_until(dressing.done, PATIENCE)
	assert_true(dressing.done(), "her thread let her go without her sinking")
	assert_false(is_instance_valid(art), "and freed what it built")
