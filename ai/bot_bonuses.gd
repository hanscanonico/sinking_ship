class_name BotBonuses
extends RefCounted
## A bot and the bonuses aboard (#307) as its delayed view shows them (D10) — every one,
## walls or not, as the props are: the feed has told every player each one's kind and room.
## The bonus it goes for, chosen at a think: of a kind worth something to it that it holds
## fewer than the most of (BonusRules.most_held) — each it takes adds to those it has — a
## walk of its range or less away — bonus_range_m, grown on a hull longer than the steamer's
## (BotProfile.bonus_range) — while the floor it lies on and the lowest point of its
## way there stand bonus_margin_m or more above the water as its view has the water now —
## never as the timeline has it next; the best for its worth, less the farther it lies.
## Unlike a lifebuoy, it goes down toward the water for one by design. Then the Grab press
## that takes it once a press would (GrabReach), never a second before its view shows the
## first. And the spare cold meters its own bonuses give it, unspent (Double life): more
## time in the sea, which its swim counts on. Nothing here rolls the bot's
## stream.

## The bonus spot of the bonus it goes for, by its index in the layout's, as the last think
## chose it; -1 for none.
var spot := -1

var _seat: int
var _profile: BotProfile
## How far a walk it goes for a bonus on her hull (BotProfile.bonus_range).
var _range: float
var _rules: BrawlRules
var _layout: ShipLayout
## What a Grab press reaches, in a match played with bonuses; null in one without.
var _reach: GrabReach
## The kinds of the match's bonuses (BonusRules.kinds): none in a match without bonuses.
var _kinds: Array[BonusKind] = []
## The most bonuses of one kind it holds (BonusRules.most_held).
var _most_held := 0
## The props a hand may hold (GrabReach.holdable_of).
var _holdable: PackedInt32Array
## The tick of its last Grab press, or -1.
var _pressed_at := -1


## The bonuses of [param seat]'s bot in a match on [param layout] under [param rules],
## played with [param bonus_rules] (null for none).
func _init(
	seat: int, profile: BotProfile, rules: BrawlRules, layout: ShipLayout, bonus_rules: BonusRules
) -> void:
	_seat = seat
	_profile = profile
	_rules = rules
	_layout = layout
	var hull := layout.structure.length() if layout.structure != null else 0.0
	_range = profile.bonus_range(hull)
	if bonus_rules != null:
		_reach = GrabReach.new(layout, rules, bonus_rules)
		_kinds.assign(bonus_rules.kinds)
		_most_held = bonus_rules.most_held
	_holdable = GrabReach.holdable_of(layout)


## Picks the bonus to go for at a think, from [param me] in [param seen], among those
## [param found] — a search of [param graph] from where it stands — reaches under
## [param pose]: of a kind worth something to it (worth) that it holds fewer than the most
## of, a walk of its range or less away, its floor and its way there its margin above the
## water (_clear) — the best by its worth, less by up to bonus_walk_share of that
## the farther away it lies. Returns its score, that by bonus_weight, or 0 with none to go
## for: none, too, off her decks, where a body takes nothing (GrabReach) and her spots are
## no points of the frame it finds its way in.
func choose(
	seen: Dictionary, me: Dictionary, found: WalkSearch, graph: WalkGraph, pose: ShipPose
) -> float:
	spot = -1
	if _reach == null or me["state"] != PlayerState.Body.GROUNDED or found.is_empty():
		return 0.0
	if seen["up"][me["piece"]] != Faces.Up.DECK:
		return 0.0
	var my_pos: Vector3 = me["pos"]
	var held: Array = me["bonuses"]
	var best := 0.0
	for entry: Dictionary in seen["bonuses"]:
		var kind: int = entry["kind"]
		var gain := worth(kind) if held.count(kind) < _most_held else 0.0
		var at := _layout.bonus_spots[entry["spot"]].point
		var zone := graph.zone_at(at, graph.surfaces().under(at, _rules.step_height))
		if gain <= 0.0 or zone == WalkGraph.NONE:
			continue
		# Past its range, it need not know how far: the search stops there.
		var walked := found.cost_to(zone, _range)
		if walked == INF:
			continue
		var far := walked + Vector2(at.x - my_pos.x, at.z - my_pos.z).length()
		if far > _range or not _clear(graph, found, zone, at, pose):
			continue
		var walk := _profile.bonus_walk_share * far / _range
		var score := _profile.bonus_weight * gain * (1.0 - walk)
		if score > best:
			best = score
			spot = entry["spot"]
	return best


## What a bonus of [param kind] — by its index among the match's bonus kinds, -1 for none
## — is worth to the bot: its tier's worth for the kind (BotProfile.bonus_worth), nothing
## for one it leaves out.
func worth(kind: int) -> float:
	if kind == -1:
		return 0.0
	return _profile.bonus_worth.get(_kinds[kind], 0.0)


## The bonus [param seen] has aboard at the spot it goes for, or empty: taken, lost, or
## none chosen.
func target(seen: Dictionary) -> Dictionary:
	if spot != -1:
		for entry: Dictionary in seen["bonuses"]:
			if entry["spot"] == spot:
				return entry
	return {}


## Where it stands to take the bonus it goes for and where that lies, as [param seen] has
## it — the one spot: it walks onto it — or empty, the bonus gone.
func aim(seen: Dictionary) -> PackedVector3Array:
	if target(seen).is_empty():
		return PackedVector3Array()
	var at := _layout.bonus_spots[spot].point
	return PackedVector3Array([at, at])


## A Grab press on [param tick] when a press by the bot — [param me] in [param seen],
## carried to [param now_pos] and looking [param look] — would take the bonus it goes for,
## as [param surfaces] has her; else nothing. None while its view predates its last. A
## press that reaches no bonus lets go of what the hands hold: holding a prop, it presses
## only once a press would take the bonus from where its view shows it, too.
func grab(
	seen: Dictionary, me: Dictionary, now_pos: Vector3, look: int, surfaces: Surfaces, tick: int
) -> int:
	if target(seen).is_empty() or seen["tick"] <= _pressed_at:
		return 0
	var aboard: Array[BonusState] = []
	for entry: Dictionary in seen["bonuses"]:
		aboard.append(BonusState.from_dict(entry))
	var player := PlayerState.from_dict(me)
	player.facing = InputFrame.yaw_angle(look)
	var from: Array[Vector3] = [now_pos]
	if PropState.held_in(seen, _seat, _holdable) != -1:
		from.append(player.pos)
	for at: Vector3 in from:
		player.pos = at
		var height := _rules.height_at(surfaces, at)
		var takes := _reach.bonus_taken(player, Faces.Up.DECK, height, aboard, surfaces)
		if takes == -1 or aboard[takes].spot != spot:
			return 0
	_pressed_at = tick
	return InputFrame.GRAB


## The seconds of cold the spare meters [param me]'s bonuses give it add while unspent
## (Double life): a whole cold meter more each, as the sim counts them
## (MatchVerdict.cold_left); none without one.
func spare(me: Dictionary) -> float:
	var spares := 0
	for kind: int in me["bonuses"]:
		if _kinds[kind].spare_meter:
			spares += 1
	return _rules.cold_meter * spares


## How high above the water there is in her now under [param pose] the floor under a body
## at [param at] in the layout's room [param room_index] — NONE on an open deck — stands
## (ShipPose.above_water_held): a room's by its lowest corner, where the water comes in
## first, an open deck's where the body stands. A dry room
## on dry cells stands clear of any water, however far below the sea outside her it lies
## (#340); a room with water in it, or in a cell under it, as far as its floor is over that.
## A room's corners are where a body's middle can come to, a body's radius in from the
## middle of its walls its area runs out to: at her shell that middle lies past her cells,
## where the sea outside her would read as water in the room (#491).
func floor_held(room_index: int, at: Vector3, pose: ShipPose) -> float:
	if room_index < 0 or room_index >= _layout.rooms.size():
		return pose.above_water_held(at)
	var room := _layout.rooms[room_index]
	var size := room.area.size
	var inset := Vector2(
		minf(_rules.body_radius, size.x * 0.5), minf(_rules.body_radius, size.y * 0.5)
	)
	var inside := Rect2(room.area.position + inset, size - inset * 2.0)
	var lowest := INF
	for corner: Vector2 in [
		inside.position,
		Vector2(inside.end.x, inside.position.y),
		inside.end,
		Vector2(inside.position.x, inside.end.y)
	]:
		var point := Vector3(corner.x, room.floor_height, corner.y)
		lowest = minf(lowest, pose.above_water_held(point))
	return lowest


## Whether the floor of [param zone], where a bonus lies at [param at], and the lowest point
## of the way [param found] has to it — both ends of every portal on it, and the floor of
## every room it enters — stand bonus_margin_m or more above the water there is in her under
## [param pose] (floor_held): the water as it stands now, never as the timeline has it next.
func _clear(graph: WalkGraph, found: WalkSearch, zone: int, at: Vector3, pose: ShipPose) -> bool:
	var margin := _profile.bonus_margin_m
	if floor_held(graph.room_of(zone), at, pose) < margin:
		return false
	for leg: WalkGraph.Portal in graph.route_in(found, zone):
		var room := graph.room_of(leg.to_zone)
		if room != WalkGraph.NONE and floor_held(room, Vector3(), pose) < margin:
			return false
		for end: Vector3 in [leg.entry, leg.exit]:
			if pose.above_water_held(end) < margin:
				return false
	return true
