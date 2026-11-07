extends GutTest
## The Titanic's rooms on her decks C to G stand inside her hull sections (#318): each
## section's shell, taken at its middle and held all along it, is cut fine enough where
## she tapers to stay within her structure's section_tolerance of her lines, which her
## plates' rooms follow. Held to a section cut from her middle out to a wide end, a room
## by her bow or her stern once stood past it by up to 1.66 m — her windlass machinery
## room — and the sea was drawn inside it.

const TITANIC := "res://data/ships/titanic.tres"
## Her decks C to G by their floors: G deck's, up to C deck's forward at her sheer.
const LOWEST_FLOOR := -11.0
const HIGHEST_FLOOR := 1.5625
## How far in from a room's floor and the deck over it its sides are read, and how far
## apart up them; and how far a section must run past a room's end to stand under it,
## clear of the hair her sections' rounded ends touch the next one by.
const UP_IN := 0.05
const UP_STEP := 0.25
const OVERLAP := 0.01


func test_every_room_on_decks_c_to_g_stands_inside_its_sections() -> void:
	var layout: ShipLayout = load(TITANIC)
	var tolerance := layout.structure.section_tolerance
	assert_gt(tolerance, 0.0, "her sections are cut to a tolerance")
	var space := ShipSpace.new(layout)
	var past := []
	var checked := 0
	for room: ShipRoom in layout.rooms:
		if room.floor_height < LOWEST_FLOOR - 1e-3 or room.floor_height > HIGHEST_FLOOR + 1e-3:
			continue
		checked += 1
		var found := _past_its_sections(layout.structure, space, room, tolerance)
		if not found.is_empty():
			past.append(found)
	assert_gt(checked, 1000, "her rooms on decks C to G")
	assert_eq(past, [], "rooms standing past their sections")


## Her windlass machinery room stays a room, where it stood past her sections most.
func test_her_windlass_machinery_room_is_a_room() -> void:
	var layout: ShipLayout = load(TITANIC)
	var found := 0
	for room: ShipRoom in layout.rooms:
		if room.name == &"windlass machinery room":
			found += 1
	assert_gt(found, 0, "her windlass machinery room")


## Where [param room] stands further past the shell of a section under it than
## [param tolerance], from its floor to the deck over it above that section, on either
## side it reaches; empty when it never does.
func _past_its_sections(
	structure: ShipStructure, space: ShipSpace, room: ShipRoom, tolerance: float
) -> String:
	var middle := room.area.get_center()
	for section: HullSection in structure.sections:
		var half := section.length * 0.5
		var from := maxf(room.area.position.x, section.x - half)
		var to := minf(room.area.end.x, section.x + half)
		if to - from < OVERLAP:
			continue
		# Up to the deck over it there, under her shell's top: her forecastle's step stands
		# over the windlass machinery room's after end, her fo'c'sle deck's lower.
		var top := space.ceiling(room, (from + to) * 0.5, middle.y) - UP_IN
		var y := room.floor_height + UP_IN
		while y <= top:
			for side: int in [1, -1]:
				var reach := room.area.end.y if side == 1 else -room.area.position.y
				if reach <= 0.0:
					continue
				var shell := section.shell_at(y, side)
				var held := 0.0 if is_nan(shell) else absf(shell)
				if reach - held > tolerance:
					return (
						"%s at x %.2f-%.2f, %.2f past the section at x %.3f, %.2f up"
						% [
							room.name,
							room.area.position.x,
							room.area.end.x,
							reach - held,
							section.x,
							y
						]
					)
			y += UP_STEP
	return ""
