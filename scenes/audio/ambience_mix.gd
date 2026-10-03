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
## Quieter than this is off.
const SILENT_DB := -60.0
## Fully enclosed, the outside is heard through the hull: muffled to ENCLOSED_HZ,
## the wind down by ENCLOSED_WIND_DB, and the room's own reverb at ENCLOSED_WET.
const OPEN_HZ := 20000.0
const ENCLOSED_HZ := 700.0
const ENCLOSED_WIND_DB := -18.0
const ENCLOSED_WET := 0.35


static func sea_db(above_sea: float) -> float:
	return lerpf(SEA_NEAR_DB, SEA_FAR_DB, _height(above_sea, SEA_FAR_M))


static func sea_cutoff_hz(above_sea: float) -> float:
	return _sweep(SEA_NEAR_HZ, SEA_FAR_HZ, _height(above_sea, SEA_FAR_M))


static func wind_db(above_sea: float, enclosure: float) -> float:
	var open := lerpf(WIND_LOW_DB, WIND_HIGH_DB, _height(above_sea, WIND_HIGH_M))
	return open + ENCLOSED_WIND_DB * clampf(enclosure, 0.0, 1.0)


## [param sink_rate] is how fast the ship is settling, metres a second.
static func rush_db(sink_rate: float, above_sea: float) -> float:
	var pace := clampf(sink_rate / RUSH_FULL_RATE, 0.0, 1.0)
	var near := lerpf(1.0, RUSH_FAR_SHARE, _height(above_sea, SEA_FAR_M))
	return maxf(RUSH_DB + linear_to_db(pace * near), SILENT_DB)


## 1 when feet at [param feet] stand in one of [param layout]'s rooms, within
## [param step] of its floor; 0 on open deck.
static func enclosure(layout: ShipLayout, feet: Vector3, step: float) -> float:
	return 1.0 if layout.room_at(feet, step) != -1 else 0.0


## The cutoff of everything heard from outside, by how enclosed the listener is.
static func outside_cutoff_hz(enclosure: float) -> float:
	return _sweep(OPEN_HZ, ENCLOSED_HZ, clampf(enclosure, 0.0, 1.0))


static func reverb_wet(enclosure: float) -> float:
	return ENCLOSED_WET * clampf(enclosure, 0.0, 1.0)


## 0 at the water, 1 at [param far] metres above it or higher.
static func _height(above_sea: float, far: float) -> float:
	return clampf(above_sea / far, 0.0, 1.0)


## From [param from] to [param to] evenly in octaves, as the ear hears a cutoff move.
static func _sweep(from: float, to: float, weight: float) -> float:
	return from * pow(to / from, weight)
