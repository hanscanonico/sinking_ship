class_name HitDamage
extends RefCounted
## What a match's iceberg hit does to her before any water moves (HitMapper, §5b.1):
## the gash's openings to the sea, the line it runs along her shell, the watertight
## walls it weakens, and which watertight doors will jam open and which openings that
## start shut were left open. Match data, like the hit: never in a snapshot (D5).
## Ship-local metres (D6).

## The gash's span along her within her hit zone; [member to_x] at or under
## [member from_x] when it misses the zone.
var from_x: float
var to_x: float
## One GASH opening per cell the gash crosses within its bite, in her cells' order.
var openings: Array[ShipOpening] = []
## Where the gash runs on her shell, aft to fore: where it is seen from outside.
var trace := PackedVector3Array()
## The watertight walls next to its ends, in her walls' order, and the share of their
## strength they keep.
var weakened: Array[StringName] = []
var weakened_to := 1.0
## The watertight doors that will jam open as the ship shuts them, and the openings
## that start shut but were left open — a porthole — each in her openings' order.
var jammed: Array[StringName] = []
var left_open: Array[StringName] = []


## The area the gash lets the sea in through, all its openings together, in m².
func area() -> float:
	var total := 0.0
	for opening: ShipOpening in openings:
		total += opening.area
	return total
