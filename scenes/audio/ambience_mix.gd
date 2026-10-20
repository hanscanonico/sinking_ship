class_name AmbienceMix
extends RefCounted
## The beds' levels and the buses' filters, from where the listener's ears are:
## how far above the sea (the world plane, D7), how fast the ship is settling, and
## how enclosed the space round them is. Pure, so the mix is testable without a
## Node; MatchAudio applies it every frame.

## The sea at the feet, and as quiet and dull as it gets SEA_FAR_M above it.
const SEA_NEAR_DB := -3.0
const SEA_FAR_DB := -16.0
const SEA_FAR_M := 14.0
const SEA_NEAR_HZ := 16000.0
const SEA_FAR_HZ := 1500.0
## The wind low over the water, and at its loudest WIND_HIGH_M above it.
const WIND_LOW_DB := -22.0
const WIND_HIGH_DB := -9.0
const WIND_HIGH_M := 12.0
## The sea rushing in is at its loudest once the ship settles this fast, in
## metres a second — the steamer's last plunge — and fades to RUSH_FAR_SHARE of
## that SEA_FAR_M above the water.
const RUSH_FULL_RATE := 0.15
const RUSH_DB := -2.0
const RUSH_FAR_SHARE := 0.35
## The water rushing into the listener's own cell is at its loudest once it rises
## this fast, in metres a second, and CELL_RUSH_UNDER_DB quieter heard from under it.
const CELL_RUSH_FULL_RATE := 0.25
const CELL_RUSH_UNDER_DB := -6.0
## The water lapping round the listener's cell: none below LAP_FROM_M deep, at
## LAP_DB from LAP_FULL_M to LAP_DEEP_FROM_M, and down to LAP_DEEP_SHARE of that by
## LAP_DEEP_M, where it is too deep to lap at the feet.
const LAP_DB := -10.0
const LAP_FROM_M := 0.02
const LAP_FULL_M := 0.3
const LAP_DEEP_FROM_M := 1.2
const LAP_DEEP_M := 3.0
const LAP_DEEP_SHARE := 0.25
## Quieter than this is off.
const SILENT_DB := -60.0
## Fully enclosed, the outside is heard through the hull: muffled to ENCLOSED_HZ,
## the wind down by ENCLOSED_WIND_DB, and the room's own reverb at ENCLOSED_WET.
const OPEN_HZ := 20000.0
const ENCLOSED_HZ := 700.0
const ENCLOSED_WIND_DB := -18.0
const ENCLOSED_WET := 0.35
## With the ears under the sea (SH5) the outside is heard through the water: muffled
## to UNDER_HZ, and the wind down by UNDER_WIND_DB.
const UNDER_HZ := 300.0
const UNDER_WIND_DB := -30.0
## With the ears under, every cue in the room — and the rush — is heard through the
## water too, muffled to UNDER_CUE_HZ.
const UNDER_CUE_HZ := 500.0


static func sea_db(above_sea: float) -> float:
	return lerpf(SEA_NEAR_DB, SEA_FAR_DB, _height(above_sea, SEA_FAR_M))


static func sea_cutoff_hz(above_sea: float) -> float:
	return _sweep(SEA_NEAR_HZ, SEA_FAR_HZ, _height(above_sea, SEA_FAR_M))


static func wind_db(above_sea: float, enclosure: float, under: bool = false) -> float:
	var open := lerpf(WIND_LOW_DB, WIND_HIGH_DB, _height(above_sea, WIND_HIGH_M))
	var ducked := open + ENCLOSED_WIND_DB * clampf(enclosure, 0.0, 1.0)
	return ducked + UNDER_WIND_DB if under else ducked


## [param sink_rate] is how fast the ship is settling, metres a second.
static func rush_db(sink_rate: float, above_sea: float) -> float:
	var pace := clampf(sink_rate / RUSH_FULL_RATE, 0.0, 1.0)
	var near := lerpf(1.0, RUSH_FAR_SHARE, _height(above_sea, SEA_FAR_M))
	return maxf(RUSH_DB + linear_to_db(pace * near), SILENT_DB)


## [param rise] is how fast the water in the listener's own cell is rising, metres a
## second; heard [param ears_under] it, quieter.
static func cell_rush_db(rise: float, ears_under: bool) -> float:
	if rise <= 0.0:
		return SILENT_DB
	var pace := clampf(rise / CELL_RUSH_FULL_RATE, 0.0, 1.0)
	var level := RUSH_DB + linear_to_db(pace) + (CELL_RUSH_UNDER_DB if ears_under else 0.0)
	return maxf(level, SILENT_DB)


## The water lapping in the listener's cell, [param depth] metres of it over the
## floor; silent with the ears under it.
static func lap_db(depth: float, ears_under: bool) -> float:
	if ears_under or depth <= LAP_FROM_M:
		return SILENT_DB
	var share := clampf((depth - LAP_FROM_M) / (LAP_FULL_M - LAP_FROM_M), 0.0, 1.0)
	if depth > LAP_DEEP_FROM_M:
		var deep := clampf((depth - LAP_DEEP_FROM_M) / (LAP_DEEP_M - LAP_DEEP_FROM_M), 0.0, 1.0)
		share = lerpf(1.0, LAP_DEEP_SHARE, deep)
	return maxf(LAP_DB + linear_to_db(share), SILENT_DB)


## 1 when feet at [param feet] stand in one of [param layout]'s rooms, within
## [param step] of its floor; 0 on open deck.
static func enclosure(layout: ShipLayout, feet: Vector3, step: float) -> float:
	return 1.0 if layout.room_at(feet, step) != -1 else 0.0


## The cutoff of everything heard from outside, by how enclosed the listener is, or
## whether its ears are [param under] the sea.
static func outside_cutoff_hz(enclosure: float, under: bool = false) -> float:
	if under:
		return UNDER_HZ
	return _sweep(OPEN_HZ, ENCLOSED_HZ, clampf(enclosure, 0.0, 1.0))


## The cutoff of every cue in the room, by whether the ears are [param under] the sea.
static func cue_cutoff_hz(under: bool) -> float:
	return UNDER_CUE_HZ if under else OPEN_HZ


static func reverb_wet(enclosure: float) -> float:
	return ENCLOSED_WET * clampf(enclosure, 0.0, 1.0)


## 0 at the water, 1 at [param far] metres above it or higher.
static func _height(above_sea: float, far: float) -> float:
	return clampf(above_sea / far, 0.0, 1.0)


## From [param from] to [param to] evenly in octaves, as the ear hears a cutoff move.
static func _sweep(from: float, to: float, weight: float) -> float:
	return from * pow(to / from, weight)
