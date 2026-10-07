class_name FloodState
extends RefCounted
## The sinking physics' state at one moment (§5b.1): what SinkStepper takes in and
## gives back — never changed once given. Match data like the timeline it is baked
## into, never in a snapshot (D5). Ship-local metres.

## Physics seconds since the hit, and the steps taken to get here.
var seconds := 0.0
var steps := 0
## Per cell, in her cells' order, the water in it, in m³, and how high it stands
## (SinkStepper.head) — for a full cell the step held, the head it pushed with.
var water := PackedFloat64Array()
var heads := PackedFloat64Array()
## Per cell, the air trapped in it as the m³ it would fill at the atmosphere's
## pressure, or SinkAir.FREE where its air is free (SinkAir).
var air := PackedFloat64Array()
## The height of the sea up her: how far along the world's up from her origin it
## stands (Hydrostatics.Sea).
var sea := 0.0
## Her attitude (Attitude): the rotation from ship space to the world, row by row.
var rotation := Attitude.level()
## How fast her centre of mass rises, in m/s, and she pitches — bow up — and rolls —
## starboard down — in radians a second (ShipMotion).
var heave_rate := 0.0
var pitch_rate := 0.0
var roll_rate := 0.0
## How hard a roll is pushed back, per radian, as a volume of sea times metres times g:
## at or under 0 she has lost her stability.
var roll_stiffness := 0.0
## The step the physics tries next, in seconds, and how far the highest point of her
## hull stands over the sea, under it when negative (SinkStepper.advance).
var next_step := 0.0
var above := INF
## The sea as an account (§5b.1): the water it has given her, less what it took back.
## Her water always adds up to it — water is never made or lost.
var sea_given := 0.0
## Per opening the stepper moves water through, in its order, what passed in the step
## that led here: positive from its first side to its second.
var moved := PackedFloat64Array()
## What has given way (SinkFailures, SH31): per opening, in the stepper's order, how far
## a failure has opened it — 0 for none, its leak's share of its area once it leaks, 1
## once it has given way, for good; and per funnel, 1 once it has fallen.
var opened := PackedFloat64Array()
var fallen := PackedByteArray()
## Her lights (ShipPower): whether her generator runs, her emergency power does or
## neither (ShipPower.Power); whether the sea has drowned the generator, for good; the
## seconds her emergency power has left, under 0 once spent; per cell, 1 once its water
## has reached its lamps, for good; and per cell what lights it now (ShipPower.Power).
var power := 0
var drowned := false
var battery := 0.0
var shorted := PackedByteArray()
var lit := PackedByteArray()
## Her bending at the station worst off against its strength (HullGirder): the share
## of that strength, positive hogging, negative sagging, and where along her.
var bending := 0.0
var bending_x := 0.0


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
	made.air = air.duplicate()
	made.sea = sea
	made.rotation = rotation.duplicate()
	made.heave_rate = heave_rate
	made.pitch_rate = pitch_rate
	made.roll_rate = roll_rate
	made.roll_stiffness = roll_stiffness
	made.next_step = next_step
	made.above = above
	made.sea_given = sea_given
	made.moved = moved.duplicate()
	made.opened = opened.duplicate()
	made.fallen = fallen.duplicate()
	made.power = power
	made.drowned = drowned
	made.battery = battery
	made.shorted = shorted.duplicate()
	made.lit = lit.duplicate()
	made.bending = bending
	made.bending_x = bending_x
	return made
