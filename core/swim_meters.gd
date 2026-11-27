class_name SwimMeters
extends RefCounted
## The two meters a swimmer runs on (#861), each its own: the cold is the water's on its
## body, the breath the air its head has not got. MatchSim counts both each tick (_water).


## Whether [param player], [param height] tall, has its head under the water it swims in
## under [param pose] with her as [param surfaces] has her: a swimmer's, not climbing, its
## head (BrawlRules.head_height) below where that water stands over it (BodyWater.height)
## — held down by a deck with no air under it, or dunked by a dive or a pour. Afloat its
## head rides above the water, in a pocket as on the open sea; and a body on its feet
## stands no deeper than it wades.
static func head_under(
	player: PlayerState, height: float, surfaces: Surfaces, rules: BrawlRules, pose: ShipPose
) -> bool:
	if player.body != PlayerState.Body.SWIMMING or player.is_climbing():
		return false
	var head := player.pos.y + rules.head_height(height)
	return head < BodyWater.height(surfaces, rules, pose, player.pos)


## One tick of the breath of [param player], [param height] tall, under [param rules]:
## running out with its head under the water (head_under), coming back at breath_regen
## with it in the air — afloat, on its feet or climbing.
static func breathe(
	player: PlayerState, height: float, surfaces: Surfaces, rules: BrawlRules, pose: ShipPose
) -> void:
	var dt := Ticks.SECONDS_PER_TICK
	if head_under(player, height, surfaces, rules, pose):
		player.breath = maxf(player.breath - dt, 0.0)
	else:
		player.breath = minf(player.breath + rules.breath_regen * dt, rules.breath_meter)


## One tick of the cold on [param player], [param height] tall, swimming and not climbing,
## its seat's rules [param mine]: its meter drains at pocket_cold_rate of the open water's
## with its head in trapped air (Q22), at the sea_cold_rate of a prop it holds that keeps
## it afloat (#273), the lower of the two where both do.
static func chill(
	player: PlayerState, height: float, mine: SeatRules, rules: BrawlRules, pose: ShipPose
) -> void:
	var head := player.pos + Vector3.UP * rules.head_height(height)
	var rate := rules.pocket_cold_rate if pose.in_pocket(head) else 1.0
	rate = minf(rate, mine.sea_cold_rate)
	player.cold = maxf(player.cold - Ticks.SECONDS_PER_TICK * rate, 0.0)


## A spare life's (Double life): both of [param player]'s meters full again.
static func refill(player: PlayerState, rules: BrawlRules) -> void:
	player.cold = rules.cold_meter
	player.breath = rules.breath_meter


## How [param player], a meter of its empty in the water, goes out: by the cold when that
## meter is, drowned when only its breath is.
static func cause(player: PlayerState) -> PlayerState.Cause:
	return PlayerState.Cause.DROWNED if player.cold > 0.0 else PlayerState.Cause.COLD
