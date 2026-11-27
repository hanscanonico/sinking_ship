class_name BonusRules
extends Resource
## How bonuses come aboard (#307), the match data's (MatchRules.bonus_rules): the kinds a bonus
## may be and their odds, when the first comes, how far apart the next ones come and by how
## much that varies, and the most aboard at once. A seat takes any number of them, of any
## kind (BonusKind.stack_share). Every time is on her sinking's clock, quickened with her on the fast clock (BonusPlan). A
## match without bonuses has none.

## The kinds a bonus may be, and per kind its odds: a weight, each kind's chance its share
## of their sum.
@export var kinds: Array[BonusKind] = []
@export var odds := PackedFloat64Array()
## When the first bonus comes, in seconds after the start; then the seconds from one to the
## next, give or take up to jitter.
@export var first: float
@export var interval: float
@export var jitter: float
## The most bonuses aboard at once: one the plan brings while as many are aboard never
## comes.
@export var most_aboard: int


## The kinds of the bonuses [param held] names among [param rules]' kinds — a seat's
## (PlayerState.bonuses), two of a kind listed twice — in its order; none in a match without
## bonuses (null rules).
static func kinds_of(rules: BonusRules, held: Variant) -> Array[BonusKind]:
	var found: Array[BonusKind] = []
	if rules != null:
		for index: int in held:
			found.append(rules.kinds[index])
	return found


## The kinds of the bonuses [param seat] has in [param snapshot] — whose seats are listed by
## id, maybe only some of them (SH22) — of a match played with [param rules] (kinds_of); none
## for a seat with none, or one the snapshot does not list.
static func of_seat(rules: BonusRules, snapshot: Dictionary, seat: int) -> Array[BonusKind]:
	var entry := MatchState.entry_of(snapshot["seats"], seat)
	return kinds_of(rules, entry["bonuses"]) if not entry.is_empty() else ([] as Array[BonusKind])


## Every reason these rules cannot be played — their kinds' beside [param brawl_rules], the
## match's, when they are given, for one of each and for any number (BonusKind.problems),
## and those of a seat holding any number of every kind at once (SeatRules.at_most); empty
## when they can.
func problems(brawl_rules: BrawlRules = null) -> PackedStringArray:
	var found := PackedStringArray()
	if kinds.is_empty() or odds.size() != kinds.size():
		found.append("bonus rules: a kind or more, and odds for each")
	var total := 0.0
	for odd: float in odds:
		if odd < 0.0:
			found.append("bonus rules: odds are 0 or more")
		total += odd
	if total <= 0.0:
		found.append("bonus rules: odds that sum to more than 0")
	if first < 0.0:
		found.append("bonus rules: the first bonus comes at the start or later")
	if interval <= 0.0 or jitter < 0.0 or jitter >= interval:
		found.append("bonus rules: a positive interval, its jitter 0 or more and under it")
	if most_aboard < 1:
		found.append("bonus rules: at least one aboard at once")
	var everything: Array[BonusKind] = []
	for kind: BonusKind in kinds:
		if kind == null:
			found.append("bonus rules: a kind is missing")
			continue
		found.append_array(kind.problems(brawl_rules))
		everything.append(kind)
	if brawl_rules != null and found.is_empty():
		for problem: String in SeatRules.at_most(brawl_rules, everything).problems(brawl_rules):
			found.append("bonus rules: a seat with any number of every kind: " + problem)
	return found
