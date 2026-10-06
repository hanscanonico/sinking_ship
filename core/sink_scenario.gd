class_name SinkScenario
extends Resource
## One match's sinking, as a value the match carries (D7): the bands its iceberg hit
## is drawn from, the sea under her, the clock that maps physics seconds to match
## seconds and the bake's limits — and the physics decides everything after the hit.
## Which end or side goes under first, and when, is never a rule. The authored kind the
## MVP shipped — keyframes and events — survives only as a test fixture
## (tests/fixtures/sinking/): a scenario with neither a hit's bands nor an explicit hit
## plays its keyframes.

## The ship-local point an authored scenario's trim and heel turn about.
@export var pivot: Vector3
## Seconds into the match before the ship starts to move; level until then.
@export var starts_at: float
## Authored only: in ascending [member SinkKeyframe.at]; once the scenario starts the
## pose is linear between them, holding the first before it and the last after it.
@export var keyframes: Array[SinkKeyframe] = []
## Authored only: lurches, collapses, failing railings and the plunge.
@export var events: Array[SinkEvent] = []
## The bands the match's iceberg hit is drawn from (§5b.1); null for none — the flat
## deck and the authored fixtures.
@export var hit: HitBands
## A hit given rather than drawn — a test's, a tool's HIT= — which bypasses the
## must-sink rule (§5b.1); null for a match's own.
@export var explicit_hit: IcebergHit
## How deep the sea is under her, in metres.
@export var sea_depth: float
## Physics seconds per match second: one to one for now (Q20, deferred).
@export var clock: float = 1.0
## The most simulated seconds a bake runs: past it, a hit still afloat is afloat.
@export var bake_cap: float
## The must-sink rule's bounds (§5b.1): hits the quick check may throw out, bakes
## before the fallback, and the fallback's rungs; and the dry deck, in metres, the
## quick check needs to spare to throw a hit out.
@export var quick_redraws: int
@export var bakes: int
@export var rungs: int
@export var spare_deck: float


## Whether the physics plays this scenario, rather than its keyframes.
func is_physical() -> bool:
	return hit != null or explicit_hit != null


## Every reason this scenario cannot run; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if starts_at < 0.0:
		found.append("sinking: starts_at must not be negative")
	if not is_physical() and keyframes.is_empty():
		found.append("sinking: no keyframes and no hit")
	var previous := -INF
	for keyframe: SinkKeyframe in keyframes:
		if keyframe == null:
			found.append("sinking: an empty keyframe")
			continue
		if keyframe.at < 0.0 or keyframe.at <= previous:
			found.append("sinking: keyframe times must start at 0 or later and rise")
		previous = keyframe.at
	for event: SinkEvent in events:
		if event == null:
			found.append("sinking: an empty event")
			continue
		found.append_array(event.problems())
	if hit != null:
		found.append_array(hit.problems())
	if sea_depth < 0.0:
		found.append("sinking: the sea's depth must not be negative")
	if is_physical() and (clock <= 0.0 or bake_cap <= 0.0):
		found.append("sinking: the physics needs a clock and a bake's cap")
	if quick_redraws < 0 or bakes < 0 or rungs < 0 or spare_deck < 0.0:
		found.append("sinking: the must-sink rule's bounds must not be negative")
	return found
