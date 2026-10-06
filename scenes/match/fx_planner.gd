class_name FxPlanner
extends RefCounted
## Turns one step of the match into what the sinking shows (SinkingFx), as
## CuePlanner turns it into sounds: the snapshot before it, the snapshot after it
## with the events it carries, and the ship's pose at both ticks as SinkSchedule
## answers them (D7) — where the sea crosses a deck is where that pose puts the
## world plane. Its own memory — how near each waterline's next burst of spray is, how
## far the plunge's blast of air has come — is presentation state; nothing it does
## reaches the sim (D5, D12).

## The sea climbing a deck this fast, in m/s, throws its whitest water; a waterline
## that hardly moves still shows WASH_LEAST of it.
const RUSH_SPEED := 0.2
const WASH_LEAST := 0.3
## Bursts of spray a second where a waterline meets a deck's edge, at full.
const SPRAY_RATE := 2.5
## Once the plunge has begun, everything the sea does is this much harder.
const PLUNGE_BOOST := 1.6
## How high white water climbs over the sea, in metres: spray, at least and at most
## by its strength; the sea breaking over the sides in the plunge, up past the
## deckhouses; the sheet a lurch slaps up the low side; a splash, by how hard the
## body came down.
const SPRAY_RISE := Vector2(0.6, 1.6)
const PLUNGE_RISE := 4.5
const LURCH_RISE := 2.4
const SPLASH_RISE := Vector2(0.5, 1.2)
## A splash under a deck stops this far short of its underside, in metres.
const SPLASH_HEADROOM := 0.1
## The sea breaking over the sides in the plunge leans back over the deck this much:
## a band along the side, not a field across the deck.
const PLUNGE_LEAN := 0.3
## In the plunge, the sea breaks over a deck's edge from SWALLOW.x under it to
## SWALLOW.y over it, in metres, every SWALLOW_TICKS.
const SWALLOW := Vector2(-0.8, 0.8)
const SWALLOW_TICKS := 24
## The funnel's smoke in the plunge bends over toward the ship's high end this much.
const SMOKE_BEND := 2.5
## Once the plunge has begun, air blasts out of every opening and vent still over the
## sea, one every VENT_TICKS, round them all BLASTS times.
const VENT_TICKS := 9
const BLASTS := 3
## All through the plunge: spray rains over the ship, harder over its first
## RAIN_GATHER seconds; loose gear slides down the decks every SLIDE_TICKS; and every
## ASTERN_TICKS air blown out of the hull boils up on the sea off the stern and brings
## a piece of wreckage up with it, from CLEAR_ASTERN to ASTERN metres aft of it or up
## to ASTERN along its quarters, from QUARTER to QUARTER + ASTERN_SPREAD out from its
## side.
const RAIN_GATHER := 8.0
const SLIDE_TICKS := 75
const ASTERN_TICKS := 50
const CLEAR_ASTERN := 3.0
const ASTERN := 14.0
const QUARTER := 4.0
const ASTERN_SPREAD := 10.0
## How far round a boil astern spreads, and for how long, in metres and seconds.
const ASTERN_BOIL := Vector2(2.0, 3.0)
## A piece of wreckage comes down on the sea this far outboard of every deck.
const OVERBOARD := 1.2
## How long each sheet of spray a lurch slaps up the low side is, in metres.
const LURCH_SPACING := 6.0
## The dust a deck giving way throws up billows from this far over it, in metres;
## the bits of it thrown up rain down this far round it.
const CLOUD_LIFT := 0.8
const DEBRIS_REACH := 7.0
## A deck whose highest corner stands this little over the sea has nothing loose
## left to slide, in metres.
const SLIDE_DRY := 0.3
## A deck about to give way sheds dust every TRICKLE_TICKS; one that has gone
## lands FALL_SECONDS later (MatchView draws it falling that long).
const TRICKLE_TICKS := 18
const FALL_SECONDS := MatchView.FALL_SECONDS
## The wreckage a collapse throws onto the sea, each way.
const COLLAPSE_PIECES := 2
## Steam from a machinery room: as the sea first reaches its floor, and as it
## drowns the machine, in seconds at full.
const STEAM_FIRST := 4.0
const STEAM_DROWNED := 6.0
## How many vents a machinery room breathes through, at most.
const VENTS := 2
## The funnel belches as its top comes down to this height over the sea, in metres.
const FUNNEL_DIP := 6.0
## Bubbles over a deck that has just gone under, and where the ship has gone.
const BUBBLES_SECONDS := 5.0
const BOIL_SECONDS := 14.0
## The wreckage the ship leaves where it went down.
const WRECKAGE := 6
## The funnel's smoke thickens in this many steps as the sinking goes on.
const SMOKE_STEPS := 12.0
## How far a falling body comes down, in m/s, that splashes hardest.
const SPLASH_FALL := 6.0
const SPLASH_LEAST := 0.35
## A deck's corners round its edge, as shares of its area from its least corner.
const _CORNERS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)
]

var _layout: ShipLayout
var _surfaces: Surfaces
var _schedule: SinkSchedule
## The iceberg's strike, as it shows (D13).
var _gash: GashPlanner
var _space: ShipSpace
var _railing_height: float
var _start_tick: int
var _end_tick: int
## Every platform's area together, in the ship plane, and the middle of it.
var _hull: Rect2
var _centre := Vector3.ZERO
## The funnel's top, ship-local, or NAN when the ship has none.
var _funnel := Vector3(NAN, NAN, NAN)
## Per room, the openings air blows out of as it floods: points and their outward.
var _openings: Array[PackedVector3Array] = []
var _outwards: Array[PackedVector3Array] = []
## Per room, the top of the machine standing in it, or NAN for none; and the vents
## its steam comes up through.
var _machines := PackedVector3Array()
var _vents: Array[PackedVector3Array] = []
## Per platform end of its waterline, how near its next burst of spray is, 0…1.
var _spray := PackedFloat32Array()
## Per platform, whether what was loose on it has floated off.
var _floated := PackedByteArray()
var _smoke := -1.0
## Whether the smoke was last told bent over by the plunge.
var _bent := false
## Every opening and machinery vent, and its outward; and how far round them the
## plunge's blasts have come, -1 before it.
var _blasts := PackedVector3Array()
var _blast_ways := PackedVector3Array()
var _venting := -1
## The line the sea crosses a deck along, and the heights of the deck's corners
## over the sea, as _crossing() last found them.
var _line := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _heights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _init(config: MatchConfig, surfaces: Surfaces, schedule: SinkSchedule) -> void:
	_layout = config.ship
	_surfaces = surfaces
	_schedule = schedule
	_gash = GashPlanner.new(schedule, config.ship.structure)
	_space = ShipSpace.new(_layout)
	_railing_height = config.rules.railing_height
	_start_tick = Ticks.from_seconds(config.scenario.starts_at)
	_end_tick = schedule.end_tick()
	_hull = _layout.platforms[0].area
	for platform: ShipPlatform in _layout.platforms:
		_hull = _hull.merge(platform.area)
	_centre = Vector3(_hull.get_center().x, 0.0, _hull.get_center().y)
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.shape == ShipBlocker.Shape.CYLINDER and blocker.radius >= ShipArt.FUNNEL_FROM:
			_funnel = Vector3(blocker.centre.x, blocker.top, blocker.centre.y)
	for room: ShipRoom in _layout.rooms:
		_find_openings(room, config.rules)
		_find_machine(room)
	for index in _openings.size():
		_blasts.append_array(_openings[index])
		_blast_ways.append_array(_outwards[index])
		for vent: Vector3 in _vents[index]:
			_blasts.append(vent)
			_blast_ways.append(Vector3.UP)
	_spray.resize(_layout.platforms.size() * 2)
	_floated.resize(_layout.platforms.size())


## The effects of the step from [param previous] to [param current], whose events
## are the ones that step raised.
func plan(previous: Dictionary, current: Dictionary) -> Array[FxCue]:
	var cues: Array[FxCue] = []
	var tick: int = current["tick"]
	var pose_then := _schedule.pose_at(previous["tick"])
	var pose_now := _schedule.pose_at(tick)
	var fired := _schedule.fired(tick)
	var plunged := _schedule.plunge_tick()
	var plunging := plunged >= 0 and plunged <= tick
	var boost := PLUNGE_BOOST if plunging else 1.0
	for event: Dictionary in current["events"]:
		_from_event(event, previous, current, pose_now, cues)
	_gash.bursts(tick, cues)
	_waterlines(pose_then, pose_now, tick, plunging, cues)
	_floods(pose_then, pose_now, tick, cues)
	_machinery(pose_then, pose_now, tick, cues)
	_collapses(pose_now, fired, tick, cues)
	_funnel_going(pose_then, pose_now, tick, cues)
	_smoke_level(tick, plunging, pose_now, cues)
	_blast(pose_now, tick, cues)
	# Only the plunge takes the last deck under.
	if plunging:
		_swallowing(pose_now, tick, cues)
		_gone(pose_then, pose_now, tick, cues)
		_plunge_going_on(pose_now, tick - plunged, tick, cues)
	return cues


func _from_event(
	event: Dictionary, previous: Dictionary, current: Dictionary, pose: ShipPose, cues: Array[FxCue]
) -> void:
	var tick: int = event["tick"]
	match event["kind"]:
		SimEvent.Kind.ENTERED_WATER, SimEvent.Kind.KNOCKED_BACK_IN:
			var seat: int = event["seat"]
			var splash := FxCue.new(FxCue.Kind.SPLASH, tick, current["seats"][seat]["pos"])
			splash.on_sea = true
			splash.seat = seat
			var falling: float = -(previous["seats"][seat]["vel"] as Vector3).y
			splash.strength = clampf(falling / SPLASH_FALL, SPLASH_LEAST, 1.0)
			if event["kind"] == SimEvent.Kind.KNOCKED_BACK_IN:
				splash.strength = 1.0
			var rise := lerpf(SPLASH_RISE.x, SPLASH_RISE.y, splash.strength)
			splash.rise = minf(rise, _headroom(splash.position, pose))
			cues.append(splash)
		SimEvent.Kind.CRATE_LOST:
			var crate: Vector3 = current["props"][event["prop"]]["pos"]
			_throw(FxCue.Piece.CRATE, crate, _side_of(crate), tick, cues)
		SimEvent.Kind.RAILING_BROKE:
			var span := _layout.railings[event["railing"]]
			var middle := _layout.railing_middle(event["railing"], _railing_height * 0.5)
			var outward := _edge_outward(_layout.platforms[span.platform].area, middle)
			var along := Vector3(span.to.x - span.from.x, 0.0, span.to.y - span.from.y) * 0.25
			_throw(FxCue.Piece.PLANK, middle - along, outward, tick, cues)
			_throw(FxCue.Piece.PLANK, middle + along, outward, tick, cues)
		SimEvent.Kind.SHIP_LURCHED:
			_lurch(event["heel"], pose, tick, cues)
		SimEvent.Kind.PLATFORM_COLLAPSING:
			for platform: ShipPlatform in _named(event["platform"]):
				var under := _underside(platform)
				_dust(under, platform.area.size.length() * 0.3, 0.5, tick, cues)
				var splinters := FxCue.new(FxCue.Kind.SPLINTERS, tick, under)
				splinters.strength = 0.4
				cues.append(splinters)
		SimEvent.Kind.PLATFORM_COLLAPSED:
			for platform: ShipPlatform in _named(event["platform"]):
				_collapse(platform, tick, cues)
			# The shock runs through the ship: the funnel shudders out a cough of soot.
			if not is_nan(_funnel.x):
				cues.append(FxCue.new(FxCue.Kind.BELCH, tick, _funnel))
		SimEvent.Kind.PLUNGE_BEGAN:
			if not is_nan(_funnel.x):
				cues.append(FxCue.new(FxCue.Kind.BELCH, tick, _funnel))
			_venting = 0
			_slides(_downhill(pose), pose, tick, cues)
		SimEvent.Kind.HOLED:
			_gash.strike(tick, cues)


## Where the sea crosses each deck still standing: white water along the line, and
## spray bursting where the line meets the edge of an open deck — the sea climbing
## the deck, harder the faster it climbs; in the plunge, the sea breaking over the
## sides instead.
func _waterlines(
	pose_then: ShipPose, pose_now: ShipPose, tick: int, plunging: bool, cues: Array[FxCue]
) -> void:
	var boost := PLUNGE_BOOST if plunging else 1.0
	var uphill := -_downhill(pose_now)
	for index in _layout.platforms.size():
		var platform := _layout.platforms[index]
		if platform.name in pose_now.collapsed or not _crossing(platform, pose_now):
			_spray[index * 2] = 0.0
			_spray[index * 2 + 1] = 0.0
			continue
		var middle := (_line[0] + _line[1]) * 0.5
		var climbing := (
			(pose_then.world_height(middle) - pose_now.world_height(middle)) * Ticks.RATE
		)
		var strength := clampf(absf(climbing) / RUSH_SPEED * boost, WASH_LEAST, 1.0)
		var wash := FxCue.new(FxCue.Kind.WASH, tick, _line[0])
		wash.end = _line[1]
		wash.toward = uphill
		wash.strength = strength
		wash.on_sea = true
		cues.append(wash)
		# In the plunge the sea breaking over the sides (_swallowing) is the spray.
		for end in 0 if plunging else 2:
			var slot := index * 2 + end
			_spray[slot] += SPRAY_RATE * strength * Ticks.SECONDS_PER_TICK
			if _spray[slot] < 1.0:
				continue
			_spray[slot] = fposmod(_spray[slot], 1.0)
			# Out on deck only: below decks the edge is the hull, and the spray would
			# come out through it.
			if not _at_edge(platform, _line[end]) or not _space.outdoors(_line[end] + Vector3.UP):
				continue
			var spray := FxCue.new(FxCue.Kind.SPRAY, tick, _line[end])
			spray.on_sea = true
			spray.strength = strength
			var outward := _edge_outward(platform.area, _line[end])
			spray.rise = lerpf(SPRAY_RISE.x, SPRAY_RISE.y, strength)
			spray.toward = (Vector3.UP * 2.0 + outward).normalized()
			cues.append(spray)


## As the sea reaches the middle of a deck that stands outdoors: bubbles over it,
## and whatever was loose on it comes up the first time beside the hull on the low
## side, where the sea came over — never across a still dry rail. Under a deck the air
## the water drives out is InnerWater's: a burst on the water at the opening the water
## reaches the top of, never grains thrown about the room.
func _floods(pose_then: ShipPose, pose_now: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	for index in _layout.platforms.size():
		if not _surfaces.flooded(index, pose_now) or _surfaces.flooded(index, pose_then):
			continue
		var platform := _layout.platforms[index]
		var middle := platform.area.get_center()
		var over := Vector3(middle.x, platform.height, middle.y)
		if not _space.outdoors(over + Vector3.UP * 0.5):
			continue
		var bubbles := FxCue.new(FxCue.Kind.BUBBLES, tick, over)
		bubbles.on_sea = true
		bubbles.radius = minf(platform.area.size.x, platform.area.size.y) * 0.5
		bubbles.seconds = BUBBLES_SECONDS
		cues.append(bubbles)
		if platform.area.get_area() > 4.0 and _floated[index] == 0:
			_floated[index] = 1
			var side := ShipPose.low_side(pose_now.heel_deg).y
			var low := Vector3(0.0, 0.0, side) if side != 0.0 else _side_of(over)
			var out := _overboard(over, low)
			out.y = pose_now.water_height(out)
			var afloat := FxCue.new(FxCue.Kind.FLOTSAM, tick, out)
			afloat.piece = FxCue.Piece.CHAIR if index % 2 == 0 else FxCue.Piece.LIFEBELT
			afloat.toward = low
			afloat.on_sea = true
			cues.append(afloat)


## Steam from a machinery room's vents as the sea first reaches its floor, and
## again, with the funnel, as it drowns the machine.
func _machinery(pose_then: ShipPose, pose_now: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	for index in _layout.rooms.size():
		var machine := _machines[index]
		if is_nan(machine.x):
			continue
		var room := _layout.rooms[index]
		var reached := _first_wet(room.area, room.floor_height, pose_now)
		if reached and not _first_wet(room.area, room.floor_height, pose_then):
			_steam(_vents[index], STEAM_FIRST, 0.6, tick, cues)
		if _surfaces.wet(machine, pose_now) and not _surfaces.wet(machine, pose_then):
			_steam(_vents[index], STEAM_DROWNED, 1.0, tick, cues)
			if not is_nan(_funnel.x):
				_steam(PackedVector3Array([_funnel]), STEAM_DROWNED, 1.0, tick, cues)


## A deck about to give way sheds dust from under it all through its warning, and a
## collapsed one throws up dust where it lands.
func _collapses(
	pose: ShipPose, fired: Array[SinkSchedule.Scheduled], tick: int, cues: Array[FxCue]
) -> void:
	if tick % TRICKLE_TICKS == 0:
		for platform_name: StringName in pose.collapsing:
			for platform: ShipPlatform in _named(platform_name):
				var corner := (tick / TRICKLE_TICKS) % 4
				var area := platform.area.grow(-0.3)
				var x := area.position.x if corner % 2 == 0 else area.end.x
				var z := area.position.y if corner < 2 else area.end.y
				var under := Vector3(x, platform.height - ShipArt.PLANK, z)
				_dust(under, 0.6, 0.35, tick, cues)
	var landed := Ticks.from_seconds(FALL_SECONDS)
	for scheduled: SinkSchedule.Scheduled in fired:
		if scheduled.event.kind != SinkEvent.Kind.COLLAPSE or scheduled.at + landed != tick:
			continue
		for platform: ShipPlatform in _named(scheduled.event.platform):
			var middle := platform.area.get_center()
			var floor := Vector3(middle.x, _space.floor_beneath(platform), middle.y)
			_dust(floor, platform.area.size.length() * 0.6, 1.0, tick, cues)


## The funnel belches as its top comes down near the sea, and hisses as it goes
## under.
func _funnel_going(pose_then: ShipPose, pose_now: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	if is_nan(_funnel.x):
		return
	var now := pose_now.world_height(_funnel)
	var then := pose_then.world_height(_funnel)
	if now < FUNNEL_DIP and then >= FUNNEL_DIP:
		cues.append(FxCue.new(FxCue.Kind.BELCH, tick, _funnel))
	if now < 0.0 and then >= 0.0:
		var hiss := FxCue.new(FxCue.Kind.STEAM, tick, _funnel)
		hiss.on_sea = true
		hiss.seconds = STEAM_FIRST
		cues.append(hiss)


## The funnel's smoke, thicker and darker in steps as the sinking goes on, and bent
## over toward the ship's high end once the plunge drags the funnel down: told on the
## first step and whenever it changes.
func _smoke_level(tick: int, plunging: bool, pose: ShipPose, cues: Array[FxCue]) -> void:
	if is_nan(_funnel.x):
		return
	var progress := 0.0
	if _end_tick > _start_tick:
		progress = clampf(float(tick - _start_tick) / (_end_tick - _start_tick), 0.0, 1.0)
	var level := snappedf(progress, 1.0 / SMOKE_STEPS)
	if level == _smoke and plunging == _bent:
		return
	_smoke = level
	_bent = plunging
	var smoke := FxCue.new(FxCue.Kind.SMOKE, tick, _funnel)
	smoke.strength = level
	if plunging:
		smoke.toward = (Vector3.UP - _downhill(pose) * SMOKE_BEND).normalized()
	cues.append(smoke)


## Once the plunge has begun: air blasting out of the next opening or vent still
## over the sea, every VENT_TICKS, round them all BLASTS times.
func _blast(pose: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	if _venting < 0 or tick % VENT_TICKS != 0:
		return
	while _venting < _blasts.size() * BLASTS:
		var index := _venting % _blasts.size()
		_venting += 1
		if _surfaces.wet(_blasts[index], pose):
			continue
		var vent := FxCue.new(FxCue.Kind.VENT, tick, _blasts[index])
		vent.toward = _blast_ways[index]
		cues.append(vent)
		return


## All through the plunge, [param since] ticks in: spray raining over the ship from
## where the sea breaks over it, gathering, until it has all gone under; loose gear
## sliding on down the decks; and air boiling up off the stern with wreckage.
func _plunge_going_on(pose: ShipPose, since: int, tick: int, cues: Array[FxCue]) -> void:
	if not _sunk(pose):
		var rain := FxCue.new(FxCue.Kind.RAIN, tick)
		rain.strength = clampf(Ticks.to_seconds(since) / RAIN_GATHER, 0.25, 1.0)
		cues.append(rain)
	if since > 0 and since % SLIDE_TICKS == 0:
		_slides(_downhill(pose), pose, tick, cues)
	if since % ASTERN_TICKS == 0:
		_astern(pose, since / ASTERN_TICKS, tick, cues)


## The [param turn]th boil of air off the stern in the plunge, and the wreckage it
## brings up: on the sea astern, or off a quarter, side by side in turn, spread
## round so no two come up in the same place.
func _astern(pose: ShipPose, turn: int, tick: int, cues: Array[FxCue]) -> void:
	var side := 1.0 if turn % 2 == 0 else -1.0
	var along := fposmod(turn * 0.618, 1.0)
	var out := fposmod(turn * 0.382, 1.0)
	var half := _hull.size.y * 0.5
	var stern := _hull.position.x
	var at := Vector3(stern - lerpf(CLEAR_ASTERN, ASTERN, along * 2.0), 0.0, side * half * out)
	if along >= 0.5:
		at = Vector3(
			stern + ASTERN * (along * 2.0 - 1.0), 0.0, side * (half + QUARTER + ASTERN_SPREAD * out)
		)
	at.z += _centre.z
	at.y = pose.water_height(at)
	var boil := FxCue.new(FxCue.Kind.BUBBLES, tick, at)
	boil.on_sea = true
	boil.radius = ASTERN_BOIL.x
	boil.seconds = ASTERN_BOIL.y
	cues.append(boil)
	var piece := FxCue.new(FxCue.Kind.FLOTSAM, tick, at)
	piece.piece = (turn % FxCue.Piece.size()) as FxCue.Piece
	piece.toward = Vector3(at.x - _centre.x, 0.0, at.z - _centre.z).normalized()
	piece.on_sea = true
	cues.append(piece)


## Once every deck still standing is under, a boil where the ship went down and its
## wreckage coming up round it.
func _gone(pose_then: ShipPose, pose_now: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	if not _sunk(pose_now) or _sunk(pose_then):
		return
	var boil := FxCue.new(FxCue.Kind.BUBBLES, tick, _centre)
	boil.on_sea = true
	boil.radius = minf(_hull.size.x, _hull.size.y) * 1.2
	boil.seconds = BOIL_SECONDS
	boil.strength = 1.0
	cues.append(boil)
	for index in WRECKAGE:
		var turn := TAU * index / WRECKAGE + 0.4
		var reach := Vector3(cos(turn) * _hull.size.x * 0.35, 0.0, sin(turn) * _hull.size.y * 0.5)
		var piece: FxCue.Piece = (index % FxCue.Piece.size()) as FxCue.Piece
		var thrown := FxCue.new(FxCue.Kind.FLOTSAM, tick, _centre + reach * 0.5)
		thrown.end = _centre + reach * 1.6
		thrown.toward = reach.normalized()
		thrown.piece = piece
		thrown.on_sea = true
		cues.append(thrown)


## A lurch slaps the sea up the low side in sheets all along it, sends loose gear
## sliding down every open deck toward it, and shakes dust down from every room's
## ceiling.
func _lurch(heel_deg: float, pose: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	var side := ShipPose.low_side(heel_deg).y
	var length := _hull.size.x / _sheets()
	for index in _sheets():
		var x := _hull.position.x + length * (index + 0.5)
		var sheet := _side_sheet(x, length, side, tick)
		if sheet != null:
			sheet.rise = LURCH_RISE
			sheet.toward = Vector3(0.0, 2.0, side).normalized()
			cues.append(sheet)
	_slides(Vector3(0.0, 0.0, side), pose, tick, cues)
	for index in _layout.rooms.size():
		var room := _layout.rooms[index]
		var middle := room.area.get_center()
		var roof := _space.roof(room, middle.x, middle.y)
		if roof == -1 or _layout.platforms[roof].name in pose.collapsed:
			continue
		var ceiling := _space.ceiling(room, middle.x, middle.y)
		var sift := FxCue.new(FxCue.Kind.SIFT, tick, Vector3(middle.x, ceiling, middle.y))
		sift.end = Vector3(room.area.size.x * 0.5, 0.0, room.area.size.y * 0.5)
		sift.radius = ceiling - room.floor_height
		sift.room = index
		cues.append(sift)


## In the plunge, the sea breaking over the ship's sides where they go under: every
## SWALLOW_TICKS, a sheet of spray outboard of each stretch of deck edge just over
## or just under the sea, flung up and back over the deck.
func _swallowing(pose: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	if tick % SWALLOW_TICKS != 0:
		return
	var length := _hull.size.x / _sheets()
	for index in _sheets():
		var x := _hull.position.x + length * (index + 0.5)
		var outline := _space.envelope(x)
		if outline.x == INF:
			continue
		for way in 2:
			var side := way * 2.0 - 1.0
			var edge := (
				Vector3(x, outline.w, outline.y) if side > 0.0 else Vector3(x, outline.z, outline.x)
			)
			var above := pose.world_height(edge)
			if above < SWALLOW.x or above > SWALLOW.y:
				continue
			var sheet := _side_sheet(x, length, side, tick)
			sheet.rise = PLUNGE_RISE
			sheet.toward = Vector3(0.0, 2.0, -side * PLUNGE_LEAN).normalized()
			cues.append(sheet)


## Down the decks under [param pose], in the ship plane, unit.
static func _downhill(pose: ShipPose) -> Vector3:
	var downhill := pose.ship_gravity(1.0)
	return Vector3(downhill.x, 0.0, downhill.z).normalized()


## How many sheets of spray run the ship's length.
func _sheets() -> int:
	return maxi(2, int(_hull.size.x / LURCH_SPACING))


## A sheet of spray on the sea along [param side] (ship-local z, -1 or 1) of the ship,
## [param length] long round [param x], outboard of the widest the decks reach along
## it; null where no deck stands at [param x].
func _side_sheet(x: float, length: float, side: float, tick: int) -> FxCue:
	var outline := _space.envelope(x)
	if outline.x == INF:
		return null
	var z := outline.y if side > 0.0 else outline.x
	for end: float in [x - length * 0.5, x + length * 0.5]:
		var reach := _space.envelope(end)
		if reach.x != INF:
			z = maxf(z, reach.y) if side > 0.0 else minf(z, reach.x)
	z += side * 0.3
	var sheet := FxCue.new(FxCue.Kind.SPRAY, tick, Vector3(x - length * 0.5, 0.0, z))
	sheet.end = Vector3(x + length * 0.5, 0.0, z)
	sheet.on_sea = true
	return sheet


## Loose gear sliding [param downhill] (ship plane, unit) down every deck still
## standing out of the sea.
func _slides(downhill: Vector3, pose: ShipPose, tick: int, cues: Array[FxCue]) -> void:
	for platform: ShipPlatform in _layout.platforms:
		if platform.name in pose.collapsed or _highest(platform, pose) < SLIDE_DRY:
			continue
		var middle := platform.area.get_center()
		var at := Vector3(middle.x, platform.height, middle.y)
		var slide := FxCue.new(FxCue.Kind.SLIDE, tick, at)
		slide.end = Vector3(platform.area.size.x * 0.5, 0.0, platform.area.size.y * 0.5)
		slide.toward = downhill
		cues.append(slide)


## A deck giving way: a cloud of its dust billowing up over it, splinters, its
## wreckage falling to the floor beneath, bits of it raining on the decks round, and
## a few pieces thrown overboard either side.
func _collapse(platform: ShipPlatform, tick: int, cues: Array[FxCue]) -> void:
	var middle := platform.area.get_center()
	var at := Vector3(middle.x, platform.height, middle.y)
	var cloud := FxCue.new(FxCue.Kind.CLOUD, tick, at + Vector3.UP * CLOUD_LIFT)
	cloud.radius = platform.area.size.length() * 0.5
	cues.append(cloud)
	cues.append(FxCue.new(FxCue.Kind.SPLINTERS, tick, at))
	var debris := FxCue.new(FxCue.Kind.DEBRIS, tick, at)
	debris.radius = DEBRIS_REACH
	cues.append(debris)
	var chunks := FxCue.new(FxCue.Kind.CHUNKS, tick, at)
	chunks.end = Vector3(platform.area.size.x * 0.5, 0.0, platform.area.size.y * 0.5)
	chunks.radius = platform.height - _space.floor_beneath(platform)
	cues.append(chunks)
	for side: float in [-1.0, 1.0]:
		var z := platform.area.position.y if side < 0.0 else platform.area.end.y
		for index in COLLAPSE_PIECES:
			var x := lerpf(platform.area.position.x, platform.area.end.x, (index + 0.5) / 2.0)
			var piece := FxCue.Piece.PLANK if index == 0 else FxCue.Piece.CHAIR
			_throw(piece, Vector3(x, platform.height, z), Vector3(0.0, 0.0, side), tick, cues)


## A piece of [param piece] leaving the ship at [param from] (ship-local) along
## [param outward], to come down on the sea OVERBOARD past every deck that way.
func _throw(
	piece: FxCue.Piece, from: Vector3, outward: Vector3, tick: int, cues: Array[FxCue]
) -> void:
	var thrown := FxCue.new(FxCue.Kind.FLOTSAM, tick, from)
	thrown.piece = piece
	thrown.end = _overboard(from, outward)
	thrown.toward = outward
	thrown.on_sea = true
	cues.append(thrown)


func _steam(
	vents: PackedVector3Array, seconds: float, strength: float, tick: int, cues: Array[FxCue]
) -> void:
	for vent: Vector3 in vents:
		var steam := FxCue.new(FxCue.Kind.STEAM, tick, vent)
		steam.seconds = seconds
		steam.strength = strength
		cues.append(steam)


func _dust(at: Vector3, radius: float, strength: float, tick: int, cues: Array[FxCue]) -> void:
	var dust := FxCue.new(FxCue.Kind.DUST, tick, at)
	dust.radius = radius
	dust.strength = strength
	cues.append(dust)


## Whether the sea crosses [param platform] under [param pose]; if it does, the
## line it crosses along is left in _line, its two ends on the deck's edge.
func _crossing(platform: ShipPlatform, pose: ShipPose) -> bool:
	var area := platform.area
	# The pose's world height over the deck is a plane: its corners' heights are its
	# height at the least corner and its rise along x and z.
	var basis := pose.transform.basis
	var least := Vector3(area.position.x, platform.height, area.position.y)
	var low := pose.world_height(least)
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


## How high over the sea [param platform]'s highest corner stands under [param pose].
func _highest(platform: ShipPlatform, pose: ShipPose) -> float:
	var highest := -INF
	for corner: Vector3 in _CORNERS:
		var at := corner * Vector3(platform.area.size.x, 0.0, platform.area.size.y)
		at += Vector3(platform.area.position.x, platform.height, platform.area.position.y)
		highest = maxf(highest, pose.world_height(at))
	return highest


## Whether [param point], on [param platform]'s edge, is on the edge of the decks:
## no deck of the same height carries on past it.
func _at_edge(platform: ShipPlatform, point: Vector3) -> bool:
	var past := point + _edge_outward(platform.area, point) * 0.3
	for other: ShipPlatform in _layout.platforms:
		if absf(other.height - platform.height) < 0.05 and other.contains(past.x, past.z):
			return false
	return true


## Out of [param area] across the edge [param point] lies nearest.
static func _edge_outward(area: Rect2, point: Vector3) -> Vector3:
	var gaps := [
		point.x - area.position.x,
		area.end.x - point.x,
		point.z - area.position.y,
		area.end.y - point.z
	]
	var ways := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var nearest := 0
	for index in 4:
		if gaps[index] < gaps[nearest]:
			nearest = index
	return ways[nearest]


## The nearer side of the ship to [param point], out across it.
func _side_of(point: Vector3) -> Vector3:
	return Vector3(0.0, 0.0, 1.0 if point.z >= _hull.get_center().y else -1.0)


## Where something leaving [param from] along [param outward] comes down on the sea:
## OVERBOARD past the last deck of any height it would cross, at the sea's height.
func _overboard(from: Vector3, outward: Vector3) -> Vector3:
	var at := from
	var step := outward * 0.25
	for _step in 200:
		var on_deck := false
		for platform: ShipPlatform in _layout.platforms:
			if platform.area.grow(0.05).has_point(Vector2(at.x, at.z)):
				on_deck = true
				break
		if not on_deck:
			break
		at += step
	return Vector3(at.x, 0.0, at.z) + outward * OVERBOARD


## How high over the sea at ship point [param point] white water may climb before
## the underside of whatever stands over it stops it: INF under the open sky.
func _headroom(point: Vector3, pose: ShipPose) -> float:
	var sea := pose.water_height(point)
	var over := _surfaces.ceiling(Vector3(point.x, sea, point.z), 0.0)
	return over if over == INF else maxf(over - sea - SPLASH_HEADROOM, 0.0)


## Every platform called [param platform_name].
func _named(platform_name: StringName) -> Array[ShipPlatform]:
	var found: Array[ShipPlatform] = []
	for platform: ShipPlatform in _layout.platforms:
		if platform.name == platform_name:
			found.append(platform)
	return found


func _underside(platform: ShipPlatform) -> Vector3:
	var middle := platform.area.get_center()
	return Vector3(middle.x, platform.height - ShipArt.PLANK, middle.y)


## Whether the water has reached any corner of [param area] at [param height]: its
## cell's, or the sea's (Surfaces.wet).
func _first_wet(area: Rect2, height: float, pose: ShipPose) -> bool:
	for corner: Vector2 in [
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y)
	]:
		if _surfaces.wet(Vector3(corner.x, height, corner.y), pose):
			return true
	return false


## Whether every deck still standing has its middle under the sea.
func _sunk(pose: ShipPose) -> bool:
	var highest := _surfaces.highest_platform(pose)
	return highest == Surfaces.NONE or _surfaces.flooded(highest, pose)


## [param room]'s doorways out onto the open deck, at chest height, and every hatch
## standing on a deck over it, at its top: what the air in it blows out through as
## it floods, where it can be seen.
func _find_openings(room: ShipRoom, rules: BrawlRules) -> void:
	var points := PackedVector3Array()
	var outwards := PackedVector3Array()
	for door: ShipRoom.Door in room.doors(_surfaces, rules.body_height, rules.step_height):
		var middle := door.middle()
		var at := Vector3(middle.x, room.floor_height + rules.body_height * 0.6, middle.y)
		var outward := Vector3(door.outward.x, 0.0, door.outward.y)
		if not _space.outdoors(at + outward * 0.6):
			continue
		points.append(at)
		outwards.append(outward)
	for blocker: ShipBlocker in _layout.blockers:
		if _is_hatch(blocker) and blocker.bottom > room.floor_height:
			var middle := blocker.area.get_center()
			if room.area.has_point(middle):
				points.append(Vector3(middle.x, blocker.top, middle.y))
				outwards.append(Vector3.UP)
	_openings.append(points)
	_outwards.append(outwards)


## The machine standing in [param room] — a box that is not a wall, indoors, as
## ShipArt draws an engine — and the vents up from it: skylights in the open deck
## straight over the room, along its middle.
func _find_machine(room: ShipRoom) -> void:
	var machine := Vector3(NAN, NAN, NAN)
	for blocker: ShipBlocker in _layout.blockers:
		if blocker.shape != ShipBlocker.Shape.BOX or _space.is_wall(blocker):
			continue
		var middle := blocker.area.get_center()
		var inside := Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y)
		var on_floor := absf(blocker.bottom - room.floor_height) < 0.05
		if on_floor and room.area.has_point(middle) and not _space.outdoors(inside):
			machine = Vector3(middle.x, blocker.top, middle.y)
	_machines.append(machine)
	var vents := PackedVector3Array()
	if not is_nan(machine.x):
		var area := room.area
		for share in VENTS:
			var at := Vector2(
				area.position.x + area.size.x * (share + 1.0) / (VENTS + 1.0), area.get_center().y
			)
			var deck := _space.deck_under(at, INF)
			var vent := Vector3(at.x, deck, at.y)
			if not is_nan(deck) and _space.outdoors(vent + Vector3.UP * 0.5):
				vents.append(vent)
	_vents.append(vents)


## A box standing outdoors on a deck that is not a wall: ShipArt's tarpaulined hatch.
func _is_hatch(blocker: ShipBlocker) -> bool:
	if blocker.shape != ShipBlocker.Shape.BOX or _space.is_wall(blocker):
		return false
	var middle := blocker.area.get_center()
	return _space.outdoors(Vector3(middle.x, (blocker.bottom + blocker.top) * 0.5, middle.y))
