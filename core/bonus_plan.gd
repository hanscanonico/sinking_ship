class_name BonusPlan
extends RefCounted
## The bonuses a match plans to bring aboard (#307): for each, the tick it comes, its kind by
## the bonus rules' odds, and how far along the open spots its pick lands — drawn once at the
## start from a stream of its own (SeedStreams' "bonus"), so turning bonuses on or off moves
## no other draw: a pure function of the match's bonus rules, seed and sinking, as her
## sinking is (D4, D7). The first comes the rules' first seconds in, each next an interval
## on, give or take its jitter, until her sinking's end, every time on her sinking's clock:
## quickened with her on the fast clock. Nothing is drawn once it is made, so none of it is
## in the snapshot: a match continued from one draws it again.

## Per planned bonus, in the order they come: its tick, its kind — by its index among the
## bonus rules' kinds — and its pick, 0…1.
var ticks := PackedInt32Array()
var kinds := PackedInt32Array()
var picks := PackedFloat64Array()


## The plan of a match on [param rules] — seeded [param match_seed], her sinking played on
## [param clock] (SinkScenario.clock) and over on [param end_tick] — or none, for no rules,
## or rules with problems (BonusRules.problems).
static func drawn(rules: BonusRules, match_seed: int, clock: float, end_tick: int) -> BonusPlan:
	var plan := BonusPlan.new()
	if rules == null or not rules.problems().is_empty() or clock <= 0.0:
		return plan
	var stream := SeedStreams.derive(match_seed, "bonus")
	var total := 0.0
	for odd: float in rules.odds:
		total += odd
	var seconds := rules.first
	var tick := Ticks.from_seconds(seconds / clock)
	while tick <= end_tick:
		plan.ticks.append(tick)
		plan.kinds.append(_kind(rules.odds, stream.randf() * total))
		plan.picks.append(stream.randf())
		seconds += rules.interval + stream.randf_range(-rules.jitter, rules.jitter)
		tick = Ticks.from_seconds(seconds / clock)
	return plan


## The planned bonuses due on [param tick], by their index in the plan, in its order.
func due(tick: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	var at := ticks.bsearch(tick)
	while at < ticks.size() and ticks[at] == tick:
		found.append(at)
		at += 1
	return found


## The spot of [param open] — spots by their index in her layout, none empty — that planned
## bonus [param planned]'s pick lands on.
func spot_of(planned: int, open: PackedInt32Array) -> int:
	return open[mini(floori(picks[planned] * open.size()), open.size() - 1)]


## The kind among [param odds] a [param roll] over their sum lands on: the first whose odds,
## added to those before it, pass it — the last with any, for a roll of the whole sum.
static func _kind(odds: PackedFloat64Array, roll: float) -> int:
	var landed := -1
	var reached := 0.0
	for index in odds.size():
		if odds[index] <= 0.0:
			continue
		landed = index
		reached += odds[index]
		if roll < reached:
			break
	return landed
