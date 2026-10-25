class_name GrabReach
extends RefCounted
## What a Grab press takes (#273): the nearest prop that can be held — loose on a deck,
## afloat at hand or hung on a railing — within grab_reach beyond the body's edge and the
## prop's, inside grab_cone_deg of where the body faces, at a height it reaches — from
## step_height under its feet up to its own height, a ring on a railing among them — with
## no blocker between them; of two as near, the lower prop. Only a body on its feet on her decks,
## idle, neither staggered nor frozen and holding nothing, takes one. Before any prop, a
## bonus aboard reached the same way (#307), the hands full or not. The sim's grabs and the
## HUD's prompt both ask here (D13), so the prompt names what a press would take.


## The props of [param layout] a Grab press may take (PropKind.holdable), by index in
## order: the only ones a hand ever holds — a laid saloon's furniture none of them.
static func holdable_of(layout: ShipLayout) -> PackedInt32Array:
	var found := PackedInt32Array()
	for index in layout.props.size():
		if layout.props[index].prop_kind().holdable:
			found.append(index)
	return found


## The prop [param player] — [param height] tall where it stands, in the frame
## [param up] — would take with a Grab press now, by its index in [param layout]'s props,
## as [param props] has them — only [param holdable]'s (holdable_of) asked of, or of none
## given every one; -1 for none. Two seats taking one prop on one tick are the sim's to
## settle.
static func take(
	player: PlayerState,
	up: int,
	height: float,
	props: Array[PropState],
	layout: ShipLayout,
	rules: BrawlRules,
	surfaces: Surfaces,
	holdable := PackedInt32Array()
) -> int:
	if not _grabs(player, up):
		return -1
	var best := -1
	var best_gap := INF
	for index: int in holdable if not holdable.is_empty() else holdable_of(layout):
		var candidate := props[index]
		if candidate.holder == player.seat:
			return -1
		if not PropState.within_grasp(candidate.body):
			continue
		var prop := layout.props[candidate.prop]
		var gap := _gap(
			player, height, candidate.pos, prop.height, prop.radius, rules, surfaces, best_gap
		)
		if gap < best_gap:
			best = candidate.prop
			best_gap = gap
	return best


## The bonus aboard [param player] — [param height] tall where it stands, in the frame
## [param up] — would take with a Grab press now, by its place in [param bonuses], each at
## its spot of [param layout] and of its size among [param kinds]; -1 for none. It reaches
## one as take() reaches a prop, the nearest, of two as near the one aboard first — but
## whatever its hands hold: a press takes a bonus before any prop (#307). Two seats taking
## one bonus on one tick are the sim's to settle.
static func bonus(
	player: PlayerState,
	up: int,
	height: float,
	bonuses: Array[BonusState],
	layout: ShipLayout,
	kinds: Array[BonusKind],
	rules: BrawlRules,
	surfaces: Surfaces
) -> int:
	if not _grabs(player, up):
		return -1
	var best := -1
	var best_gap := INF
	for index in bonuses.size():
		var aboard := bonuses[index]
		var kind := kinds[aboard.kind]
		var at := layout.bonus_spots[aboard.spot].point
		var gap := _gap(player, height, at, kind.height, kind.radius, rules, surfaces, best_gap)
		if gap < best_gap:
			best = index
			best_gap = gap
	return best


## Whether [param player], standing in the frame [param up], takes anything with a Grab
## press: on its feet on her decks, idle, neither staggered nor frozen — never in the sea,
## climbing out of it, in the air or mid-shove.
static func _grabs(player: PlayerState, up: int) -> bool:
	return (
		up == Faces.Up.DECK
		and player.body == PlayerState.Body.GROUNDED
		and player.action == PlayerState.Action.IDLE
		and not player.is_staggered()
		and not player.is_frozen()
	)


## How far beyond [param player]'s edge — it [param height] tall where it stands — the
## edge of a thing [param radius] round and [param tall] high, its underside at
## [param at], stands, when a Grab press by it reaches the thing: within grab_reach and
## nearer than [param nearest], inside grab_cone_deg of where it faces, at a height it
## reaches — from step_height under its feet up to its own height — with no blocker
## between them; INF when it does not.
static func _gap(
	player: PlayerState,
	height: float,
	at: Vector3,
	tall: float,
	radius: float,
	rules: BrawlRules,
	surfaces: Surfaces,
	nearest: float
) -> float:
	var feet := player.pos
	if at.y + tall < feet.y - rules.step_height or at.y > feet.y + height:
		return INF
	var offset := Vector2(at.x - feet.x, at.z - feet.z)
	var gap := offset.length() - rules.body_radius - radius
	if gap > rules.grab_reach or gap >= nearest:
		return INF
	var ahead := Vector2.from_angle(player.facing)
	if (
		not offset.is_zero_approx()
		and absf(ahead.angle_to(offset)) > deg_to_rad(rules.grab_cone_deg)
	):
		return INF
	if surfaces.blocked(feet, at, height, rules.step_height):
		return INF
	return gap


## What a Grab press by [param seat] would take as [param snapshot] — of a match on
## [param layout] — stands: the HUD's question, answered as the sim answers it, among
## [param holdable] (holdable_of) when given.
static func would_take(
	snapshot: Dictionary,
	seat: int,
	layout: ShipLayout,
	rules: BrawlRules,
	surfaces: Surfaces,
	holdable := PackedInt32Array()
) -> int:
	var among := holdable if not holdable.is_empty() else holdable_of(layout)
	for entry: Dictionary in snapshot["seats"]:
		if entry["seat"] != seat or entry["out"]:
			continue
		var player := PlayerState.from_dict(entry)
		var height := rules.height_at(surfaces, player.pos)
		var props := PropState.some_of(snapshot, among)
		var up := MatchState.up_of(snapshot, entry)
		return take(player, up, height, props, layout, rules, surfaces, among)
	return -1


## What a Grab press by [param seat] would take of the bonuses aboard as [param snapshot] —
## of a match on [param layout] played with [param bonus_rules] — stands, by its place
## among the snapshot's bonuses; -1 for none, as for a match without bonuses: the HUD's
## question, answered as the sim answers it, and the press's first (would_take).
static func would_take_bonus(
	snapshot: Dictionary,
	seat: int,
	layout: ShipLayout,
	rules: BrawlRules,
	surfaces: Surfaces,
	bonus_rules: BonusRules
) -> int:
	var aboard: Array = snapshot["bonuses"]
	var entry := MatchState.entry_of(snapshot["seats"], seat)
	if bonus_rules == null or aboard.is_empty() or entry.is_empty() or entry["out"]:
		return -1
	var bonuses: Array[BonusState] = []
	for each: Dictionary in aboard:
		bonuses.append(BonusState.from_dict(each))
	var player := PlayerState.from_dict(entry)
	var height := rules.height_at(surfaces, player.pos)
	var up := MatchState.up_of(snapshot, entry)
	return bonus(player, up, height, bonuses, layout, bonus_rules.kinds, rules, surfaces)
