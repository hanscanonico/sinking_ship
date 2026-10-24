class_name Hazards
extends RefCounted
## The hazards with state (SH10, §6): the ship's loose cargo, and the damage its
## railings take. Rules, never physics bodies (D1); their state is MatchState's and
## in the snapshot (D5).
##
## A crate is an upright circle on the deck, as a body is (D8). It holds while the
## deck is no steeper than its own grip angle; past it, the world's gravity turned by
## the pose pulls it downhill against its friction — the slope rule bodies follow. It
## meets walls, blockers, railings and the other crates through Surfaces (D6), and
## falls off an open edge or down a stair opening. Falling into the sea, it is lost once
## the water stands wade_depth over its underside; standing, the water lifts it off its
## floor there, and it floats on its cell's water crate_draft deep, never under its
## floor, rising with it — a blocker still, as it stood, and its lid a surface a body may
## stand on, carried by nothing — until its top meets the ceiling over it or, with none,
## until the water over its floor is crate_adrift_depth deep and the sea sweeps it away:
## lost. As she heels and trims her water runs to her low side and carries it there,
## whatever its height in her: crate_float_pull of the deck-plane pull of gravity, with
## no grip angle to hold it and none on an even keel, into her walls, blockers and the
## other crates as a sliding crate meets them — and off an open edge or through a broken
## span into the sea, lost. Its planar speed keeps crate_float_drag of itself a tick,
## against a standing crate's friction. The water falling back under wade_depth over
## its floor sets it down there again. Running into a brawler at crate_impact_speed or
## more, it staggers it and knocks it back through a hit-stop, as a shove does (D12),
## and keeps going, slowed; slower, it pushes it. Either way the two part with the
## closing speed by their masses. A shove sends a crate at its knockback weighed by
## the two masses, never faster than the shove's own. Two crates meeting part the same
## way, by their masses — with crate_restitution of the speed they met at from
## crate_impact_speed, together below it — the one running into the other handing on
## its shover; and a staggered body slamming into a crate at crate_impact_speed or more
## sends it off so (slams). A body on its feet leans on a crate as on a wall: a laden
## crate does not give to a walk.
##
## Furniture is a crate of a kind of its own (PropKind): its own draft is both the water
## that lifts it and how deep it rides — a table stands in the water until it nearly
## covers its top; floating aboard, it comes down afloat as it falls into the water and
## rides pressed under the ceiling, lost only to the open sea; a body moving into a piece
## that gives way pushes it before it (gives); a harmless piece only ever pushes a body it
## runs into, and damages no railing.
##
## Every prop of hers is stepped as a crate is (#273) while it lies loose — not hung on a
## railing nor held — but only a solid one (PropKind) holds bodies back, stands a lid,
## takes a shove, runs into a body or damages a railing: bodies walk through any other.
## A prop hung on a span the sinking fails, the match breaks or a collapse takes is lost
## with it.
##
## A crate at rest — standing still on her own floor, clear of everything, since the last
## tick it was stepped — is passed over, as stepping it would leave it as it is, until
## anything runs into it, the deck tilts past its grip, the water reaches it or her shape
## changes (Surfaces.shapes): a saloon of furniture costs a tick only what moves in it.
## What rests is never the match's state: stepped, it would come out the same.
##
## A vault damages the span it goes over by vault_damage, and a crate crossing one at
## railing_break_speed or more by crate_damage; a span with no hits left is broken,
## gone from Surfaces like a failed one, and holds nothing.
##
## A funnel falling (SH31) knocks down every body in the strip it lands across on the
## tick it lands (FunnelFall, from the pose): sent out of it to the side its centre is
## on at struck_knockback, staggered struck_stagger and held through a hit-stop, as a
## crate's impact is (D12) — no brace takes anything off it. What it lands on and the
## railings it breaks are the pose's (SinkSchedule.place_falls).
##
## MatchSim steps the crates once a tick, after the bodies have moved, landed and
## thawed and before the shoves (§4); a funnel lands first. Once she has broken (SH33)
## there are hazards per piece of her (Pieces): each the crates over its stretch, the
## bodies on it and its railings, numbered among its own — a span's hits are hers.

## For tests: every crate stepped every tick, none passed over at rest — what proves
## that passing over changes nothing.
static var never_rest := false
## How far, in world metres, a crate at rest stands clear of the water of its cell, and
## the water of its ceiling, before its own water is looked for as a crate stepped looks
## (ShipPose.water_height): what no rounding of the two reaches across.
const DRY_MARGIN := 0.01
## A crate at rest's cell not yet looked for.
const UNKNOWN_CELL := -2

var _rules: BrawlRules
var _layout: ShipLayout
var _props: Array[ShipProp] = []
## Per prop, its kind; 1 for a solid one; its grip angle; and how deep the water lifts it
## (PropKind.lift).
var _kinds: Array[PropKind] = []
var _solid := PackedByteArray()
var _grips := PackedFloat64Array()
var _lifts := PackedFloat64Array()
var _surfaces: Surfaces
## The piece of her these are, and her pieces; null for a ship that never breaks.
var _piece := 0
var _pieces: Pieces
## Per crate, 1 while it is over this piece's stretch, as of this tick's step.
var _aboard := PackedByteArray()
var _stagger_ticks: int
var _hitstop_ticks: int
var _hitstop_braced_ticks: int
var _credit_window_ticks: int
var _struck_ticks: int
## The railings the match has broken, as of this tick's step or the last break since:
## the crates honour them many times a tick, and only a break changes them.
var _broken := PackedInt32Array()
## The crates at rest, where they came to rest, on a grid of their own (_settle): what a
## crate moving among them may wake. Per crate, the floor it rests on; and her shape
## changes as of the last step (Surfaces.shapes), -1 before the first.
var _at_rest: PropStands
var _rested_on := PackedInt32Array()
var _shapes := -1
## Per crate at rest, the cell of her it rests in (CellMap, CellMap.NONE outside them,
## UNKNOWN_CELL not yet looked for) and that cell's ceiling, in the cells they were
## looked for in; and the least grip of any crate: while the deck is no steeper, every
## crate at rest holds, unasked.
var _rest_cells := PackedInt32Array()
var _rest_roofs := PackedFloat64Array()
var _looked_in: CellMap
var _least_grip := INF
## Per crate, how this tick takes it (Turn); where its underside stood and its middle in
## the deck plane as the tick's move began.
var _turn := PackedByteArray()
var _feet_before := PackedFloat64Array()
var _came_from := PackedVector2Array()

## How a tick takes a crate: none of its loose ones aboard, or at rest, or stepped.
enum Turn { NONE, RESTS, STEPS }


## The hazards of [param config]'s ship asked of [param surfaces] — or of piece
## [param piece] of [param pieces], its decks' own.
func _init(config: MatchConfig, surfaces: Surfaces, piece := 0, pieces: Pieces = null) -> void:
	_rules = config.rules
	_layout = config.ship
	_props = config.ship.props
	_surfaces = surfaces
	_piece = piece
	_pieces = pieces
	_aboard.resize(_props.size())
	_aboard.fill(1)
	for prop: ShipProp in _props:
		var kind := prop.prop_kind()
		_kinds.append(kind)
		_solid.append(1 if kind.solid else 0)
		_grips.append(prop.grip_angle_deg)
		_lifts.append(kind.lift(_rules))
		_least_grip = minf(_least_grip, prop.grip_angle_deg)
	_at_rest = PropStands.new(config.ship, SpatialIndex.bounds_of(config.ship))
	_rested_on.resize(_props.size())
	_rest_cells.resize(_props.size())
	_rest_cells.fill(UNKNOWN_CELL)
	_rest_roofs.resize(_props.size())
	_turn.resize(_props.size())
	_feet_before.resize(_props.size())
	_came_from.resize(_props.size())
	_stagger_ticks = Ticks.from_seconds(_rules.stagger)
	_hitstop_ticks = Ticks.from_seconds(_rules.hitstop)
	_hitstop_braced_ticks = Ticks.from_seconds(_rules.hitstop_braced)
	_credit_window_ticks = Ticks.from_seconds(_rules.credit_window)
	_struck_ticks = Ticks.from_seconds(_rules.struck_stagger)


## One tick of the cargo, in [param state], under [param pose] — the whole ship's — and
## before it, every funnel landing; a prop hung on a span gone by now goes with it. Once
## the match stands on any face but its decks (Faces), the piece has rolled past where
## cargo stays stowed: what is still aboard and not held breaks loose into the sea.
func step(state: MatchState, pose: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	var here := pose.of_piece(_piece)
	# A funnel's strip lies on her decks: off them (SH32) its landing strikes nobody, and
	# the bodies' points are in another frame's.
	if state.up[_piece] == Faces.Up.DECK:
		_strike(state, here, tick, events)
	_broken = state.broken_railings()
	var rolled := state.up[_piece] != Faces.Up.DECK
	if _surfaces.shapes != _shapes:
		_shapes = _surfaces.shapes
		_unrest()
	var loose: Array[PropState] = []
	var unhung: Array[PropState] = []
	var crates := _stirring(state, pose, rolled, loose, unhung)
	_lose(unhung, tick, events)
	if loose.is_empty():
		return
	if rolled:
		_lose(loose, tick, events)
		return
	_stand(state, pose)
	if _surfaces.shapes != _shapes:
		# Her shape changed as the crates were told where they stand: none rests.
		_shapes = _surfaces.shapes
		_unrest()
		crates = loose.duplicate()
		for crate: PropState in crates:
			_turn[crate.prop] = Turn.STEPS
	if crates.size() < loose.size():
		for crate: PropState in crates.duplicate():
			_stir_near(state, crates, crate)
	_forces(crates, here)
	_move(state, crates, pose, tick, events)
	_run_into_bodies(state, crates, loose, pose, tick, events)
	_ground(crates)
	_sea(crates, here, tick, events)
	for crate: PropState in crates:
		_stand_one(crate, pose)
	_settle(crates)


## The crates this tick steps, in their order, of [param state]'s under [param pose] —
## the whole ship's: every one loose over this piece into [param loose], those of them at
## rest left out (Turn); every one hung on a span gone by now — or all, [param rolled] —
## into [param unhung]. A crate rests while it stands still where it came to rest and on
## the same floor (_settle), the deck no steeper than its grip and the water short of
## lifting it — as it surely is while the water of the cell it rests in stands lower than
## its lift over its underside, and lower than that cell's ceiling (_water_short).
func _stirring(
	state: MatchState,
	pose: ShipPose,
	rolled: bool,
	loose: Array[PropState],
	unhung: Array[PropState]
) -> Array[PropState]:
	_turn.fill(Turn.NONE)
	var here := pose.of_piece(_piece)
	var slope := here.slope_deg()
	var all_hold := slope <= _least_grip
	if not is_same(here.cells, _looked_in):
		_looked_in = here.cells
		_rest_cells.fill(UNKNOWN_CELL)
	var broken := _pieces != null and _pieces.count() > 1
	# Read here once, not of _at_rest per crate: a crate's own take() changes only its own.
	var resting := _at_rest.gone
	var rested_at := _at_rest.feet
	var crates: Array[PropState] = []
	for crate: PropState in state.props:
		var prop := crate.prop
		if broken:
			_aboard[prop] = 1 if _pieces.piece_at(pose.standing, crate.pos.x) == _piece else 0
		var body := crate.body
		var loose_here := body != PropState.Body.LOST and body < PropState.Body.HUNG
		if _aboard[prop] == 0 or not loose_here:
			# Held, hung or over another piece, it is not at rest here, wherever it comes back.
			_at_rest.take(prop)
			if _aboard[prop] == 1 and body == PropState.Body.HUNG:
				if rolled or _span_gone(crate, pose):
					unhung.append(crate)
			continue
		loose.append(crate)
		if not never_rest and resting[prop] == 0:
			var pos := crate.pos
			if (
				body == PropState.Body.GROUNDED
				and crate.vel == Vector3.ZERO
				and pos == rested_at[prop]
				and crate.surface == _rested_on[prop]
				and (all_hold or slope <= _grips[prop])
				and (_water_short(prop, pos, here) or here.water_height(pos) - pos.y < _lifts[prop])
			):
				_turn[prop] = Turn.RESTS
				continue
			_at_rest.take(prop)
		_turn[prop] = Turn.STEPS
		crates.append(crate)
	return crates


## Whether, under [param pose], the water of the cell crate [param prop] rests in at
## [param pos] surely stands short of lifting it — lower than its lift over its underside
## and lower than the cell's ceiling, past which ShipPose.water_height reads a higher
## cell's — by DRY_MARGIN; false when it may not, and only water_height can tell.
func _water_short(prop: int, pos: Vector3, pose: ShipPose) -> bool:
	var basis := pose.transform.basis
	var up := basis.y.y
	if up <= DRY_MARGIN:
		return false
	# A pose keeping no cells reads the sea everywhere, as water_height does: no cell is
	# looked for in it, nor kept for the poses after.
	var level := 0.0
	var roof := INF
	if not pose.levels.is_empty():
		if _rest_cells[prop] == UNKNOWN_CELL:
			var looked := pose.cell_at(pos)
			_rest_cells[prop] = looked
			_rest_roofs[prop] = INF if looked == CellMap.NONE else pose.cells.ceiling_of(looked)
		if _rest_cells[prop] != CellMap.NONE:
			level = pose.levels[_rest_cells[prop]]
			roof = _rest_roofs[prop]
	var plane := basis.x.y * pos.x + basis.z.y * pos.z + pose.transform.origin.y
	return (
		level < plane + up * (pos.y + _lifts[prop] - DRY_MARGIN)
		and level < plane + up * roof - DRY_MARGIN
	)


## Every crate of [param crates] that came to rest this tick rests from the next: standing
## still on her own floor — not another crate's lid, which may move under it — touching
## nothing that would move it, so that stepping it would leave it as it is.
func _settle(crates: Array[PropState]) -> void:
	for crate: PropState in crates:
		_at_rest.take(crate.prop)
		if (
			crate.body != PropState.Body.GROUNDED
			or crate.vel != Vector3.ZERO
			or crate.surface < 0
			or crate.surface >= _surfaces.count()
			or _touches(crate)
		):
			continue
		_at_rest.put(crate.prop, crate.pos)
		_rested_on[crate.prop] = crate.surface
		_rest_cells[crate.prop] = UNKNOWN_CELL


## Every crate at rest stepped from the next tick on.
func _unrest() -> void:
	_at_rest.clear()


## Whether [param crate], grounded, touches anything that would move it were it stepped:
## a railing, or anything holding it back in the deck plane.
func _touches(crate: PropState) -> bool:
	var prop := _props[crate.prop]
	if not _surfaces.rail_contacts(crate.pos, prop.radius, crate.surface).is_empty():
		return true
	var held := _surfaces.obstacle_contacts(
		crate.pos, prop.radius, prop.height, _rules.step_height, crate.prop
	)
	return not held.is_empty()


## [param other], met this tick by a crate of [param crates] while at rest: stepped from
## here on with them, in their order, as if it had been all along — it has not moved.
func _wake(crates: Array[PropState], other: PropState) -> void:
	if _turn[other.prop] != Turn.RESTS:
		return
	_turn[other.prop] = Turn.STEPS
	_at_rest.take(other.prop)
	_feet_before[other.prop] = other.pos.y
	_came_from[other.prop] = Vector2(other.pos.x, other.pos.z)
	var at := crates.size()
	while at > 0 and crates[at - 1].prop > other.prop:
		at -= 1
	crates.insert(at, other)


## Wakes every crate at rest — of any kind — that [param crate]'s circle may reach where
## it stands now, among [param state]'s, if it is solid: one a crate has moved into is
## stepped in its turn, in index order, whichever of the two is to move out of the
## other. Another kind meets no crate at rest that would move for it.
func _stir_near(state: MatchState, crates: Array[PropState], crate: PropState) -> void:
	if _solid[crate.prop] == 0:
		return
	var radius := _props[crate.prop].radius
	for index: int in _at_rest.near(crate.pos.x, crate.pos.z, radius, crate.prop):
		if _turn[index] == Turn.RESTS:
			_wake(crates, state.props[index])


## Whether the span [param crate] hangs on is gone under [param pose]: failed by the
## sinking, broken by the match, or gone with its deck.
func _span_gone(crate: PropState, pose: ShipPose) -> bool:
	var span := _props[crate.prop].railing
	return (
		span in _broken
		or span in pose.broken_railings
		or _layout.platforms[_layout.railings[span].platform].name in pose.collapsed
	)


## The railing of hers that railing [param railing] of the Surfaces these are asked of
## is (Pieces.rail).
func rail(railing: int) -> int:
	return railing if _pieces == null else _pieces.rail(_piece, railing)


## Every body on board — not out, climbing or swimming — in the strip of a funnel
## landing on [param tick] knocked down, seat by seat in ascending order.
func _strike(state: MatchState, pose: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	for fall: FunnelFall in pose.falls:
		if fall.lands_at != tick:
			continue
		var base := Vector2(fall.fitting.base.x, fall.fitting.base.z)
		for player: PlayerState in state.seats:
			if player.piece != _piece:
				continue
			if player.is_out() or player.is_climbing() or player.body == PlayerState.Body.SWIMMING:
				continue
			if not fall.covers(player.pos, _rules.body_radius):
				continue
			var off := Vector2(player.pos.x, player.pos.z) - base
			var aside := Vector2(fall.along.y, -fall.along.x)
			var away := aside * (1.0 if off.dot(aside) >= 0.0 else -1.0) * _rules.struck_knockback
			var moving := player.held_vel if player.is_frozen() else player.vel
			player.stagger_ticks = maxi(player.stagger_ticks, _struck_ticks)
			player.bracing = false
			player.freeze(Vector3(away.x, moving.y, away.y), _hitstop_ticks)
			events.append(SimEvent.knocked_down(tick, player.seat, fall.fitting.name))


## The solid props still on board — over this piece, as of this tick's step — as a shove
## may land on them, numbered from [param first]: crate n is candidate first + n. Only
## those within [param reach] of the edge of a body's circle about one of [param origins]
## — beyond it no shove from there lands (ShoveResolver.lands).
func candidates(
	state: MatchState, first: int, origins: PackedVector2Array, reach: float
) -> Array[ShoveResolver.Candidate]:
	var near := PackedInt32Array()
	for origin: Vector2 in origins:
		near.append_array(_surfaces.stands.near(origin.x, origin.y, reach + _rules.body_radius))
	near.sort()
	var found: Array[ShoveResolver.Candidate] = []
	var last := -1
	for index: int in near:
		var crate := state.props[index]
		if index == last or not crate.is_loose() or _aboard[index] == 0 or _solid[index] == 0:
			continue
		last = index
		var prop := _props[index]
		found.append(
			ShoveResolver.Candidate.new(first + index, crate.pos, prop.radius, prop.height)
		)
	return found


## A shove of [param speed] landing on the crate [param hit] names, numbered from
## [param first] as candidates() numbered it: sent at that speed weighed by the two
## masses — never faster than the shove: a light one goes at its speed — and the
## shover's, for its credit.
func shove(state: MatchState, hit: ShoveResolver.Hit, first: int, speed: float, tick: int) -> void:
	var crate := state.props[hit.target - first]
	var mass := _props[crate.prop].mass
	var sent := hit.direction * speed
	if mass > _rules.body_mass:
		sent = sent * _rules.body_mass / mass
	crate.vel = Vector3(sent.x, crate.vel.y, sent.y)
	crate.shoved_by = hit.shover
	crate.shoved_at = tick


## Takes [param amount] off the span [param railing] — by [param by]'s vault, or the
## crate [param by_crate] — and breaks it when nothing is left: it is gone from
## Surfaces at once, under [param pose]. True when the span is broken.
func damage(
	state: MatchState,
	railing: int,
	amount: float,
	pose: ShipPose,
	tick: int,
	events: Array[SimEvent],
	by: int = -1,
	by_crate: int = -1
) -> bool:
	if state.railing_hp[railing] <= 0.0:
		return true
	state.railing_hp[railing] = maxf(state.railing_hp[railing] - amount, 0.0)
	if state.railing_hp[railing] > 0.0:
		return false
	events.append(SimEvent.railing_broke(tick, railing, by, by_crate))
	_broken = state.broken_railings()
	_stand(state, pose)
	return true


## Gravity in the air; afloat, crate_float_pull of the downhill pull at any slope, and
## the water's drag; on the deck, the downhill pull past its grip angle, and its
## friction.
func _forces(crates: Array[PropState], pose: ShipPose) -> void:
	var dt := Ticks.SECONDS_PER_TICK
	var gravity := pose.ship_gravity(_rules.gravity)
	var downhill := Vector2(gravity.x, gravity.z) * dt
	var slope := pose.slope_deg()
	for crate: PropState in crates:
		if crate.body == PropState.Body.AIRBORNE:
			crate.vel += gravity * dt
			continue
		if crate.body == PropState.Body.FLOATING:
			var afloat := Vector2(crate.vel.x, crate.vel.z) + downhill * _rules.crate_float_pull
			afloat *= _rules.crate_float_drag
			crate.vel = Vector3(afloat.x, 0.0, afloat.y)
			continue
		var prop := _props[crate.prop]
		var planar := Vector2(crate.vel.x, crate.vel.z)
		if slope > prop.grip_angle_deg:
			planar += downhill
		planar = planar.move_toward(Vector2.ZERO, prop.friction * dt)
		crate.vel = Vector3(planar.x, crate.vel.y, planar.y)


## Integration, then contacts — blockers, walls, deck edges and the other crates,
## then railings — crate by crate, pass after pass until nothing moves, the tick cut
## into steps so that no crate crosses more than its radius in one, as bodies' moves
## are (Movement.move). A crate at rest another runs into joins them (_wake). Keeps each
## crate's underside height before it moved, and its middle (_feet_before, _came_from).
func _move(
	state: MatchState, crates: Array[PropState], pose: ShipPose, tick: int, events: Array[SimEvent]
) -> void:
	var steps := 1
	for crate: PropState in crates:
		_feet_before[crate.prop] = crate.pos.y
		_came_from[crate.prop] = Vector2(crate.pos.x, crate.pos.z)
		var reach := Vector2(crate.vel.x, crate.vel.z).length() * Ticks.SECONDS_PER_TICK
		steps = maxi(steps, ceili(reach / _props[crate.prop].radius))
	var dt := Ticks.SECONDS_PER_TICK / steps
	for _step in steps:
		var at := 0
		while at < crates.size():
			var crate := crates[at]
			crate.pos += crate.vel * dt
			if crate.vel != Vector3.ZERO:
				_stand_one(crate, pose)
				_stir_near(state, crates, crate)
			at = _after(crates, at, crate)
		# Each crate meets the others where they stand now, the earlier ones moved:
		# Surfaces is told of each as it moves.
		for _contact_pass in Movement.CONTACT_PASSES:
			var held := false
			at = 0
			while at < crates.size():
				var crate := crates[at]
				var blocked := _blockers(state, crates, crate, tick)
				var railed := _railings(state, crate, pose, tick, events)
				if blocked or railed:
					_stand_one(crate, pose)
					_stir_near(state, crates, crate)
					held = true
				at = _after(crates, at, crate)
			if not held:
				break


## Where in [param crates] the one after [param crate] is, which stood at [param at]
## before a crate woken in its turn may have come before it.
static func _after(crates: Array[PropState], at: int, crate: PropState) -> int:
	return (at if crates[at] == crate else crates.find(crate)) + 1


## Whatever stops [param crate] in the deck plane, met at the height its underside
## stood at before this tick's move: another crate takes its share of the speed
## (_knock) — one at rest joins [param crates] (_wake) — anything else holds it. True
## when it moved it.
func _blockers(state: MatchState, crates: Array[PropState], crate: PropState, tick: int) -> bool:
	var prop := _props[crate.prop]
	var feet := Vector3(crate.pos.x, _feet_before[crate.prop], crate.pos.z)
	var contacts := _surfaces.obstacle_contacts(
		feet, prop.radius, prop.height, _rules.step_height, crate.prop
	)
	for contact: Surfaces.Contact in contacts:
		if contact.prop == -1:
			_hold(crate, contact)
		else:
			var other := state.props[contact.prop]
			_wake(crates, other)
			_knock(crate, other, contact, tick)
	return not contacts.is_empty()


## Moves [param crate] out of [param other], the crate [param contact] is with, and
## parts the two along it by their masses: with crate_restitution of the speed they met
## at from crate_impact_speed, going on together below it. At an impact the one that
## ran into the other — the faster of the two toward it — hands on its shover, within
## credit_window.
func _knock(crate: PropState, other: PropState, contact: Surfaces.Contact, tick: int) -> void:
	var normal := contact.normal
	crate.pos += Vector3(normal.x, 0.0, normal.y) * contact.depth
	var mine := Vector2(crate.vel.x, crate.vel.z)
	var theirs := Vector2(other.vel.x, other.vel.z)
	var toward := -mine.dot(normal)
	var back := theirs.dot(normal)
	var meeting := toward + back
	if meeting <= 0.0:
		return
	var impact := meeting >= _rules.crate_impact_speed
	var parting := 1.0 + (_rules.crate_restitution if impact else 0.0)
	var mass := _props[crate.prop].mass
	var other_mass := _props[other.prop].mass
	var total := mass + other_mass
	mine += normal * (parting * other_mass / total * meeting)
	theirs -= normal * (parting * mass / total * meeting)
	crate.vel = Vector3(mine.x, crate.vel.y, mine.y)
	other.vel = Vector3(theirs.x, other.vel.y, theirs.y)
	if not impact:
		return
	var hitter := crate if toward >= back else other
	var struck := other if toward >= back else crate
	if hitter.shoved_by != -1 and tick - hitter.shoved_at < _credit_window_ticks:
		struck.shoved_by = hitter.shoved_by
		struck.shoved_at = tick


## Whether [param player] slams into the crate [param contact] is with — off its feet,
## staggered, as no walker is, and meeting it at crate_impact_speed or more: the two
## then part along the contact by their masses with crate_restitution of the speed they
## met at, as a crate running into a body does, and the crate is credited to the shove
## that sent the body, within credit_window. Movement holds a body that does not, as a
## wall would, or is pushed by it (gives); a body frozen in a hit-stop never does.
func slams(state: MatchState, player: PlayerState, contact: Surfaces.Contact, tick: int) -> bool:
	if not player.is_staggered() or player.is_frozen():
		return false
	var crate := state.props[contact.prop]
	var normal := contact.normal
	var body := Vector2(player.vel.x, player.vel.z)
	var cargo := Vector2(crate.vel.x, crate.vel.z)
	var meeting := (cargo - body).dot(normal)
	if meeting < _rules.crate_impact_speed:
		return false
	var mass := _props[crate.prop].mass
	var total := mass + _rules.body_mass
	var parting := 1.0 + _rules.crate_restitution
	body += normal * (parting * mass / total * meeting)
	cargo -= normal * (parting * _rules.body_mass / total * meeting)
	player.vel = Vector3(body.x, player.vel.y, body.y)
	crate.vel = Vector3(cargo.x, crate.vel.y, cargo.y)
	if player.last_hit_by != -1 and tick - player.last_hit_at < _credit_window_ticks:
		crate.shoved_by = player.last_hit_by
		crate.shoved_at = tick
	return true


## Whether [param player], not slamming into the crate [param contact] is with, pushes it
## before it — a piece of furniture that gives way (PropKind.gives_way), the body not held
## in a hit-stop: out of it, the two then share the speed into it by their masses, the
## crate going on at least at that speed and the body no faster. Movement holds a body
## against any other, as a wall would.
func gives(state: MatchState, player: PlayerState, contact: Surfaces.Contact) -> bool:
	var crate := state.props[contact.prop]
	if not _kinds[crate.prop].gives_way or player.is_frozen():
		return false
	var normal := contact.normal
	player.pos += Vector3(normal.x, 0.0, normal.y) * contact.depth
	var body := Vector2(player.vel.x, player.vel.z)
	var cargo := Vector2(crate.vel.x, crate.vel.z)
	var into := -body.dot(normal)
	var ahead := -cargo.dot(normal)
	if into <= ahead:
		return true
	var mass := _props[crate.prop].mass
	var shared := (_rules.body_mass * into + mass * ahead) / (_rules.body_mass + mass)
	body += normal * (into - shared)
	cargo -= normal * (shared - ahead)
	player.vel = Vector3(body.x, player.vel.y, body.y)
	crate.vel = Vector3(cargo.x, crate.vel.y, cargo.y)
	return true


## A railing holds [param crate] as it holds a body — in the air, only from the
## side it came from — unless the crate crosses it at railing_break_speed or more and
## breaks it, as a harmless one never does. True when it moved it.
func _railings(
	state: MatchState, crate: PropState, pose: ShipPose, tick: int, events: Array[SimEvent]
) -> bool:
	var prop := _props[crate.prop]
	var contacts: Array[Surfaces.Contact]
	if crate.body == PropState.Body.AIRBORNE:
		contacts = _surfaces.airborne_rail_contacts(
			crate.pos, _came_from[crate.prop], prop.radius, prop.height, _rules.railing_height
		)
	else:
		contacts = _surfaces.rail_contacts(crate.pos, prop.radius, crate.surface)
	var held := false
	for contact: Surfaces.Contact in contacts:
		var into := -Vector2(crate.vel.x, crate.vel.z).dot(contact.normal)
		if (
			into >= _rules.railing_break_speed
			and _solid[crate.prop] == 1
			and not _kinds[crate.prop].harmless
			and damage(
				state,
				rail(contact.railing),
				_rules.crate_damage,
				pose,
				tick,
				events,
				-1,
				crate.prop
			)
		):
			continue
		_hold(crate, contact)
		held = true
	return held


## Moves [param crate] out of [param contact] in the deck plane and takes the
## velocity into it.
func _hold(crate: PropState, contact: Surfaces.Contact) -> void:
	crate.pos += Vector3(contact.normal.x, 0.0, contact.normal.y) * contact.depth
	var planar := Vector2(crate.vel.x, crate.vel.z)
	var into := -planar.dot(contact.normal)
	if into > 0.0:
		planar += contact.normal * into
		crate.vel = Vector3(planar.x, crate.vel.y, planar.y)


## Every crate against every body on board its circle and height overlap, crate by
## crate and seat by seat — a body standing on a crate's lid is not in its way, and a
## crate never comes down on a swimmer: it is lost or afloat as it reaches the water.
## The crates are [param crates], this tick's, and those of [param loose] at rest a body
## stands within reach of — none other could meet one — and a crate at rest a body meets
## joins [param crates] (_wake).
func _run_into_bodies(
	state: MatchState,
	crates: Array[PropState],
	loose: Array[PropState],
	pose: ShipPose,
	tick: int,
	events: Array[SimEvent]
) -> void:
	var bodies: Array[PlayerState] = []
	for player: PlayerState in state.seats:
		if player.piece != _piece:
			continue
		if player.is_out() or player.is_climbing() or player.body == PlayerState.Body.SWIMMING:
			continue
		bodies.append(player)
	if bodies.is_empty():
		return
	var visit := PackedInt32Array()
	var broken := _pieces != null and _pieces.count() > 1
	# Once she is in pieces a crate may stand over one piece and be stood on another's
	# Surfaces: every crate is asked, as all were before any rested.
	for crate: PropState in loose if broken else crates:
		visit.append(crate.prop)
	if not broken:
		for player: PlayerState in bodies:
			_within_reach(visit, player, -1)
	visit.sort()
	var at := 0
	while at < visit.size():
		var crate := state.props[visit[at]]
		at += 1
		if crate.prop == (visit[at - 2] if at > 1 else -1):
			continue
		if _solid[crate.prop] == 0 or not crate.is_loose() or _aboard[crate.prop] == 0:
			continue
		var prop := _props[crate.prop]
		var reach := prop.radius + _rules.body_radius
		for player: PlayerState in bodies:
			# Out of reach first: the cheapest test, and most pairs fail it.
			var offset := Vector2(player.pos.x - crate.pos.x, player.pos.z - crate.pos.z)
			var distance := offset.length()
			if distance >= reach:
				continue
			if (
				player.pos.y + _rules.step_height >= crate.pos.y + prop.height
				or player.pos.y + _rules.body_height <= crate.pos.y
				# A crawler's head is lower: asked last, it is the dearest test.
				or player.pos.y + _rules.height_at(_surfaces, player.pos) <= crate.pos.y
			):
				continue
			var normal := offset / distance if distance > 0.0 else Vector2.RIGHT
			_wake(crates, crate)
			_collide(crate, player, normal, reach - distance, tick, events)
			# The body moved: a later crate at rest it now reaches is asked in its turn.
			if not broken:
				_within_reach(visit, player, crate.prop)
	for crate: PropState in crates:
		_stand_one(crate, pose)


## Adds to [param visit] every crate standing within reach of [param player]'s circle
## whose index is above [param after], unless it is there already, keeping its order
## from [param after] on.
func _within_reach(visit: PackedInt32Array, player: PlayerState, after: int) -> void:
	for index: int in _surfaces.stands.near(player.pos.x, player.pos.z, _rules.body_radius):
		if index <= after:
			continue
		var at := visit.bsearch(index)
		if at < visit.size() and visit[at] == index:
			continue
		visit.insert(at, index)


## [param crate] and [param player], [param overlap] into each other along
## [param normal] (from the crate to the body), part by their masses. Closing at
## crate_impact_speed or more, a crate not harmless staggers the body and the two part
## with crate_restitution of the closing speed — the body sent away at crate_knockback
## at the least, held through a hit-stop, a front brace taking crate_brace_reduction off
## that; slower, or harmless, it pushes the body and they go on together. A hit credits
## the crate, and through it the seat that shoved it within credit_window — else the
## seat its own hit within credit_window credited; a push does the same only over no
## other credit within credit_window — a crate drifting into a body a seat has just
## shoved takes nothing from that seat.
func _collide(
	crate: PropState,
	player: PlayerState,
	normal: Vector2,
	overlap: float,
	tick: int,
	events: Array[SimEvent]
) -> void:
	var mass := _props[crate.prop].mass
	var total := mass + _rules.body_mass
	var apart := Vector3(normal.x, 0.0, normal.y) * overlap
	player.pos += apart * (mass / total)
	crate.pos -= apart * (_rules.body_mass / total)
	var moving := player.held_vel if player.is_frozen() else player.vel
	var body_planar := Vector2(moving.x, moving.z)
	var crate_planar := Vector2(crate.vel.x, crate.vel.z)
	var closing := (crate_planar - body_planar).dot(normal)
	if closing <= 0.0:
		return
	var impact := closing >= _rules.crate_impact_speed and not _kinds[crate.prop].harmless
	var parting := 1.0 + (_rules.crate_restitution if impact else 0.0)
	crate_planar -= normal * (parting * _rules.body_mass / total * closing)
	crate.vel = Vector3(crate_planar.x, crate.vel.y, crate_planar.y)
	var along := body_planar.dot(normal)
	var away := along + parting * mass / total * closing
	var stop := 0
	if impact:
		away = maxf(away, _rules.crate_knockback)
		stop = _hitstop_ticks
		if player.braced_against(normal, _rules.brace_arc_deg):
			away *= 1.0 - _rules.crate_brace_reduction
			stop = _hitstop_braced_ticks
		player.stagger_ticks = maxi(player.stagger_ticks, _stagger_ticks)
		player.bracing = false
		events.append(SimEvent.prop_hit(tick, player.seat, crate.prop))
	body_planar += normal * (away - along)
	player.freeze(Vector3(body_planar.x, moving.y, body_planar.y), stop)
	if not impact and _credited_elsewhere(player, crate.prop, tick):
		return
	if crate.shoved_by != -1 and tick - crate.shoved_at < _credit_window_ticks:
		player.last_hit_by = crate.shoved_by
	elif not _credited_to(player, crate.prop, tick):
		player.last_hit_by = -1
	player.last_hit_crate = crate.prop
	player.last_hit_at = tick


## Whether [param player]'s last hit, within credit_window of [param tick], is
## credited to anything but the crate [param prop].
func _credited_elsewhere(player: PlayerState, prop: int, tick: int) -> bool:
	if tick - player.last_hit_at >= _credit_window_ticks or player.last_hit_crate == prop:
		return false
	return player.last_hit_by != -1 or player.last_hit_crate != -1


## Whether [param player]'s last hit, within credit_window of [param tick], is the
## crate [param prop]'s.
func _credited_to(player: PlayerState, prop: int, tick: int) -> bool:
	return tick - player.last_hit_at < _credit_window_ticks and player.last_hit_crate == prop


## What each crate stands on: a grounded one follows its surface within step_height
## and goes over an edge deeper than that; a falling one comes down on the highest
## surface under it. Never on its own lid. A floating one is the water's (_float).
func _ground(crates: Array[PropState]) -> void:
	for crate: PropState in crates:
		if crate.body == PropState.Body.FLOATING:
			continue
		if crate.body == PropState.Body.GROUNDED:
			var surface := _surfaces.under(crate.pos, _rules.step_height, crate.prop)
			crate.surface = surface
			if surface == Surfaces.NONE:
				crate.body = PropState.Body.AIRBORNE
				continue
			crate.pos.y = _surfaces.height_at(surface, crate.pos)
			continue
		if crate.vel.y > 0.0:
			continue
		var from := Vector3(crate.pos.x, _feet_before[crate.prop], crate.pos.z)
		var below := _surfaces.landing(from, crate.prop)
		if below == Surfaces.NONE or crate.pos.y > _surfaces.height_at(below, crate.pos):
			continue
		crate.body = PropState.Body.GROUNDED
		crate.surface = below
		crate.pos.y = _surfaces.height_at(below, crate.pos)
		crate.vel.y = 0.0


## A crate with its cell's water deep enough over its underside to lift it (PropKind.lift):
## standing, it floats off its floor; falling, it is lost — or comes down afloat, if it
## floats aboard. One afloat rides the water (_float).
func _sea(crates: Array[PropState], pose: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	var lost: Array[PropState] = []
	for crate: PropState in crates:
		if crate.body != PropState.Body.FLOATING:
			var kind := _kinds[crate.prop]
			if pose.water_height(crate.pos) - crate.pos.y < kind.lift(_rules):
				continue
			if crate.body == PropState.Body.AIRBORNE and not kind.floats_aboard:
				lost.append(crate)
				continue
			crate.body = PropState.Body.FLOATING
			events.append(SimEvent.prop_afloat(tick, crate.prop))
		if _float(crate, pose):
			lost.append(crate)
	_lose(lost, tick, events)


## Floats [param crate] on its cell's water under [param pose]: its underside its ride
## under the water over its x/z (PropKind.ride), never under the floor beneath it. Set
## down on that floor once the water over it is too shallow to lift it. True when it is
## lost: its top at the ceiling over it — for one that floats aboard, never: pressed
## under it — or, with none, the water over its floor crate_adrift_depth deep — or
## nothing under it at all.
func _float(crate: PropState, pose: ShipPose) -> bool:
	var prop := _props[crate.prop]
	var kind := _kinds[crate.prop]
	var floor_surface := _surfaces.landing(crate.pos, crate.prop)
	if floor_surface == Surfaces.NONE:
		return true
	var floor_height := _surfaces.height_at(floor_surface, crate.pos)
	var water := pose.water_height(crate.pos)
	crate.surface = floor_surface
	crate.vel.y = 0.0
	if water - floor_height < kind.lift(_rules):
		crate.body = PropState.Body.GROUNDED
		crate.pos.y = floor_height
		return false
	crate.pos.y = maxf(water - kind.ride(_rules, prop.height), floor_height)
	var floor_point := Vector3(crate.pos.x, floor_height, crate.pos.z)
	var roof := _surfaces.ceiling(floor_point, _rules.step_height)
	if roof == INF:
		return water - floor_height >= _rules.crate_adrift_depth
	if kind.floats_aboard:
		crate.pos.y = maxf(minf(crate.pos.y, roof - prop.height), floor_height)
		return false
	return crate.pos.y + prop.height >= roof


## [param crates] gone into the sea.
func _lose(crates: Array[PropState], tick: int, events: Array[SimEvent]) -> void:
	for crate: PropState in crates:
		crate.body = PropState.Body.LOST
		crate.surface = Surfaces.NONE
		crate.vel = Vector3.ZERO
		_at_rest.take(crate.prop)
		events.append(SimEvent.prop_lost(tick, crate.prop))


## Hands Surfaces the railings the match has broken and where its crates stand.
func _stand(state: MatchState, pose: ShipPose) -> void:
	if _pieces == null:
		_surfaces.honour(pose, _broken, state.props)
	else:
		_pieces.honour(_piece, pose, _broken, state.props)


## Tells Surfaces where [param crate] alone stands now, under [param pose], as _stand
## would tell it with the rest.
func _stand_one(crate: PropState, pose: ShipPose) -> void:
	if _pieces == null:
		_surfaces.stands.stand(crate)
	else:
		_pieces.stand(_piece, pose, crate)
