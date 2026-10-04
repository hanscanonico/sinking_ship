class_name ShipHull
extends RefCounted
## The hull, lofted round the decks (ShipArt) as a steamer's: a section at every
## station along the ship, from its decks' edge at the sheer down round the bilge to
## the keel, clear of everything inside it, and fine at the ends, where its
## waterlines taper to a raked stem with a forefoot and to a rounded counter stern
## over the sternpost. A step in the sheer or the beam ends one run of the loft and
## starts the next, joined by the step between their sections. Nowhere does it stand
## wider than the deck edge over it, so a body going over the side falls clear.
## Past each end of the decks — beyond the end railing, where nobody stands — it
## falls away from the deck line: a turtleback bow, steep from the deck's edge down
## to a plumb stem head, anchors in its hawses, and a rounded counter down to its
## knuckle. Nothing there stands above the deck or turns up like a floor, so a body
## going over an end railing, or through a broken span of it, falls past steel that
## drops away under it. A jackstaff and an ensign staff stand on the end railings'
## middle spans. A teak toe rail runs round the sheer; a keel, a rudder and a bronze
## propeller hang under the counter. Its paint (ship.gdshaderinc) is dark above the
## boot line, red oxide below, with a pale riband under the sheer.

## How far the keel reaches below the waterline of a level, unsunk ship, and how far
## it stays below anything inside the hull.
const DRAFT := 2.0
const KEEL_CLEARANCE := 0.4
## How far the hull stands clear of what is inside it, and how fast that need falls
## off with the distance fore or aft of it and under it, in metres per metre.
const CONTENT_CLEARANCE := 0.12
const CONTENT_FALL := Vector2(1.2, 0.4)
## The midship section, a superellipse of this power from the sheer to the keel.
const BILGE := 4.0
## Below the topsides, FLARE deep, the hull's body narrows FAIR per metre ahead of
## a narrower run, so it fairs into it where the decks' edge steps in.
const FLARE := 2.2
const FAIR := 0.15
## How sharply a waterline closes on the stem or the sternpost.
const TAPER := 2.0
## The bow: past the decks' fore end, a turtleback falls away from their edge to the
## stem head, STEM_HEAD over the waterline and up to STEM_LEAD times the fore deck
## end's half breadth ahead of the deck end; a plumb stem under it, the keel rising
## into it through FOREFOOT. Below the deck line the waterlines taper over ever more
## of the ship, to ENTRANCE at the waterline.
const STEM_LEAD := 0.6
const STEM_HEAD := 1.2
const ENTRANCE := 7.5
const FOREFOOT := 2.5
## The power the turtleback and the counter fall away with — upright at the stem
## head and the knuckle — and the least they fall per metre out, where they leave
## the deck line: steeper than any floor. Where that leaves too little drop for the
## lead, the lead is shorter.
const TURTLE := 1.2
const FALL_AWAY := 1.3
## The counter: falling away from the decks' after end to a knuckle KNUCKLE over the
## waterline, up to COUNTER_LEAD times the after deck end's half breadth aft of it;
## under it, the counter sweeps forward to meet the sternpost COUNTER_LIFT over the
## waterline. The sternpost stands STERNPOST forward of the deck end, and the run
## under the counter closes on it over RUN. The counter's round plan gives way to the
## run's fine one over COUNTER_BLEND either side.
const COUNTER_LEAD := 0.5
const KNUCKLE := 0.7
const COUNTER_LIFT := 0.15
const STERNPOST := 1.6
const RUN := 5.5
const COUNTER_BLEND := 0.5
## Points down one side of a section, sheer to keel, and the stations' spacing along
## the runs. Past each end: rings TOP_RINGS more under the deck line than a section
## has points, and points along each half ring from the deck's end to the stem.
const SECTION_POINTS := 14
const STATION_SPACING := 0.4
const TOP_RINGS := 4
const RING_POINTS := 8
## The toe rail along the sheer: its width and how high it stands over the deck.
const TOE_RAIL_WIDTH := 0.07
const TOE_RAIL_HEIGHT := 0.1
## How far a break face between two runs stands into the taller one.
const BREAK_INSET := 0.005
## The keel bar, and the rudder: its chord, how far aft of the sternpost it hangs,
## its thickness; the propeller: its blades' reach, chord and pitch, its hub, and
## how far aft of the sternpost and over the keel it turns.
const KEEL_BAR := Vector2(0.16, 0.12)
const RUDDER_CHORD := 1.1
const RUDDER_GAP := 0.75
const RUDDER_THICKNESS := 0.12
const BLADE_REACH := 0.75
const BLADE_CHORD := 0.34
const BLADE_PITCH := 0.45
const HUB := 0.13
const PROPELLER_AFT := 0.3
const PROPELLER_UP := 0.95
## The anchors: how far under the deck line the hawse stands, and how far there from
## the deck's end to the stem; its radius, and the anchor's shank and arms.
const HAWSE_DOWN := 1.6
const HAWSE_ALONG := 0.4
const HAWSE_RADIUS := 0.16
const SHANK := 1.0
const ARMS := 0.75
const ANCHOR_OFF := 0.06
## The jackstaff and the ensign staff: how far over the railing, how far under the
## deck line their heel, how thick.
const STAFF_HEIGHT := 1.8
const STAFF_HEEL := 0.25
const STAFF_RADIUS := 0.035
const SLIVER := ShipSpace.SLIVER

var _space: ShipSpace
var _layout: ShipLayout
## The rules' railing height: what the staffs stand over.
var _rail: float
## The x range of the decks, and the runs of the loft over it.
var _span := Vector2(INF, -INF)
var _run_list := []
var _waterline: float
var _keel: float
## The decks' outline just inside each end, the half breadth there and the deck line.
var _fore := Vector4.INF
var _aft := Vector4.INF
var _fore_edge: float
var _aft_edge: float
var _fore_deck: float
var _aft_deck: float
## How far the stem head stands ahead of the decks' fore end, and the counter's
## knuckle aft of their after end.
var _bow_lead: float
var _counter_lead: float
## What the hull must stay clear of: per piece, its plan and its foot.
var _inside: Array[Rect2] = []
var _inside_foot := PackedFloat32Array()
## Kept from the last x _body() and _needed() were asked at, for the next point of
## the same section: that x, the body's half breadth per side (port, starboard), and
## the pieces within reach there with how far out each needs the hull per side
## before its fall under it.
var _body_x := NAN
var _body_at := Vector2.ZERO
var _near_x := NAN
var _near := PackedInt32Array()
var _near_reach := PackedVector2Array()


func _init(space: ShipSpace, railing_height: float) -> void:
	_space = space
	_layout = space.layout
	_rail = railing_height
	for platform: ShipPlatform in _layout.platforms:
		_span = Vector2(minf(_span.x, platform.area.position.x), maxf(_span.y, platform.area.end.x))
	_waterline = -_layout.freeboard
	_fore = _space.envelope(_span.y - SLIVER)
	_aft = _space.envelope(_span.x + SLIVER)
	_fore_edge = maxf(-_fore.x, _fore.y)
	_aft_edge = maxf(-_aft.x, _aft.y)
	_fore_deck = maxf(_fore.z, _fore.w)
	_aft_deck = maxf(_aft.z, _aft.w)
	var fall := FALL_AWAY * TURTLE
	var bow_drop := maxf(_fore_deck - _waterline - STEM_HEAD, 0.0)
	_bow_lead = minf(STEM_LEAD * _fore_edge, bow_drop / fall)
	var counter_drop := maxf(_aft_deck - _waterline - KNUCKLE, 0.0)
	_counter_lead = minf(COUNTER_LEAD * _aft_edge, counter_drop / fall)
	for platform: ShipPlatform in _layout.platforms:
		_hold(platform.area, platform.height - ShipArt.PLANK)
	for ramp: ShipRamp in _layout.ramps:
		_hold(ramp.area, ramp.base())
	for blocker: ShipBlocker in _layout.blockers:
		var plan := blocker.area
		if blocker.shape == ShipBlocker.Shape.CYLINDER:
			plan = Rect2(
				blocker.centre - Vector2.ONE * blocker.radius, Vector2.ONE * blocker.radius * 2.0
			)
		_hold(plan, blocker.bottom)
	_keel = _waterline - DRAFT
	for foot: float in _inside_foot:
		_keel = minf(_keel, foot - KEEL_CLEARANCE)
	_run_list = _runs()


## Keeps the hull clear of [param plan] from [param foot] up, when that stands under
## the sheer: inside the hull, not on its decks.
func _hold(plan: Rect2, foot: float) -> void:
	var middle := plan.get_center()
	var shape := _space.envelope(clampf(middle.x, _span.x + SLIVER, _span.y - SLIVER))
	if shape.x == INF or foot >= minf(shape.z, shape.w) - ShipArt.PLANK - SLIVER:
		return
	_inside.append(plan)
	_inside_foot.append(foot)


func build(mesh: ShipMesh) -> void:
	var behind: Array[PackedVector3Array] = []
	var behind_shape := Vector4.INF
	for run: Array in _run_list:
		var shape: Vector4 = run[2]
		var sections := _loft(mesh, _stations(run[0], run[1]), shape)
		_toe_rails(mesh, run[0], run[1], shape)
		if not behind.is_empty():
			_step(mesh, behind[behind.size() - 1], behind_shape, sections[0], shape)
		behind = sections
		behind_shape = shape
	_end(mesh, true)
	_end(mesh, false)
	_keel_bar(mesh)
	_rudder(mesh)
	_propeller(mesh)
	for side in 2:
		_anchor(mesh, side)


## The faces of [param platform]'s planking ([constant ShipMesh.SIDES]) that lie on
## the hull's skin — along its sheer, against a step up to a taller run, or inside an
## end's plating — which ShipArt leaves undrawn so no two faces share a plane.
func hidden_faces(platform: ShipPlatform) -> int:
	var area := platform.area
	var middle := area.get_center()
	var shape := _space.envelope(middle.x)
	var hidden := 0
	if shape.x != INF:
		if is_equal_approx(shape.x, area.position.y) and is_equal_approx(shape.z, platform.height):
			hidden |= ShipMesh.NEG_Z
		if is_equal_approx(shape.y, area.end.y) and is_equal_approx(shape.w, platform.height):
			hidden |= ShipMesh.POS_Z
	for end in 2:
		var x := area.position.x if end == 0 else area.end.x
		var beyond := _space.envelope(x + (SLIVER if end == 1 else -SLIVER))
		if beyond.x == INF or minf(beyond.z, beyond.w) > platform.height + SLIVER:
			hidden |= ShipMesh.POS_X if end == 1 else ShipMesh.NEG_X
	return hidden


## The hull's half breadth on [param side] (0 port, 1 starboard) at (x, y): how far
## from the centreline its skin stands there, 0 where there is none.
func breadth(x: float, y: float, side: int) -> float:
	return _breadth(x, y, side, _shape_at(x))


## The hull's outward normal on [param side] at (x, y).
func normal(x: float, y: float, side: int) -> Vector3:
	var step := 0.05
	var along := breadth(x + step, y, side) - breadth(x - step, y, side)
	var up := breadth(x, y + step, side) - breadth(x, y - step, side)
	var out := 1.0 if side == 1 else -1.0
	return Vector3(-along / (2.0 * step) * out, -up / (2.0 * step), out).normalized()


## The runs of the loft: [from x, to x, outline], one wherever the decks' outline
## holds, neighbours with one outline merged.
func _runs() -> Array:
	var stations := PackedFloat32Array()
	for platform: ShipPlatform in _layout.platforms:
		stations.append_array([platform.area.position.x, platform.area.end.x])
	stations.sort()
	var runs := []
	var last := _span.x
	for x: float in stations:
		if x <= last + SLIVER:
			continue
		var shape := _space.envelope((last + x) * 0.5)
		if shape.x == INF:
			last = x
			continue
		if not runs.is_empty():
			var previous: Array = runs[runs.size() - 1]
			var joins: bool = is_equal_approx(previous[1], last)
			if joins and (previous[2] as Vector4).is_equal_approx(shape):
				previous[1] = x
				last = x
				continue
		runs.append([last, x, shape])
		last = x
	return runs


## The stations of a run from [param from] to [param to]: evenly spaced, and either
## side of the sternpost, where the keel steps up into the counter.
func _stations(from: float, to: float) -> PackedFloat32Array:
	var count := maxi(1, ceili((to - from) / STATION_SPACING))
	var xs := PackedFloat32Array()
	for index in count + 1:
		xs.append(lerpf(from, to, float(index) / count))
	var post := _span.x + STERNPOST
	for x: float in [post - SLIVER, post + SLIVER]:
		if x > from + SLIVER and x < to - SLIVER:
			xs.append(x)
	xs.sort()
	return xs


## The loft through stations [param xs] under the outline [param shape], drawn; its
## sections, aft to fore. Along a stretch where the section holds, only its first and
## last stations are kept.
func _loft(mesh: ShipMesh, xs: PackedFloat32Array, shape: Vector4) -> Array[PackedVector3Array]:
	var sections: Array[PackedVector3Array] = []
	for x: float in xs:
		var section := _section(x, shape)
		var count := sections.size()
		if (
			count >= 2
			and _same(section, sections[count - 1])
			and _same(sections[count - 1], sections[count - 2])
		):
			sections[count - 1] = section
		else:
			sections.append(section)
	var normals := _normals(sections)
	var top := maxf(shape.z, shape.w)
	var head := PackedFloat32Array([top, top, top, top])
	for i in sections.size() - 1:
		for j in sections[i].size() - 1:
			var corners := PackedVector3Array(
				[sections[i][j], sections[i][j + 1], sections[i + 1][j + 1], sections[i + 1][j]]
			)
			if corners[0].is_equal_approx(corners[1]) and corners[2].is_equal_approx(corners[3]):
				continue
			var at := PackedVector3Array(
				[normals[i][j], normals[i][j + 1], normals[i + 1][j + 1], normals[i + 1][j]]
			)
			mesh.smooth_quad(corners, at, ShipPaints.hull, head)
	return sections


## Whether sections [param a] and [param b] stand alike across the ship, wherever
## along it.
func _same(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	for index in a.size():
		if a[index].y != b[index].y or a[index].z != b[index].z:
			return false
	return true


## The section at [param x] under [param shape], from the port sheer down round the
## keel and up to the starboard sheer. Its points down each side stand at the same
## heights at every station under one deck line — those under the stem or the
## counter on it — so neighbouring stations, runs and ends meet point for point.
func _section(x: float, shape: Vector4) -> PackedVector3Array:
	var bottom := _bottom(x, shape)
	var sides: Array[PackedVector3Array] = []
	for side in 2:
		var deck := shape.z if side == 0 else shape.w
		var line := clampf(deck, bottom, INF)
		var out := -1.0 if side == 0 else 1.0
		var points := PackedVector3Array()
		for index in SECTION_POINTS - 1:
			var share := sin(PI * 0.5 * index / (SECTION_POINTS - 1))
			var y := maxf(line - (line - _keel) * share, bottom)
			points.append(Vector3(x, y, out * _breadth(x, y, side, shape)))
		sides.append(points)
	var section := sides[0]
	section.append(Vector3(x, bottom, 0.0))
	var starboard := sides[1]
	starboard.reverse()
	section.append_array(starboard)
	return section


## The lowest point of the hull at [param x]: the keel, or the stem or the counter
## where they rise from it.
func _bottom(x: float, shape: Vector4) -> float:
	var low := _keel
	var high := maxf(shape.z, shape.w)
	if _within(x, low):
		return low
	if not _within(x, high):
		return high
	for _step in 24:
		var middle := (low + high) * 0.5
		if _within(x, middle):
			high = middle
		else:
			low = middle
	return high


## Whether (x, y) stands between the stem and the stern.
func _within(x: float, y: float) -> bool:
	return x < _stem_x(y) and x > _stern_x(y)


## Per section, per point, the hull's outward normal there, off its neighbours.
func _normals(sections: Array[PackedVector3Array]) -> Array[PackedVector3Array]:
	var normals: Array[PackedVector3Array] = []
	var count := sections.size()
	for i in count:
		var section := sections[i]
		var at := PackedVector3Array()
		for j in section.size():
			var along := sections[mini(i + 1, count - 1)][j] - sections[maxi(i - 1, 0)][j]
			var down := section[mini(j + 1, section.size() - 1)] - section[maxi(j - 1, 0)]
			var n := down.cross(along)
			if n.length_squared() < 1e-10:
				n = Vector3(0.0, -1.0, section[j].z)
			n = n.normalized()
			var middle := (section[0].y + section[section.size() / 2].y) * 0.5
			var out := Vector3(0.0, section[j].y - middle, section[j].z)
			if j == section.size() / 2:
				out = Vector3.DOWN
			at.append(n if n.dot(out) >= 0.0 else -n)
		normals.append(at)
	return normals


## The hull's half breadth on [param side] at (x, y) under the outline [param shape]:
## the midship section, narrowed toward the stem and the stern, never nearer than
## CONTENT_CLEARANCE to what it holds, never wider than the deck edge.
func _breadth(x: float, y: float, side: int, shape: Vector4) -> float:
	var edge := -shape.x if side == 0 else shape.y
	var deck := shape.z if side == 0 else shape.w
	var full := edge
	if y < deck:
		var body := minf(_body(x, side), edge)
		var depth := clampf((deck - y) / maxf(deck - _keel, SLIVER), 0.0, 1.0)
		full = lerpf(edge, body, smoothstep(0.0, FLARE, deck - y))
		full *= pow(1.0 - pow(depth, BILGE), 1.0 / BILGE)
	var width := full * _fore_taper(x, y) * _aft_taper(x, y)
	if _within(x, y):
		width = maxf(width, _needed(x, y, side))
	return clampf(width, 0.0, edge)


## How far out the hull's body below its topsides stands on [param side] at x: the
## nearest decks' edge, faired along the ship so it narrows ahead of a narrower run
## rather than stepping in at it.
func _body(x: float, side: int) -> float:
	if x != _body_x:
		_body_x = x
		_body_at = Vector2.INF
		for run: Array in _run_list:
			var shape: Vector4 = run[2]
			var away := maxf(maxf(run[0] - x, x - run[1]), 0.0)
			_body_at = _body_at.min(Vector2(-shape.x, shape.y) + Vector2.ONE * FAIR * away)
	return _body_at[side]


## How far out on [param side] the hull must stand at (x, y) to clear what is inside
## it, the need falling off outside each piece.
func _needed(x: float, y: float, side: int) -> float:
	if x != _near_x:
		_near_x = x
		_near.clear()
		_near_reach.clear()
		for index in _inside.size():
			var plan := _inside[index]
			var along := maxf(maxf(plan.position.x - x, x - plan.end.x), 0.0)
			var spare := CONTENT_CLEARANCE - CONTENT_FALL.x * along
			var reach := Vector2(-plan.position.y, plan.end.y) + Vector2.ONE * spare
			if maxf(reach.x, reach.y) > 0.0:
				_near.append(index)
				_near_reach.append(reach)
	var need := 0.0
	for index in _near.size():
		var under := maxf(_inside_foot[_near[index]] - y, 0.0)
		need = maxf(need, _near_reach[index][side] - CONTENT_FALL.y * under)
	return need


## Where the stem stands at height [param y]: the turtleback falling away from the
## deck's edge to the stem head, plumb under it to the waterline, and swept back
## through the forefoot into the keel under that.
func _stem_x(y: float) -> float:
	var head := _waterline + STEM_HEAD
	if y >= head:
		var rise := minf((y - head) / maxf(_fore_deck - head, SLIVER), 1.0)
		return _span.y + SLIVER + _bow_lead * (1.0 - pow(rise, TURTLE))
	var plumb := _span.y + SLIVER + _bow_lead
	if y >= _waterline:
		return plumb
	var depth := clampf((_waterline - y) / (_waterline - _keel), 0.0, 1.0)
	return plumb - FOREFOOT * (1.0 - sqrt(1.0 - depth * depth))


## The share (0…1) of its breadth the hull keeps at (x, y) as it closes on the stem:
## from the deck's end at the deck line, from ever further aft below it.
func _fore_taper(x: float, y: float) -> float:
	var stem := _stem_x(y)
	var lead := maxf(stem - _span.y, SLIVER)
	var low := clampf((_fore_deck - y) / (_fore_deck - _waterline), 0.0, 1.0)
	var share := (stem - x) / lerpf(lead, maxf(ENTRANCE, lead), low * low)
	if share <= 0.0:
		return 0.0
	return 1.0 - pow(1.0 - minf(share, 1.0), TAPER)


## Where the stern stands at height [param y]: the counter falling away from the
## deck's edge to its knuckle, under it sweeping forward to the sternpost, then the
## sternpost itself.
func _stern_x(y: float) -> float:
	var knuckle := _waterline + KNUCKLE
	if y >= knuckle:
		var rise := minf((y - knuckle) / maxf(_aft_deck - knuckle, SLIVER), 1.0)
		return _span.x - SLIVER - _counter_lead * (1.0 - pow(rise, TURTLE))
	var post := _span.x + STERNPOST
	var meet := _waterline + COUNTER_LIFT
	if y <= meet:
		return post
	var tip := _span.x - SLIVER - _counter_lead
	var depth := (knuckle - y) / (knuckle - meet)
	return post - (post - tip) * sqrt(1.0 - depth * depth)


## The share (0…1) of its breadth the hull keeps at (x, y) as it closes on the
## stern: round under the counter, from the deck's end, and fine along the run
## beneath it.
func _aft_taper(x: float, y: float) -> float:
	var stern := _stern_x(y)
	var meet := _waterline + COUNTER_LIFT
	var round_up := smoothstep(meet - COUNTER_BLEND, meet + COUNTER_BLEND, y)
	var length := lerpf(RUN, maxf(_span.x - stern, SLIVER), round_up)
	var share := (x - stern) / length
	if share <= 0.0:
		return 0.0
	var rest := 1.0 - minf(share, 1.0)
	return lerpf(1.0 - pow(rest, TAPER), sqrt(1.0 - rest * rest), round_up)


## The outline the hull is lofted under at [param x]: the decks' there, or the end's
## beyond them.
func _shape_at(x: float) -> Vector4:
	if x >= _span.y - SLIVER:
		return _fore
	if x <= _span.x + SLIVER:
		return _aft
	return _space.envelope(x)


## The hull past one end of the decks — the bow when [param fore], else the counter —
## ring by ring down from the deck line: at the heights of the end section's points,
## TOP_RINGS more under the deck line, each ring the waterline there from the deck's
## end round to the stem or the counter. Each half is drawn apart, so the stem keeps
## its edge.
func _end(mesh: ShipMesh, fore: bool) -> void:
	var end := _span.y if fore else _span.x
	var shape := _fore if fore else _aft
	var away := 1.0 if fore else -1.0
	var bottom := _bottom(end, shape)
	for side in 2:
		var deck := shape.z if side == 0 else shape.w
		var out := -1.0 if side == 0 else 1.0
		var rings: Array[PackedVector3Array] = []
		for y: float in _ring_heights(deck, bottom):
			var reach := maxf((_stem_x(y) - end) if fore else (end - _stern_x(y)), 0.0)
			var ring := PackedVector3Array()
			for index in RING_POINTS + 1:
				var x := end + away * reach * sin(PI * 0.5 * index / RING_POINTS)
				ring.append(Vector3(x, y, out * _breadth(x, y, side, shape)))
			rings.append(ring)
		var normals := _ring_normals(rings, end - away)
		var head := PackedFloat32Array([deck, deck, deck, deck])
		for i in rings.size() - 1:
			for j in RING_POINTS:
				var corners := PackedVector3Array(
					[rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j]]
				)
				var area := (corners[2] - corners[0]).cross(corners[3] - corners[1])
				if area.length_squared() < 1e-10:
					continue
				var at := PackedVector3Array(
					[normals[i][j], normals[i][j + 1], normals[i + 1][j + 1], normals[i + 1][j]]
				)
				mesh.smooth_quad(corners, at, ShipPaints.hull, head)


## The heights of an end's rings from [param deck] down to [param bottom]: its
## section's points' (_section), with TOP_RINGS more between the deck line and the
## first point under it.
func _ring_heights(deck: float, bottom: float) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	for index in SECTION_POINTS - 1:
		var y := deck - (deck - _keel) * sin(PI * 0.5 * index / (SECTION_POINTS - 1))
		if index == 1:
			for extra in range(1, TOP_RINGS + 1):
				heights.append(lerpf(deck, y, float(extra) / (TOP_RINGS + 1)))
		if y <= bottom:
			break
		heights.append(y)
	heights.append(bottom)
	return heights


## Per ring, per point, an end's outward normal there, off its neighbours: away
## from the line along the ship at [param inside] (x), within the hull.
func _ring_normals(rings: Array[PackedVector3Array], inside: float) -> Array[PackedVector3Array]:
	var normals: Array[PackedVector3Array] = []
	var count := rings.size()
	for i in count:
		var ring := rings[i]
		var at := PackedVector3Array()
		for j in ring.size():
			var across := ring[mini(j + 1, ring.size() - 1)] - ring[maxi(j - 1, 0)]
			var down := rings[mini(i + 1, count - 1)][j] - rings[maxi(i - 1, 0)][j]
			var out := Vector3(ring[j].x - inside, 0.0, ring[j].z)
			var n := across.cross(down)
			if n.length_squared() < 1e-10:
				n = out
			n = n.normalized()
			at.append(n if n.dot(out) >= 0.0 else -n)
		normals.append(at)
	return normals


## The jackstaff over the bow or the ensign staff over the stern, when
## [param railing] spans the decks' end across the centreline: stepped just
## outboard of its posts, over the end falling away, so it goes with the span.
func staff(mesh: ShipMesh, railing: ShipRailing) -> void:
	for fore: bool in [false, true]:
		var end := _span.y if fore else _span.x
		if not (is_equal_approx(railing.from.x, end) and is_equal_approx(railing.to.x, end)):
			continue
		if minf(railing.from.y, railing.to.y) > 0.0 or maxf(railing.from.y, railing.to.y) <= 0.0:
			continue
		var deck := _fore_deck if fore else _aft_deck
		var away := 1.0 if fore else -1.0
		var at := Vector2(end + away * (ShipArt.POST * 0.5 + STAFF_RADIUS), 0.0)
		var top := deck + _rail + STAFF_HEIGHT
		mesh.cylinder(at, STAFF_RADIUS, deck - STAFF_HEEL, top, 6, ShipPaints.white)


## Teak toe rails along the sheer of the run from [param from] to [param to], on
## the deck at its edge, their outer faces carrying the hull's side up — and across
## the deck's edge where the run ends the decks.
func _toe_rails(mesh: ShipMesh, from: float, to: float, shape: Vector4) -> void:
	for side in 2:
		var edge := shape.x if side == 0 else shape.y - TOE_RAIL_WIDTH
		var deck := shape.z if side == 0 else shape.w
		mesh.box(
			Rect2(from, edge, to - from, TOE_RAIL_WIDTH),
			deck,
			deck + TOE_RAIL_HEIGHT,
			ShipPaints.teak,
			ShipMesh.TOP | ShipMesh.SIDES
		)
	var across := Rect2(0.0, shape.x + TOE_RAIL_WIDTH, TOE_RAIL_WIDTH, shape.y - shape.x)
	across.size.y -= TOE_RAIL_WIDTH * 2.0
	var deck := maxf(shape.z, shape.w)
	var faces := ShipMesh.TOP | ShipMesh.POS_X | ShipMesh.NEG_X
	if from <= _span.x + SLIVER:
		across.position.x = from
		mesh.box(across, deck, deck + TOE_RAIL_HEIGHT, ShipPaints.teak, faces)
	if to >= _span.y - SLIVER:
		across.position.x = to - TOE_RAIL_WIDTH
		mesh.box(across, deck, deck + TOE_RAIL_HEIGHT, ShipPaints.teak, faces)


## Where one run of the loft meets the next at the same station: on each side, the
## band between the two sections up to the lower deck line — facing the narrower
## side — and, above that, the taller run's break face up to its deck. Never a whole
## section: that would wall off a room the two runs share.
func _step(
	mesh: ShipMesh,
	aft: PackedVector3Array,
	aft_shape: Vector4,
	fore: PackedVector3Array,
	fore_shape: Vector4
) -> void:
	var x := aft[0].x
	var top := maxf(maxf(aft_shape.z, aft_shape.w), maxf(fore_shape.z, fore_shape.w))
	for side in 2:
		var low := minf(
			aft_shape.z if side == 0 else aft_shape.w, fore_shape.z if side == 0 else fore_shape.w
		)
		var a := _side_of(aft, side)
		var b := _side_of(fore, side)
		var levels := PackedFloat32Array()
		for point: Vector3 in a + b:
			if point.y <= low + SLIVER:
				levels.append(point.y)
		levels.append(low)
		levels.sort()
		for index in levels.size() - 1:
			var y0 := levels[index]
			var y1 := levels[index + 1]
			if y1 - y0 < SLIVER:
				continue
			var a0 := _across(a, y0)
			var a1 := _across(a, y1)
			var b0 := _across(b, y0)
			var b1 := _across(b, y1)
			if absf(a0 - b0) + absf(a1 - b1) < SLIVER:
				continue
			var normal := Vector3.RIGHT if a0 + a1 > b0 + b1 else Vector3.LEFT
			var out := -1.0 if side == 0 else 1.0
			mesh.quad(
				Vector3(x, y0, out * b0),
				Vector3(x, y0, out * a0),
				Vector3(x, y1, out * a1),
				Vector3(x, y1, out * b1),
				normal,
				ShipPaints.hull,
				0,
				NAN,
				top
			)
	var aft_top := maxf(aft_shape.z, aft_shape.w)
	var fore_top := maxf(fore_shape.z, fore_shape.w)
	if absf(aft_top - fore_top) < SLIVER:
		return
	var taller := aft_shape if aft_top > fore_top else fore_shape
	var facing := Vector3.RIGHT if aft_top > fore_top else Vector3.LEFT
	# Set into the taller run, so a blocker standing on the same line shows in front.
	var at := x - facing.x * BREAK_INSET
	var bottom := minf(aft_top, fore_top)
	var height := maxf(aft_top, fore_top) - bottom
	mesh.face(
		Vector3(at, bottom, taller.x),
		Vector3(0.0, 0.0, taller.y - taller.x) if facing.x < 0.0 else Vector3(0.0, height, 0.0),
		Vector3(0.0, height, 0.0) if facing.x < 0.0 else Vector3(0.0, 0.0, taller.y - taller.x),
		ShipPaints.hull,
		ShipMesh.RIM_ALL,
		NAN,
		maxf(aft_top, fore_top)
	)


## One side of [param section], sheer to keel, as (z, y) pairs in x, y, z.
func _side_of(section: PackedVector3Array, side: int) -> PackedVector3Array:
	var half := section.size() / 2
	var points := section.slice(0, half + 1)
	if side == 1:
		points = section.slice(half)
		points.reverse()
	return points


## How far out [param side] (sheer to keel) stands at height [param y].
func _across(side: PackedVector3Array, y: float) -> float:
	for index in side.size() - 1:
		var high := side[index]
		var low := side[index + 1]
		if y <= high.y + SLIVER and y >= low.y - SLIVER:
			var share := 0.0 if high.y - low.y < SLIVER else (high.y - y) / (high.y - low.y)
			return absf(lerpf(high.z, low.z, share))
	return 0.0


## A keel bar under the hull from the sternpost to the forefoot.
func _keel_bar(mesh: ShipMesh) -> void:
	var from := _span.x + STERNPOST
	var to := _stem_x(_keel + KEEL_BAR.y)
	mesh.box(
		Rect2(from, -KEEL_BAR.x * 0.5, to - from, KEEL_BAR.x),
		_keel - KEEL_BAR.y,
		_keel + KEEL_BAR.y,
		ShipPaints.hull,
		ShipMesh.ALL_FACES,
		NAN,
		_fore_deck
	)


## The rudder, hung aft of the sternpost from the keel's line up into the counter.
func _rudder(mesh: ShipMesh) -> void:
	var post := _span.x + STERNPOST
	var top := _waterline + COUNTER_LIFT + 0.4
	var blade := Rect2(
		post - RUDDER_GAP - RUDDER_CHORD, -RUDDER_THICKNESS * 0.5, RUDDER_CHORD, RUDDER_THICKNESS
	)
	mesh.box(blade, _keel + 0.15, top, ShipPaints.hull, ShipMesh.ALL_FACES, NAN, _fore_deck)
	var heel := Rect2(post - RUDDER_GAP - 0.15, -0.05, RUDDER_GAP + 0.15, 0.1)
	var foot := _keel - KEEL_BAR.y
	mesh.box(heel, foot, _keel + 0.05, ShipPaints.hull, ShipMesh.ALL_FACES, NAN, _fore_deck)


## A four-bladed bronze propeller on its shaft, between the sternpost and the rudder.
func _propeller(mesh: ShipMesh) -> void:
	var post := _span.x + STERNPOST
	var hub := Vector3(post - PROPELLER_AFT, _keel + PROPELLER_UP, 0.0)
	var shaft := Basis.IDENTITY
	mesh.turned_box(
		Transform3D(shaft, hub + Vector3.RIGHT * PROPELLER_AFT * 0.5),
		Vector3(PROPELLER_AFT + 0.3, HUB, HUB),
		ShipPaints.brass,
		0
	)
	var boss := Vector3(0.36, HUB * 2.0, HUB * 2.0)
	mesh.turned_box(Transform3D(shaft, hub), boss, ShipPaints.brass, 0)
	for blade in 4:
		var spin := Basis(Vector3.RIGHT, TAU * (blade + 0.5) / 4.0)
		var pitch := Basis(Vector3.UP, BLADE_PITCH)
		var turn := spin * pitch
		var centre := hub + spin * Vector3.UP * (HUB + BLADE_REACH * 0.5)
		var blade_size := Vector3(0.05, BLADE_REACH, BLADE_CHORD)
		mesh.turned_box(Transform3D(turn, centre), blade_size, ShipPaints.brass, 0)


## A hawse on the bow's [param side], HAWSE_DOWN under the deck line and
## HAWSE_ALONG of the way there from the deck's end to the stem, and a stockless
## anchor stowed in it, lying against the plating.
func _anchor(mesh: ShipMesh, side: int) -> void:
	var y := _fore_deck - HAWSE_DOWN
	var x := _span.y + HAWSE_ALONG * (_stem_x(y) - _span.y)
	var out := -1.0 if side == 0 else 1.0
	var at := Vector3(x, y, out * breadth(x, y, side))
	var facing := normal(x, y, side)
	var right := facing.cross(Vector3.UP).normalized()
	var up := right.cross(facing).normalized()
	var ring := PackedVector3Array()
	for index in 16:
		var angle := TAU * index / 16.0
		ring.append(at + facing * 0.01 + (right * cos(angle) + up * sin(angle)) * HAWSE_RADIUS)
	mesh.polygon(ring, facing, ShipPaints.dark, NAN, NAN)
	var foot_y := y - SHANK
	var foot := Vector3(x, foot_y, out * breadth(x, foot_y, side))
	foot += normal(x, foot_y, side) * ANCHOR_OFF
	var top := at + facing * ANCHOR_OFF
	var along := (top - foot).normalized()
	var across := along.cross(facing).normalized()
	var lie := Basis(across, along, facing).orthonormalized()
	var shank := Vector3(0.1, SHANK, 0.1)
	mesh.turned_box(Transform3D(lie, (top + foot) * 0.5), shank, ShipPaints.dark, 0)
	var arms := Vector3(ARMS, 0.16, 0.12)
	mesh.turned_box(Transform3D(lie, foot + along * 0.08), arms, ShipPaints.dark, 0)
	for end: float in [-1.0, 1.0]:
		var fluke := foot + across * end * ARMS * 0.45 + along * 0.2
		mesh.turned_box(Transform3D(lie, fluke), Vector3(0.18, 0.32, 0.1), ShipPaints.dark, 0)
