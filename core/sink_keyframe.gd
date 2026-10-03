class_name SinkKeyframe
extends Resource
## One point on a sinking's timeline. Signed, so no end or side is assumed (D7):
## positive trim is bow down, positive heel is starboard down.

## Seconds after the scenario's start.
@export var at: float
## Metres the pivot has dropped below its level-and-unsunk height.
@export var sink: float
@export var trim_deg: float
@export var heel_deg: float
