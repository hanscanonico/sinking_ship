class_name SinkEvent
extends Resource
## One scheduled event of a sinking (D7): when it happens, how far the sinking
## stream may move it, how long it is telegraphed, and what it does. Which side a
## lurch puts down and which platform gives way are its own numbers, never a rule.

## LURCH: the heel swings out by heel_deg and back over duration, so every body
## past the grip angle slides with the deck. COLLAPSE: every platform called
## platform stops being a surface. RAILING_FAIL: the layout's railing at railing
## stops holding. PLUNGE: the plunge begins — it marks the keyframes, it moves
## nothing.
enum Kind { LURCH, COLLAPSE, RAILING_FAIL, PLUNGE }

@export var kind: Kind
## Seconds after the scenario's start, before jitter.
@export var at: float
## The most the sinking stream moves it, either way, in seconds.
@export var jitter: float
## LURCH, COLLAPSE: seconds it is telegraphed before it happens. Nothing else is.
@export var warning: float
## LURCH: the heel added at the height of the swing, signed — positive puts
## starboard down.
@export var heel_deg: float
## LURCH: seconds the swing takes, out and back.
@export var duration: float
## COLLAPSE: the name of the platforms that give way.
@export var platform: StringName
## RAILING_FAIL: the railing that fails, by its index in [member ShipLayout.railings].
@export var railing: int


## Every reason this event cannot run; empty when it can.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if at < 0.0 or jitter < 0.0 or warning < 0.0:
		found.append("sinking: an event's time, jitter and warning must not be negative")
	if kind == Kind.LURCH and duration <= 0.0:
		found.append("sinking: a lurch must take some time")
	if kind == Kind.COLLAPSE and platform == &"":
		found.append("sinking: a collapse must name a platform")
	if kind == Kind.RAILING_FAIL and railing < 0:
		found.append("sinking: a railing failure must name a railing")
	return found
