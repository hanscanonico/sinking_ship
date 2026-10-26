class_name GrabReach
extends RefCounted
## What a Grab press does (#273, #307), in a match on one layout under its rules: one
## question, which the sim's grabs and the HUD's prompt both ask (D13), so the prompt names
## what a press would do. A press takes the nearest bonus aboard it reaches, whatever its
## hands hold; else, holding a prop, it lets go of it; else it takes the nearest prop that can
## be held — loose on a deck, afloat at hand or hung on a railing. It reaches a thing within
## grab_reach beyond the body's edge and the thing's, inside grab_cone_deg of where the body
## faces, at a height it reaches — from step_height under its feet up to its own height, a
## ring on a railing among them — with no blocker between them; of two as near, the first:
## the lower prop, the bonus aboard first. Only a body on its feet on her decks, idle,
## neither staggered nor frozen, takes anything.


## What one Grab press does (press): one of these at most; -1 for each it does not do.
class Press:
	extends RefCounted
	## The bonus aboard it takes, by its place among the bonuses aboard.
	var aboard := -1
	## The prop it lets go of, the one in its hands, by its index in the layout's props.
	var let_go := -1
	## The prop it takes, by its index in the layout's props.
	var prop := -1


## The ship it reaches over, and the kinds of the match's bonuses (BonusRules.kinds) — none
## in a match without bonuses: read them, never write them.
var ship: ShipLayout
var kinds: Array[BonusKind] = []
var _rules: BrawlRules
## The props a hand may hold (holdable_of).
var _holdable: PackedInt32Array


## The reach of a match on [param layout] under [param rules], played with
## [param bonus_rules] (null for none).
func _init(layout: ShipLayout, rules: BrawlRules, bonus_rules: BonusRules = null) -> void:
	ship = layout
	_rules = rules
	if bonus_rules != null:
		kinds.assign(bonus_rules.kinds)
	_holdable = holdable_of(layout)


## What a Grab press by [param player] does now — it [param height] tall where it stands,
## in the frame [param up], its hands holding the prop [param held] (-1 for none) — with
## the bonuses [param aboard] and [param props] as the match has them, and her as
## [param surfaces] has her.
func press(
	player: PlayerState,
	up: int,
	height: float,
	held: int,
	aboard: Array[BonusState],
	props: Array[PropState],
	surfaces: Surfaces
) -> Press:
	var made := Press.new()
	made.aboard = bonus_taken(player, up, height, aboard, surfaces)
	if made.aboard != -1:
		return made
	if held != -1:
		made.let_go = held
	else:
		made.prop = take(player, up, height, props, ship, _rules, surfaces, _holdable)
	return made


## What a Grab press by [param seat] would do as [param snapshot] stands, her as
## [param surfaces] has her then: the HUD's question, answered as the sim answers it.
func would_press(snapshot: Dictionary, seat: int, surfaces: Surfaces) -> Press:
	var entry := MatchState.entry_of(snapshot["seats"], seat)
	if entry.is_empty() or entry["out"]:
		return Press.new()
	var aboard: Array[BonusState] = []
	for bonus: Dictionary in snapshot["bonuses"]:
		aboard.append(BonusState.from_dict(bonus))
	var player := PlayerState.from_dict(entry)
	var height := _rules.height_at(surfaces, player.pos)
	var held := PropState.held_in(snapshot, seat, _holdable)
	var props := PropState.some_of(snapshot, _holdable)
	var up := MatchState.up_of(snapshot, entry)
	return press(player, up, height, held, aboard, props, surfaces)


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
## given every one; -1 for none, as with its hands full. What a press does with no bonus in
## reach and nothing held (press), and what a bot asks of the ring it goes for.
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


## The bonus of [param aboard] — its place among them — a Grab press by [param player]
## takes, whatever its hands hold, as take() reaches a prop; -1 for none. What a press does
## first (press), and what a bot asks of the bonus it goes for.
func bonus_taken(
	player: PlayerState, up: int, height: float, aboard: Array[BonusState], surfaces: Surfaces
) -> int:
	if aboard.is_empty() or not _grabs(player, up):
		return -1
	var best := -1
	var best_gap := INF
	for index in aboard.size():
		var kind := kinds[aboard[index].kind]
		var at := ship.bonus_spots[aboard[index].spot].point
		var gap := _gap(player, height, at, kind.height, kind.radius, _rules, surfaces, best_gap)
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
