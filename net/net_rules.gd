class_name NetRules
extends Resource
## How the match travels between a host and its clients (D11), authored in seconds
## and converted to ticks by Ticks; the numbers live in data/net/net.tres. A client
## over an instant wire (Transport.instant) — the offline game's — needs no lead and
## no interpolation delay, and takes none.

const PATH := "res://data/net/net.tres"

## Ticks between two snapshots the host sends each client.
@export var snapshot_interval: int
## How far behind the newest snapshot a client draws the seats it does not play:
## enough to hold a late or a lost snapshot.
@export var interp_delay: float
## How many ticks of frames each input packet carries, the newest last — and how many
## snapshots back the events in each snapshot reach — so a lost packet costs nothing.
@export var input_redundancy: int
## How early a client's frame should reach the host before its tick is stepped, and
## how much earlier than that it may come before the client stops running so far
## ahead: the client keeps its lead inside that band.
@export var lead_buffer: float
@export var lead_slack: float
## The farthest a client predicts past the newest snapshot it holds; beyond it, its
## own seat waits for the host.
@export var prediction_cap: float
## The longest a client goes on trusting its prediction without resetting it to a
## snapshot: a bound on whatever drift no check catches.
@export var trust_limit: float
## How long the scene takes to draw away a correction to the local seat's predicted
## position (D12): presentation only, never the sim's.
@export var correction_time: float


static func load_default() -> NetRules:
	return load(PATH)


func interp_ticks() -> int:
	return Ticks.from_seconds(interp_delay)


func lead_ticks() -> int:
	return Ticks.from_seconds(lead_buffer)


func slack_ticks() -> int:
	return Ticks.from_seconds(lead_slack)


func prediction_cap_ticks() -> int:
	return Ticks.from_seconds(prediction_cap)


func trust_ticks() -> int:
	return Ticks.from_seconds(trust_limit)


func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if snapshot_interval < 1:
		found.append("net: snapshot_interval must be at least 1")
	if input_redundancy < 1:
		found.append("net: input_redundancy must be at least 1")
	for field: String in [
		"interp_delay", "lead_buffer", "lead_slack", "correction_time", "trust_limit"
	]:
		if float(get(field)) < 0.0:
			found.append("net: %s must not be negative" % field)
	# A seat drawn from older snapshots than the host sends would wait on every one.
	if interp_ticks() < snapshot_interval:
		found.append("net: interp_delay must cover snapshot_interval")
	if slack_ticks() < 1:
		found.append("net: lead_slack must be at least a tick")
	if prediction_cap_ticks() <= lead_ticks() + slack_ticks():
		found.append("net: prediction_cap must be beyond lead_buffer and lead_slack")
	# Shorter, every snapshot would reset the prediction: trust turned off unsaid.
	if trust_ticks() < snapshot_interval:
		found.append("net: trust_limit must cover snapshot_interval")
	return found
