class_name BotInputSource
extends InputSource
## A bot seat behind the same door as every other seat (D10): it watches the
## snapshots through a delayed BotView and answers its brain's frame.

var brain: BotBrain
var view: BotView


func _init(seat: int, profile: BotProfile, config: MatchConfig) -> void:
	view = BotView.new(profile.reaction_ticks)
	var surfaces := Surfaces.new(config.ship)
	brain = BotBrain.new(
		seat,
		profile,
		config.rules,
		surfaces,
		WalkGraph.new(config.ship, surfaces, config.rules.body_radius),
		SeedStreams.derive(config.match_seed, seat)
	)


## One bot source per seat from [param first_seat] to the match's last.
static func fill(
	config: MatchConfig, profile: BotProfile, first_seat: int = 0
) -> Array[InputSource]:
	var sources: Array[InputSource] = []
	for seat in range(first_seat, config.seats):
		# Unqualified: `BotInputSource.new` here keeps the script alive at exit (4.7.1).
		sources.append(new(seat, profile, config))
	return sources


func next_frame(tick: int) -> InputFrame:
	return brain.decide(view, tick)


func observe(snapshot: Dictionary, pose: ShipPose) -> void:
	view.push(snapshot, pose)
