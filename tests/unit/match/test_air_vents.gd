extends GutTest
## A pocket's air going free bursts out of one opening (#631, AirVents): the one InnerWater
## draws its burst at is the one the match's blast blows swimmers clear of (Falls), on her
## real ships' sinkings — the whole ship's water as MatchView draws it, a piece's as
## ShipPieces does once she breaks (D13).

const RunMatch := preload("res://tools/run_match.gd")
const SEA := preload("res://scenes/art/water.gdshader")
const SHIPS: Array[StringName] = [&"steamer", &"titanic"]
const SEED := 1701


func test_her_water_bursts_the_air_out_where_the_match_blows_swimmers_clear() -> void:
	var sea := ShaderMaterial.new()
	sea.shader = SEA
	for ship: StringName in SHIPS:
		var config := RunMatch.default_config(SEED, 2, ship)
		var schedule := config.schedule()
		var sim := MatchSim.create(config)
		var named := 0
		var differences: Array[String] = []
		for piece in schedule.piece_count():
			var currents := Currents.of_piece(config, schedule, piece)
			var falls := Falls.of_piece(config, schedule, piece, currents)
			if falls == null or falls.blasts() == 0:
				continue
			var water: InnerWater = add_child_autofree(InnerWater.new())
			if piece == 0:
				water.setup(
					config.ship.structure,
					config.ship.rooms,
					config.ship,
					schedule.passages(),
					schedule.failing(),
					sea,
					{}
				)
			else:
				var structure := schedule.structure_of(piece)
				var layout := sim.pieces.layout(piece)
				var span := schedule.span_of(piece)
				water.setup(
					structure,
					layout.rooms,
					layout,
					AirVents.kept(schedule.passages(), structure, span),
					AirVents.kept(schedule.failing(), structure, span),
					sea,
					{}
				)
			for blast in falls.blasts():
				var at := falls.blast_at(blast)
				var pose := schedule.pose_at(at.x).of_piece(piece)
				var way := water._vents.way_out(at.y, pose)
				var drawn := &"" if way == -1 else water._vents.openings()[way].name
				var blown := falls.way_out_of(blast)
				var blows := &"" if blown == null else blown.name
				named += 1 if blows != &"" else 0
				if drawn != blows and differences.size() < 4:
					differences.append("piece %d tick %d: %s, %s" % [piece, at.x, drawn, blows])
		assert_eq(differences, [] as Array[String], "%s's bursts are its blasts" % ship)
		assert_gt(named, 0, "%s's sinking lets a pocket's air out by an opening" % ship)
