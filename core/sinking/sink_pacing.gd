class_name SinkPacing
extends Resource
## How a sinking is paced in match time (Q20, decided 2026-10-18): the physics untouched,
## its seconds played faster or slower by how far she has flooded — her share of the most
## water she ever holds, which while she floats is the spare buoyancy she has lost. The
## opening, the middle and the end each take their share of the match's length; the
## plunge, the last of it, at least plunge_least; and the clock never runs slower than
## slowest or faster than fastest times the physics, where realism wins over the length.
## A scenario's clock (Fast sinking) plays the whole of it that many times quicker. The
## numbers live in data/rules/sink_pacing.tres; a scenario may carry its own.

const PATH := "res://data/rules/sink_pacing.tres"

## Where a share of her flooding stands: the opening, the middle, the end before the
## plunge, and the plunge.
enum Phase { OPENING, MIDDLE, END, PLUNGE }

## Match seconds from the hit to her going, the clock at 1.
@export var length: float
## Where her flooding share leaves the opening, the middle, and starts the plunge.
@export var opening_until: float
@export var middle_until: float
@export var plunge_from: float
## The shares of the length the opening and the middle take; the end takes the rest.
@export var opening_share: float
@export var middle_share: float
## The plunge's least match seconds.
@export var plunge_least: float
## Physics seconds per match second, at least and at most.
@export var slowest: float
@export var fastest: float


static func load_default() -> SinkPacing:
	return load(PATH)


## The paced clock of a sinking whose [param sunk] is the physics second she first holds
## each SinkTimeline.SUNK_STEPS-th of her water (SinkTimeline.sunk), -1 for never: each
## step its phase's share of the length, split evenly among the phase's steps — the
## plunge's at least plunge_least among them — at the pace that takes, held within
## slowest…fastest. Past the last step she reached, the clock keeps that step's pace; with
## no flooding recorded, it is the physics itself.
func clock_of(sunk: PackedFloat64Array) -> PacedClock:
	var clock := PacedClock.even()
	var steps := sunk.size()
	var counts := PackedInt32Array([0, 0, 0, 0])
	for step in steps:
		counts[_phase((step + 0.5) / steps)] += 1
	var shares := PackedFloat64Array([opening_share, middle_share, end_share(), end_share()])
	var end_steps := counts[Phase.END] + counts[Phase.PLUNGE]
	var before := 0.0
	for step in steps:
		if sunk[step] < 0.0:
			break
		var phase := _phase((step + 0.5) / steps)
		var among := end_steps if phase >= Phase.END else counts[phase]
		var wanted := length * shares[phase] / among
		if phase == Phase.PLUNGE:
			wanted = maxf(wanted, plunge_least / counts[Phase.PLUNGE])
		var physics := sunk[step] - before
		clock.add(physics, clampf(physics / wanted, slowest, fastest))
		before = sunk[step]
	return clock


## The share of the length the end, the plunge with it, takes: what the opening and the
## middle leave.
func end_share() -> float:
	return 1.0 - opening_share - middle_share


## The phase flooding share [param share] stands in.
func _phase(share: float) -> Phase:
	if share < opening_until:
		return Phase.OPENING
	if share < middle_until:
		return Phase.MIDDLE
	return Phase.END if share < plunge_from else Phase.PLUNGE


## Every reason this pacing cannot pace a sinking; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if length <= 0.0:
		found.append("pacing: the length must be over 0")
	if not (
		0.0 < opening_until
		and opening_until < middle_until
		and middle_until < plunge_from
		and plunge_from < 1.0
	):
		found.append("pacing: the phases' marks must rise within 0…1")
	if opening_share <= 0.0 or middle_share <= 0.0 or opening_share + middle_share >= 1.0:
		found.append("pacing: the shares must be over 0 and leave the end some")
	if slowest <= 0.0 or fastest < slowest:
		found.append("pacing: the limits must run from over 0 up")
	if plunge_least < 0.0:
		found.append("pacing: the plunge's least must not be negative")
	return found
