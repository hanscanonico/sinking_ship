class_name BotInputSource
extends InputSource
## A bot seat behind the same door as every other seat (D10): it watches the
## snapshots through a delayed BotView and answers its brain's frame. The view and the
## brain ask a Surfaces of the bots' own, never the sim's.

var brain: BotBrain
var view: BotView


## [param walk_graph] and the Surfaces it was built over may be shared by the bots of
## one match: both only ever answer for the pose they are handed, so sharing them
## shares what each tick costs to work out, never a decision. Without one, the bot
## builds its own.
func _init(
	seat: int, profile: BotProfile, config: MatchConfig, walk_graph: WalkGraph = null
) -> void:
	if walk_graph == null:
		walk_graph = WalkGraph.new(config.ship, Surfaces.new(config.ship), config.rules)
	view = BotView.new(seat, profile, walk_graph.surfaces())
	brain = BotBrain.new(
		seat,
		profile,
		config.rules,
		config.ship.props,
		walk_graph.surfaces(),
		walk_graph,
		SeedStreams.derive(config.match_seed, seat)
	)


## One bot source per seat from [param first_seat] to the match's last.
static func fill(
	config: MatchConfig, profile: BotProfile, first_seat: int = 0
) -> Array[InputSource]:
	var sources: Array[InputSource] = []
	var walk_graph := WalkGraph.new(config.ship, Surfaces.new(config.ship), config.rules)
	for seat in range(first_seat, config.seats):
		# Unqualified: `BotInputSource.new` here keeps the script alive at exit (4.7.1).
		sources.append(new(seat, profile, config, walk_graph))
	return sources


func next_frame(tick: int) -> InputFrame:
	return brain.decide(view, tick)


func observe(snapshot: Dictionary, pose: ShipPose) -> void:
	view.push(snapshot, pose)
