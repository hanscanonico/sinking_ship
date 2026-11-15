extends GutTest
## No body walks off a flight's open side and falls further than a step, on every ship of
## the fleet (#587), as on the Titanic (#574): every walk off each side of each of her
## flights at its quarters (ShipWalks), from where the walk graph reaches from her first
## spawn. The Titanic and her sisters are walked by test_titanic_shell_line, floors and all.
## A ship whose flights' sides are railed (tools/flight_rails.py) has none; the rest are
## held to what they had before theirs were (FALLS), so none gets more while they wait.

## Per ship with a flight, by its path: the most walks off a flight's side, set out beyond
## a body's breadth of its ends, that fall further than a step; and the most walks off one,
## its ends too, that fall more than a metre.
const FALLS := {
	"res://data/ships/small_titanic.tres": [0, 0],
	"res://data/ships/barque.tres": [8, 12],
	"res://data/ships/ferry.tres": [22, 16],
	"res://data/ships/freighter.tres": [32, 24],
	"res://data/ships/steamer.tres": [28, 14],
	"res://data/ships/trawler.tres": [6, 12],
	"res://data/ships/tug.tres": [2, 4],
}

## Per ship of FALLS, by its path: what went wrong on its flights' walks.
var _walked_on := {}


func before_all() -> void:
	var walks := ShipWalks.new()
	for path: String in FALLS:
		_walked_on[path] = walks.gone_wrong(load(path), false)


func test_no_ship_has_more_walks_off_her_flights_sides_past_a_step() -> void:
	for path: String in FALLS:
		var falls := ShipWalks.off_sides_past_a_step(_walked_on[path])
		gut.p("%s: %d past a step" % [path, falls.size()])
		assert_lte(falls.size(), int(FALLS[path][0]), "%s\n%s" % [path, "\n".join(falls)])


func test_no_ship_has_more_walks_off_her_flights_sides_past_a_metre() -> void:
	for path: String in FALLS:
		var falls := ShipWalks.off_sides_past_a_metre(_walked_on[path])
		gut.p("%s: %d past a metre" % [path, falls.size()])
		assert_lte(falls.size(), int(FALLS[path][1]), "%s\n%s" % [path, "\n".join(falls)])


func test_every_ship_of_the_fleet_is_walked() -> void:
	var dir := DirAccess.open("res://data/ships")
	for file in dir.get_files():
		var path := "res://data/ships/" + file.trim_suffix(".remap")
		if path.ends_with(".tres") and not path.ends_with("/titanic.tres"):
			var layout: ShipLayout = load(path)
			assert_true(FALLS.has(path) or layout.ramps.is_empty(), path)
