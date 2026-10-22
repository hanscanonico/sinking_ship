class_name ViewSettings
extends Resource
## How the local player's first-person view turns and frames (D14), the window — its
## mode, VSync and a frame-rate cap — and the graphics — the preset (GraphicsQuality)
## and the 3D view's render scale, each this machine's own until the player picks one
## — with defaults. The settings screen saves them at PATH. Presentation only: none of it is
## ever sent, and no rule reads it.

const PATH := "user://view_settings.tres"
const FOV_MIN := 75.0
const FOV_MAX := 110.0
## A graphics choice the player has not made: the machine's own stands in.
const AUTOMATIC := -1
## The frame-rate caps on offer, 0 for none.
const MAX_FPS_CHOICES: Array[int] = [0, 60, 120, 144, 240]

## How the window sits on the screen: in a frame, filling it borderless, or owning it.
enum WindowMode { WINDOWED, BORDERLESS, EXCLUSIVE }

## The one instance the game reads and the settings screen edits while either
## holds it, so a change reaches the look as it is made. Weak: a script's static
## holding an instance of that script is a cycle that outlives the game.
static var _shared: WeakRef

## Degrees the look turns per pixel of mouse motion.
@export_range(0.01, 1.0) var mouse_deg_per_pixel: float = 0.12:
	set(value):
		mouse_deg_per_pixel = clampf(value, 0.01, 1.0)
## Degrees per second the look turns with the right stick fully over.
@export_range(30.0, 720.0) var stick_deg_per_second: float = 200.0
@export var invert_y: bool = false
## How much of the deck's list the view rolls with: 0 keeps the horizon level, the
## default against motion sickness (Q17, R15); 1 rolls with the deck.
@export_range(0.0, 1.0) var deck_roll: float = 0.0:
	set(value):
		deck_roll = clampf(value, 0.0, 1.0)
## Horizontal field of view.
@export_range(75.0, 110.0) var fov_deg: float = 90.0:
	set(value):
		fov_deg = clampf(value, FOV_MIN, FOV_MAX)
## How hard a hit kicks the view and a lurch shakes it: 0 turns both off (R15).
@export_range(0.0, 1.0) var view_kick: float = 1.0:
	set(value):
		view_kick = clampf(value, 0.0, 1.0)
@export var window_mode: WindowMode = WindowMode.WINDOWED
@export var vsync: bool = true
## The most frames a second the game draws, 0 for no cap.
@export_range(0, 240) var max_fps: int = 0:
	set(value):
		max_fps = maxi(value, 0)
## The graphics preset (GraphicsQuality.Preset), or AUTOMATIC until the player picks
## one: then this machine's own (graphics()).
@export var quality: int = AUTOMATIC:
	set(value):
		quality = clampi(value, AUTOMATIC, GraphicsQuality.Preset.HIGH)
## The share of the window's pixels, across and down, the 3D view is drawn at, or
## AUTOMATIC until the player picks one: then the preset's own (render_scale_3d()).
@export var render_scale: float = AUTOMATIC:
	set(value):
		render_scale = (
			float(AUTOMATIC)
			if value <= 0.0
			else clampf(value, GraphicsQuality.SCALE_MIN, GraphicsQuality.SCALE_MAX)
		)
## A preset and a render scale for this run alone, over quality and render_scale
## (--quality, --render-scale), or AUTOMATIC: never saved, and set aside the moment the
## player picks their own.
var run_quality: int = AUTOMATIC
var run_render_scale: float = AUTOMATIC


## The saved settings, or the defaults when none are saved.
static func local() -> ViewSettings:
	var shared: ViewSettings = _shared.get_ref() if _shared != null else null
	if shared == null:
		shared = read(PATH)
		_shared = weakref(shared)
	return shared


## The settings saved at [param path], or the defaults when there are none.
static func read(path: String) -> ViewSettings:
	if ResourceLoader.exists(path):
		var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ViewSettings
		if saved != null:
			return saved
	return ViewSettings.new()


func save(path: String = PATH) -> Error:
	return ResourceSaver.save(self, path)


## A file saved before window_mode held a fullscreen flag: it reads as borderless,
## the mode it set.
func _set(property: StringName, value: Variant) -> bool:
	if property != &"fullscreen":
		return false
	window_mode = WindowMode.BORDERLESS if value else WindowMode.WINDOWED
	return true


## Puts the window in its mode, and VSync and the frame cap as chosen. VSync on and
## no cap are the engine's own defaults: unless [param overrule_launch] (the player
## just chose them), those leave the launch's own be, so --disable-vsync and
## --max-fps still measure what they ask for.
func apply_window(overrule_launch := false) -> void:
	var mode: DisplayServer.WindowMode = [
		DisplayServer.WINDOW_MODE_WINDOWED,
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	][window_mode]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if overrule_launch or not vsync:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
	if overrule_launch or max_fps > 0:
		Engine.max_fps = max_fps


## The preset the game draws with: this run's, else the player's, else this
## machine's until they pick one.
func graphics() -> GraphicsQuality:
	var chosen := run_quality if run_quality != AUTOMATIC else quality
	return GraphicsQuality.of(GraphicsQuality.automatic_preset() if chosen == AUTOMATIC else chosen)


## The render scale the game draws its 3D at: this run's, else the player's, else the
## preset's until they pick one.
func render_scale_3d() -> float:
	if run_render_scale > 0.0:
		return run_render_scale
	return graphics().render_scale if render_scale <= 0.0 else render_scale


## Draws [param viewport] — the window's own — as the graphics settings say.
func apply_graphics(viewport: Viewport) -> void:
	graphics().apply_to(viewport, render_scale_3d())
