class_name BotInputSource
extends InputSource
## A bot seat behind the same door as every other seat (D10): it watches the
## snapshots through a delayed BotView and answers its brain's frame. The view and the
## brain ask Surfaces of the bots' own, never the sim's — her decks', and those of the
## faces she turns up (BotFloors).

var brain: BotBrain
var view: BotView


## [param floors] — the walk graphs and the Surfaces they were built over — may be
## shared by the bots of one match: they only ever answer for the pose they are handed,
## so sharing them shares what each tick costs to work out, never a decision. Without
## them, the bot builds its own.
func _init(seat: int, profile: BotProfile, config: MatchConfig, floors: BotFloors = null) -> void:
	if floors == null:
		floors = floors_of(config)
	view = BotView.new(seat, profile, floors)
	brain = BotBrain.new(
		seat,
		profile,
		config.rules,
		config.ship.props,
		floors,
		SeedStreams.derive(config.match_seed, seat)
	)


## The floors [param config]'s bots find their way on, her decks' walk graph first.
static func floors_of(config: MatchConfig) -> BotFloors:
	var deck := WalkGraph.new(config.ship, Surfaces.new(config.ship), config.rules)
	return BotFloors.new(deck, config)


## One bot source per seat from [param first_seat] to the match's last.
static func fill(
	config: MatchConfig, profile: BotProfile, first_seat: int = 0
) -> Array[InputSource]:
	var sources: Array[InputSource] = []
	var floors := floors_of(config)
	for seat in range(first_seat, config.seats):
		# Unqualified: `BotInputSource.new` here keeps the script alive at exit (4.7.1).
		sources.append(new(seat, profile, config, floors))
	return sources


func next_frame(tick: int) -> InputFrame:
	return brain.decide(view, tick)


func observe(snapshot: Dictionary, pose: ShipPose) -> void:
	view.push(snapshot, pose)
