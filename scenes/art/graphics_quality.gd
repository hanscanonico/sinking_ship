class_name GraphicsQuality
extends RefCounted
## How much a frame of the art may cost: one of three presets the settings screen
## offers (Settings → Graphics), each a row of PRESETS. HIGH is the look as it was
## tuned, whatever it costs; MEDIUM the same look at a price most machines pay at
## 60 fps, the desktop's default; LOW runs everywhere, the browser's default. The
## 3D view's render scale is chosen beside it (ViewSettings): neither reaches the
## HUD or the menus, which the window draws at its own resolution. Presentation
## only: no rule reads any of it, and a server builds none of what it drives.

enum Preset { LOW, MEDIUM, HIGH }

## Every preset's knobs, read nowhere else:
##   name, summary: what the settings screen calls it, and says it changes;
##   msaa: the 3D view's multisampling;
##   glow: the dusk's bloom round the sun, the lamps and the foam;
##   shadow_distance: metres from the eye the sun's shadows reach (the ship is 60 m);
##   shadow_splits: the sun's shadow map in one piece (1), or two, finer near the eye;
##   shadow_size: the sun's shadow map's side, in texels;
##   shadow_filter: how softly a shadow's edge is sampled (RenderingServer.ShadowQuality);
##   sea_detail: the share (0…1) of its full reach (water.gdshader's detail_reach,
##       150 m) the sea's fine detail — its finest swell, streaks, sparkle, whitecaps
##       and foam — is drawn to, fading out as much sooner; past it, none is worked out;
##   lamps: the most room lamps lit at once, nearest first (LampSight);
##   lamp_sight: whether only the lamps of the rooms the eye can see into light.
const PRESETS := {
	Preset.LOW:
	{
		"name": "Low",
		"summary":
		(
			"Short, hard sun shadows, the sea's fine detail close by only, the four"
			+ " nearest lamps in sight, no smoothing of edges and no glow."
		),
		"msaa": Viewport.MSAA_DISABLED,
		"glow": false,
		"shadow_distance": 40.0,
		"shadow_splits": 1,
		"shadow_size": 2048,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_HARD,
		"sea_detail": 0.4,
		"lamps": 4,
		"lamp_sight": true,
	},
	Preset.MEDIUM:
	{
		"name": "Medium",
		"summary":
		(
			"Sun shadows over the whole ship, the sea's fine detail to the middle"
			+ " distance, the eight nearest lamps in sight, smoothed edges and glow."
		),
		"msaa": Viewport.MSAA_2X,
		"glow": true,
		"shadow_distance": 60.0,
		"shadow_splits": 2,
		"shadow_size": 4096,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"sea_detail": 0.6,
		"lamps": 8,
		"lamp_sight": true,
	},
	Preset.HIGH:
	{
		"name": "High",
		"summary":
		(
			"Sun shadows to 70 m, the sea's fine detail far out, every lamp nearby,"
			+ " smoothed edges and glow: the look as tuned, whatever it costs."
		),
		"msaa": Viewport.MSAA_2X,
		"glow": true,
		"shadow_distance": 70.0,
		"shadow_splits": 2,
		"shadow_size": 4096,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"sea_detail": 1.0,
		"lamps": 999,
		"lamp_sight": false,
	},
}
## The automatic choice, until the player makes one: the browser's preset and the
## desktop's; and the render scale of a screen of two or more pixels to a point (a
## Retina panel): one 3D pixel to a point, as a standard screen draws, not four.
const WEB_PRESET := Preset.LOW
const DESKTOP_PRESET := Preset.MEDIUM
const HIDPI := 2.0
const HIDPI_SCALE := 0.5
## The render scales the settings screen offers.
const SCALE_MIN := 0.5
const SCALE_MAX := 1.0

var preset: Preset
var msaa: Viewport.MSAA
var glow: bool
var shadow_distance: float
var shadow_mode: DirectionalLight3D.ShadowMode
var shadow_size: int
var shadow_filter: RenderingServer.ShadowQuality
var sea_detail: float
var lamps: int
var lamp_sight: bool


## [param chosen]'s knobs: a Preset, held to the ones there are.
static func of(chosen: int) -> GraphicsQuality:
	var quality := GraphicsQuality.new()
	quality.preset = clampi(chosen, Preset.LOW, Preset.HIGH) as Preset
	var row: Dictionary = PRESETS[quality.preset]
	quality.msaa = row["msaa"]
	quality.glow = row["glow"]
	quality.shadow_distance = row["shadow_distance"]
	quality.shadow_mode = (
		DirectionalLight3D.SHADOW_ORTHOGONAL
		if row["shadow_splits"] == 1
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	)
	quality.shadow_size = row["shadow_size"]
	quality.shadow_filter = row["shadow_filter"]
	quality.sea_detail = row["sea_detail"]
	quality.lamps = row["lamps"]
	quality.lamp_sight = row["lamp_sight"]
	return quality


## What the settings screen calls [param chosen], and what it says it changes.
static func title(chosen: int) -> String:
	return PRESETS[clampi(chosen, Preset.LOW, Preset.HIGH)]["name"]


static func summary(chosen: int) -> String:
	return PRESETS[clampi(chosen, Preset.LOW, Preset.HIGH)]["summary"]


## The preset a player who has not chosen one gets on this machine.
static func automatic_preset() -> Preset:
	return WEB_PRESET if OS.has_feature("web") else DESKTOP_PRESET


## The render scale a player who has not chosen one gets on this screen.
static func automatic_scale() -> float:
	var screen := DisplayServer.window_get_current_screen()
	return HIDPI_SCALE if DisplayServer.screen_get_scale(screen) >= HIDPI else 1.0


## Draws [param viewport]'s 3D at [param scale] of its pixels across and down, as
## this preset multisamples it; the sun's shadow map, which every view shares, too.
func apply_to(viewport: Viewport, scale: float) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = clampf(scale, SCALE_MIN, SCALE_MAX)
	viewport.msaa_3d = msaa
	RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow_filter)
