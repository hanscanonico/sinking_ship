class_name ViewKick
extends RefCounted
## The eyes' share of a hit (D14): a short kick when the seat they are in lands a
## shove or takes one, and a brief shake for a lurch. Both are an offset on the
## camera's rotation that decays to nothing — never written into the look, so the
## yaw a frame sends and the mouse's turning are untouched — and both are small and
## short against motion sickness (R15), scaled by ViewSettings' view_kick, 0 = off.
## Presentation only (D12): it reads snapshots and never holds the sim back.

## Landing a shove nods the view forward, this many degrees at the peak.
const LAND_DEG := 1.2
## Taking one tips the view the way the body is sent: back when shoved from the
## front, sideways when from the side, at most this many degrees.
const TAKE_DEG := 2.5
## A kick peaks this soon, then eases out to nothing at KICK_SECONDS.
const KICK_RISE := 0.03
const KICK_SECONDS := 0.2
## A lurch's shake at its strongest, and how long it lasts: well under half a second.
const SHAKE_DEG := 0.8
const SHAKE_SECONDS := 0.35
## The shake's wobble per axis, in hertz — pitch, yaw, roll — and how much of it
## turns the view sideways, the axis that most fights a mouse.
const SHAKE_HZ := Vector3(13.0, 9.0, 11.0)
const SHAKE_YAW_SHARE := 0.4

var _comfort: float
## Pitch, yaw and roll in radians at the current kick's peak.
var _kick := Vector3.ZERO
var _kick_age := INF
var _shake := 0.0
var _shake_age := INF
var _seat := -1
var _tick := -1


func _init(comfort: float = 1.0) -> void:
	_comfort = comfort


## Kicks for the shoves [param seat] landed or took on [param snapshot]'s tick, as
## seen along the ship-plane [param yaw]; once per tick. Switching seats never kicks.
func follow(snapshot: Dictionary, seat: int, yaw: float) -> void:
	var tick: int = snapshot["tick"]
	if seat != _seat:
		_seat = seat
		_tick = tick
		_kick_age = INF
		return
	if tick == _tick:
		return
	_tick = tick
	for event: Dictionary in snapshot["events"]:
		if event["kind"] != SimEvent.Kind.SHOVE_LANDED:
			continue
		if event["target"] == seat:
			var shover: Dictionary = snapshot["seats"][event["seat"]]
			take(angle_difference(yaw, shover["shove_facing"]))
		elif event["seat"] == seat:
			land()


## Your shove landed: the view nods forward.
func land() -> void:
	_start(Vector3(-deg_to_rad(LAND_DEG), 0.0, 0.0))


## You were shoved [param sent] radians round from where you look, toward
## starboard: the view tips that way.
func take(sent: float) -> void:
	var tip := Vector2.from_angle(sent) * deg_to_rad(TAKE_DEG)
	# Sent forward tips the view down; sent to the right rolls it right.
	_start(Vector3(-tip.x, 0.0, -tip.y))


## A lurch shakes the view, [param strength] 0…1. The ship's lurch event (SH6)
## calls this; a stronger lurch never shakes longer.
func shake(strength: float = 1.0) -> void:
	_shake = clampf(strength, 0.0, 1.0)
	_shake_age = 0.0


## Moves the effects on by [param delta] seconds; returns the offset now.
func advance(delta: float) -> Vector3:
	_kick_age += delta
	_shake_age += delta
	return offset()


## Pitch, yaw and roll in radians to add to the eyes' rotation: zero once every
## kick and shake has run out, or when the comfort setting is 0.
func offset() -> Vector3:
	var total := _kick * _kick_envelope(_kick_age)
	if _shake_age < SHAKE_SECONDS:
		var fade := 1.0 - _shake_age / SHAKE_SECONDS
		var wobble := Vector3(
			sin(TAU * SHAKE_HZ.x * _shake_age),
			sin(TAU * SHAKE_HZ.y * _shake_age + 1.3) * SHAKE_YAW_SHARE,
			sin(TAU * SHAKE_HZ.z * _shake_age + 2.1)
		)
		total += wobble * deg_to_rad(SHAKE_DEG) * _shake * fade * fade
	return total * _comfort


func _start(kick: Vector3) -> void:
	_kick = kick
	_kick_age = 0.0


## 0 → 1 over KICK_RISE, then easing back to exactly 0 at KICK_SECONDS.
static func _kick_envelope(age: float) -> float:
	if age < KICK_RISE:
		return age / KICK_RISE
	if age >= KICK_SECONDS:
		return 0.0
	var left := 1.0 - (age - KICK_RISE) / (KICK_SECONDS - KICK_RISE)
	return left * left
