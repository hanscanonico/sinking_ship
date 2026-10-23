class_name GrabReach
extends RefCounted
## What a Grab press takes (#273): the nearest prop that can be held — loose on a deck or
## hung on a railing — within grab_reach beyond the body's edge and the prop's, inside
## grab_cone_deg of where the body faces, at a height it reaches — from step_height under
## its feet up to its own height, a ring on a railing among them — with no blocker
## between them; of two as near, the lower prop. Only a body on its feet on her decks,
## idle, neither staggered nor frozen and holding nothing, takes one. The sim's grabs and
## the HUD's prompt both ask here (D13), so the prompt names what a press would take.


## The prop [param player] — [param height] tall where it stands, in the frame
## [param up] — would take with a Grab press now, by its index in [param layout]'s props,
## as [param props] has them; -1 for none. Two seats taking one prop on one tick are the
## sim's to settle.
static func take(
	player: PlayerState,
	up: int,
	height: float,
	props: Array[PropState],
	layout: ShipLayout,
	rules: BrawlRules,
	surfaces: Surfaces
) -> int:
	if (
		up != Faces.Up.DECK
		or player.body != PlayerState.Body.GROUNDED
		or player.action != PlayerState.Action.IDLE
		or player.is_staggered()
		or player.is_frozen()
	):
		return -1
	var feet := player.pos
	var ahead := Vector2.from_angle(player.facing)
	var cone := deg_to_rad(rules.grab_cone_deg)
	var best := -1
	var best_gap := INF
	for crate: PropState in props:
		if crate.holder == player.seat:
			return -1
		if crate.body != PropState.Body.GROUNDED and crate.body != PropState.Body.HUNG:
			continue
		var prop := layout.props[crate.prop]
		if not prop.prop_kind().holdable:
			continue
		if crate.pos.y + prop.height < feet.y - rules.step_height or crate.pos.y > feet.y + height:
			continue
		var offset := Vector2(crate.pos.x - feet.x, crate.pos.z - feet.z)
		var gap := offset.length() - rules.body_radius - prop.radius
		if gap > rules.grab_reach or gap >= best_gap:
			continue
		if not offset.is_zero_approx() and absf(ahead.angle_to(offset)) > cone:
			continue
		if surfaces.blocked(feet, crate.pos, height, rules.step_height):
			continue
		best = crate.prop
		best_gap = gap
	return best


## What a Grab press by [param seat] would take as [param snapshot] — of a match on
## [param layout] — stands: the HUD's question, answered as the sim answers it.
static func would_take(
	snapshot: Dictionary, seat: int, layout: ShipLayout, rules: BrawlRules, surfaces: Surfaces
) -> int:
	for entry: Dictionary in snapshot["seats"]:
		if entry["seat"] != seat or entry["out"]:
			continue
		var player := PlayerState.from_dict(entry)
		var height := rules.height_at(surfaces, player.pos)
		var props := PropState.from_snapshot(snapshot)
		return take(
			player, MatchState.up_of(snapshot, entry), height, props, layout, rules, surfaces
		)
	return -1
