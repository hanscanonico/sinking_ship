class_name Movement
extends RefCounted
## How bodies move (D8), one tick's steps of it as MatchSim calls them in §4's order:
## walking, friction and gravity as velocity; the move itself, met by blockers,
## railings and the other bodies; what each body stands on after it; and in the sea,
## how a swimmer floats, rests on a bottom, ducks under a ceiling and climbs out. What
## stands where it asks Surfaces (D6, D13); a railing a vault damages, Hazards. The
## stamina, the shoves and the cold stay MatchSim's.
##
## A tick moves its bodies on whichever of her faces are floors then (SH32, §5b.3): the
## match stands in the frame of the axis Faces finds up — every body's points turned
## into it for the tick, its heights along that up, its plane that of the floors — and
## a body is upright to the world on any face. A floor tilted past stand_limit_deg is in
## the band where nobody walks: a body that braces holds where it is, up to
## brace_holds_to; anyone else slides down it into the corner and rests there, free to
## move along the corner, never away from it.
##
## Once she has broken (SH33) a Movement moves the bodies on one piece of her (Pieces):
## in the frame of that piece's own faces, its points in that piece's space.

## How many times a tick's contacts are resolved, at most. In one pass each contact
## is met where the body stood before it, so a body pushed two ways — into a corner,
## between a doorway's jambs, against a wall by a crowd — can end inside one wall or
## slip through a gap narrower than itself. Four passes settle a body wedged between
## two walls and another body; they stop as soon as nothing moves.
const CONTACT_PASSES := 4
## How far apart a swimmer looks for a ceiling along the way it swims, out to where its
## circle reaches next (_headroom): half the thinnest lintel, so none slips between.
const DUCK_LOOK := 0.1
## How far one pass of _bodies may push a body before the pairs it took from the grid
## at its start may miss one (_pairs): a pair it skipped was more than four of these
## farther apart than touching then, and once it has pushed any body this far it scans
## every pair left instead, so such a pair ends it at least two of these out of touch.
const CROWD_DRIFT := 0.1

var _rules: BrawlRules
var _hazards: Hazards
var _faces: Faces
## The piece of her whose bodies it moves: 0, the whole ship, until she breaks.
var _piece: int
## The Surfaces of the frame the tick stands in.
var _surfaces: Surfaces
## The bodies of the piece on a grid of the frame the tick stands in (SpatialIndex), each
## numbered by its place in the list last put on it; and that frame.
var _crowd: SpatialIndex
var _crowd_up := Faces.Up.DECK
var _climb_ticks: int


func _init(rules: BrawlRules, faces: Faces, hazards: Hazards, piece := 0) -> void:
	_rules = rules
	_faces = faces
	_piece = piece
	_surfaces = faces.surfaces(Faces.Up.DECK)
	_crowd = _crowd_in(Faces.Up.DECK)
	_hazards = hazards
	_climb_ticks = Ticks.from_seconds(rules.climb_time)


## Stands [param state]'s match on the faces of its piece that are floors under
## [param pose] — the piece's — for the tick [param tick]: in the frame Faces finds up,
## the points of every seat on the piece turned into it — a body standing as it turns to
## another loses its footing, its fall measured from there, and a climb lets go. Returns
## the pose as that frame reads it.
func face(state: MatchState, pose: ShipPose, tick: int, events: Array[SimEvent]) -> ShipPose:
	var was: int = state.up[_piece]
	var up := _faces.up_at(pose, was)
	var framed := _faces.framed(pose, up)
	_surfaces = _faces.surfaces(up, framed)
	if up != Faces.Up.DECK:
		_surfaces.honour(framed)
	if up != _crowd_up:
		_crowd = _crowd_in(up)
		_crowd_up = up
	var turned := up != was
	var middle := Faces.axis(was) * _rules.body_height * 0.5
	for player: PlayerState in state.seats:
		if player.piece != _piece:
			continue
		var reseated := turned and not player.is_out()
		if reseated:
			player.pos += middle
		if up != Faces.Up.DECK:
			Faces.into(player, up)
		if reseated:
			_reseat(player, tick, events)
	state.up[_piece] = up
	return framed


## The points of every seat on its piece back from the tick's frame into the piece's
## space, as a snapshot keeps them (D5).
func unface(state: MatchState) -> void:
	var up: int = state.up[_piece]
	if up == Faces.Up.DECK:
		return
	for player: PlayerState in state.seats:
		if player.piece == _piece:
			Faces.out_of(player, up)


## The Surfaces of the frame the tick stands in: what every rule of the tick asks.
func surfaces() -> Surfaces:
	return _surfaces


## A grid for bodies over the layout of the frame [param up], of the data's cells.
func _crowd_in(up: int) -> SpatialIndex:
	var bounds := SpatialIndex.bounds_of(_faces.layout(up))
	return SpatialIndex.new(bounds, IndexRules.load_default().body_cell)


## The seats of [param live] whose circles a body's at any of [param points] (x/z) could
## reach across [param reach], in seat order: every one that comes that near, and some a
## little farther, off the grid — who a shove from there could land on.
func around(
	live: Array[PlayerState], points: PackedVector2Array, reach: float
) -> Array[PlayerState]:
	_gather(live)
	var marked := PackedByteArray()
	marked.resize(live.size())
	var grow := Vector2.ONE * (_rules.body_radius + reach + CROWD_DRIFT)
	for point: Vector2 in points:
		for index: int in _crowd.near(Rect2(point - grow, grow * 2.0)):
			marked[index] = 1
	var found: Array[PlayerState] = []
	for index in live.size():
		if marked[index] == 1:
			found.append(live[index])
	return found


## Puts [param bodies] on the grid, each the square its circle fits in, numbered by its
## place in the list.
func _gather(bodies: Array[PlayerState]) -> void:
	_crowd.clear()
	var half := Vector2.ONE * _rules.body_radius
	for index in bodies.size():
		var at := Vector2(bodies[index].pos.x, bodies[index].pos.z)
		_crowd.insert(index, Rect2(at - half, half * 2.0))


## [param player] in a frame new to it, its [member PlayerState.pos] the middle of its
## body: upright again about that middle, its feet on the highest face within half its
## height under it, or hanging that far under it. What it stood on is gone from under
## it, so a body standing comes down from there, and a climber lets go.
func _reseat(player: PlayerState, tick: int, events: Array[SimEvent]) -> void:
	var middle := player.pos
	player.pos.y -= _rules.body_height * 0.5
	var under := _surfaces.landing(middle)
	if under != Surfaces.NONE:
		player.pos.y = maxf(player.pos.y, _surfaces.height_at(under, middle))
	player.surface = Surfaces.NONE
	player.climb_left = 0
	if player.body == PlayerState.Body.GROUNDED:
		player.body = PlayerState.Body.AIRBORNE
		player.jumped = false
		events.append(SimEvent.fell(tick, player.seat))
	if player.body == PlayerState.Body.AIRBORNE:
		player.fall_from = player.pos.y


## Walking, friction and gravity, as velocity. Gravity is the world's, turned
## into ship space by the pose; a grounded body feels its downhill part only once
## it has lost its grip — staggered, or idle on a deck steeper than the grip angle.
## On a floor tilted past stand_limit_deg nobody walks: a brace holds where it is up to
## brace_holds_to, anyone else slides into the corner and walks only along it (_slid).
## Wading slows a walk; swimming is _swim's. A body frozen in a hit-stop feels none
## of it, and its stagger waits.
func forces(live: Array[PlayerState], pose_now: ShipPose) -> void:
	var dt := Ticks.SECONDS_PER_TICK
	var gravity := pose_now.ship_gravity(_rules.gravity)
	var downhill := Vector2(gravity.x, gravity.z) * dt
	var slope := pose_now.slope_deg()
	var steep := slope > _rules.grip_angle_deg
	var banded := slope > _rules.stand_limit_deg
	var holds := slope <= _rules.brace_holds_to
	for player: PlayerState in live:
		if player.is_frozen():
			continue
		if player.body == PlayerState.Body.AIRBORNE:
			player.vel += gravity * dt
			_steer_in_air(player)
			continue
		if player.body == PlayerState.Body.SWIMMING:
			_swim(player, pose_now)
			continue
		var planar := Vector2(player.vel.x, player.vel.z)
		var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.walk_speed
		if player.action == PlayerState.Action.CHARGE:
			wish = wish.limit_length(_rules.charge_walk)
		elif player.bracing:
			wish = Vector2.ZERO
		if _surfaces.wet(player.pos, pose_now):
			wish = wish.limit_length(_rules.wade_speed)
		# A brace is rooted: the deck past the grip angle does not pull it.
		var pulled := steep and not (player.bracing and holds)
		if player.is_staggered():
			planar = (planar + downhill).move_toward(Vector2.ZERO, _rules.stagger_friction * dt)
			player.stagger_ticks -= 1
		elif wish == Vector2.ZERO and pulled:
			planar = (planar + downhill).move_toward(Vector2.ZERO, _rules.slide_friction * dt)
		elif banded and pulled:
			planar = _slid(planar, wish, downhill)
		else:
			if pulled:
				planar += downhill
			var rate := _rules.ground_accel if wish != Vector2.ZERO else _rules.ground_friction
			planar = planar.move_toward(wish, rate * dt)
			# The shove is spent once the body moves as its own input says; until then
			# a slide that outlasts the stagger is still the shover's.
			if planar == wish:
				player.forget_hit()
		player.vel = Vector3(planar.x, player.vel.y, planar.y)


## [param planar], a body's velocity on a floor in the band, slid on down
## [param downhill] — this tick's pull — against slide_friction, and turned across the
## slope toward the share of [param wish] that runs along it: it walks along the
## corner it slides into, never up away from it.
func _slid(planar: Vector2, wish: Vector2, downhill: Vector2) -> Vector2:
	var dt := Ticks.SECONDS_PER_TICK
	var down := downhill.normalized()
	var sliding := planar.dot(down)
	var across := planar - down * sliding
	var along := wish - down * wish.dot(down)
	sliding = move_toward(sliding + downhill.length(), 0.0, _rules.slide_friction * dt)
	across = across.move_toward(along, _rules.ground_accel * dt)
	return across + down * sliding


## A jumper steers toward its input at air_control of ground_accel, and keeps its
## speed when it gives none; a fall, a vault or a jumper staggered by a shove flies
## where it was sent.
func _steer_in_air(player: PlayerState) -> void:
	if not player.jumped or player.is_staggered() or player.last_move == Vector2i.ZERO:
		return
	var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.walk_speed
	var rate := _rules.ground_accel * _rules.air_control * Ticks.SECONDS_PER_TICK
	var planar := Vector2(player.vel.x, player.vel.z).move_toward(wish, rate)
	player.vel = Vector3(planar.x, player.vel.y, planar.y)


## The seats of [param live] that move as bodies do: all but the climbers.
func _moving_seats(live: Array[PlayerState]) -> Array[PlayerState]:
	var moving: Array[PlayerState] = []
	for player: PlayerState in live:
		if not player.is_climbing():
			moving.append(player)
	return moving


## Integration, then contacts: blockers, then railings, then bodies pushing each
## other apart pair by pair in seat order, pass after pass until nothing moves.
## Walls and rails have the last word — the last pass stops before bodies push — so
## a crowd may end a tick pressed together, never inside a wall. A climber is where
## its climb has it, and takes no part. Returns each seat's feet height before it
## moved, by seat of [param state].
func move(
	state: MatchState,
	live_seats: Array[PlayerState],
	pose_now: ShipPose,
	tick: int,
	events: Array[SimEvent]
) -> PackedFloat64Array:
	var live := _moving_seats(live_seats)
	var feet_before := PackedFloat64Array()
	feet_before.resize(state.seats.size())
	var came_from := PackedVector2Array()
	came_from.resize(state.seats.size())
	# A body that would cross more than its own radius in one move could land past a
	# thin wall's middle and be pushed out of its far side — two shovers on one
	# staggered body reach twice the restagger knockback, two-thirds of a metre a tick.
	# So the tick's move is cut into as many equal steps as the fastest body needs to
	# cross at most its radius in each, every step met by the contacts; at walking and
	# single-shove speeds it is one step, the move exactly as it always was.
	var steps := 1
	for player: PlayerState in live:
		feet_before[player.seat] = player.pos.y
		came_from[player.seat] = Vector2(player.pos.x, player.pos.z)
		var reach := Vector2(player.vel.x, player.vel.z).length() * Ticks.SECONDS_PER_TICK
		steps = maxi(steps, ceili(reach / _rules.body_radius))
	var dt := Ticks.SECONDS_PER_TICK / steps
	# Where each body last met no blocker, and no railing: nothing that holds a body
	# moves while bodies do, and a railing only breaks, so a body still there meets
	# nothing again and is not asked.
	var clear_of_blockers: Dictionary[int, Vector3] = {}
	var clear_of_railings: Dictionary[int, Vector3] = {}
	for _step in steps:
		for player: PlayerState in live:
			player.pos += player.vel * dt
		for contact_pass in CONTACT_PASSES:
			var held := _blockers(live, feet_before, pose_now, clear_of_blockers)
			held = (
				_railings(state, live, pose_now, tick, events, came_from, clear_of_railings) or held
			)
			if contact_pass == CONTACT_PASSES - 1:
				break
			if not _bodies(live) and not held:
				break
	_ceilings(live, feet_before)
	return feet_before


## A rising body stops with its head against the lowest underside over it — a deck,
## a stair, a lintel — and loses its upward speed. It is looked for from where the
## feet stood before this tick's move, so a fast rise cannot pass through a deck.
func _ceilings(live: Array[PlayerState], feet_before: PackedFloat64Array) -> void:
	for player: PlayerState in live:
		if player.body != PlayerState.Body.AIRBORNE or player.vel.y <= 0.0:
			continue
		var feet := Vector3(player.pos.x, feet_before[player.seat], player.pos.z)
		var highest := _surfaces.ceiling(feet, _rules.step_height) - _rules.body_height
		if player.pos.y > highest:
			player.pos.y = highest
			player.vel.y = 0.0


## Whatever stops a body — a blocker, a wall, a deck edge too high to step onto —
## pushes it back out in the deck plane and takes the velocity into it. It is met at
## the height the feet stood at before this tick's move, so a fall lands on a deck
## in _ground rather than being pushed off its edge. A swimmer steps as a swimmer
## does (_swim_step). A body still where [param clear] last found it held by nothing
## is not asked again. True when it moved anyone.
func _blockers(
	live: Array[PlayerState],
	feet_before: PackedFloat64Array,
	pose_now: ShipPose,
	clear: Dictionary[int, Vector3]
) -> bool:
	var moved := false
	for player: PlayerState in live:
		if clear.get(player.seat) == player.pos:
			continue
		var feet := Vector3(player.pos.x, feet_before[player.seat], player.pos.z)
		var step := _rules.step_height
		if player.body == PlayerState.Body.SWIMMING:
			step = _swim_step(feet, pose_now.water_height(feet))
		var contacts := _surfaces.obstacle_contacts(
			feet, _rules.body_radius, _rules.body_height, step
		)
		if contacts.is_empty():
			clear[player.seat] = player.pos
		for contact: Surfaces.Contact in contacts:
			_hold(player, contact)
			moved = true
	return moved


## A railing stops a grounded body crossing it slower than vault_speed — it loses
## the velocity into the rail — and tips one at or above it over, into the air,
## damaging the span by vault_damage (Hazards.damage). In the air, a body that came
## from a rail's side with its feet below the rail's top is held the same way, unless
## it crosses at vault_speed or more: a vaulter is never pulled back. A body still
## where [param clear] last found it held by none is not asked again. True when it
## moved anyone.
func _railings(
	state: MatchState,
	live: Array[PlayerState],
	pose_now: ShipPose,
	tick: int,
	events: Array[SimEvent],
	came_from: PackedVector2Array,
	clear: Dictionary[int, Vector3]
) -> bool:
	var moved := false
	for player: PlayerState in live:
		if clear.get(player.seat) == player.pos:
			continue
		var airborne := player.body == PlayerState.Body.AIRBORNE
		var contacts: Array[Surfaces.Contact]
		if airborne:
			contacts = _surfaces.airborne_rail_contacts(
				player.pos,
				came_from[player.seat],
				_rules.body_radius,
				_rules.body_height,
				_rules.railing_height
			)
		elif player.body == PlayerState.Body.GROUNDED:
			contacts = _surfaces.rail_contacts(player.pos, _rules.body_radius, player.surface)
		if contacts.is_empty():
			clear[player.seat] = player.pos
		for contact: Surfaces.Contact in contacts:
			var planar := Vector2(player.vel.x, player.vel.z)
			var into := -planar.dot(contact.normal)
			if into >= _rules.vault_speed:
				if airborne:
					continue
				player.body = PlayerState.Body.AIRBORNE
				player.surface = Surfaces.NONE
				player.fall_from = player.pos.y
				player.vel.y = _rules.vault_lift
				events.append(SimEvent.vaulted(tick, player.seat))
				_hazards.damage(
					state,
					_hazards.rail(contact.railing),
					_rules.vault_damage,
					pose_now,
					tick,
					events,
					player.seat
				)
				# In the air it meets other railings than on its feet: where it stood clear
				# before is no answer for it now.
				clear.erase(player.seat)
				break
			_hold(player, contact)
			moved = true
	return moved


## Bodies whose heights overlap push each other apart, pair by pair in seat order,
## each moving half the overlap: the pairs the grid finds near enough (_pairs), and every
## pair left once a body has been pushed CROWD_DRIFT. True when it moved anyone.
func _bodies(live: Array[PlayerState]) -> bool:
	var moved := false
	var pairs := _pairs(live)
	var pushed := PackedFloat64Array()
	pushed.resize(live.size())
	for at in range(0, pairs.size(), 2):
		var first := pairs[at]
		var second := pairs[at + 1]
		var push := _push_apart(live[first], live[second])
		if push == 0.0:
			continue
		moved = true
		pushed[first] += push
		pushed[second] += push
		if pushed[first] >= CROWD_DRIFT or pushed[second] >= CROWD_DRIFT:
			for a in range(first, live.size()):
				for b in range(second + 1 if a == first else a + 1, live.size()):
					_push_apart(live[a], live[b])
			return true
	return moved


## Every pair of [param live] whose squares, one grown by four drifts, share a cell of
## the grid, as (first, second) by place in the list, first before second, in seat order.
func _pairs(live: Array[PlayerState]) -> PackedInt32Array:
	_gather(live)
	var pairs := PackedInt32Array()
	var grow := Vector2.ONE * (_rules.body_radius + CROWD_DRIFT * 4.0)
	for first in live.size():
		var at := Vector2(live[first].pos.x, live[first].pos.z)
		for second: int in _crowd.near(Rect2(at - grow, grow * 2.0)):
			if second > first:
				pairs.append(first)
				pairs.append(second)
	return pairs


## Pushes [param a] and [param b] apart, each half the overlap, when their heights
## overlap and their circles do; how far each moved, or 0.
func _push_apart(a: PlayerState, b: PlayerState) -> float:
	var reach := _rules.body_radius * 2.0
	var a_pos := a.pos
	var b_pos := b.pos
	if absf(a_pos.y - b_pos.y) >= _rules.body_height:
		return 0.0
	var offset := Vector2(b_pos.x - a_pos.x, b_pos.z - a_pos.z)
	var distance := offset.length()
	if distance >= reach:
		return 0.0
	var normal := offset / distance if distance > 0.0 else Vector2.RIGHT
	var push := normal * ((reach - distance) * 0.5)
	a.pos -= Vector3(push.x, 0.0, push.y)
	b.pos += Vector3(push.x, 0.0, push.y)
	return (reach - distance) * 0.5


## Moves [param player] out of [param contact] in the deck plane and takes the
## velocity into it.
func _hold(player: PlayerState, contact: Surfaces.Contact) -> void:
	player.pos += Vector3(contact.normal.x, 0.0, contact.normal.y) * contact.depth
	var planar := Vector2(player.vel.x, player.vel.z)
	var into := -planar.dot(contact.normal)
	if into > 0.0:
		planar += contact.normal * into
		player.vel = Vector3(planar.x, player.vel.y, planar.y)


## What each body stands on. A grounded body follows its surface up and down
## within step_height; past an edge deeper than that it falls. A falling body lands
## on the highest surface it comes down onto, staggered by the drop — a jump's by
## the drop below where it left, so its own height costs nothing. A swimmer's height
## is the water's (_water).
func ground(
	live: Array[PlayerState], tick: int, events: Array[SimEvent], feet_before: PackedFloat64Array
) -> void:
	for player: PlayerState in live:
		if player.body == PlayerState.Body.SWIMMING:
			continue
		if player.body == PlayerState.Body.GROUNDED:
			var surface := _surfaces.under(player.pos, _rules.step_height)
			player.surface = surface
			if surface == Surfaces.NONE:
				player.body = PlayerState.Body.AIRBORNE
				player.fall_from = player.pos.y
				events.append(SimEvent.fell(tick, player.seat))
				continue
			player.pos.y = _surfaces.height_at(surface, player.pos)
			continue
		if not player.jumped:
			player.fall_from = maxf(player.fall_from, player.pos.y)
		if player.vel.y > 0.0:
			continue
		var below := _surfaces.landing(
			Vector3(player.pos.x, feet_before[player.seat], player.pos.z)
		)
		if below == Surfaces.NONE:
			continue
		var ground := _surfaces.height_at(below, player.pos)
		if player.pos.y > ground:
			continue
		var drop := maxf(player.fall_from - ground, 0.0)
		var stagger := Ticks.from_seconds(drop * _rules.fall_stagger_per_m)
		player.body = PlayerState.Body.GROUNDED
		player.jumped = false
		player.surface = below
		player.pos.y = ground
		player.vel.y = 0.0
		player.stagger_ticks = maxi(player.stagger_ticks, stagger)
		events.append(SimEvent.landed(tick, player.seat, below, stagger))


## A swimmer moves across the sea at swim_speed, without control while staggered.
## A body above the sea falls into it; in it, the water takes a dive's speed and
## floats it back to where it rests (_rest_at). A climber hangs where its climb has
## it (_water).
func _swim(player: PlayerState, pose_now: ShipPose) -> void:
	if player.is_climbing():
		return
	var dt := Ticks.SECONDS_PER_TICK
	var planar := Vector2(player.vel.x, player.vel.z)
	if player.is_staggered():
		planar = planar.move_toward(Vector2.ZERO, _rules.stagger_friction * dt)
		player.stagger_ticks -= 1
	else:
		var wish := Vector2(player.last_move) / InputFrame.AXIS_MAX * _rules.swim_speed
		planar = planar.move_toward(wish, _rules.ground_accel * dt)
	var rise := player.vel.y
	if _surfaces.wet(player.pos, pose_now):
		var rest := _rest_at(player.pos, player.pos.y, pose_now, _heading(player))
		var toward := signf(rest - player.pos.y)
		rise = move_toward(rise, toward * _rules.float_speed, _rules.dunk_drag * dt)
	else:
		rise -= _rules.gravity * dt
	player.vel = Vector3(planar.x, rise, planar.y)


## Where a swimmer's feet rest at [param feet]'s x/z, coming from
## [param feet_before]'s height and swimming [param heading]: swim_depth under the
## water it is in — its cell's, so it surfaces in a pocket (SH29) — or on the bottom
## there when that is higher.
func _rest_at(feet: Vector3, feet_before: float, pose_now: ShipPose, heading: Vector2) -> float:
	var sea := pose_now.water_height(feet)
	var bottom := _bottom(feet, feet_before, sea)
	var rest := maxf(sea - _rules.swim_depth, bottom)
	return minf(rest, _headroom(feet, feet_before, heading, sea, bottom))


## The highest a swimmer's feet at [param feet]'s x/z, coming from
## [param feet_before]'s height, may rest: a body's height under the lowest deck over
## its head (Surfaces.ceiling) — and, swimming [param heading], under the lowest along
## the way to where its circle reaches next, so it ducks under a lintel or a deck's
## edge it swims into: through a flooded doorway into the next cell, to surface there.
## Not under one it floats over — wade_depth under its water at [param sea] — nor one
## too low for a body over [param bottom]. Under a deck the sea is filling, it stays
## under that deck as the water closes over its head; a head pressed into the deck — by
## as little as its feet's height rounds up, CLEARANCE_SLACK under it — would be pushed
## out sideways by it, through a wall or the hull.
func _headroom(
	feet: Vector3, feet_before: float, heading: Vector2, sea: float, bottom: float
) -> float:
	var from := Vector3(feet.x, feet_before, feet.z)
	var body := _rules.body_height + Surfaces.CLEARANCE_SLACK
	var room := _surfaces.ceiling(from, _rules.step_height) - body
	if heading == Vector2.ZERO:
		return room
	var reach := _rules.body_radius + _rules.swim_speed * Ticks.SECONDS_PER_TICK
	var looks := ceili(reach / DUCK_LOOK)
	for look in range(1, looks + 1):
		var ahead := from + Vector3(heading.x, 0.0, heading.y) * (reach * look / looks)
		var over := _surfaces.ceiling(ahead, _rules.step_height)
		if over > sea - _rules.wade_depth and over - body >= bottom:
			room = minf(room, over - body)
	return room


## The way a swimmer presses, x/z, a unit vector — none while it presses none or is
## staggered.
func _heading(player: PlayerState) -> Vector2:
	if player.is_staggered():
		return Vector2.ZERO
	return Vector2(player.last_move).normalized()


## The height of the sea's bottom under a swimmer at [param feet] that came from
## [param feet_before]'s height: the surface it would come down on — within a
## swimmer's step over its feet (_swim_step), so a ramp it swims up carries it and a
## flooded deck it swims over lifts it — when that is under [param sea]; -INF
## otherwise. A surface above the sea is never its bottom: a climber shoved back
## falls past the edge it was climbing.
func _bottom(feet: Vector3, feet_before: float, sea: float) -> float:
	var from := Vector3(feet.x, maxf(feet.y, feet_before), feet.z)
	from.y += _swim_step(from, sea)
	var bottom := _surfaces.landing(from)
	if bottom == Surfaces.NONE:
		return -INF
	var height := _surfaces.height_at(bottom, feet)
	return height if height < sea else -INF


## How far up a swimmer with its feet at [param feet] steps: over any edge it can
## float across, as high as wade_depth under [param sea], but never so high that its
## head would meet a deck over it; a step_height at the least. A deck's edge it swims
## onto stands below its head and a deck it swims under above it, within a step: the
## first is no wall to someone swimming in from deeper water, the second no floor.
func _swim_step(feet: Vector3, sea: float) -> float:
	var clearance := _rules.body_height - _rules.step_height
	var overhead := _surfaces.ceiling(feet, clearance) - _rules.body_height
	return maxf(_rules.step_height, minf(sea - _rules.wade_depth, overhead) - feet.y)


## Whether [param player], not swimming, is in the sea: in the air, its feet under
## it over a bottom wade_depth deep or more — it lands on a shallower one; on a
## surface, wade_depth under it or more.
func in_the_sea(player: PlayerState, pose_now: ShipPose) -> bool:
	if player.body == PlayerState.Body.AIRBORNE:
		var sea := pose_now.water_height(player.pos)
		var depth := sea - _bottom(player.pos, player.pos.y, sea)
		return _surfaces.wet(player.pos, pose_now) and depth >= _rules.wade_depth
	return sea_over(player.surface, player.pos, pose_now) >= _rules.wade_depth


## How deep the sea stands over [param surface] under [param feet]'s x/z.
func sea_over(surface: int, feet: Vector3, pose_now: ShipPose) -> float:
	return pose_now.water_height(feet) - _surfaces.height_at(surface, feet)


## After this tick's move: on the bottom, if it went under it; at rest, if it rose
## to it, or sank onto it no faster than the water floats a body.
func come_to_rest(player: PlayerState, feet_before: float, pose_now: ShipPose) -> void:
	var sea := pose_now.water_height(player.pos)
	var bottom := _bottom(player.pos, feet_before, sea)
	var headroom := _headroom(player.pos, feet_before, _heading(player), sea, bottom)
	var rest := minf(maxf(sea - _rules.swim_depth, bottom), headroom)
	var rise := player.vel.y
	if player.pos.y < bottom:
		player.pos.y = bottom
		rise = maxf(rise, 0.0)
	var speed := _rules.float_speed
	var risen := rise > 0.0 and player.pos.y >= rest
	var settled := (
		rise <= 0.0
		and rise >= -speed
		and player.pos.y <= rest
		and player.pos.y >= rest - speed * Ticks.SECONDS_PER_TICK
	)
	if risen or settled:
		player.pos.y = rest
		rise = 0.0
	player.vel.y = rise


## A swimmer pressing toward a way out that Surfaces finds (climb_out) starts up it:
## climb_time, or longer up a ladder at ladder_speed.
func start_climb(player: PlayerState, pose_now: ShipPose) -> void:
	if player.is_staggered() or player.last_move == Vector2i.ZERO:
		return
	var climb := _surfaces.climb_out(
		player.pos, Vector2(player.last_move).normalized(), pose_now, _rules
	)
	if climb == null:
		return
	var rise := climb.stand.y - pose_now.water_height(climb.stand)
	player.climb_left = maxi(_climb_ticks, Ticks.from_seconds(rise / _rules.ladder_speed))
	player.climb_to = climb.stand
	player.vel = Vector3.ZERO
	player.jumped = false


## A climb rises an equal share of the rest of the way each tick, hanging at the
## edge, and steps over it at walk_speed at the end, to stand where it was going.
## Where that is gone — the deck collapsed under it — the climber lets go, back into
## the sea.
func climb(player: PlayerState, tick: int, events: Array[SimEvent]) -> void:
	var ground := _surfaces.under(player.climb_to, _rules.step_height)
	if ground == Surfaces.NONE:
		player.climb_left = 0
		return
	player.pos.y += (player.climb_to.y - player.pos.y) / player.climb_left
	var across := Vector2(player.climb_to.x - player.pos.x, player.climb_to.z - player.pos.z)
	var later := _rules.walk_speed * Ticks.SECONDS_PER_TICK * (player.climb_left - 1)
	var stride := across.limit_length(maxf(across.length() - later, 0.0))
	player.pos += Vector3(stride.x, 0.0, stride.y)
	player.climb_left -= 1
	if player.climb_left == 0:
		stand(player, ground, tick, events)


## Out of the sea, standing on [param surface]: the shove or the crate that put it
## there no longer counts.
func stand(player: PlayerState, surface: int, tick: int, events: Array[SimEvent]) -> void:
	player.body = PlayerState.Body.GROUNDED
	player.surface = surface
	player.pos.y = _surfaces.height_at(surface, player.pos)
	player.vel.y = 0.0
	player.jumped = false
	player.climb_left = 0
	player.forget_hit()
	events.append(SimEvent.climbed_out(tick, player.seat, surface))
