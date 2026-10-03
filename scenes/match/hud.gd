class_name Hud
extends CanvasLayer
## Seats left, the match clock and the tilt gauge, read from the latest snapshot
## and the pose SinkSchedule gives for its tick.

const TILT_COLOUR := Color(1.0, 1.0, 1.0)
const STEEP_COLOUR := Color(1.0, 0.72, 0.2)

var _schedule: SinkSchedule
var _grip_angle_deg: float

@onready var _seats_left: Label = %SeatsLeft
@onready var _clock: Label = %Clock
@onready var _tilt: Label = %Tilt


func setup(sim: MatchSim) -> void:
	_schedule = sim.schedule
	_grip_angle_deg = sim.config.rules.grip_angle_deg


func show_snapshot(snapshot: Dictionary) -> void:
	var seats: Array = snapshot["seats"]
	var left := 0
	for entry: Dictionary in seats:
		if not entry["out"]:
			left += 1
	_seats_left.text = "Seats left %d / %d" % [left, seats.size()]
	_clock.text = MatchTranscript.clock(snapshot["tick"])
	_show_tilt(_schedule.pose_at(snapshot["tick"]))


## Signed trim and heel, naming the end and side that are low; amber once the
## deck is steeper than the grip angle.
func _show_tilt(pose: ShipPose) -> void:
	var low_end := _low(pose.trim_deg, "bow", "stern")
	var low_side := _low(pose.heel_deg, "starboard", "port")
	_tilt.text = (
		"Trim %+.1f° %s\nHeel %+.1f° %s" % [pose.trim_deg, low_end, pose.heel_deg, low_side]
	)
	var steep := pose.slope_deg() > _grip_angle_deg
	_tilt.add_theme_color_override("font_color", STEEP_COLOUR if steep else TILT_COLOUR)


static func _low(signed_deg: float, positive: String, negative: String) -> String:
	if is_zero_approx(signed_deg):
		return "level"
	return "%s low" % (positive if signed_deg > 0.0 else negative)
