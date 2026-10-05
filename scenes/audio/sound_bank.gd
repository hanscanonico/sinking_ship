class_name SoundBank
extends RefCounted
## What every cue kind sounds like and how it carries: the files it draws from —
## a footfall and a landing by what they come down on — its level, its bus, and
## for a positional cue the distance it plays at that level and the farthest it is
## heard. Every file is listed in assets/LICENSES.md.

const DIR := "res://assets/audio/"
## The bus every positional cue plays on: the reverb of the room the listener is in.
const ROOM_BUS := &"Room"
const STING_BUS := &"Music"
## A seat's own sounds, heard in the head, sit this far under the same sounds heard
## from someone else close by.
const IN_HEAD_DB := -6.0
## A heavy cue — a full charge's whoosh and impact — plays this much lower and
## louder than its kind.
const HEAVY_PITCH := 0.8
const HEAVY_DB := 3.0

const STEPS := {
	AudioCue.Ground.WOOD:
	[
		"steps/wood_0.wav",
		"steps/wood_1.wav",
		"steps/wood_2.wav",
		"steps/wood_3.wav",
		"steps/wood_4.wav"
	],
	AudioCue.Ground.METAL:
	[
		"steps/metal_0.wav",
		"steps/metal_1.wav",
		"steps/metal_2.wav",
		"steps/metal_3.wav",
		"steps/metal_4.wav"
	],
	AudioCue.Ground.WET:
	["steps/wet_0.wav", "steps/wet_1.wav", "steps/wet_2.wav", "steps/wet_3.wav"],
}
const LANDINGS := {
	AudioCue.Ground.WOOD:
	["brawl/land_wood_0.wav", "brawl/land_wood_1.wav", "brawl/land_wood_2.wav"],
	AudioCue.Ground.METAL:
	["brawl/land_metal_0.wav", "brawl/land_metal_1.wav", "brawl/land_metal_2.wav"],
	AudioCue.Ground.WET: ["brawl/land_wet_0.wav", "brawl/land_wet_1.wav"],
}
const FILES := {
	AudioCue.Kind.GRUNT:
	["brawl/grunt_0.wav", "brawl/grunt_1.wav", "brawl/grunt_2.wav", "brawl/grunt_3.wav"],
	AudioCue.Kind.WHOOSH:
	["brawl/whoosh_0.wav", "brawl/whoosh_1.wav", "brawl/whoosh_2.wav", "brawl/whoosh_3.wav"],
	AudioCue.Kind.IMPACT:
	[
		"brawl/impact_0.wav",
		"brawl/impact_1.wav",
		"brawl/impact_2.wav",
		"brawl/impact_3.wav",
		"brawl/impact_4.wav",
	],
	AudioCue.Kind.VAULT: ["brawl/vault_0.wav", "brawl/vault_1.wav", "brawl/vault_2.wav"],
	AudioCue.Kind.FALL: ["brawl/fall_0.wav", "brawl/fall_1.wav", "brawl/fall_2.wav"],
	AudioCue.Kind.SPLASH: ["brawl/splash_0.wav", "brawl/splash_1.wav", "brawl/splash_2.wav"],
	AudioCue.Kind.WIN_STING: ["ship/bell.wav"],
	AudioCue.Kind.LOSS_STING: ["ship/bell.wav"],
	AudioCue.Kind.CREAK:
	[
		"ship/creak_0.wav",
		"ship/creak_1.wav",
		"ship/creak_2.wav",
		"ship/creak_3.wav",
		"ship/creak_4.wav",
		"ship/creak_5.wav",
	],
	AudioCue.Kind.GROAN: ["ship/groan_0.wav", "ship/groan_1.wav", "ship/groan_2.wav"],
	AudioCue.Kind.FLOOD: ["ship/flood_0.wav", "ship/flood_1.wav"],
	AudioCue.Kind.HORN: ["ship/horn.wav"],
	AudioCue.Kind.COLLAPSE: ["ship/collapse_0.wav"],
	## Wet footfalls, slowed: a hand through the water.
	AudioCue.Kind.STROKE:
	["steps/wet_0.wav", "steps/wet_1.wav", "steps/wet_2.wav", "steps/wet_3.wav"],
	## The hull's creaks, quick and high: wood dragged over planks.
	AudioCue.Kind.SCRAPE:
	[
		"ship/creak_0.wav",
		"ship/creak_1.wav",
		"ship/creak_2.wav",
		"ship/creak_3.wav",
		"ship/creak_4.wav",
		"ship/creak_5.wav",
	],
	## A body's landing on planks, low: a laden crate.
	AudioCue.Kind.THUD: ["brawl/land_wood_0.wav", "brawl/land_wood_1.wav", "brawl/land_wood_2.wav"],
	## A deck giving way, short and high: one span of rail.
	AudioCue.Kind.CRACK: ["ship/collapse_0.wav"],
	## Plates struck hard, far down: the iceberg booming through the hull.
	AudioCue.Kind.HOLED:
	["brawl/land_metal_0.wav", "brawl/land_metal_1.wav", "brawl/land_metal_2.wav"],
}
## How each kind carries: its level in dB; for a positional cue the distance it
## plays at that level ("near") and the farthest it is heard ("far"), in metres;
## and its pitch.
const CARRY := {
	AudioCue.Kind.FOOTSTEP: {"db": -8.0, "near": 2.5, "far": 25.0},
	AudioCue.Kind.GRUNT: {"db": -5.0, "near": 3.0, "far": 30.0},
	AudioCue.Kind.WHOOSH: {"db": -4.0, "near": 3.0, "far": 25.0},
	AudioCue.Kind.IMPACT: {"db": -2.0, "near": 4.0, "far": 40.0},
	AudioCue.Kind.VAULT: {"db": -5.0, "near": 4.0, "far": 35.0},
	AudioCue.Kind.FALL: {"db": -8.0, "near": 3.0, "far": 25.0},
	AudioCue.Kind.LANDING: {"db": -3.0, "near": 4.0, "far": 40.0},
	AudioCue.Kind.SPLASH: {"db": 0.0, "near": 6.0, "far": 60.0},
	AudioCue.Kind.WIN_STING: {"db": -4.0},
	## The same bell, a fourth lower and slower: the knell.
	AudioCue.Kind.LOSS_STING: {"db": -4.0, "pitch": 0.75},
	AudioCue.Kind.CREAK: {"db": -9.0, "near": 4.0, "far": 30.0},
	AudioCue.Kind.GROAN: {"db": -1.0, "near": 25.0, "far": 150.0},
	AudioCue.Kind.FLOOD: {"db": -2.0, "near": 12.0, "far": 100.0},
	AudioCue.Kind.HORN: {"db": 0.0, "near": 60.0, "far": 400.0},
	AudioCue.Kind.COLLAPSE: {"db": 0.0, "near": 10.0, "far": 80.0},
	AudioCue.Kind.STROKE: {"db": -6.0, "near": 2.5, "far": 25.0, "pitch": 0.8},
	AudioCue.Kind.SCRAPE: {"db": -8.0, "near": 3.0, "far": 30.0, "pitch": 1.6},
	AudioCue.Kind.THUD: {"db": -1.0, "near": 4.0, "far": 45.0, "pitch": 0.7},
	AudioCue.Kind.CRACK: {"db": -2.0, "near": 6.0, "far": 60.0, "pitch": 1.4},
	AudioCue.Kind.HOLED: {"db": 3.0, "near": 40.0, "far": 250.0, "pitch": 0.4},
}

var _streams := {}


## Whether there is a device to hear anything on. The Dummy driver — every headless
## run, and windowed runs started with --audio-driver Dummy — has none, and a
## playback still alive as the engine quits is reported leaked, so nothing is
## started there; cues are still planned and announced.
static func audible() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


## One stream for [param kind] — on [param ground] for a footfall or a landing —
## that picks among its files, never the same one twice running, with a little
## give in pitch and level so no two sound alike.
func stream(kind: AudioCue.Kind, ground: AudioCue.Ground = AudioCue.Ground.WOOD) -> AudioStream:
	var key := Vector2i(kind, ground)
	if not _streams.has(key):
		var picks := AudioStreamRandomizer.new()
		picks.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		picks.random_pitch = 1.08
		picks.random_volume_offset_db = 1.5
		for file: String in files(kind, ground):
			picks.add_stream(-1, load(DIR + file))
		_streams[key] = picks
	return _streams[key]


static func files(kind: AudioCue.Kind, ground: AudioCue.Ground = AudioCue.Ground.WOOD) -> Array:
	match kind:
		AudioCue.Kind.FOOTSTEP:
			return STEPS[ground]
		AudioCue.Kind.LANDING:
			return LANDINGS[ground]
	return FILES[kind]


static func db(kind: AudioCue.Kind) -> float:
	return CARRY[kind]["db"]


static func near(kind: AudioCue.Kind) -> float:
	return CARRY[kind].get("near", 10.0)


static func far(kind: AudioCue.Kind) -> float:
	return CARRY[kind].get("far", 0.0)


static func pitch(kind: AudioCue.Kind) -> float:
	return CARRY[kind].get("pitch", 1.0)


static func bus(kind: AudioCue.Kind) -> StringName:
	if kind == AudioCue.Kind.WIN_STING or kind == AudioCue.Kind.LOSS_STING:
		return STING_BUS
	return ROOM_BUS
