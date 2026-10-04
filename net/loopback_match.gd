class_name LoopbackMatch
extends PlayedMatch
## A match served and played in one process (SH11): a MatchHost, and one MatchClient
## joined to it by a LoopbackTransport that lies as NetConditions say. The offline
## game is this with no lie at all, so playing alone and playing online are one code
## path, and over the honest wire the client's view is the host's snapshot of the
## same beat; each step() is one beat of the match's 30 Hz, the wire's clock moved on
## with it.

const HOST_PEER := 0
const CLIENT_PEER := 1

var host: MatchHost
var clock := NetClock.new()


## [param config]'s match, the client playing [param seat] with [param source] — or
## only watching when it is -1 — and the host running [param sources], one per seat
## by id, the client's seat's left null.
func _init(
	config: MatchConfig,
	net_rules: NetRules,
	conditions: NetConditions,
	seat: int,
	source: InputSource,
	sources: Array[InputSource]
) -> void:
	var host_end := _end(HOST_PEER, config, conditions)
	var client_end := _end(CLIENT_PEER, config, conditions)
	LoopbackTransport.link(host_end, client_end)
	var served := sources.duplicate()
	var buffer: SeatBuffer = null
	if seat >= 0:
		buffer = SeatBuffer.new(seat)
		served[seat] = buffer
	host = MatchHost.new(MatchRunner.new(MatchSim.create(config), served), host_end, net_rules)
	host.admit(CLIENT_PEER, buffer)
	client = MatchClient.new(config, net_rules, client_end, HOST_PEER, seat, source)


## One beat: the client samples and sends, the host takes it in and steps, the
## client takes in what came back. Returns the events the client's view reached.
func step() -> Array[SimEvent]:
	clock.advance(Ticks.SECONDS_PER_TICK)
	client.sample()
	host.step()
	return client.step()


func _end(peer: int, config: MatchConfig, conditions: NetConditions) -> LoopbackTransport:
	var stream := SeedStreams.derive(config.match_seed, "wire %d" % peer)
	return LoopbackTransport.new(peer, clock, conditions, stream)
