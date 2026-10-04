class_name RailingRemains
extends RefCounted
## What a broken railing span leaves (ShipArt): at each of its ends a splintered
## stub of the cap rail drooping from the post it hung on and the middle rail's end
## dangling over the side — or, where no other span shares that post, a splintered
## stump of it — and near one end a stanchion bent out over the side from its foot.
## Nothing reaches more than STUB into the span or stands inboard of its line, so
## nothing drawn seems to bar the gap the rules leave open. Drawn only, and shown
## only once the span is broken.

## How far into the span a stub reaches, at most, and at most this share of it.
const STUB := 0.35
const STUB_SHARE := 0.2
## How far the cap's stub droops, and the middle rail's end hangs, from level.
const DROOP := 0.35
const HANG := 1.1
const HANG_LENGTH := 0.45
## A post's stump, and the bent stanchion: how far it leans out past upright, and
## the share of the railing's height left of it.
const STUMP := 0.28
const BENT_LEAN := 0.95
const BENT_SHARE := 0.8
## The splinters at a broken end: how many, how long, how thick, how far they fan.
const SPLINTERS := 3
const SPLINTER := 0.16
const SPLINTER_WIDTH := 0.022
const SPLINTER_FAN := 0.45

var _layout: ShipLayout
## The rules' railing height, the rails' sections and the posts' side (ShipArt).
var _height: float
var _cap: Vector2
var _middle: Vector2
var _post: float


func _init(layout: ShipLayout, height: float, cap: Vector2, middle: Vector2, post: float) -> void:
	_layout = layout
	_height = height
	_cap = cap
	_middle = middle
	_post = post


## The remains of railing [param index] into [param mesh].
func build(mesh: ShipMesh, index: int) -> void:
	var railing := _layout.railings[index]
	var platform := _layout.platforms[railing.platform]
	var deck := platform.height
	var span := railing.to - railing.from
	var along := span.normalized()
	var outward := along.orthogonal()
	if (platform.area.get_center() - railing.from).dot(outward) > 0.0:
		outward = -outward
	var reach := minf(STUB, span.length() * STUB_SHARE)
	var out := Vector3(outward.x, 0.0, outward.y)
	for end in 2:
		var at := railing.from if end == 0 else railing.to
		var inward := along if end == 0 else -along
		var into := Vector3(inward.x, 0.0, inward.y)
		var foot := Vector3(at.x, deck, at.y)
		# A little twist per end, so no two breaks look stamped from one die.
		var twist := sin(index * 2.3 + end * 1.7)
		if _shared(index, at):
			_stub(mesh, foot, into, out, reach, twist)
		else:
			_stump(mesh, foot, into, twist)
	var base := (
		Vector3(railing.from.x, deck, railing.from.y) + Vector3(along.x, 0.0, along.y) * reach
	)
	_bent(mesh, base, out)


## The cap rail's stub drooping from the post at [param foot] into the span along
## [param into], splintered at its tip, and the middle rail's end hanging out over
## the side ([param out]).
func _stub(
	mesh: ShipMesh, foot: Vector3, into: Vector3, out: Vector3, reach: float, twist: float
) -> void:
	var droop := Basis(into.cross(Vector3.UP).normalized(), -DROOP * (1.0 + twist * 0.3))
	var direction := (droop * into).normalized()
	var root := foot + Vector3.UP * (_height - _cap.y * 0.5)
	var tip := root + direction * reach
	mesh.beam(root, tip, _cap, ShipPaints.teak, 0)
	_splinters(mesh, tip, direction, twist)
	var hang := (into * cos(HANG) * 0.4 + out * 0.5 + Vector3.DOWN * sin(HANG)).normalized()
	var start := foot + Vector3.UP * _height * 0.5
	mesh.beam(start, start + hang * HANG_LENGTH, _middle, ShipPaints.white, 0)


## A post snapped off at [param foot], splintered at its top.
func _stump(mesh: ShipMesh, foot: Vector3, into: Vector3, twist: float) -> void:
	var top := foot + Vector3.UP * STUMP * (1.0 + twist * 0.2)
	mesh.beam(foot, top, Vector2.ONE * _post, ShipPaints.white, 0)
	_splinters(mesh, top, (Vector3.UP + into * 0.3).normalized(), twist)


## A stanchion standing at [param base] bent out over the side ([param out]).
func _bent(mesh: ShipMesh, base: Vector3, out: Vector3) -> void:
	var knee := base + Vector3.UP * 0.12
	var lean := (Vector3.UP * cos(BENT_LEAN) + out * sin(BENT_LEAN)).normalized()
	var section := Vector2.ONE * _post
	mesh.beam(base, knee, section, ShipPaints.white, 0)
	mesh.beam(knee, knee + lean * _height * BENT_SHARE, section, ShipPaints.white, 0)


## Fresh splinters fanning out of a broken end at [param tip] along [param direction].
func _splinters(mesh: ShipMesh, tip: Vector3, direction: Vector3, twist: float) -> void:
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	for index in SPLINTERS:
		var fan := (index - (SPLINTERS - 1) * 0.5) * SPLINTER_FAN + twist * 0.2
		var bend := Basis(direction.cross(side).normalized(), fan)
		var way := (bend * direction).normalized()
		var length := SPLINTER * (0.7 + 0.3 * absf(sin(index * 1.9 + twist * 3.0)))
		var from := tip - direction * 0.03 + side * (index - 1) * SPLINTER_WIDTH
		mesh.beam(from, from + way * length, Vector2.ONE * SPLINTER_WIDTH, ShipPaints.splinter, 0)


## Whether another railing span at the same height ends at [param point], its post
## still standing when railing [param index] is gone.
func _shared(index: int, point: Vector2) -> bool:
	var height := _layout.platforms[_layout.railings[index].platform].height
	for other_index in _layout.railings.size():
		var other := _layout.railings[other_index]
		var level := _layout.platforms[other.platform].height
		if other_index == index or not is_equal_approx(level, height):
			continue
		if other.from.is_equal_approx(point) or other.to.is_equal_approx(point):
			return true
	return false
