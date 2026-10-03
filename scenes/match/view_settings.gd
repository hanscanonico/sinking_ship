class_name ViewSettings
extends Resource
## How the local player's first-person view turns and frames (D14), with defaults.
## SH15's settings screen saves them at PATH; until then they are read from there
## when someone has put a file there by hand. Presentation only: none of it is ever
## sent, and no rule reads it.

const PATH := "user://view_settings.tres"

## Degrees the look turns per pixel of mouse motion.
@export_range(0.01, 1.0) var mouse_deg_per_pixel: float = 0.12
## Degrees per second the look turns with the right stick fully over.
@export_range(30.0, 720.0) var stick_deg_per_second: float = 200.0
@export var invert_y: bool = false
## How much of the deck's list the view rolls with: 0 keeps the horizon level, the
## default against motion sickness (Q17, R15); 1 rolls with the deck.
@export_range(0.0, 1.0) var deck_roll: float = 0.0
## Horizontal field of view.
@export_range(75.0, 110.0) var fov_deg: float = 90.0


## The saved settings, or the defaults when none are saved.
static func local() -> ViewSettings:
	if ResourceLoader.exists(PATH):
		var saved := load(PATH) as ViewSettings
		if saved != null:
			return saved
	return ViewSettings.new()
