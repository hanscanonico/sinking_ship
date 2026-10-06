class_name FloodState
extends RefCounted
## The sinking physics' state at one moment (§5b.1): what SinkStepper takes in and
## gives back — never changed once given. Heave only until SH27: she floats level, so
## where the sea stands on her is her whole attitude. Match data like the timeline it
## is baked into, never in a snapshot (D5). Ship-local metres.

## Physics seconds since the hit, and the steps taken to get here.
var seconds := 0.0
var steps := 0
## Per cell, in her cells' order, the water in it, in m³, and how high it stands
## (SinkStepper.head) — for a full cell the step held, the head it pushed with.
var water := PackedFloat64Array()
var heads := PackedFloat64Array()
## The height of the sea up her: where a level sea stands in ship space.
var sea := 0.0
## The sea as an account (§5b.1): the water it has given her, less what it took back.
## Her water always adds up to it — water is never made or lost.
var sea_given := 0.0
## Per opening the stepper moves water through, in its order, what passed in the step
## that led here: positive from its first side to its second.
var moved := PackedFloat64Array()


## The total of her cells' water, in m³.
func total() -> float:
	var sum := 0.0
	for volume: float in water:
		sum += volume
	return sum


func copy() -> FloodState:
	var made := FloodState.new()
	made.seconds = seconds
	made.steps = steps
	made.water = water.duplicate()
	made.heads = heads.duplicate()
	made.sea = sea
	made.sea_given = sea_given
	made.moved = moved.duplicate()
	return made
