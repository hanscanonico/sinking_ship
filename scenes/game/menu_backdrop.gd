class_name MenuBackdrop
extends TextureRect
## Behind the main menu: the steamer at dusk with the list the sinking has given her
## by POSE_SECONDS, dressed as a match draws her (ShipArt) on the match's sea and sky,
## seen from a camera drifting slowly about her quarter, framed in the room the screens
## over her leave her to their right. A world of its own, silent, rendered at the
## window's own resolution however the UI is scaled, and to the graphics settings as
## a match is (show_graphics). Nothing of it exists until the
## menu first shows — a server or a headless client never builds it — and it is
## stopped, not freed, while a match runs: dressing her again costs seconds, a hitch on
## every return to the menu, where keeping her costs some megabytes.

const SEA_AND_SKY := preload("res://scenes/art/sea_and_sky.tscn")
## The moment of the default sinking she is posed at, in match seconds.
const POSE_SECONDS := 100.0
## Where the camera looks from, round the ship's middle: the bearing off her bow and
## the height over the sea; and how far above her middle it aims.
const BEARING_DEG := 118.0
const HEIGHT := 3.5
const AIM_UP := 2.0
## How much of the width right of the panels her drawn bounds span at the widest the
## drift shows her, and the least share of the window's width she keeps clear of the
## panels and of its right edge: she is drawn smaller rather than cut.
const FILL := 0.84
const MARGIN := 0.04
## The drift: its sway either side, in degrees and metres of height, and how long one
## sway takes, in seconds.
const DRIFT_DEG := 9.0
const DRIFT_RISE := 1.2
const DRIFT_SECONDS := 70.0
## How many moments of the drift, end to end, her framing looks at her from, and how
## many times it is refined.
const FRAMING_SWAYS := 17
const FRAMING_STEPS := 8
## How many ways round her outline is looked for.
const OUTLINE_TURNS := 12

var _viewport: SubViewport
var _sea_and_sky: SeaAndSky
var _ship: Node3D
var _art: ShipArt
var _camera: Camera3D
var _middle := Vector3.ZERO
## The points of her drawn hull, decks and masts that stand out furthest (_outline).
var _corners := PackedVector3Array()
## How far off her middle the camera stands, and how far left of her middle it aims:
## her framing, for the panels beside her and the window's shape.
var _distance := 1.0
var _aim_left := 0.0
var _time := 0.0
## The sway (-1…1) the drift is held at for a capture; NAN while it drifts.
var _held := NAN
## The match data whose ship is still to be dressed.
var _undressed: MatchRules
## The panels of the screens over her, which she stands to the right of.
var _beside: Array[Control] = []


func _ready() -> void:
	set_process(false)


## Frames her to the right of [param panel] as well as of every panel framed beside
## that is still in the tree — the widest of them, shown or not — so she stands still,
## and clear of them all, as the screens over her change. Any screen that shows a
## panel over her hands it in here, as often as it shows it; a panel leaving the tree
## leaves her framing with it.
func frame_beside(panel: Control) -> void:
	if panel in _beside:
		return
	_beside.append(panel)
	panel.item_rect_changed.connect(_frame)
	panel.tree_exiting.connect(_forget.bind(panel), CONNECT_ONE_SHOT)
	_frame()


## Dresses [param match_rules]' ship — as soon as the backdrop runs — and poses her as
## its sinking has her at POSE_SECONDS, every crate where it is loaded.
func show_ship(match_rules: MatchRules) -> void:
	_undressed = match_rules
	if is_processing():
		_dress()


## Draws and drifts while [param running]; otherwise neither draws nor processes.
func run(running: bool) -> void:
	if _viewport == null:
		if not running:
			return
		_build()
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if running else SubViewport.UPDATE_DISABLED
	)
	_viewport.process_mode = Node.PROCESS_MODE_INHERIT if running else Node.PROCESS_MODE_DISABLED
	set_process(running)
	if running:
		_fit()
		if _undressed != null:
			_dress()


## Holds the drift at [param sway] (-1…1, one end of its sway to the other), for a
## capture to show her at a chosen moment of it.
func hold_drift(sway: float) -> void:
	_held = clampf(sway, -1.0, 1.0)


## Where the camera stands and looks at [param sway] (-1…1) of the drift, as she is
## framed.
func view_at(sway: float) -> Transform3D:
	var bearing := deg_to_rad(BEARING_DEG + DRIFT_DEG * sway)
	var from := _middle + Vector3(cos(bearing), 0.0, sin(bearing)) * _distance
	var left := Vector3.UP.cross(_middle - from).normalized()
	from.y = HEIGHT + DRIFT_RISE * sway
	var aim := _middle + left * _aim_left + Vector3.UP * AIM_UP
	return Transform3D(Basis.looking_at(aim - from), from)


## Where [param point] falls on the view from [param view] whose height takes in
## [param fov] degrees, [param aspect] its width over its height: (0, 0) at its top
## left corner, (1, 1) at its bottom right.
static func on_view(view: Transform3D, fov: float, aspect: float, point: Vector3) -> Vector2:
	var seen := view.affine_inverse() * point
	var reach := tan(deg_to_rad(fov * 0.5)) * -seen.z
	return Vector2(0.5 + 0.5 * seen.x / (reach * aspect), 0.5 - 0.5 * seen.y / reach)


func _process(delta: float) -> void:
	_time += delta
	_camera.transform = view_at(_sway())


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	add_child(_viewport)
	_sea_and_sky = SEA_AND_SKY.instantiate()
	_viewport.add_child(_sea_and_sky)
	_ship = Node3D.new()
	_ship.name = "Ship"
	_viewport.add_child(_ship)
	_art = ShipArt.new()
	_art.name = "ShipArt"
	_ship.add_child(_art)
	_camera = Camera3D.new()
	_camera.far = 800.0
	_viewport.add_child(_camera)
	_camera.make_current()
	texture = _viewport.get_texture()
	get_window().size_changed.connect(_fit)
	resized.connect(_frame)
	show_graphics(ViewSettings.local())


## Draws her as [param settings]' graphics say, as the window's own view draws.
func show_graphics(settings: ViewSettings) -> void:
	if _viewport == null:
		return
	var quality := settings.graphics()
	quality.apply_to(_viewport, settings.render_scale_3d())
	_sea_and_sky.show_graphics(quality)
	_art.show_graphics(quality)


## One pixel of her render for every pixel of the window, which the UI's scaling
## does not reach.
func _fit() -> void:
	# A minimised window can be 0×0, which a viewport cannot.
	_viewport.size = get_window().size.maxi(1)


func _forget(panel: Control) -> void:
	panel.item_rect_changed.disconnect(_frame)
	_beside.erase(panel)
	_frame()


func _dress() -> void:
	var layout := _undressed.ship
	var rules := _undressed.rules
	_art.build(layout, rules.railing_height, rules.body_radius)
	var crates := _art.crates()
	for index in crates.size():
		crates[index].position = layout.props[index].pos
	var schedule := SinkSchedule.new(
		_undressed.sinking, layout.freeboard, SeedStreams.derive(0, "sink")
	)
	var tick := Ticks.from_seconds(POSE_SECONDS)
	_ship.transform = schedule.pose_at(tick).transform
	# The sea as a match has it at that moment: the dusk's gloom, the churn at her
	# bow, and none of the sky on the water in her rooms.
	_sea_and_sky.setup(schedule.cap_tick(), layout)
	_sea_and_sky.show_sinking(tick, _ship.transform)
	var bounds := layout.platforms[0].area
	for platform: ShipPlatform in layout.platforms:
		bounds = bounds.merge(platform.area)
	var centre := bounds.get_center()
	_middle = _ship.transform * Vector3(centre.x, 0.0, centre.y)
	_corners = _outline()
	_undressed = null
	_frame()
	_camera.transform = view_at(_sway())


## Where the drift is now, -1…1, or where a capture holds it.
func _sway() -> float:
	return _held if not is_nan(_held) else sin(_time * TAU / DRIFT_SECONDS)


## Of every point drawn of her, posed, those furthest out each way across the sea,
## OUTLINE_TURNS ways round: what stands furthest out to either side of any view of
## her from the sea. A part whose box stops short of where another part's box surely
## reaches holds none of them, and is passed over.
func _outline() -> PackedVector3Array:
	var ways: Array[Vector3] = []
	for turn in OUTLINE_TURNS:
		ways.append(Vector3.RIGHT.rotated(Vector3.UP, TAU * turn / OUTLINE_TURNS))
	var parts: Array[MeshInstance3D] = []
	parts.assign(_art.find_children("*", "MeshInstance3D", true, false))
	var sure := PackedFloat64Array()
	sure.resize(ways.size())
	sure.fill(-INF)
	for part: MeshInstance3D in parts:
		var box := part.global_transform * part.get_aabb()
		for turn in ways.size():
			sure[turn] = maxf(sure[turn], -_reach(box, -ways[turn]))
	var furthest := PackedVector3Array()
	furthest.resize(ways.size())
	var reach := sure.duplicate()
	for part: MeshInstance3D in parts:
		var box := part.global_transform * part.get_aabb()
		var turns := PackedInt32Array()
		for turn in ways.size():
			if _reach(box, ways[turn]) > sure[turn]:
				turns.append(turn)
		for surface in part.mesh.get_surface_count() if not turns.is_empty() else 0:
			var arrays := part.mesh.surface_get_arrays(surface)
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var at := part.global_transform * point
				for turn: int in turns:
					if at.dot(ways[turn]) >= reach[turn]:
						reach[turn] = at.dot(ways[turn])
						furthest[turn] = at
	var outline := PackedVector3Array()
	for point: Vector3 in furthest:
		if not point in outline:
			outline.append(point)
	return outline


## How far [param box] reaches along [param way].
static func _reach(box: AABB, way: Vector3) -> float:
	return box.get_center().dot(way) + (box.size * 0.5).dot(way.abs())


## Measures her framing for the panels beside her and the window's shape: the camera
## as far off as makes the widest the drift shows her span FILL of the width right of
## the widest panel — less, to keep MARGIN clear either side of her — and aimed so
## that span sits in the middle of that width.
func _frame() -> void:
	if _camera == null or _corners.is_empty() or size.x < 1.0 or size.y < 1.0:
		return
	var free_from := 0.0
	for panel: Control in _beside:
		var width := maxf(panel.size.x, panel.get_combined_minimum_size().x)
		free_from = maxf(free_from, (panel.get_global_rect().position.x + width) / size.x)
	var room := 1.0 - free_from
	var span := maxf(minf(room * FILL, room - MARGIN * 2.0), MARGIN)
	var aspect := size.x / size.y
	# Every share of the view's width is this many metres per metre off her middle.
	var across := tan(deg_to_rad(_camera.fov * 0.5)) * aspect * 2.0
	_aim_left = 0.0
	var reach := 0.0
	for corner: Vector3 in _corners:
		reach = maxf(reach, corner.distance_to(_middle))
	_distance = reach * 2.0 / (across * span)
	for step in FRAMING_STEPS:
		var seen := _seen(aspect)
		_aim_left += (free_from + room * 0.5 - (seen.x + seen.y) * 0.5) * across * _distance
		var nearer := (seen.y - seen.x) / span
		_distance *= nearer
		_aim_left *= nearer


## The least and the most across the view — 0 at its left edge, 1 at its right — her
## outline reaches at FRAMING_SWAYS moments of the drift, end to end.
func _seen(aspect: float) -> Vector2:
	var seen := Vector2(INF, -INF)
	for index in FRAMING_SWAYS:
		var view := view_at(lerpf(-1.0, 1.0, float(index) / (FRAMING_SWAYS - 1)))
		for corner: Vector3 in _corners:
			var at := on_view(view, _camera.fov, aspect, corner).x
			seen = Vector2(minf(seen.x, at), maxf(seen.y, at))
	return seen
