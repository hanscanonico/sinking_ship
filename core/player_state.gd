class_name PlayerState
extends RefCounted
## One seat's body and timers. Every field here is in the snapshot (D5): a field
## that affects the future and is missing from to_dict() is a continuation bug.

## SWIMMING: in the sea (SH5), climbing out of it while climb_left counts down.
enum Body { GROUNDED, AIRBORNE, SWIMMING, OUT }
## CHARGE: the shove held past charge_threshold, until it is released.
enum Action { IDLE, WINDUP, ACTIVE, RECOVERY, CHARGE }
enum Cause { NONE, COLD }

var seat: int
## Ship-local; y is the feet's height above the main deck.
var pos: Vector3
var vel: Vector3
## Radians in the ship plane, measured from +x (the bow) toward +z (starboard):
## the look yaw of the last frame applied (D14).
var facing: float
var body: Body = Body.GROUNDED
var surface: int = Surfaces.NONE
## While airborne, the highest the feet have been since leaving a surface — or,
## after a jump, the height it left from: a landing staggers by the drop from here.
var fall_from: float
## Whether this time in the air began with a jump: it steers a little, and its
## landing forgives the jump's own height.
var jumped: bool
var action: Action = Action.IDLE
## Ticks spent in the current action phase.
var action_ticks: int
## Whether this shove's active window has already landed.
var shove_spent: bool
## Where this shove goes, in the facing's radians: set as its active window starts.
var shove_facing: float
## Ticks the shove was held for, from the press, once it became a charge (capped at
## charge_full); kept through the charged shove's active window, 0 otherwise.
var charge: int
## Planted: rooted, and a shove into the front arc loses brace_reduction.
var bracing: bool
var stamina: float
## Ticks left before stamina starts to come back.
var stamina_wait: int
## Run dry: no brace and no charge until stamina is full again.
var exhausted: bool
var stagger_ticks: int
## Ticks left frozen in a hit-stop: the body holds still and nothing it does or
## spends moves on, though its look still turns it (D12).
var hitstop: int
## The velocity a hit-stop holds back, handed back as the stop ends.
var held_vel: Vector3
## Seconds of swimming left before the cold puts the seat out.
var cold: float
## Ticks of a climb out of the sea left; 0 when not climbing.
var climb_left: int
## Where the climb puts the feet, standing.
var climb_to: Vector3
## The seat whose shove last landed on this one, until this body moves under its
## own input again on deck — through a swim, until it regains one; -1 otherwise.
var last_hit_by: int = -1
## The tick that shove landed on, or -1.
var last_hit_at: int = -1
## 0 while still in; the shared finishing place once out.
var place: int
var out_tick: int = -1
var out_cause: Cause = Cause.NONE
var prev_buttons: int
## The last frame applied, repeated when a tick's frame is missing.
var last_move: Vector2i
var last_look: int
var last_buttons: int


func _init(seat_id: int = 0) -> void:
	seat = seat_id


func is_out() -> bool:
	return body == Body.OUT


func is_staggered() -> bool:
	return stagger_ticks > 0


func is_charged() -> bool:
	return charge > 0


func is_frozen() -> bool:
	return hitstop > 0


func is_climbing() -> bool:
	return climb_left > 0


func to_dict() -> Dictionary:
	return {
		"seat": seat,
		"out": is_out(),
		"place": place,
		"out_tick": out_tick,
		"out_cause": out_cause,
		"pos": pos,
		"vel": vel,
		"facing": facing,
		"surface": surface,
		"state": body,
		"fall_from": fall_from,
		"jumped": jumped,
		"action": action,
		"action_ticks": action_ticks,
		"shove_spent": shove_spent,
		"shove_facing": shove_facing,
		"charge": charge,
		"bracing": bracing,
		"stamina": stamina,
		"stamina_wait": stamina_wait,
		"exhausted": exhausted,
		"stagger": stagger_ticks,
		"hitstop": hitstop,
		"held_vel": held_vel,
		"cold": cold,
		"climb": climb_left,
		"climb_to": climb_to,
		"last_hit_by": last_hit_by,
		"last_hit_at": last_hit_at,
		"prev_buttons": prev_buttons,
		"last_input": [last_move.x, last_move.y, last_look, last_buttons],
	}


static func from_dict(entry: Dictionary) -> PlayerState:
	var player := PlayerState.new(entry["seat"])
	player.place = entry["place"]
	player.out_tick = entry["out_tick"]
	player.out_cause = entry["out_cause"]
	player.pos = entry["pos"]
	player.vel = entry["vel"]
	player.facing = entry["facing"]
	player.surface = entry["surface"]
	player.body = entry["state"]
	player.fall_from = entry["fall_from"]
	player.jumped = entry["jumped"]
	player.action = entry["action"]
	player.action_ticks = entry["action_ticks"]
	player.shove_spent = entry["shove_spent"]
	player.shove_facing = entry["shove_facing"]
	player.charge = entry["charge"]
	player.bracing = entry["bracing"]
	player.stamina = entry["stamina"]
	player.stamina_wait = entry["stamina_wait"]
	player.exhausted = entry["exhausted"]
	player.stagger_ticks = entry["stagger"]
	player.hitstop = entry["hitstop"]
	player.held_vel = entry["held_vel"]
	player.cold = entry["cold"]
	player.climb_left = entry["climb"]
	player.climb_to = entry["climb_to"]
	player.last_hit_by = entry["last_hit_by"]
	player.last_hit_at = entry["last_hit_at"]
	player.prev_buttons = entry["prev_buttons"]
	var last_input: Array = entry["last_input"]
	player.last_move = Vector2i(last_input[0], last_input[1])
	player.last_look = last_input[2]
	player.last_buttons = last_input[3]
	return player
