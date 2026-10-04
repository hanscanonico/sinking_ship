class_name BotProfile
extends Resource
## A bot's difficulty (D10) — this and nothing else: §7's knobs, the weights its
## intents are scored by, and what it perceives. The numbers live in
## data/bots/*.tres, one file per tier.

const DIRECTORY := "res://data/bots"

## Where the tier stands among the others, easiest first: the order the menu lists
## them in.
@export var difficulty: int
## How many ticks old the snapshot a bot acts on is.
@export var reaction_ticks: int
## Ticks between thinks: re-scoring its intents and re-choosing its target.
@export var think_period: int
## Each choice of heading is off by up to this many degrees either way.
@export var aim_error_deg: float
## The fastest a bot turns its look, so that none turns faster than a person.
@export var turn_rate_deg: float
## The chance, rolled each think, that a bot braces against a facing windup.
@export var brace_read: float
## The chance, rolled each think, that a bot answers a bracing target with a charge.
@export var charge_read: float
## How much a bot wants its target between itself and the water before it shoves:
## the line-up intent's score, against the plain approach's.
@export var lineup_weight: float
## The plain approach's score: the bar lineup_weight, times how near its drop the
## target stands, must clear for the bot to come round it first.
@export var hunt_weight: float
## The score of making for high ground with nobody to go at: anything beats it, and it
## beats standing still.
@export var wander_weight: float
## How far a bot keeps from the waterline and the deck's open edges, in metres.
@export var edge_margin_m: float
## Late in the sinking a bot presses. Times the share of the ship's platforms under
## water: how much more the hunt and the line-up score, and the share of its edge
## margin it gives up — the last perches are fought for at their edges, not shared.
@export var late_hunt_gain: float
@export var late_margin_share: float
## How much a bot would rather go at whoever stands highest than at whoever stands
## nearest, 0…1.
@export var king_of_hill_bias: float
## How much less king_of_hill_bias counts once two or more stand on the highest ground
## the bot can reach, 0…1: up there is a crowd, not a prize.
@export var crowd_taper: float
## How much a target counts for how far over a shove would put it — the water or an
## open drop close behind it, unbraced — 0…1.
@export var exposure_weight: float
## How much less a target counts that another seat stands nearer than the bot, 0…1.
@export var crowd_aversion: float
## Whether a bot holds its shove while a seat other than its victim could land one on
## it: a shove thrown then leaves its back open.
@export var minds_its_back: bool
## How often, per second, a bot lapses: for mistake_seconds it walks a heading of
## its own stream's choosing, still keeping off the water — and off open drops too,
## but for the share heedless_lapses of its lapses, which may take it off an unrailed
## edge or through a gap in a railing.
@export var mistake_rate: float
@export var mistake_seconds: float
@export var heedless_lapses: float
## The climb intent's weight: once the lowest corner of the floor it stands on — its
## room, or its open deck — is less than this many metres above the sea, the bot
## makes for the highest ground it can reach.
@export var climb_margin_m: float
## How near, in metres, a seat in the sea must be for the bot to make it its
## target and guard the edge against its climbing out.
@export var guard_range_m: float
## Told of a lurch, a bot within this many metres of the side it will put down, or
## of an unrailed drop that way, walks away from it; any farther, it stays.
@export var ride_margin_m: float
## Whether a bot steps out of the path of a crate it sees sliding at it (SH10): the
## easy tier is caught by the cargo.
@export var dodges_cargo: bool
## How much better another intent or target must score than the bot's current one
## before it switches: what keeps it from dithering between two.
@export var hysteresis: float
## A bot sees a body only where no wall, deck or hull stands between their eyes, and
## hears one within hearing_m through anything; it remembers where it last saw or
## heard one for memory_seconds.
@export var eye_height_m: float
@export var hearing_m: float
@export var memory_seconds: float


## The tier [param tier]'s profile, or null when there is none.
static func for_tier(tier: StringName) -> BotProfile:
	var path := "%s/%s.tres" % [DIRECTORY, tier]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as BotProfile


## Every tier there is a profile for, by file name, easiest first.
static func tiers() -> PackedStringArray:
	var found: Array[BotProfile] = []
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.get_extension() == "tres":
			found.append(for_tier(StringName(file.get_basename())))
	found.sort_custom(
		func(a: BotProfile, b: BotProfile) -> bool: return a.difficulty < b.difficulty
	)
	var names := PackedStringArray()
	for profile: BotProfile in found:
		names.append(profile.resource_path.get_file().get_basename())
	return names


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if reaction_ticks < 0:
		found.append("bot: reaction_ticks must not be negative")
	if think_period < 1:
		found.append("bot: think_period must be at least 1")
	if turn_rate_deg <= 0.0:
		found.append("bot: turn_rate_deg must be positive")
	for field: String in [
		"brace_read",
		"charge_read",
		"lineup_weight",
		"hunt_weight",
		"wander_weight",
		"king_of_hill_bias",
		"heedless_lapses",
		"crowd_taper",
		"exposure_weight",
		"crowd_aversion",
		"late_margin_share",
	]:
		if float(get(field)) < 0.0 or float(get(field)) > 1.0:
			found.append("bot: %s must be within 0…1" % field)
	for field: String in [
		"aim_error_deg",
		"edge_margin_m",
		"late_hunt_gain",
		"mistake_rate",
		"mistake_seconds",
		"climb_margin_m",
		"guard_range_m",
		"ride_margin_m",
		"hysteresis",
		"eye_height_m",
		"hearing_m",
		"memory_seconds",
	]:
		if float(get(field)) < 0.0:
			found.append("bot: %s must not be negative" % field)
	return found
