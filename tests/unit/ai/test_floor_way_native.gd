extends GutTest
## A bot's search for a way round by the floor in the game's extension
## (NativeSurfaces.floor_way, #410) against BotFloorWay's own GDScript, bit for bit: from
## every kind of start to every kind of portal on her ships — through a door, onto a stair
## and off one, ways found and none — as the bot asks it, every point of every way the
## same, and the same none. The extension's Surfaces.under, which it asks per square, is
## held to the GDScript in test_contacts_native. Where the extension is not loaded there
## is nothing to hold it to; CI sets SINKING_NATIVE_REQUIRED, so a missing library there
## fails.

const STEAMER := "res://data/ships/steamer.tres"
const TITANIC := "res://data/ships/titanic.tres"
## The Titanic's G deck aft of O (test_bot_floor_way): the stair foot a way round leaves
## from, and the door aft behind both stairs.
const G_DECK_STAIR_FOOT := Vector3(-110.6, -11.0, 0.3)
const G_DECK_PAST_THE_DOOR := Vector3(-117.5, -11.0, 1.2)
## How many tries at a start and a portal far apart deep searches are looked for in, and how
## many of each kind found are searched both ways.
const DEEP_TRIES := 20000
const DEEP_ASKED := 2
## How many portals of a ship are searched to, and from how many starts each.
const PORTALS := 24
const STARTS := 3

var _rng := RandomNumberGenerator.new()
var _differences: Array[String] = []
var _found := 0
var _none := 0


func before_each() -> void:
	_rng.seed = 410
	_differences.clear()
	_found = 0
	_none = 0
	ContactsNative.off = false


func after_each() -> void:
	ContactsNative.off = false


func test_the_g_deck_way_round_its_stairs_is_found_alike() -> void:
	if not _loaded():
		return
	var ways := _ways(load(TITANIC))
	var graph: WalkGraph = ways[0]
	var step := SimFixtures.rules().step_height
	var surfaces := graph.surfaces()
	var out_of := graph.zone_at(G_DECK_STAIR_FOOT, surfaces.under(G_DECK_STAIR_FOOT, step))
	var into := graph.zone_at(G_DECK_PAST_THE_DOOR, surfaces.under(G_DECK_PAST_THE_DOOR, step))
	var asked := 0
	for portal: WalkGraph.Portal in graph.portals():
		if portal.from_zone == out_of and portal.to_zone == into:
			_ask(ways, G_DECK_STAIR_FOOT, portal)
			asked += 1
	assert_eq(asked, 1, "the door aft of the passage")
	assert_eq(_found, 1, "a way round its stairs")
	_assert_none("the G deck passage")


## Ways round on the Titanic found only after more than half the squares a search may settle
## have settled, as the GDScript counts them, and searches that settle them all and give up:
## where the search gives up counts.
func test_ways_found_deep_in_their_search_are_found_alike() -> void:
	if not _loaded():
		return
	var ways := _ways(load(TITANIC))
	var graph: WalkGraph = ways[0]
	var native: BotFloorWay = ways[1]
	var twin: BotFloorWay = ways[2]
	var surfaces := graph.surfaces()
	var step := SimFixtures.rules().step_height
	var halved := native._native_rules.duplicate()
	halved[2] = BotFloorWay.MOST / 2
	var portals := graph.portals()
	var deep := 0
	var given_up := 0
	for _try in DEEP_TRIES:
		var portal: WalkGraph.Portal = portals[_rng.randi_range(0, portals.size() - 1)]
		var off := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(4.0, 30.0)
		var from := portal.entry + Vector3(off.x, 0.0, off.y)
		var under := surfaces.under(from, step)
		if under == Surfaces.NONE:
			continue
		var keep := PackedInt32Array([under])
		if portal.ramp != WalkGraph.NONE:
			keep.append(surfaces.ramp_surface(portal.ramp))
		# Only those the extension, given half as many, finds no way for, to spare the
		# GDScript most of the tries.
		var short: PackedVector3Array = surfaces.native.floor_way(from, portal.entry, keep, halved)
		if not short.is_empty():
			continue
		var theirs := twin._find(from, portal, keep)
		if not theirs.is_empty() and twin._settled > BotFloorWay.MOST / 2 and deep < DEEP_ASKED:
			deep += 1
		elif theirs.is_empty() and twin._settled == BotFloorWay.MOST and given_up < DEEP_ASKED:
			given_up += 1
		else:
			continue
		_ask(ways, from, portal)
		if deep == DEEP_ASKED and given_up == DEEP_ASKED:
			break
	assert_eq(deep, DEEP_ASKED, "ways found deep in their search")
	assert_eq(given_up, DEEP_ASKED, "searches giving up")
	_assert_none("deep in the search")


func test_her_ships_ways_round_are_found_alike() -> void:
	if not _loaded():
		return
	for path: String in [STEAMER, TITANIC]:
		var ways := _ways(load(path))
		var graph: WalkGraph = ways[0]
		var portals := graph.portals()
		for _pick in PORTALS:
			var portal: WalkGraph.Portal = portals[_rng.randi_range(0, portals.size() - 1)]
			for from: Vector3 in _starts(graph, portal):
				_ask(ways, from, portal)
		_assert_none(path)
	assert_gt(_found, 0, "some ways round found")
	assert_gt(_none, 0, "and some searches finding none")


## [param layout]'s walk graph, with two searches over it: one asking the extension, and its
## twin over a Surfaces of its own that answers in GDScript.
func _ways(layout: ShipLayout) -> Array:
	var rules := SimFixtures.rules()
	var graph := WalkGraph.new(layout, Surfaces.new(layout), rules)
	assert_not_null(graph.surfaces().native, "the native Surfaces asks the extension")
	var native := BotFloorWay.new(graph, rules, 1)
	ContactsNative.off = true
	var twin := BotFloorWay.new(graph, rules, 1)
	twin._surfaces = Surfaces.new(layout)
	ContactsNative.off = false
	assert_null(twin._surfaces.native, "its twin answers in GDScript")
	return [graph, native, twin]


## Where a bot might stand going through [param portal]: the entries of up to STARTS - 1
## other ways into the zone it leaves, and a point on a floor a few metres off its own entry
## and one far off.
func _starts(graph: WalkGraph, portal: WalkGraph.Portal) -> Array[Vector3]:
	var found: Array[Vector3] = []
	var surfaces := graph.surfaces()
	var step := SimFixtures.rules().step_height
	for other: WalkGraph.Portal in graph.portals():
		if found.size() >= STARTS - 1:
			break
		if other.to_zone == portal.from_zone and other != portal and _rng.randf() < 0.5:
			found.append(other.entry)
	# Near it, and far: a search far from its portal settles its most squares and gives up.
	for reach: float in [6.0, 24.0]:
		for _try in 8:
			var off := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(1.0, reach)
			var at := portal.entry + Vector3(off.x, 0.0, off.y)
			if surfaces.under(at, step) != Surfaces.NONE:
				found.append(at)
				break
	return found


## Searches for a way from [param from] to [param portal]'s entry both ways, as the bot asks
## (BotFloorWay._look): kept to the floor under it, and the portal's own stair.
func _ask(ways: Array, from: Vector3, portal: WalkGraph.Portal) -> void:
	var graph: WalkGraph = ways[0]
	var native: BotFloorWay = ways[1]
	var twin: BotFloorWay = ways[2]
	var surfaces := graph.surfaces()
	var keep := PackedInt32Array([surfaces.under(from, SimFixtures.rules().step_height)])
	if portal.ramp != WalkGraph.NONE:
		keep.append(surfaces.ramp_surface(portal.ramp))
	var mine := native._find(from, portal, keep)
	var theirs := twin._find(from, portal, keep)
	if theirs.is_empty():
		_none += 1
	else:
		_found += 1
	if var_to_bytes(mine) != var_to_bytes(theirs):
		_differences.append(
			(
				"from %s to %s (keeping %s): %d points, not %d"
				% [from, portal.entry, keep, mine.size(), theirs.size()]
			)
		)


func _assert_none(what: String) -> void:
	assert_eq(
		_differences,
		[] as Array[String],
		"%s finds alike (%d found, %d none)" % [what, _found, _none]
	)


func _loaded() -> bool:
	if ClassDB.class_exists(&"NativeCrates"):
		return true
	if OS.get_environment("SINKING_NATIVE_REQUIRED") == "1":
		fail_test("the extension is not loaded: make native, then make import")
	else:
		pending("the extension is not built here (make native)")
	return false
