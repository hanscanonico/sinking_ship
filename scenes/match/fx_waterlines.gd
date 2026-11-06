class_name FxWaterlines
extends RefCounted
## Where the sea crosses each deck still standing, as FxPlanner shows it: white water along
## the line out on deck, never through a room (D7: the sea outside reaches no room's
## floor), and spray bursting where it meets an open deck's edge — the sea climbing the
## deck, harder the faster it climbs; in the plunge, the sea breaking over the sides
## instead. Once she has broken (SH33), each stretch of a deck on a piece of her is crossed
## as that piece stands (PieceViews, #478): a deck across a cut is two stretches, each with
## its own spray. Its memory, how near each waterline's next burst of spray is, is
## presentation state (D12).

## A deck's corners round its edge, as shares of its area from its least corner.
const _CORNERS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)
]

var _layout: ShipLayout
var _space: ShipSpace
var _pieces: PieceViews
## Per platform end of its waterline on each piece of her — the first's while she is
## whole — how near its next burst of spray is, 0…1.
var _spray := PackedFloat32Array()
## The line the sea crosses a deck along, and the heights of the deck's corners over the
## sea, as _crossing() last found them.
var _line := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _heights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
## Her platforms' least corners, the corner a deck's plane of heights is read from
## (_crossing), and their sizes along x and z: what plan reads of every deck, a tick,
## without touching one.
var _least := PackedVector3Array()
var _size_x := PackedFloat64Array()
var _size_z := PackedFloat64Array()


func _init(layout: ShipLayout, space: ShipSpace, pieces: PieceViews) -> void:
	_layout = layout
	_space = space
	_pieces = pieces
	for deck: ShipPlatform in layout.platforms:
		_least.append(Vector3(deck.area.position.x, deck.height, deck.area.position.y))
		_size_x.append(deck.area.size.x)
		_size_z.append(deck.area.size.y)
	_spray.resize(layout.platforms.size() * 2 * maxi(pieces.leaves.size(), 1))


## The waterlines of the step from [param pose_then] to [param pose_now], at [param tick],
## into [param cues]; [param plunging] once the plunge has begun.
func plan(
	pose_then: ShipPose, pose_now: ShipPose, tick: int, plunging: bool, cues: Array[FxCue]
) -> void:
	var views := _pieces.of(pose_now)
	if views.size() == 1:
		_whole(pose_then, pose_now, tick, plunging, cues)
		return
	# Broken: every stretch of a deck on a piece, as that piece stands.
	var platforms := _layout.platforms.size()
	for place in views.size():
		var view := views[place]
		var then := _pieces.of_piece(pose_then, _pieces.leaves[place])
		var low_x := -INF if place == 0 else _pieces.cuts[place - 1]
		var high_x := INF if place == views.size() - 1 else _pieces.cuts[place]
		for index in platforms:
			var slot := (place * platforms + index) * 2
			var platform := _layout.platforms[index]
			var area := platform.area
			var from := maxf(area.position.x, low_x)
			var to := minf(area.end.x, high_x)
			var crossed := to > from and not platform.name in pose_now.collapsed
			if crossed:
				area = Rect2(from, area.position.y, to - from, area.size.y)
				var least := Vector3(from, platform.height, area.position.y)
				var low := view.world_height(least)
				crossed = _crossing_area(area, platform.height, view, low)
			if not crossed:
				_spray[slot] = 0.0
				_spray[slot + 1] = 0.0
				continue
			_crossed(index, slot, then, view, tick, plunging, cues)


## plan while she is whole, as it ever was: the decks clear of the sea told from the
## packed arrays alone.
func _whole(
	pose_then: ShipPose, pose_now: ShipPose, tick: int, plunging: bool, cues: Array[FxCue]
) -> void:
	var basis := pose_now.transform.basis
	var lows := pose_now.transform * _least
	var size_x := _size_x
	var size_z := _size_z
	for index in lows.size():
		var low := lows[index].y
		# Every corner clear of the sea, over or under it, by more than its plane rises
		# across it: no line to find (_crossing), on most of the Titanic's 1,349 decks —
		# told from the packed arrays alone, no deck read.
		var rise := absf(basis.x.y * size_x[index]) + absf(basis.z.y * size_z[index])
		if absf(low) > rise + FxPlanner.CLEAR_OF_SEA:
			_spray[index * 2] = 0.0
			_spray[index * 2 + 1] = 0.0
			continue
		var platform := _layout.platforms[index]
		if platform.name in pose_now.collapsed or not _crossing(platform, pose_now, low):
			_spray[index * 2] = 0.0
			_spray[index * 2 + 1] = 0.0
			continue
		_crossed(index, index * 2, pose_then, pose_now, tick, plunging, cues)


## The white water and spray along platform [param index]'s waterline, _line, from
## [param pose_then] to [param pose_now], its spray kept from [param slot] on.
func _crossed(
	index: int,
	slot: int,
	pose_then: ShipPose,
	pose_now: ShipPose,
	tick: int,
	plunging: bool,
	cues: Array[FxCue]
) -> void:
	var boost := FxPlanner.PLUNGE_BOOST if plunging else 1.0
	var uphill := -FxPlanner._downhill(pose_now)
	var platform := _layout.platforms[index]
	var middle := (_line[0] + _line[1]) * 0.5
	var climbing := (pose_then.world_height(middle) - pose_now.world_height(middle)) * Ticks.RATE
	var strength := clampf(absf(climbing) / FxPlanner.RUSH_SPEED * boost, FxPlanner.WASH_LEAST, 1.0)
	for run: Vector2 in DeckWetness.out_on_deck_along(_layout, index, _line[0], _line[1]):
		var wash := FxCue.new(FxCue.Kind.WASH, tick, _line[0].lerp(_line[1], run.x))
		wash.end = _line[0].lerp(_line[1], run.y)
		wash.toward = uphill
		wash.strength = strength
		wash.on_sea = true
		cues.append(wash)
	# In the plunge the sea breaking over the sides (_swallowing) is the spray.
	for end in 0 if plunging else 2:
		var at := slot + end
		_spray[at] += FxPlanner.SPRAY_RATE * strength * Ticks.SECONDS_PER_TICK
		if _spray[at] < 1.0:
			continue
		_spray[at] = fposmod(_spray[at], 1.0)
		# Out on deck only: below decks the edge is the hull, and the spray would come
		# out through it.
		if not _at_edge(platform, _line[end]) or not _space.outdoors(_line[end] + Vector3.UP):
			continue
		var spray := FxCue.new(FxCue.Kind.SPRAY, tick, _line[end])
		spray.on_sea = true
		spray.strength = strength
		var outward := FxPlanner._edge_outward(platform.area, _line[end])
		spray.rise = lerpf(FxPlanner.SPRAY_RISE.x, FxPlanner.SPRAY_RISE.y, strength)
		spray.toward = (Vector3.UP * 2.0 + outward).normalized()
		cues.append(spray)


## Whether the sea crosses [param platform] under [param pose], its least corner
## [param low] up in the world there; if it does, the line it crosses along is left in
## _line, its two ends on the deck's edge.
func _crossing(platform: ShipPlatform, pose: ShipPose, low: float) -> bool:
	return _crossing_area(platform.area, platform.height, pose, low)


## _crossing of a deck over [param area] at [param height].
func _crossing_area(area: Rect2, height: float, pose: ShipPose, low: float) -> bool:
	# The pose's world height over the deck is a plane: its corners' heights are its
	# height at the least corner and its rise along x and z.
	var basis := pose.transform.basis
	var least := Vector3(area.position.x, height, area.position.y)
	var along_x := basis.x.y * area.size.x
	var along_z := basis.z.y * area.size.y
	_heights[0] = low
	_heights[1] = low + along_x
	_heights[2] = low + along_x + along_z
	_heights[3] = low + along_z
	var found := 0
	for index in 4:
		var above_a := _heights[index]
		var above_b := _heights[(index + 1) % 4]
		if (above_a < 0.0) == (above_b < 0.0) or found == 2:
			continue
		var a := least + _CORNERS[index] * Vector3(area.size.x, 0.0, area.size.y)
		var b := least + _CORNERS[(index + 1) % 4] * Vector3(area.size.x, 0.0, area.size.y)
		_line[found] = a.lerp(b, above_a / (above_a - above_b))
		found += 1
	return found == 2


## Whether [param point], on [param platform]'s edge, is on the edge of the decks:
## no deck of the same height carries on past it.
func _at_edge(platform: ShipPlatform, point: Vector3) -> bool:
	var past := point + FxPlanner._edge_outward(platform.area, point) * 0.3
	for other: ShipPlatform in _layout.platforms:
		if absf(other.height - platform.height) < 0.05 and other.contains(past.x, past.z):
			return false
	return true
