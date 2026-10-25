extends GutTest
## Every brawler with a bonus wears its kind's mark (#313): a band round its chest in the
## kind's colour, lit from within as the bonus was. MatchView draws it from the snapshot,
## so it shows through any seat's eyes, from the orbit camera and in a replay alike; a seat
## without one wears none. Through a seat's own eyes it is not drawn at all (D14): its HUD
## names its bonus, in its kind's colour (FirstPersonHud).

const MATCH := preload("res://scenes/match/match.tscn")
const MATCH_DATA := "res://data/match/default.tres"


## A match of three seats in below_decks' hold, bonuses played and none coming, seen
## through seat 0's eyes.
func _match() -> MatchScene:
	var scene: MatchScene = MATCH.instantiate()
	add_child_autofree(scene)
	var config := SimFixtures.config(3, SimFixtures.calm_until(600.0), 1, SimFixtures.below_decks())
	config.bot_tier = (load(MATCH_DATA) as MatchRules).bot_tier
	config.bonus_rules = SimFixtures.bonus_rules(600.0)
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
	seats[1]["bonus"] = 0
	var mark := _mark(scene, 1)
	assert_not_null(mark, "seat 1 has a Double life: it wears its mark")
	if mark != null:
		var kind := SimFixtures.double_life()
		var material := mark.material_override as StandardMaterial3D
		assert_eq(material.albedo_color, kind.mark, "in its kind's colour")
		assert_true(material.emission_enabled, "lit from within")
		assert_eq(material.emission, kind.mark)
	assert_null(_mark(scene, 2), "seat 2 has none: no mark")
	seats[1]["bonus"] = -1
	assert_null(_mark(scene, 1), "spent, or the seat out: the mark goes")
