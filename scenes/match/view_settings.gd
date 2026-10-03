class_name ViewSettings
extends Resource
## How the local player's first-person view turns and frames (D14), and whether the
## window fills the screen, with defaults. The settings screen saves them at PATH.
## Presentation only: none of it is ever sent, and no rule reads it.

const PATH := "user://view_settings.tres"
const FOV_MIN := 75.0
const FOV_MAX := 110.0

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
@export var fullscreen: bool = false


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


func apply_window() -> void:
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
