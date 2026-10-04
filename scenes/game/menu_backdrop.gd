class_name MenuBackdrop
extends TextureRect
## Behind the main menu: the steamer at dusk with the list the sinking has given her
## by POSE_SECONDS, dressed as a match draws her (ShipArt) on the match's sea and sky,
## seen from a camera drifting slowly about her quarter, framed in the room the menu
## leaves her to its right. A world of its own, silent, rendered at the window's own
## resolution however the UI is scaled. Nothing of it exists until the menu first
## shows — a server or a headless client never builds it — and it is stopped, not
## freed, while a match runs: dressing her again costs seconds, a hitch on every
## return to the menu, where keeping her costs some megabytes.

const SEA_AND_SKY := preload("res://scenes/art/sea_and_sky.tscn")
## The moment of the default sinking she is posed at, in match seconds.
const POSE_SECONDS := 100.0
## Where the camera looks from, round the ship's middle: the bearing off her bow and
## the height over the sea; how far above her middle it aims; and how much of the
## width the menu leaves her her decks fill — her hull, rails and mast reach further,
## so this leaves her clear of the menu and the screen's edge (seen on captures).
const BEARING_DEG := 118.0
const HEIGHT := 4.5
const AIM_UP := 2.0
const FILL := 0.5
## The drift: its sway either side, in degrees and metres of height, and how long one
## sway takes, in seconds.
const DRIFT_DEG := 9.0
const DRIFT_RISE := 1.2
const DRIFT_SECONDS := 70.0

var _viewport: SubViewport
var _ship: Node3D
var _art: ShipArt
var _camera: Camera3D
var _middle := Vector3.ZERO
## Half of her length and beam as the camera sees her across, in metres.
var _half_seen := 1.0
var _time := 0.0
## The match data whose ship is still to be dressed.
var _undressed: MatchRules
## The menu's panel, which she stands to the right of.
var _beside: Control


func _ready() -> void:
	set_process(false)


## Frames her to the right of [param panel].
func frame_beside(panel: Control) -> void:
	_beside = panel


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


func _process(delta: float) -> void:
	_time += delta
	_place_camera()


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	# As the project's own view draws (rendering/anti_aliasing/quality/msaa_3d).
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	_viewport.add_child(SEA_AND_SKY.instantiate())
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


## One pixel of her render for every pixel of the window, which the UI's scaling
## does not reach.
func _fit() -> void:
	# A minimised window can be 0×0, which a viewport cannot.
	_viewport.size = get_window().size.maxi(1)


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
	_ship.transform = schedule.pose_at(Ticks.from_seconds(POSE_SECONDS)).transform
	var bounds := layout.platforms[0].area
	for platform: ShipPlatform in layout.platforms:
		bounds = bounds.merge(platform.area)
	var centre := bounds.get_center()
	_middle = _ship.transform * Vector3(centre.x, 0.0, centre.y)
	var bearing := deg_to_rad(BEARING_DEG)
	_half_seen = (bounds.size.x * absf(sin(bearing)) + bounds.size.y * absf(cos(bearing))) * 0.5
	_undressed = null
	_place_camera()


## Stands the camera off her quarter, as far as makes her fill FILL of the width right
## of the panel at this window's aspect, aimed so her middle sits in the middle of it.
func _place_camera() -> void:
	var free_from := 0.0 if _beside == null else _beside.get_global_rect().end.x / size.x
	var room := 1.0 - free_from
	# The camera keeps its height's view: the window's aspect sets how much it sees across.
	var across := tan(deg_to_rad(_camera.fov * 0.5)) * size.x / size.y
	var distance := _half_seen / (across * room * FILL)
	var aim_left := distance * across * free_from
	var sway := sin(_time * TAU / DRIFT_SECONDS)
	var bearing := deg_to_rad(BEARING_DEG + DRIFT_DEG * sway)
	var from := _middle + Vector3(cos(bearing), 0.0, sin(bearing)) * distance
	from.y = HEIGHT + DRIFT_RISE * sway
	var toward := (_middle - from).normalized()
	var left := Vector3.UP.cross(toward).normalized()
	_camera.look_at_from_position(from, _middle + left * aim_left + Vector3.UP * AIM_UP)
