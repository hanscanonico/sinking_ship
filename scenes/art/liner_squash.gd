class_name LinerSquash
extends RefCounted
## A liner's squash court (RoomDressing.Kind.SQUASH), named a court, and its
## spectators' gallery: both lined in white plaster over a maple floor. On the court's
## walls its red lines, painted flat on the plaster no more than LINE_OUT proud: across
## the front wall — the end wall with the most room over it — the tin's top, the
## service line and the out line; along each side wall the out line, falling from the
## front wall's to the back wall's from the front wall back to where the gallery
## roofs the court, and on at the back wall's height under it; across the back wall its
## out line. The gallery's front, over the court's play, is faced in mahogany, flat on
## the edge of its floor and hanging under it over HEADROOM, between its stairs. The
## gallery itself is its lining alone; ShipArt draws the railing along its front.
## Nothing is drawn on the court's floor and no blocker is ever widened or added to hold
## a piece (D6): between a step over the floor and a body's height, nothing it draws
## stands more than FurnishingCheck.TOLERANCE (0.12 m) out from a wall; over HEADROOM
## (1.85 m) anything may — art-lint holds it to that.

const FINISH := ShipMesh.Finish
const HEADROOM := RoomDressing.HEADROOM
## The court's lines, each by the height of its top over the floor: the tin's top and
## the service line across the front wall, the out line across the front wall and
## across the back wall; how broad a line is and how far proud of the plaster.
const TIN := 0.48
const SERVICE := 1.78
const FRONT_OUT := 4.57
const BACK_OUT := 2.13
const LINE := 0.05
const LINE_OUT := 0.005
## How long a piece of a line along a wall is at most, so no mesh it joins outgrows its
## chunk (ShipMesh).
const BAY := 1.2
## How far apart the court's ceiling is looked at from the front wall back, finding
## where the gallery roofs it, and how near that edge is then found.
const LOOK_STEP := 0.1
const EDGE_NEAR := 0.002
## The gallery's front: how far its facing hangs under its floor's underside, how far
## proud of the floor's edge it stands.
const FASCIA := 0.25
const FASCIA_OUT := 0.005

## The court's colours: white plaster, maple underfoot, the red of its lines, and the
## mahogany of the gallery's front.
const PLASTER := Color("ece9df")
const MAPLE := Color("d2ad78")
const COURT_RED := Color("b0242a")
const MAHOGANY := Color("5b2c1d")

## The court's linings (RoomDressing.Part): white plaster walls over a maple floor.
static var plaster := ShipMesh.Paint.new(FINISH.HOUSE, ArtPalette.HOUSE, FINISH.PLAIN, PLASTER)
static var maple := ShipMesh.Paint.new(FINISH.DECK, ArtPalette.DECK, FINISH.DECK, MAPLE)
## What the pieces are made of.
static var court_red := ShipMesh.Paint.new(FINISH.PLAIN, COURT_RED)
static var mahogany := ShipMesh.Paint.new(FINISH.PLAIN, MAHOGANY)

var _space: ShipSpace


func _init(space: ShipSpace, _cabins: CabinDressing) -> void:
	_space = space


## Whether [param room], a squash court's, is its gallery: what its name says.
static func gallery(room: ShipRoom) -> bool:
	return String(room.name).to_lower().contains("gallery")


## [param room]'s furnishings, into [param mesh] (RoomDressing.build()): a court's
## lines and its gallery's front; a gallery's are its lining. Its panes,
## [param _glass], take nothing: no line is drawn over one.
func build(mesh: ShipMesh, room: ShipRoom, _glass: Array[Array]) -> void:
	if gallery(room):
		return
	var walls := RoomDressing.walls(_space, room)
	var front := front_wall(walls)
	if front == null:
		return
	var play := play_depth(room, front)
	for wall: RoomDressing.Wall in walls:
		if wall == front:
			for top: float in [TIN, SERVICE, FRONT_OUT]:
				_line(mesh, wall, top, top)
		elif wall.side % 2 == front.side % 2:
			_line(mesh, wall, BACK_OUT, BACK_OUT)
		else:
			_side_line(mesh, wall, front, play)
	_fascia(mesh, room, front, play)


## The court's front wall among [param walls]: the end wall (across x) with the most
## room over it — null when it has none.
func front_wall(walls: Array[RoomDressing.Wall]) -> RoomDressing.Wall:
	var best: RoomDressing.Wall = null
	var most := -INF
	for wall: RoomDressing.Wall in walls:
		if wall.side % 2 == 0:
			continue
		var height := _over(wall.room, wall.at(wall.middle(), 0.0, 0.3))
		if height > most:
			best = wall
			most = height
	return best


## How deep [param room]'s play runs back from [param front]'s face: to where, over
## the court's middle, its ceiling first drops under the front wall's out line — where
## the gallery roofs it — else to its back wall.
func play_depth(room: ShipRoom, front: RoomDressing.Wall) -> float:
	var depth := room.area.size.x
	var middle := front.middle()
	var clear := FRONT_OUT + LINE
	var near := 0.0
	var far := depth
	var out := LOOK_STEP
	while out < depth:
		if _over(room, front.at(middle, 0.0, out)) < clear:
			near = out - LOOK_STEP
			far = out
			break
		out += LOOK_STEP
	if far >= depth:
		return depth
	while far - near > EDGE_NEAR:
		var half := (near + far) * 0.5
		if _over(room, front.at(middle, 0.0, half)) < clear:
			far = half
		else:
			near = half
	return near


## A red line along [param wall], its top [param from_top] over the floor at its
## start and [param to_top] at its end, a bay at a time — none of it where the ceiling
## stands lower.
func _line(mesh: ShipMesh, wall: RoomDressing.Wall, from_top: float, to_top: float) -> void:
	var tops := func(along: float) -> float:
		return lerpf(from_top, to_top, (along - wall.from) / wall.length())
	_strip(mesh, wall, wall.from, wall.to, tops)


## The out line along side [param wall]: from [param front]'s out line at its foot
## down to the back wall's where the play ends, [param play] back from its face, and on
## at the back wall's height under the gallery.
func _side_line(
	mesh: ShipMesh, wall: RoomDressing.Wall, front: RoomDressing.Wall, play: float
) -> void:
	var face := front.at(front.middle(), 0.0).dot(wall.right)
	var toward := front.normal.dot(wall.right)
	var tops := func(along: float) -> float:
		var back := clampf((along - face) * toward / play, 0.0, 1.0)
		return lerpf(FRONT_OUT, BACK_OUT, back)
	var bend := face + toward * play
	var stops := PackedFloat32Array([wall.from, wall.to])
	if bend > wall.from and bend < wall.to:
		stops.insert(1, bend)
	for index in stops.size() - 1:
		_strip(mesh, wall, stops[index], stops[index + 1], tops)


## The red strip LINE broad along [param wall] from [param a] to [param b] along it,
## its top over the floor at each point [param tops] (along) -> float, cut into bays —
## none of a bay where the ceiling leaves no room over it.
func _strip(mesh: ShipMesh, wall: RoomDressing.Wall, a: float, b: float, tops: Callable) -> void:
	var count := maxi(1, ceili((b - a) / BAY))
	for index in count:
		var from := lerpf(a, b, float(index) / count)
		var to := lerpf(a, b, float(index + 1) / count)
		var top_from: float = tops.call(from)
		var top_to: float = tops.call(to)
		var need := maxf(top_from, top_to) + LINE
		if (
			_over(wall.room, wall.at(from, 0.0, 0.3)) < need
			or _over(wall.room, wall.at(to, 0.0, 0.3)) < need
		):
			continue
		mesh.quad(
			wall.at(from, top_from - LINE, LINE_OUT),
			wall.at(to, top_to - LINE, LINE_OUT),
			wall.at(to, top_to, LINE_OUT),
			wall.at(from, top_from, LINE_OUT),
			wall.normal,
			court_red,
			0
		)


## The gallery's front over [param room]'s play, [param play] back from
## [param front]'s face: mahogany from its floor's top to FASCIA under its underside,
## facing the front wall, along the front wall's length but where a stair comes up
## to it — none where it would hang under HEADROOM.
func _fascia(mesh: ShipMesh, room: ShipRoom, front: RoomDressing.Wall, play: float) -> void:
	if play >= room.area.size.x - LOOK_STEP:
		return
	var edge := front.at(front.middle(), 0.0, play + LOOK_STEP)
	var top := _space.ceiling(room, edge.x, edge.z)
	var bottom := top - ShipArt.PLANK - FASCIA
	if bottom < room.floor_height + HEADROOM:
		return
	var spans: Array[Vector2] = [Vector2(front.from, front.to)]
	var line := front.rect(front.from, front.to, play - FASCIA_OUT, play + FASCIA_OUT)
	for ramp: ShipRamp in _space.layout.ramps:
		if not ramp.area.intersects(line):
			continue
		var low := ramp.area.position.dot(Vector2(front.right.x, front.right.z))
		var high := ramp.area.end.dot(Vector2(front.right.x, front.right.z))
		var cut: Array[Vector2] = []
		for span: Vector2 in spans:
			if span.x < low:
				cut.append(Vector2(span.x, minf(span.y, low)))
			if span.y > high:
				cut.append(Vector2(maxf(span.x, high), span.y))
		spans = cut
	var facing := -front.normal
	for span: Vector2 in spans:
		var count := maxi(1, ceili((span.y - span.x) / BAY))
		for index in count:
			var a := lerpf(span.x, span.y, float(index) / count)
			var b := lerpf(span.x, span.y, float(index + 1) / count)
			var foot_a := front.at(a, bottom - front.floor, play - FASCIA_OUT)
			var foot_b := front.at(b, bottom - front.floor, play - FASCIA_OUT)
			var up := Vector3.UP * (top - bottom)
			mesh.quad(foot_b, foot_a, foot_a + up, foot_b + up, facing, mahogany, 0)


## How high [param room]'s ceiling stands over its floor at ship point [param point].
func _over(room: ShipRoom, point: Vector3) -> float:
	return _space.ceiling(room, point.x, point.z) - room.floor_height


## The lights [param room] is lit by; none keeps RoomDressing's pendants, as many as
## ever.
func lights(_room: ShipRoom) -> Array[RoomDressing.Light]:
	var found: Array[RoomDressing.Light] = []
	return found


## What a squash court lines its walls, floor, ceiling and beams with
## (RoomDressing.Part): white plaster over a maple floor, the ship's own ceiling and
## beams.
static func linings() -> Array[ShipMesh.Paint]:
	var paints: Array[ShipMesh.Paint] = [plaster, maple, null, null]
	return paints
