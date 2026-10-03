class_name Hazards
extends RefCounted
## The hazards with state (SH10, §6): the ship's loose cargo, and the damage its
## railings take. Rules, never physics bodies (D1); their state is MatchState's and
## in the snapshot (D5).
##
## A crate is an upright circle on the deck, as a body is (D8). It holds while the
## deck is no steeper than its own grip angle; past it, the world's gravity turned by
## the pose pulls it downhill against its friction — the slope rule bodies follow. It
## meets walls, blockers, railings and the other crates through Surfaces (D6), falls
## off an open edge or down a stair opening, and is lost once the sea stands
## wade_depth over its underside. Running into a brawler at crate_impact_speed or
## more, it staggers it and knocks it back through a hit-stop, as a shove does (D12),
## and keeps going, slowed; slower, it pushes it. Either way the two part with the
## closing speed by their masses. A shove sends a crate at its knockback weighed by
## the two masses.
##
## A vault damages the span it goes over by vault_damage, and a crate crossing one at
## railing_break_speed or more by crate_damage; a span with no hits left is broken,
## gone from Surfaces like a failed one, and holds nothing.
##
## MatchSim steps the crates once a tick, after the bodies have moved, landed and
## thawed and before the shoves (§4).

var _rules: BrawlRules
var _props: Array[ShipProp] = []
var _surfaces: Surfaces
var _stagger_ticks: int
var _hitstop_ticks: int
var _hitstop_braced_ticks: int
var _credit_window_ticks: int


func _init(config: MatchConfig, surfaces: Surfaces) -> void:
	_rules = config.rules
	_props = config.ship.props
	_surfaces = surfaces
	_stagger_ticks = Ticks.from_seconds(_rules.stagger)
	_hitstop_ticks = Ticks.from_seconds(_rules.hitstop)
	_hitstop_braced_ticks = Ticks.from_seconds(_rules.hitstop_braced)
	_credit_window_ticks = Ticks.from_seconds(_rules.credit_window)


## One tick of the cargo, in [param state], under [param pose].
func step(state: MatchState, pose: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	var crates: Array[PropState] = []
	for crate: PropState in state.props:
		if not crate.is_lost():
			crates.append(crate)
	if crates.is_empty():
		return
	_forces(crates, pose)
	var feet_before := _move(state, crates, pose, tick, events)
	_run_into_bodies(state, crates, tick, events)
	_stand(state, pose)
	_ground(crates, feet_before)
	_sea(crates, pose, tick, events)
	_stand(state, pose)


## The crates still on board as a shove may land on them, numbered from
## [param first]: crate n is candidate first + n.
func candidates(state: MatchState, first: int) -> Array[ShoveResolver.Candidate]:
	var found: Array[ShoveResolver.Candidate] = []
	for crate: PropState in state.props:
		if not crate.is_lost():
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
	_stand(state, pose)
	return true


## Gravity in the air; on the deck, the downhill pull past its grip angle, and its
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
		var prop := _props[crate.prop]
		var planar := Vector2(crate.vel.x, crate.vel.z)
		if slope > prop.grip_angle_deg:
			planar += downhill
		planar = planar.move_toward(Vector2.ZERO, prop.friction * dt)
		crate.vel = Vector3(planar.x, crate.vel.y, planar.y)


## Integration, then contacts — blockers, walls, deck edges and the other crates,
## then railings — crate by crate, pass after pass until nothing moves, the tick cut
## into steps so that no crate crosses more than its radius in one, as bodies' moves
## are (MatchSim._move). Returns each crate's underside height before it moved.
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
		for _contact_pass in MatchSim.CONTACT_PASSES:
			var held := false
			for crate: PropState in crates:
				# Each crate meets the others where they stand now, the earlier ones moved.
				_stand(state, pose)
				held = _blockers(crate, feet_before) or held
				held = _railings(state, crate, came_from, pose, tick, events) or held
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
			and damage(
				state, contact.railing, _rules.crate_damage, pose, tick, events, -1, crate.prop
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
## crate never comes down on a swimmer: it is lost as it reaches the sea.
func _run_into_bodies(
	state: MatchState, crates: Array[PropState], tick: int, events: Array[SimEvent]
) -> void:
	for crate: PropState in crates:
		var prop := _props[crate.prop]
		var reach := prop.radius + _rules.body_radius
		for player: PlayerState in state.seats:
			if player.is_out() or player.is_climbing() or player.body == PlayerState.Body.SWIMMING:
				continue
			if (
				player.pos.y + _rules.step_height >= crate.pos.y + prop.height
				or player.pos.y + _rules.body_height <= crate.pos.y
			):
				continue
			var offset := Vector2(player.pos.x - crate.pos.x, player.pos.z - crate.pos.z)
			var distance := offset.length()
			if distance >= reach:
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
		events.append(SimEvent.crate_hit(tick, player.seat, crate.prop))
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
## surface under it. Never on its own lid.
func _ground(crates: Array[PropState], feet_before: PackedFloat64Array) -> void:
	for crate: PropState in crates:
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


## A crate with the sea wade_depth or more over its underside floats off: lost.
func _sea(crates: Array[PropState], pose: ShipPose, tick: int, events: Array[SimEvent]) -> void:
	for crate: PropState in crates:
		if pose.sea_height(crate.pos.x, crate.pos.z) - crate.pos.y < _rules.wade_depth:
			continue
		crate.body = PropState.Body.LOST
		crate.surface = Surfaces.NONE
		crate.vel = Vector3.ZERO
		events.append(SimEvent.crate_lost(tick, crate.prop))


## Hands Surfaces the railings the match has broken and where its crates stand.
func _stand(state: MatchState, pose: ShipPose) -> void:
	_surfaces.honour(pose, state.broken_railings(), state.props)
