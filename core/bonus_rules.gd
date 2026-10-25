class_name BonusRules
extends Resource
## How bonuses come aboard (#307), the match data's (MatchRules.bonus_rules): the kinds a bonus
## may be and their odds, when the first comes, how far apart the next ones come and by how
## much that varies, and the most aboard at once. Every time is on her sinking's clock,
## quickened with her on the fast clock (BonusPlan). A match without bonuses has none.

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


## Every reason these rules cannot be played; empty when they can.
func problems() -> PackedStringArray:
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
	for kind: BonusKind in kinds:
		if kind == null:
			found.append("bonus rules: a kind is missing")
		else:
			found.append_array(kind.problems())
	return found
