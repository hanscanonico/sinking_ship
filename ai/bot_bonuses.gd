class_name BotBonuses
extends RefCounted
## A bot and the bonuses aboard (#307) as its delayed view shows them (D10) — every one,
## walls or not, as the props are: the feed has told every player each one's kind and room.
## The bonus it goes for, chosen at a think: of a kind worth more to it than its own bonus, a
## walk of bonus_range_m or less away, while the floor it lies on and every portal of its way
## there stand bonus_margin_m or more above the water as its view has the water now — never
## as the timeline has it next; the best for how much more it is worth, less the farther it
## lies. Unlike a lifebuoy, it goes down toward the water for one by design. Then the Grab
## press that takes it once a press would (GrabReach), never a second before its view shows
## the first. And the spare cold meter its own bonus gives it, unspent (Double life): more
## time in the sea, which its swim counts on. Nothing here rolls the bot's stream.

## The bonus spot of the bonus it goes for, by its index in the layout's, as the last think
## chose it; -1 for none.
var spot := -1

var _seat: int
var _profile: BotProfile
var _rules: BrawlRules
var _layout: ShipLayout
## What a Grab press reaches, in a match played with bonuses; null in one without.
var _reach: GrabReach
## The props a hand may hold (GrabReach.holdable_of).
var _holdable: PackedInt32Array
## The tick of its last Grab press, or -1.
var _pressed_at := -1


## The bonuses of [param seat]'s bot in a match on [param layout] under [param rules],
## played with [param bonus_rules] (null for none).
func _init(
	seat: int, profile: BotProfile, rules: BrawlRules, layout: ShipLayout, bonus_rules: BonusRules
) -> void:
	_seat = seat
	_profile = profile
	_rules = rules
	_layout = layout
	if bonus_rules != null:
		_reach = GrabReach.new(layout, rules, bonus_rules)
	_holdable = GrabReach.holdable_of(layout)


## Picks the bonus to go for at a think, from [param me] in [param seen], among those
## [param found] — a search of [param graph] from where it stands — reaches under
## [param pose]: of a kind worth more to it than its own bonus (worth), a walk of
## bonus_range_m or less away, its floor and its way there its margin above the water
## (_clear) — the best by how much more it is worth, less by up to half the farther away it
## lies. Returns its score, that by bonus_weight, or 0 with none to go for: none, too, off
## her decks, where a body takes nothing (GrabReach) and her spots are no points of the
## frame it finds its way in.
func choose(
	seen: Dictionary, me: Dictionary, found: WalkGraph.Search, graph: WalkGraph, pose: ShipPose
) -> float:
	spot = -1
	if _reach == null or me["state"] != PlayerState.Body.GROUNDED or found.cost.is_empty():
		return 0.0
	if seen["up"][me["piece"]] != Faces.Up.DECK:
		return 0.0
	var my_pos: Vector3 = me["pos"]
	var mine := worth(me["bonus"])
	var best := 0.0
	for entry: Dictionary in seen["bonuses"]:
		var gain := worth(entry["kind"]) - mine
		var at := _layout.bonus_spots[entry["spot"]].point
		var zone := graph.zone_at(at, graph.surfaces().under(at, _rules.step_height))
		if gain <= 0.0 or zone == WalkGraph.NONE or found.cost[zone] == INF:
			continue
		var far := found.cost[zone] + Vector2(at.x - my_pos.x, at.z - my_pos.z).length()
		if far > _profile.bonus_range_m or not _clear(graph, found, zone, at, pose):
			continue
		var score := _profile.bonus_weight * gain * (1.0 - 0.5 * far / _profile.bonus_range_m)
		if score > best:
			best = score
			spot = entry["spot"]
	return best


## What a bonus of [param kind] — by its index among the match's bonus kinds, -1 for none
## — is worth to the bot: its tier's worth for the kind's title (BotProfile.bonus_worth).
func worth(kind: int) -> float:
	if kind == -1:
		return 0.0
	return _profile.bonus_worth.get(_reach.kinds[kind].title, 1.0)


## The bonus [param seen] has aboard at the spot it goes for, or empty: taken, lost, or
## none chosen.
func target(seen: Dictionary) -> Dictionary:
	if spot != -1:
		for entry: Dictionary in seen["bonuses"]:
			if entry["spot"] == spot:
				return entry
	return {}


## Where it stands to take the bonus it goes for and where that lies, as [param seen] has
## it — the one spot: it walks onto it — or empty, the bonus gone.
func aim(seen: Dictionary) -> PackedVector3Array:
	if target(seen).is_empty():
		return PackedVector3Array()
	var at := _layout.bonus_spots[spot].point
	return PackedVector3Array([at, at])


## A Grab press on [param tick] when a press by the bot — [param me] in [param seen],
## carried to [param now_pos] and looking [param look] — would take the bonus it goes for,
## as [param surfaces] has her; else nothing. None while its view predates its last. A
## press that reaches no bonus lets go of what the hands hold: holding a prop, it presses
## only once a press would take the bonus from where its view shows it, too.
func grab(
	seen: Dictionary, me: Dictionary, now_pos: Vector3, look: int, surfaces: Surfaces, tick: int
) -> int:
	if target(seen).is_empty() or seen["tick"] <= _pressed_at:
		return 0
	var aboard: Array[BonusState] = []
	for entry: Dictionary in seen["bonuses"]:
		aboard.append(BonusState.from_dict(entry))
	var player := PlayerState.from_dict(me)
	player.facing = InputFrame.yaw_angle(look)
	var from: Array[Vector3] = [now_pos]
	if PropState.held_in(seen, _seat, _holdable) != -1:
		from.append(player.pos)
	for at: Vector3 in from:
		player.pos = at
		var height := _rules.height_at(surfaces, at)
		var takes := _reach.bonus_taken(player, Faces.Up.DECK, height, aboard, surfaces)
		if takes == -1 or aboard[takes].spot != spot:
			return 0
	_pressed_at = tick
	return InputFrame.GRAB


## The seconds of cold the spare meter [param me]'s bonus gives it add while unspent (Double
## life): a whole cold meter more, as the sim counts it (MatchVerdict.cold_left); none
## without one.
func spare(me: Dictionary) -> float:
	var kind: int = me["bonus"]
	if kind == -1 or not _reach.kinds[kind].spare_meter:
		return 0.0
	return _rules.cold_meter


## Whether the floor of [param zone], where a bonus lies at [param at] — a room's, by its
## lowest corner — and both ends of every portal on the way [param found] has to it stand
## bonus_margin_m or more above the water under [param pose]: the water as it stands now,
## never as the timeline has it next.
func _clear(
	graph: WalkGraph, found: WalkGraph.Search, zone: int, at: Vector3, pose: ShipPose
) -> bool:
	if graph.floor_height(zone, at, pose) < _profile.bonus_margin_m:
		return false
	for leg: WalkGraph.Portal in graph.route_in(found, zone):
		for end: Vector3 in [leg.entry, leg.exit]:
			if pose.above_water(end) < _profile.bonus_margin_m:
				return false
	return true
