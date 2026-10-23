extends GutTest
## What her props sound like (#273): a prop taken in the hands, let go of or knocked loose
## knocks once at the brawler (CuePlanner). A prop going into the sea splashes as a crate
## does (test_cue_planner).


func _planner(sim: MatchSim) -> CuePlanner:
	var planner := CuePlanner.new(sim.config, sim.surfaces, sim.schedule, 0)
	planner.listener_seat = -1
	return planner


func _of(cues: Array[AudioCue], kind: AudioCue.Kind) -> Array[AudioCue]:
	return cues.filter(func(cue: AudioCue) -> bool: return cue.kind == kind)


## Steps [param sim] once per row of [param rows] — each a seat → frame map — planning
## each step.
func _play(planner: CuePlanner, sim: MatchSim, rows: Array) -> Array[AudioCue]:
	var heard: Array[AudioCue] = []
	for frames: Dictionary in rows:
		var previous := sim.snapshot()
		SimFixtures.step(sim, frames)
		heard.append_array(planner.plan(previous, sim.snapshot()))
	return heard


## A Grab press that takes a prop, and one that lets it go, each knock once at the
## brawler (#273); a ring knocked loose too.
func test_a_grab_and_a_let_go_knock_at_the_brawler() -> void:
	var layout := SimFixtures.crated([SimFixtures.lifebuoy(Vector3(1.0, 0.0, 0.0))])
	var sim := SimFixtures.sim(1, null, layout)
	SimFixtures.place(sim, 0, Vector3.ZERO, 0.0)
	var grab := {0: SimFixtures.frame(0, Vector2.ZERO, InputFrame.GRAB)}
	var rest := {0: SimFixtures.frame(0)}
	var knocks := _of(_play(_planner(sim), sim, [grab, rest, grab, rest]), AudioCue.Kind.GRAB)
	assert_eq(knocks.size(), 2, "one as it takes the ring, one as it lets go")
	for knock: AudioCue in knocks:
		assert_eq(knock.seat, 0)
		assert_true(knock.positional)
