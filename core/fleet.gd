class_name Fleet
extends RefCounted
## The ships a match can be played on, by name (SH30): each one's layout and structure
## data/ships/NAME.tres, struck in her open-sea scenario data/sinking/NAME_open_sea.tres
## — or in another of hers, data/sinking/NAME_SETTING.tres, a coast's shallow water
## (SH32). The menu's ship picker, --ship, --scenario and the tools' SHIP= and SCENARIO=
## all ask here (D13); the match data names the default (MatchRules). A test-only ship
## (SH33) — a variant of one of the fleet's, NAME_VARIANT, under tests/fixtures/ships —
## plays by name, struck in her ship's open sea, and is never among names(): the menu
## never offers one.

const SHIPS := "res://data/ships"
const TEST_SHIPS := "res://tests/fixtures/ships/%s.tres"
const SCENARIOS := "res://data/sinking/%s.tres"
const OPEN_SEA := "res://data/sinking/%s_open_sea.tres"


## Every ship there is an open-sea scenario for, by name, in name order.
static func names() -> PackedStringArray:
	var found := PackedStringArray()
	for file: String in ResourceLoader.list_directory(SHIPS):
		var ship_name := file.get_basename()
		if file.get_extension() == "tres" and ResourceLoader.exists(OPEN_SEA % ship_name):
			found.append(ship_name)
	found.sort()
	return found


## The ship called [param ship_name] — of the fleet, or a test-only one; null when there
## is none.
static func layout(ship_name: StringName) -> ShipLayout:
	if names().has(String(ship_name)):
		return load("%s/%s.tres" % [SHIPS, ship_name]) as ShipLayout
	if _tested(ship_name):
		return load(TEST_SHIPS % ship_name) as ShipLayout
	return null


## Her open-sea scenario — a test-only ship's, her ship's; null when there is no ship
## called [param ship_name].
static func scenario(ship_name: StringName) -> SinkScenario:
	if names().has(String(ship_name)):
		return load(OPEN_SEA % ship_name) as SinkScenario
	if _tested(ship_name):
		return load(OPEN_SEA % ship_of(ship_name)) as SinkScenario
	return null


## Whether [param ship_name] is a test-only ship: a variant of a ship of the fleet's.
static func _tested(ship_name: StringName) -> bool:
	return not ship_of(ship_name).is_empty() and ResourceLoader.exists(TEST_SHIPS % ship_name)


## The scenario called [param scenario_name] — one of a ship's of the fleet, its name
## hers and the setting's (steamer_coast) — or null when the fleet has none.
static func setting(scenario_name: StringName) -> SinkScenario:
	if ship_of(scenario_name).is_empty() or not ResourceLoader.exists(SCENARIOS % scenario_name):
		return null
	return load(SCENARIOS % scenario_name) as SinkScenario


## The ship of the fleet whose scenario [param scenario_name] is, or empty for none.
static func ship_of(scenario_name: StringName) -> StringName:
	for ship_name: String in names():
		if String(scenario_name).begins_with(ship_name + "_"):
			return StringName(ship_name)
	return &""


## The name [param ship] goes by: her file's.
static func name_of(ship: ShipLayout) -> StringName:
	return StringName(ship.resource_path.get_file().get_basename())
