class_name Fleet
extends RefCounted
## The ships a match can be played on, by name (SH30): each one's layout and structure
## data/ships/NAME.tres, struck in her open-sea scenario data/sinking/NAME_open_sea.tres.
## The menu's ship picker, --ship and the tools' SHIP= all ask here (D13); the match
## data names the default (MatchRules).

const SHIPS := "res://data/ships"
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


## The ship called [param ship_name]; null when the fleet has none.
static func layout(ship_name: StringName) -> ShipLayout:
	if not names().has(String(ship_name)):
		return null
	return load("%s/%s.tres" % [SHIPS, ship_name]) as ShipLayout


## Her open-sea scenario; null when the fleet has no ship called [param ship_name].
static func scenario(ship_name: StringName) -> SinkScenario:
	if not names().has(String(ship_name)):
		return null
	return load(OPEN_SEA % ship_name) as SinkScenario


## The name [param ship] goes by: her file's.
static func name_of(ship: ShipLayout) -> StringName:
	return StringName(ship.resource_path.get_file().get_basename())
