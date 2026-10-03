class_name BrawlRules
extends Resource
## The brawl's tuning (§6), authored in seconds, metres and degrees; the numbers
## live in data/rules/brawl.tres. Durations are converted to ticks once per match
## by Ticks; nothing here is read as a clock.

@export_group("Movement")
@export var walk_speed: float
@export var ground_accel: float
@export var ground_friction: float
@export var turn_rate_deg: float
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
## The speed a shover rocks back at when its shove lands.
@export var recoil: float
@export var stagger: float
## Friction while staggered, in m/s².
@export var stagger_friction: float


## Every reason these numbers cannot run a match; empty when they can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	for field: String in [
		"walk_speed",
		"ground_accel",
		"ground_friction",
		"turn_rate_deg",
		"body_radius",
		"body_height",
		"gravity",
		"shove_windup",
		"shove_active",
		"shove_reach",
		"knockback",
		"stagger",
		"stagger_friction",
	]:
		if float(get(field)) <= 0.0:
			found.append("brawl rules: %s must be positive" % field)
	for field: String in ["shove_recovery", "recoil"]:
		if float(get(field)) < 0.0:
			found.append("brawl rules: %s must not be negative" % field)
	for field: String in ["shove_cone_deg", "autoaim_cone_deg"]:
		if float(get(field)) < 0.0 or float(get(field)) > 180.0:
			found.append("brawl rules: %s must be within 0…180" % field)
	if restagger_mult < 1.0:
		found.append("brawl rules: restagger_mult must be at least 1")
	return found
