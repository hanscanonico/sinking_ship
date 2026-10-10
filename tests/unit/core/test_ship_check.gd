extends GutTest
## `make ship-check`'s float check, on every ship under data/ships/ with a structure:
## intact, she floats level at her stated waterline (§5b.2); and she founders on her
## sure hit within the bake's cap of every scenario of hers (§5b.1) — onto the bottom of
## a coast's (SH32). The tolerances are est.

const SHIPS := "res://data/ships"
const SCENARIOS := "res://data/sinking"
## Displacement against mass, as a share; draught in metres; trim and list in degrees.
const DISPLACEMENT := 0.01
const DRAUGHT := 0.02
const LEVEL_DEG := 0.1
## The Titanic on the night's condition (SH34, the research's): her displacement in kg,
## ± 2 %; her mean draught, ± 0.15 m; her trim, positive bow down, so 0.2° by the stern,
## ± 0.3°; her GM, ± 0.15 m.
const TITANIC := "res://data/ships/titanic.tres"
const NIGHT_DISPLACEMENT := 49075e3
const NIGHT_DRAUGHT := 9.83
const NIGHT_TRIM_DEG := -0.2
const NIGHT_GM := 0.80


func test_intact_steamer_floats_level_at_her_waterline() -> void:
	var sea := SeaPhysics.load_default()
	assert_eq(sea.problems(), PackedStringArray(), "the sea's constants load")
	var checked := 0
	for file: String in DirAccess.get_files_at(SHIPS):
		if not file.ends_with(".tres"):
			continue
		var layout: ShipLayout = load("%s/%s" % [SHIPS, file])
		var structure := layout.structure
		if structure == null:
			continue
		checked += 1
		assert_eq(structure.problems(), PackedStringArray(), "%s: its structure loads" % file)
		var mass := structure.total_mass()
		var centre := structure.mass_centre()
		var stated := Hydrostatics.level(structure.waterline_y)
		var displaced := Hydrostatics.cut_hull(structure.sections, stated).volume * sea.sea_density
		var volume := mass / sea.sea_density
		var rest := Hydrostatics.rest(structure.sections, volume, centre)
		# Her draught amidships, under her origin.
		var draught := rest.height / rest.up_y - structure.keel_y
		var trim := rad_to_deg(atan(rest.trim()))
		var list := rad_to_deg(atan(rest.list()))
		var gm := Hydrostatics.metacentric_height(structure.sections, volume, centre, rest)
		(
			gut
			. p(
				(
					(
						"%s: %.1f t displaced at her waterline for %.1f t (%+.3f%%); at rest draught %.4f m"
						+ " (stated %.2f), trim %+.5f°, list %+.5f°, GM %.3f m"
					)
					% [
						file,
						displaced / 1000.0,
						mass / 1000.0,
						(displaced - mass) / mass * 100.0,
						draught,
						structure.waterline_y - structure.keel_y,
						trim,
						list,
						gm,
					]
				)
			)
		)
		assert_almost_eq(displaced / mass, 1.0, DISPLACEMENT, "%s: displaces her mass" % file)
		assert_almost_eq(
			draught, structure.waterline_y - structure.keel_y, DRAUGHT, "%s: at her draught" % file
		)
		assert_almost_eq(trim, 0.0, LEVEL_DEG, "%s: no trim" % file)
		assert_almost_eq(list, 0.0, LEVEL_DEG, "%s: no list" % file)
		assert_gt(gm, 0.0, "%s: a list rights itself" % file)
	assert_gt(checked, 0, "a ship to float")


func test_the_titanic_floats_on_the_nights_condition() -> void:
	var sea := SeaPhysics.load_default()
	var structure := (load(TITANIC) as ShipLayout).structure
	var mass := structure.total_mass()
	var centre := structure.mass_centre()
	var volume := mass / sea.sea_density
	var rest := Hydrostatics.rest(structure.sections, volume, centre)
	var draught := rest.height / rest.up_y - structure.keel_y
	var trim := rad_to_deg(atan(rest.trim()))
	var gm := Hydrostatics.metacentric_height(structure.sections, volume, centre, rest)
	gut.p(
		(
			"titanic: %.0f t, draught %.3f m, trim %+.3f°, GM %.3f m"
			% [mass / 1000.0, draught, trim, gm]
		)
	)
	assert_almost_eq(mass, NIGHT_DISPLACEMENT, NIGHT_DISPLACEMENT * 0.02, "49 075 t")
	assert_almost_eq(draught, NIGHT_DRAUGHT, 0.15, "9.83 m of draught")
	assert_almost_eq(trim, NIGHT_TRIM_DEG, 0.3, "0.2° by the stern")
	assert_almost_eq(gm, NIGHT_GM, 0.15, "a GM of 0.80 m")


func test_she_founders_on_her_sure_hit() -> void:
	var sea := SeaPhysics.load_default()
	var checked := 0
	for file: String in DirAccess.get_files_at(SHIPS):
		if not file.ends_with(".tres"):
			continue
		var layout: ShipLayout = load("%s/%s" % [SHIPS, file])
		var structure := layout.structure
		if structure == null:
			continue
		var stem := file.get_basename()
		for scenario_file: String in DirAccess.get_files_at(SCENARIOS):
			if not scenario_file.begins_with(stem + "_"):
				continue
			var scenario: SinkScenario = load("%s/%s" % [SCENARIOS, scenario_file])
			checked += 1
			var damage := HitMapper.map_explicit(structure.sure_hit, structure, scenario.hit)
			damage.sea_depth = scenario.sea_depth
			var stepper := SinkStepper.new(structure, damage, sea)
			var timeline := SinkTimeline.bake(stepper, sea, scenario.bake_cap)
			gut.p(
				(
					"%s in %s: her sure hit opens %.3f m², %s at %.0f s of a %.0f s cap"
					% [
						file,
						scenario_file,
						damage.area(),
						SinkTimeline.End.keys()[timeline.end],
						timeline.length(),
						scenario.bake_cap
					]
				)
			)
			# On a coast she founders onto the bottom: gone, or aground with part of her
			# dry — what a match plays (MustSink.played, Q21).
			assert_true(
				MustSink.played(timeline.end),
				"%s founders on her sure hit in %s" % [file, scenario_file]
			)
	assert_gt(checked, 0, "a ship and a scenario to sink her in")
