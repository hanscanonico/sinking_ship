class_name Seabed
extends RefCounted
## The bottom under her (§5b.1, SH32): a plane the scenario's depth under the still sea,
## level with the world. Where the lowest points of her hull — the corners of her
## sections' outlines: her keel, her bilges, her deck edges, the tops of her deckhouses
## — reach into it, it pushes each back like a stiff spring, seabed_contacts of them
## holding her whole weight sunk seabed_sink into it, critically damped so she settles on
## it rather than bouncing; and it drags on each as it slides across it, up to
## seabed_friction of that push — Coulomb's friction, eased to nothing at a standstill
## below EASED so a step of any length settles it. The push takes weight off her lift
## at her lowest points, which is why a hull aground is the less stable and rolls onto
## her side until a side or a deck edge rests on the bottom. ShipMotion adds it to the
## push on her, her stiffness and her damping in its one implicit step. Only +, −, ×, ÷
## and square roots on 64-bit floats run here (D4, R21). Ship-local metres, seconds;
## forces as volumes of sea, moments as volumes times metres, as ShipMotion's.

## Below this a contact point's speed across the bottom, in m/s, its friction eases off
## in proportion (est.: a centimetre a second).
const EASED := 0.01
## The share of critical damping on the contacts' springs (est.).
const DAMPING := 1.0

## What press() gives, by place: the push — heave, pitch, roll — then her stiffness and
## the friction's damping, each three by three, row by row.
enum Pressed { PUSH = 0, STIFFNESS = 3, DAMPING = 12, SIZE = 21 }

## How far under the still sea the bottom lies, in metres; each contact's push for a
## metre sunk into it, and the share of it friction can take.
var _depth: float
var _spring: float
var _friction: float
## Her contact points from her centre of mass, x, y, z each, and how far the farthest
## of them stands from it.
var _points := PackedFloat64Array()
var _reach := 0.0


## The bottom [param depth] under the still sea, under [param sea]'s constants, for a
## hull of [param own] m³ of sea's weight whose contact points [param points] (x, y, z
## each, ship space) stand about her centre of mass [param centre].
func _init(
	depth: float,
	own: float,
	sea: SeaPhysics,
	points: PackedFloat64Array,
	centre: PackedFloat64Array
) -> void:
	_depth = depth
	_spring = own / (sea.seabed_contacts * sea.seabed_sink)
	_friction = sea.seabed_friction
	for index in points.size() / 3:
		var x := points[index * 3] - centre[0]
		var y := points[index * 3 + 1] - centre[1]
		var z := points[index * 3 + 2] - centre[2]
		_points.append_array(PackedFloat64Array([x, y, z]))
		_reach = maxf(_reach, sqrt(x * x + y * y + z * z))


## Whether any of her points reaches into the bottom under [param rotation], her centre
## of mass [param rise] over the still sea.
func touches(rotation: PackedFloat64Array, rise: float) -> bool:
	if rise - _reach > -_depth:
		return false
	for index in _points.size() / 3:
		if _sunk(rotation, rise, index) > 0.0:
			return true
	return false


## The bottom's part of the step (Pressed's places) under [param rotation], her centre of
## mass [param rise] over the still sea and moving at [param rates] — heave, pitch,
## roll — with gravity [param g]: its push, as ShipMotion pushes; its stiffness, times g
## and negated as ShipMotion's is; and its friction's damping, times g, at the speed each
## point slides at now.
func press(
	rotation: PackedFloat64Array, rise: float, rates: PackedFloat64Array, g: float
) -> PackedFloat64Array:
	var made := PackedFloat64Array()
	made.resize(Pressed.SIZE)
	if rise - _reach > -_depth:
		return made
	var a_x := rotation[0]
	var a_y := rotation[3]
	var a_z := rotation[6]
	for index in _points.size() / 3:
		var sunk := _sunk(rotation, rise, index)
		if sunk <= 0.0:
			continue
		var x := _points[index * 3]
		var y := _points[index * 3 + 1]
		var z := _points[index * 3 + 2]
		# Where it stands from her centre along the world's axes: ahead, up, abeam.
		var q_x := Attitude.ahead(rotation, x, y, z)
		var q_y := rotation[3] * x + rotation[4] * y + rotation[5] * z
		var q_z := Attitude.abeam(rotation, x, y, z)
		var push := _spring * sunk
		# How the point rises as she heaves, pitches bow up and rolls starboard down.
		var lifts := PackedFloat64Array([1.0, q_x, a_z * q_x - a_x * q_z])
		for row in 3:
			made[Pressed.PUSH + row] += push * lifts[row]
			for column in 3:
				made[Pressed.STIFFNESS + row * 3 + column] += (
					g * _spring * lifts[row] * lifts[column]
				)
		# How it slides across the bottom, forward and athwartships, as she pitches and
		# rolls; the friction against it is a damping, eased below EASED.
		var forward := PackedFloat64Array([0.0, -q_y, a_y * q_z - a_z * q_y])
		var across := PackedFloat64Array([0.0, 0.0, a_x * q_y - a_y * q_x])
		var v_x := forward[1] * rates[1] + forward[2] * rates[2]
		var v_z := across[2] * rates[2]
		var speed := sqrt(v_x * v_x + v_z * v_z)
		var drag := g * _friction * push / maxf(speed, EASED)
		for row in 3:
			for column in 3:
				made[Pressed.DAMPING + row * 3 + column] += (
					drag * (forward[row] * forward[column] + across[row] * across[column])
				)
	return made


## How far point [param index] has sunk into the bottom under [param rotation], her
## centre of mass [param rise] over the still sea: under 0, clear of it.
func _sunk(rotation: PackedFloat64Array, rise: float, index: int) -> float:
	var height := (
		rise
		+ rotation[3] * _points[index * 3]
		+ rotation[4] * _points[index * 3 + 1]
		+ rotation[5] * _points[index * 3 + 2]
	)
	return -_depth - height
