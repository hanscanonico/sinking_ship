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
## the two masses.
##
## Every prop of hers is stepped as a crate is (#273) while it lies loose — not hung on a
## railing nor held — but only a solid one (PropKind) holds bodies back, stands a lid,
## takes a shove, runs into a body or damages a railing: bodies walk through any other.
## A prop hung on a span the sinking fails, the match breaks or a collapse takes is lost
## with it.
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

var _rules: BrawlRules
var _layout: ShipLayout
var _props: Array[ShipProp] = []
## Per prop, 1 for a solid one.
var _solid := PackedByteArray()
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
		_solid.append(1 if prop.prop_kind().solid else 0)
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
	var crates: Array[PropState] = []
	var unhung: Array[PropState] = []
	for crate: PropState in state.props:
		if _pieces != null and _pieces.count() > 1:
			var over := _pieces.piece_at(pose.standing, crate.pos.x)
			_aboard[crate.prop] = 1 if over == _piece else 0
		if _aboard[crate.prop] == 0:
			continue
		if crate.is_loose():
			crates.append(crate)
		elif crate.body == PropState.Body.HUNG and (rolled or _span_gone(crate, pose)):
			unhung.append(crate)
	_lose(unhung, tick, events)
	if crates.is_empty():
		return
	if rolled:
		_lose(crates, tick, events)
		return
	_forces(crates, here)
	var feet_before := _move(state, crates, pose, tick, events)
	_run_into_bodies(state, crates, tick, events)
	_stand(state, pose)
	_ground(crates, feet_before)
	_sea(crates, here, tick, events)
	_stand(state, pose)


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
## may land on them, numbered from [param first]: crate n is candidate first + n.
func candidates(state: MatchState, first: int) -> Array[ShoveResolver.Candidate]:
	var found: Array[ShoveResolver.Candidate] = []
	for crate: PropState in state.props:
		if crate.is_loose() and _aboard[crate.prop] == 1 and _solid[crate.prop] == 1:
			var prop := _props[crate.prop]
			found.append(
				ShoveResolver.Candidate.new(first + crate.prop, crate.pos, prop.radius, prop.height)
			)
	return found


## A shove of [param speed] landing on the crate [param hit] names, numbered from
## [param first] as candidates() numbered it: sent at that speed weighed by the two
## masses, and the shover's, for its credit.
func shove(state: MatchState, hit: ShoveResolver.Hit, first: int, speed: float, tick: int) -> void:
	var crate := state.props[hit.target - first]
	var sent := hit.direction * speed * _rules.body_mass / _props[crate.prop].mass
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
## are (Movement.move). Returns each crate's underside height before it moved.
func _move(
	state: MatchState, crates: Array[PropState], pose: ShipPose, tick: int, events: Array[SimEvent]
) -> PackedFloat64Array:
	var feet_before := PackedFloat64Array()
	feet_before.resize(state.props.size())
	var came_from := PackedVector2Array()
	came_from.resize(state.props.size())
	var steps := 1
	for crate: PropState in crates:
		feet_before[crate.prop] = crate.pos.y
		came_from[crate.prop] = Vector2(crate.pos.x, crate.pos.z)
		var reach := Vector2(crate.vel.x, crate.vel.z).length() * Ticks.SECONDS_PER_TICK
		steps = maxi(steps, ceili(reach / _props[crate.prop].radius))
	var dt := Ticks.SECONDS_PER_TICK / steps
	for _step in steps:
		for crate: PropState in crates:
			crate.pos += crate.vel * dt
		# Each crate meets the others where they stand now, the earlier ones moved:
		# Surfaces is told again whenever one has moved since it last was.
		var moved := true
		for _contact_pass in Movement.CONTACT_PASSES:
			var held := false
			for crate: PropState in crates:
				if moved:
					_stand(state, pose)
				var blocked := _blockers(crate, feet_before)
				var railed := _railings(state, crate, came_from, pose, tick, events)
				moved = blocked or railed
				held = moved or held
			if not held:
				break
	return feet_before


## Whatever stops [param crate] in the deck plane, met at the height its underside
## stood at before this tick's move. True when it moved it.
func _blockers(crate: PropState, feet_before: PackedFloat64Array) -> bool:
	var prop := _props[crate.prop]
	var feet := Vector3(crate.pos.x, feet_before[crate.prop], crate.pos.z)
	var contacts := _surfaces.obstacle_contacts(
		feet, prop.radius, prop.height, _rules.step_height, crate.prop
	)
	for contact: Surfaces.Contact in contacts:
		_hold(crate, contact)
	return not contacts.is_empty()


## A railing holds [param crate] as it holds a body — in the air, only from the
## side it came from — unless the crate crosses it at railing_break_speed or more and
## breaks it. True when it moved it.
func _railings(
	state: MatchState,
	crate: PropState,
	came_from: PackedVector2Array,
	pose: ShipPose,
	tick: int,
	events: Array[SimEvent]
) -> bool:
	var prop := _props[crate.prop]
	var contacts: Array[Surfaces.Contact]
	if crate.body == PropState.Body.AIRBORNE:
		contacts = _surfaces.airborne_rail_contacts(
			crate.pos, came_from[crate.prop], prop.radius, prop.height, _rules.railing_height
		)
	else:
		contacts = _surfaces.rail_contacts(crate.pos, prop.radius, crate.surface)
	var held := false
	for contact: Surfaces.Contact in contacts:
		var into := -Vector2(crate.vel.x, crate.vel.z).dot(contact.normal)
		if (
			into >= _rules.railing_break_speed
			and _solid[crate.prop] == 1
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
func _run_into_bodies(
	state: MatchState, crates: Array[PropState], tick: int, events: Array[SimEvent]
) -> void:
	for crate: PropState in crates:
		if _solid[crate.prop] == 0:
			continue
		var prop := _props[crate.prop]
		var reach := prop.radius + _rules.body_radius
		for player: PlayerState in state.seats:
			if player.piece != _piece:
				continue
			# Out of reach first: the cheapest test, and most pairs fail it.
			var offset := Vector2(player.pos.x - crate.pos.x, player.pos.z - crate.pos.z)
			var distance := offset.length()
			if distance >= reach:
				continue
			if player.is_out() or player.is_climbing() or player.body == PlayerState.Body.SWIMMING:
				continue
			if (
				player.pos.y + _rules.step_height >= crate.pos.y + prop.height
				or player.pos.y + _rules.body_height <= crate.pos.y
				# A crawler's head is lower: asked last, it is the dearest test.
				or player.pos.y + _rules.height_at(_surfaces, player.pos) <= crate.pos.y
			):
				continue
			var normal := offset / distance if distance > 0.0 else Vector2.RIGHT
			_collide(crate, player, normal, reach - distance, tick, events)


## [param crate] and [param player], [param overlap] into each other along
## [param normal] (from the crate to the body), part by their masses. Closing at
## crate_impact_speed or more, the crate staggers the body and the two part with
## crate_restitution of the closing speed — the body sent away at crate_knockback at
## the least, held through a hit-stop, a front brace taking crate_brace_reduction off
## that; slower, it pushes the body and they go on together. A hit credits the crate,
## and through it the seat that shoved it within credit_window — else the seat its own
## hit within credit_window credited; a push does the same only over no other credit
## within credit_window — a crate drifting into a body a seat has just shoved takes
## nothing from that seat.
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
	var impact := closing >= _rules.crate_impact_speed
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
func _ground(crates: Array[PropState], feet_before: PackedFloat64Array) -> void:
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
		var from := Vector3(crate.pos.x, feet_before[crate.prop], crate.pos.z)
		var below := _surfaces.landing(from, crate.prop)
		if below == Surfaces.NONE or crate.pos.y > _surfaces.height_at(below, crate.pos):
			continue
		crate.body = PropState.Body.GROUNDED
		crate.surface = below
		crate.pos.y = _surfaces.height_at(below, crate.pos)
		crate.vel.y = 0.0


## A crate with its cell's water wade_depth or more over its underside: standing, it
## floats off its floor; falling, it is lost. One afloat rides the water (_float).
func _sea(crates: Array[PropState], pose: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	var lost: Array[PropState] = []
	for crate: PropState in crates:
		if crate.body != PropState.Body.FLOATING:
			if pose.water_height(crate.pos) - crate.pos.y < _rules.wade_depth:
				continue
			if crate.body == PropState.Body.AIRBORNE:
				lost.append(crate)
				continue
			crate.body = PropState.Body.FLOATING
			events.append(SimEvent.prop_afloat(tick, crate.prop))
		if _float(crate, pose):
			lost.append(crate)
	_lose(lost, tick, events)


## Floats [param crate] on its cell's water under [param pose]: its underside
## crate_draft under the water over its x/z, never under the floor beneath it. Set down
## on that floor once the water over it is shallower than wade_depth. True when it is
## lost: its top at the ceiling over it or, with none, the water over its floor
## crate_adrift_depth deep — or nothing under it at all.
func _float(crate: PropState, pose: ShipPose) -> bool:
	var prop := _props[crate.prop]
	var floor_surface := _surfaces.landing(crate.pos, crate.prop)
	if floor_surface == Surfaces.NONE:
		return true
	var floor_height := _surfaces.height_at(floor_surface, crate.pos)
	var water := pose.water_height(crate.pos)
	crate.surface = floor_surface
	crate.vel.y = 0.0
	if water - floor_height < _rules.wade_depth:
		crate.body = PropState.Body.GROUNDED
		crate.pos.y = floor_height
		return false
	crate.pos.y = maxf(water - _rules.crate_draft, floor_height)
	var floor_point := Vector3(crate.pos.x, floor_height, crate.pos.z)
	var roof := _surfaces.ceiling(floor_point, _rules.step_height)
	if roof == INF:
		return water - floor_height >= _rules.crate_adrift_depth
	return crate.pos.y + prop.height >= roof


## [param crates] gone into the sea.
func _lose(crates: Array[PropState], tick: int, events: Array[SimEvent]) -> void:
	for crate: PropState in crates:
		crate.body = PropState.Body.LOST
		crate.surface = Surfaces.NONE
		crate.vel = Vector3.ZERO
		events.append(SimEvent.prop_lost(tick, crate.prop))


## Hands Surfaces the railings the match has broken and where its crates stand.
func _stand(state: MatchState, pose: ShipPose) -> void:
	if _pieces == null:
		_surfaces.honour(pose, _broken, state.props)
	else:
		_pieces.honour(_piece, pose, _broken, state.props)
