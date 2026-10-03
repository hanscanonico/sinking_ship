class_name PlayerState
extends RefCounted
## One seat's body and timers. Every field here is in the snapshot (D5): a field
## that affects the future and is missing from to_dict() is a continuation bug.

enum Body { GROUNDED, AIRBORNE, OUT }
enum Action { IDLE, WINDUP, ACTIVE, RECOVERY }
enum Cause { NONE, WATER }

var seat: int
## Ship-local; y is the feet's height above the main deck.
var pos: Vector3
var vel: Vector3
## Radians in the ship plane, measured from +x (the bow) toward +z (starboard):
## the look yaw of the last frame applied (D14).
var facing: float
var body: Body = Body.GROUNDED
var surface: int = Surfaces.NONE
## While airborne, the highest the feet have been since leaving a surface: a
## landing staggers by the drop from here.
var fall_from: float
var action: Action = Action.IDLE
## Ticks spent in the current action phase.
var action_ticks: int
## Whether this shove's active window has already landed.
var shove_spent: bool
## Where this shove goes, in the facing's radians: set as its active window starts.
var shove_facing: float
var stagger_ticks: int
## The seat whose shove last landed on this one, until this body moves under its
## own input again; -1 otherwise.
var last_hit_by: int = -1
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
		"action": action,
		"action_ticks": action_ticks,
		"shove_spent": shove_spent,
		"shove_facing": shove_facing,
		"stagger": stagger_ticks,
		"last_hit_by": last_hit_by,
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
	player.action = entry["action"]
	player.action_ticks = entry["action_ticks"]
	player.shove_spent = entry["shove_spent"]
	player.shove_facing = entry["shove_facing"]
	player.stagger_ticks = entry["stagger"]
	player.last_hit_by = entry["last_hit_by"]
	player.prev_buttons = entry["prev_buttons"]
	var last_input: Array = entry["last_input"]
	player.last_move = Vector2i(last_input[0], last_input[1])
	player.last_look = last_input[2]
	player.last_buttons = last_input[3]
	return player
