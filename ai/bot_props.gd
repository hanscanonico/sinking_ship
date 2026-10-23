class_name BotProps
extends RefCounted
## A bot and her props (#273) as its delayed view shows them (D10) — every prop seen,
## walls or not, as the cargo is: what it holds; the lifebuoy it goes for, once
## buoy_from of her decks are under water and its hands are empty — the nearest it can
## walk to within buoy_range_m, hung on its span, lying loose or afloat at hand — and the
## Grab press that takes it once a press would (GrabReach), never a second before its
## view shows the first; whether, of a profile that steals, it would charge a seat for the
## ring in its hands, once it would go for one itself; and how fast its cold drains in the
## sea with what it holds. Nothing here rolls the bot's stream.

var _seat: int
var _profile: BotProfile
var _rules: BrawlRules
var _layout: ShipLayout
## The lifebuoy it goes for, by its index in the layout's props, as the last think chose
## it; -1 for none.
var buoy := -1
## The tick of its last Grab press, or -1.
var _pressed_at := -1
## Whether, at the last think, it would go for a ring: buoy_from of her decks under water
## and its hands empty.
var _wanting := false


func _init(seat: int, profile: BotProfile, rules: BrawlRules, layout: ShipLayout) -> void:
	_seat = seat
	_profile = profile
	_rules = rules
	_layout = layout


## The kind of what the bot holds in [param seen], or null for empty hands.
func held_kind(seen: Dictionary) -> PropKind:
	var prop := PropState.held_in(seen, _seat)
	return _layout.props[prop].prop_kind() if prop != -1 else null


## Whether what it holds in [param seen] lets it brace.
func may_brace(seen: Dictionary) -> bool:
	return PropKind.lets_brace(held_kind(seen))


## The share of the open water's rate its cold drains at in the sea in [param seen]: less
## with a prop in its hands that keeps it afloat.
func drain(seen: Dictionary) -> float:
	return PropKind.sea_rate(held_kind(seen))


## Whether, its profile stealing and wanting a ring as its last think found it, it would
## charge [param victim] — a seat in [param seen] — for the prop in its hands a charge
## knocks loose.
func steals_from(seen: Dictionary, victim: Dictionary) -> bool:
	if not _profile.steals or not _wanting or PropState.held_in(seen, _seat) != -1:
		return false
	var prop := PropState.held_in(seen, victim["seat"])
	return prop != -1 and _layout.props[prop].prop_kind().loose_on_charge


## Picks the lifebuoy to go for at a think, from [param me] in [param seen] with
## [param under] of her decks under water under [param pose], among those [param found] — a
## search of [param graph] from where it stands — reaches, but for any a body's height or
## more nearer the sea than its own feet: it never goes down a deck toward the water for
## one. Returns its score, buoy_weight by [param under], or 0 with none to go for.
func choose(
	seen: Dictionary,
	me: Dictionary,
	found: WalkGraph.Search,
	graph: WalkGraph,
	under: float,
	pose: ShipPose
) -> float:
	buoy = -1
	_wanting = under >= _profile.buoy_from and PropState.held_in(seen, _seat) == -1
	if not _wanting or me["state"] != PlayerState.Body.GROUNDED or found.cost.is_empty():
		return 0.0
	var my_pos: Vector3 = me["pos"]
	var lowest := pose.above_water(my_pos) - _rules.body_height
	var nearest := _profile.buoy_range_m
	for entry: Dictionary in seen["props"]:
		if not PropState.within_grasp(entry["state"]):
			continue
		if not _layout.props[entry["prop"]].prop_kind().afloat:
			continue
		var stand := stand_by(entry)
		if pose.above_water(stand) < lowest:
			continue
		var zone := graph.zone_at(stand, graph.surfaces().under(stand, _rules.step_height))
		if zone == WalkGraph.NONE or found.cost[zone] == INF:
			continue
		var far := found.cost[zone] + Vector2(stand.x - my_pos.x, stand.z - my_pos.z).length()
		if far <= nearest:
			nearest = far
			buoy = entry["prop"]
	return _profile.buoy_weight * under if buoy != -1 else 0.0


## Where a body stands to take the prop [param entry] — a prop of a snapshot — describes:
## where it lies, or for one hung on a span, a body's radius in from it on its deck.
func stand_by(entry: Dictionary) -> Vector3:
	var pos: Vector3 = entry["pos"]
	if entry["state"] != PropState.Body.HUNG:
		return pos
	var inboard := -_layout.railing_outward(_layout.props[entry["prop"]].railing)
	return pos + Vector3(inboard.x, 0.0, inboard.y) * _rules.body_radius


## The prop [param seen] has as the lifebuoy it goes for, or empty: gone from where it
## was, taken by another, or none chosen.
func target(seen: Dictionary) -> Dictionary:
	if buoy == -1:
		return {}
	var entry: Dictionary = seen["props"][buoy]
	return entry if PropState.within_grasp(entry["state"]) else {}


## A Grab press on [param tick] when a press by the bot — [param me] in [param seen],
## carried to [param now_pos] and looking [param look] — would take the lifebuoy it goes
## for, as [param surfaces] has her; else nothing. None while its view predates its last.
func grab(
	seen: Dictionary, me: Dictionary, now_pos: Vector3, look: int, surfaces: Surfaces, tick: int
) -> int:
	if target(seen).is_empty() or seen["tick"] <= _pressed_at:
		return 0
	var player := PlayerState.from_dict(me)
	player.pos = now_pos
	player.facing = InputFrame.yaw_angle(look)
	var height := _rules.height_at(surfaces, now_pos)
	var props := PropState.from_snapshot(seen)
	if GrabReach.take(player, Faces.Up.DECK, height, props, _layout, _rules, surfaces) != buoy:
		return 0
	_pressed_at = tick
	return InputFrame.GRAB
