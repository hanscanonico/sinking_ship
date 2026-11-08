extends GutTest
## Every brawler with a bonus wears its kind's mark (#313): a band round its chest in the
## kind's colour, lit from within as the bonus was. MatchView draws it from the snapshot on
## every body it draws — through a seat's eyes every other seat's, from the orbit camera
## every seat's, as from the observer's — and draws a replay the same way; a seat without
## one wears none. The seat whose eyes the view is in is not drawn, mark and all (D14): its
## HUD shows its bonuses, by their kinds' badges (FirstPersonHud).

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"
const BONUS_RULES := "res://data/rules/bonuses.tres"


## A match of three seats in below_decks' hold, played with [param bonus_rules] — Double life
## alone, none coming, when none are given — seen through seat 0's eyes.
func _match(bonus_rules: BonusRules = null) -> MatchScene:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(3, SimFixtures.calm_until(600.0), 1, SimFixtures.below_decks())
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	config.bonus_rules = bonus_rules if bonus_rules != null else SimFixtures.bonus_rules(600.0)
	scene.start(config, true)
	return scene


## The mark [param seat]'s brawler wears in [param scene], drawn as the snapshot has it now;
## null for none shown.
func _mark(scene: MatchScene, seat: int) -> MeshInstance3D:
	scene.get_node("MatchView")._process(0.0)
	var body := scene.get_node("MatchView/Ship/Seat%d" % seat)
	var mark := body.find_child("BonusMark", true, false) as MeshInstance3D
	return mark if mark != null and mark.is_visible_in_tree() else null


func test_a_seat_with_a_bonus_wears_its_kind_s_mark() -> void:
	var scene := _match()
	var seats: Array = scene._driver.current["seats"]
	seats[1]["bonuses"] = [0]
	var mark := _mark(scene, 1)
	assert_not_null(mark, "seat 1 has a Double life: it wears its mark")
	if mark != null:
		var kind := SimFixtures.double_life()
		var material := mark.material_override as StandardMaterial3D
		assert_eq(material.albedo_color, kind.mark, "in its kind's colour")
		assert_true(material.emission_enabled, "lit from within")
		assert_eq(material.emission, kind.mark)
	assert_null(_mark(scene, 2), "seat 2 has none: no mark")
	seats[1]["bonuses"] = []
	assert_null(_mark(scene, 1), "spent, or the seat out: the mark goes")


## A seat with bonuses of two kinds wears a band for each, in each kind's colour, the second
## under the first; two of one kind, one band.
func test_a_seat_wears_a_band_for_each_kind_it_has() -> void:
	var rules: BonusRules = load(BONUS_RULES)
	var scene := _match(rules)
	var seats: Array = scene._driver.current["seats"]
	seats[1]["bonuses"] = [1, 1, 2]
	var first := _mark(scene, 1)
	var body := scene.get_node("MatchView/Ship/Seat1")
	var second := body.find_child("BonusMark1", true, false) as MeshInstance3D
	assert_not_null(first, "High jump's band")
	assert_true(second != null and second.is_visible_in_tree(), "and Steady's")
	if first != null and second != null:
		var marks := [first.material_override.albedo_color, second.material_override.albedo_color]
		assert_eq(marks, [rules.kinds[1].mark, rules.kinds[2].mark], "each in its colour")
		assert_lt(second.position.y, first.position.y, "the second under the first")
	seats[1]["bonuses"] = [1, 1]
	_mark(scene, 1)
	assert_false(second != null and second.is_visible_in_tree(), "two of one kind: one band")


## Whichever kind of the shipped bonus rules a seat has (#316), it wears that kind's mark in
## that kind's colour.
func test_each_kind_is_worn_in_its_own_colour() -> void:
	var rules: BonusRules = load(BONUS_RULES)
	var scene := _match(rules)
	var seats: Array = scene._driver.current["seats"]
	for kind in rules.kinds.size():
		seats[1]["bonuses"] = [kind]
		var mark := _mark(scene, 1)
		var title := rules.kinds[kind].title
		assert_not_null(mark, "%s: its mark" % title)
		if mark != null:
			var material := mark.material_override as StandardMaterial3D
			assert_eq(material.albedo_color, rules.kinds[kind].mark, "%s: in its colour" % title)
			assert_eq(material.emission, rules.kinds[kind].mark, "%s: lit from within" % title)


func test_no_mark_through_the_seat_s_own_eyes_but_every_one_from_the_orbit_camera() -> void:
	var scene := _match()
	var seats: Array = scene._driver.current["seats"]
	seats[0]["bonuses"] = [0]
	assert_null(_mark(scene, 0), "through seat 0's own eyes: no body, so no mark")
	scene.get_node("MatchView").look_out_of(-1)
	assert_not_null(_mark(scene, 0), "from the orbit camera, as from the observer's: its mark")
