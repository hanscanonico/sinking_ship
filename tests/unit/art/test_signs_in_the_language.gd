extends GutTest
## A door sign names the room beyond as the HUD names it — in the language played: the
## plates over the steamer's engine-room doors read "Engine Room" and "Forward Hold" in a
## Spanish and a French game, beside a HUD that said "Sala de máquinas" (seen in an
## online crew test, 2026-11-26).

const RunMatch := preload("res://tools/run_match.gd")


func after_each() -> void:
	Language.use(Language.SOURCE)


func test_the_signs_read_in_the_language_played() -> void:
	Language.use("es")
	var said := _sign_texts()
	assert_true(said.has("Sala de máquinas"), "the engine room's plate in Spanish: %s" % [said])
	assert_false(said.has("Engine Room"), "and never in English")


func test_the_signs_read_as_before_in_english() -> void:
	Language.use("en")
	var said := _sign_texts()
	assert_true(said.has("Engine Room"), "each word capitalised: %s" % [said])


## Every door sign's letters on the steamer, dressed as a match dresses her.
static func _sign_texts() -> PackedStringArray:
	var config := RunMatch.default_config(1701)
	var art := ShipArt.new()
	art.rules = config.rules
	art.pack = true
	art.build(config.ship, config.rules.railing_height, config.rules.body_radius)
	var texts := PackedStringArray()
	for label: Label3D in (art.get_node("Dressing/Signs") as SignPool).signs():
		texts.append(label.text)
	art.free()
	return texts
