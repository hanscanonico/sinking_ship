class_name BrawlRules
extends Resource
## The brawl's tuning (§6), authored in seconds, metres and degrees; the numbers
## live in data/rules/brawl.tres. Durations are converted to ticks once per match
## by Ticks; nothing here is read as a clock.

@export_group("Movement")
@export var walk_speed: float
@export var ground_accel: float
@export var ground_friction: float
@export var body_radius: float
@export var body_height: float
@export var gravity: float

@export_group("Shove")
@export var shove_windup: float
@export var shove_active: float
@export var shove_recovery: float
## How far beyond the two bodies' edges a shove reaches, in metres.
@export var shove_reach: float
## Half-angle of the cone a shove lands in.
@export var shove_cone_deg: float
## Half-angle of the cone facing snaps to a target in, at windup start.
@export var autoaim_cone_deg: float
@export var knockback: float
## Knockback on a body that is already staggered is multiplied by this.
@export var restagger_mult: float
## The speed a shover rocks back at when its shove lands, once however many bodies
## it lands on.
@export var recoil: float
@export var stagger: float
## How long a landed quick shove freezes its shover and its target (D12).
@export var hitstop: float
## A full charge's hit-stop; a charge let go sooner stops between hitstop and this.
@export var hitstop_charged: float
## The hit-stop of a shove a front brace takes the edge off: short, a clang.
@export var hitstop_braced: float
## Friction while staggered, in m/s².
@export var stagger_friction: float

@export_group("Slope and railings")
## The combined deck slope a body standing idle holds at; past it, the deck pulls.
@export var grip_angle_deg: float
## Friction on an idle body sliding past the grip angle, in m/s².
@export var slide_friction: float
## Crossing a railing at this speed or faster tips a body over it.
@export var vault_speed: float
## The upward speed a body tips over a railing with.
@export var vault_lift: float
## How high a railing stands above its platform.
@export var railing_height: float

@export_group("Levels and falls")
## The most a body steps up or down without a ramp; a drop deeper than this is a fall.
@export var step_height: float
## Seconds of stagger on landing, per metre fallen.
@export var fall_stagger_per_m: float

@export_group("Jump")
## How high a jump lifts the feet above where it left the ground, in metres: onto
## a hatch, never over a railing.
@export var jump_height: float
## The share of ground_accel a jumper steers with in the air; 0…1.
@export var air_control: float
## Stamina a jump spends as it leaves the ground; a jump needs this much to start.
@export var jump_cost: float

@export_group("Brace, charge and stamina")
## The share of a shove's knockback a brace takes off, when the shove comes into
## its front arc and is not a full charge; 0…1.
@export var brace_reduction: float
## Half-angle of a brace's front arc, around its facing.
@export var brace_arc_deg: float
## Stamina a brace spends per second.
@export var brace_drain: float
## Holding shove this long, from the press, turns it into a charge.
@export var charge_threshold: float
## Held this long, from the press, a charge is full.
@export var charge_full: float
## A full charge's knockback; a charge released sooner sends between knockback and this.
@export var charged_knockback: float
## The most a charging body walks at, in m/s.
@export var charge_walk: float
## Stamina a charged shove spends on release; a charge needs this much to start.
@export var charge_cost: float
@export var stamina_max: float
## Stamina regained per second, once the regen delay has passed.
@export var stamina_regen: float
## Seconds after spending before stamina starts to come back.
@export var stamina_regen_delay: float

@export_group("The sea")
## How fast a swimmer moves, in m/s.
@export var swim_speed: float
## How far under the sea a floating swimmer's feet hang: its eye rides just above.
@export var swim_depth: float
## How hard the water slows a body that drops into it, in m/s²: a fall in dunks
## it under before it floats back up.
@export var dunk_drag: float
## The speed the water floats a dunked body back up at, in m/s.
@export var float_speed: float
## Water shallower than this over the feet is wading, not swimming.
@export var wade_depth: float
## A swimmer finds its feet where the water over the bottom is shallower than this:
## below wade_depth, so that a body at the waterline does not flicker between the two.
@export var stand_depth: float
## The fastest a body wades, in m/s.
@export var wade_speed: float
## Seconds of swimming a full cold meter holds.
@export var cold_meter: float
## Seconds of the cold meter regained per second out of the sea.
@export var cold_regen: float
## The share of the open water's rate the cold meter drains at while a swimmer's head is
## in trapped air — a pocket under a ceiling (Q22, est. a quarter: the 4 s meter lasts
## 16 s there). It never refills while swimming, so every match still ends.
@export var pocket_cold_rate: float
## The highest a ledge may stand above the sea for a swimmer to climb onto it.
@export var climb_reach: float
## How long a climb out takes.
@export var climb_time: float
## How fast a swimmer goes up a ladder, in m/s; a ladder's climb never takes less
## than climb_time.
@export var ladder_speed: float
## Seconds off the cold meter for a climber shoved back in.
@export var climb_penalty: float
## A shove that lands this long or longer before its target goes into the sea is
## not credited with its going out.
@export var credit_window: float

@export_group("Cargo and railing damage")
## A brawler's mass in kilograms, what a crate's (ShipProp.mass) is weighed against.
@export var body_mass: float
## A crate closing on a brawler this fast or faster staggers it and knocks it back;
## slower, it pushes it.
@export var crate_impact_speed: float
## How much of the closing speed a crate and a brawler it staggers part with; 0…1. A
## push shares the speed, as with none.
@export var crate_restitution: float
## The least a crate at crate_impact_speed or more sends a brawler at, in m/s: a laden
## crate bowls a body over as a shove does, however slow it came.
@export var crate_knockback: float
## The share of a crate's knockback a brace takes off when the crate comes into its
## front arc; 0…1. Cargo is not a person: a braced body is still staggered.
@export var crate_brace_reduction: float
## The hits a railing span takes before it breaks and holds nothing.
@export var railing_hp: float
## A crate crossing a railing span this fast or faster damages it by crate_damage.
@export var railing_break_speed: float
## What a vault over a span takes off it.
@export var vault_damage: float
## What a crate at railing_break_speed or more takes off a span.
@export var crate_damage: float


## How far over its feet a swimmer's head is reckoned, for whether it is in trapped air
## (Q22): halfway from the waterline it floats at, swim_depth, to the top of its head.
func head_height() -> float:
	return (swim_depth + body_height) * 0.5


## Every reason these numbers cannot run a match; empty when they can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	for field: String in [
		"walk_speed",
		"ground_accel",
		"ground_friction",
		"body_radius",
		"body_height",
		"gravity",
		"shove_windup",
		"shove_active",
		"shove_reach",
		"knockback",
		"stagger",
		"stagger_friction",
		"slide_friction",
		"vault_speed",
		"railing_height",
		"step_height",
		"brace_drain",
		"charge_threshold",
		"charge_walk",
		"stamina_max",
		"stamina_regen",
		"jump_height",
		"swim_speed",
		"swim_depth",
		"dunk_drag",
		"float_speed",
		"wade_depth",
		"stand_depth",
		"wade_speed",
		"cold_meter",
		"cold_regen",
		"pocket_cold_rate",
		"climb_reach",
		"climb_time",
		"ladder_speed",
		"body_mass",
		"crate_impact_speed",
		"crate_knockback",
		"railing_hp",
		"railing_break_speed",
	]:
		if float(get(field)) <= 0.0:
			found.append("brawl rules: %s must be positive" % field)
	for field: String in [
		"shove_recovery",
		"recoil",
		"vault_lift",
		"fall_stagger_per_m",
		"charge_cost",
		"stamina_regen_delay",
		"hitstop",
		"hitstop_braced",
		"jump_cost",
		"climb_penalty",
		"credit_window",
		"vault_damage",
		"crate_damage",
	]:
		if float(get(field)) < 0.0:
			found.append("brawl rules: %s must not be negative" % field)
	for field: String in ["shove_cone_deg", "autoaim_cone_deg", "brace_arc_deg"]:
		if float(get(field)) < 0.0 or float(get(field)) > 180.0:
			found.append("brawl rules: %s must be within 0…180" % field)
	if restagger_mult < 1.0:
		found.append("brawl rules: restagger_mult must be at least 1")
	if grip_angle_deg <= 0.0 or grip_angle_deg >= 90.0:
		found.append("brawl rules: grip_angle_deg must be within 0…90")
	elif gravity * sin(deg_to_rad(grip_angle_deg)) <= slide_friction:
		found.append("brawl rules: slide_friction must be below the pull at the grip angle")
	if step_height >= body_height:
		found.append("brawl rules: step_height must be below body_height")
	if brace_reduction < 0.0 or brace_reduction > 1.0:
		found.append("brawl rules: brace_reduction must be within 0…1")
	for field: String in ["air_control", "crate_restitution", "crate_brace_reduction"]:
		if float(get(field)) < 0.0 or float(get(field)) > 1.0:
			found.append("brawl rules: %s must be within 0…1" % field)
	# A railing must hold a jumper, so a perch keeps its defence.
	if jump_height >= railing_height:
		found.append("brawl rules: jump_height must be below railing_height")
	# Compared in ticks, as the sim counts them: a threshold that rounds onto the
	# windup would make every held tap a charge.
	var threshold_ticks := Ticks.from_seconds(charge_threshold)
	if threshold_ticks <= Ticks.from_seconds(shove_windup):
		found.append("brawl rules: charge_threshold must be more ticks than shove_windup")
	if Ticks.from_seconds(charge_full) <= threshold_ticks:
		found.append("brawl rules: charge_full must be more ticks than charge_threshold")
	if charged_knockback < knockback:
		found.append("brawl rules: charged_knockback must be at least knockback")
	if hitstop_charged < hitstop:
		found.append("brawl rules: hitstop_charged must be at least hitstop")
	if charge_walk > walk_speed:
		found.append("brawl rules: charge_walk must not exceed walk_speed")
	if charge_cost > stamina_max:
		found.append("brawl rules: charge_cost must not exceed stamina_max")
	if jump_cost > stamina_max:
		found.append("brawl rules: jump_cost must not exceed stamina_max")
	# A swimmer's head rides above the sea, and wading is shallower than swimming.
	if swim_depth >= body_height:
		found.append("brawl rules: swim_depth must be below body_height")
	if wade_depth >= swim_depth:
		found.append("brawl rules: wade_depth must be below swim_depth")
	if stand_depth > wade_depth:
		found.append("brawl rules: stand_depth must not exceed wade_depth")
	if pocket_cold_rate > 1.0:
		found.append("brawl rules: pocket_cold_rate must not exceed the open water's 1")
	if wade_speed > walk_speed:
		found.append("brawl rules: wade_speed must not exceed walk_speed")
	return found
