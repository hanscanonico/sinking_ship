extends GutTest
## `make ship-check`'s float check, on every ship under data/ships/ with a structure:
## intact, she floats level at her stated waterline (§5b.2). The tolerances are est.

const SHIPS := "res://data/ships"
## Displacement against mass, as a share; draught in metres; trim and list in degrees.
const DISPLACEMENT := 0.01
const DRAUGHT := 0.02
const LEVEL_DEG := 0.1


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
