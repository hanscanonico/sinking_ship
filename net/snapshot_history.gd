class_name SnapshotHistory
extends RefCounted
## The snapshots a client holds from its host, oldest first, kept for a second behind
## the newest — each with every seat of the match, by id: a snapshot that lists only
## some (D11, SH22) keeps the others where the one before it had them. Between two of
## them, a tick is drawn by interpolating the bodies and the crates.

## How far behind the newest a snapshot is kept.
const KEPT_TICKS := Ticks.RATE

var _snapshots: Array[Dictionary] = []


## A history that starts at [param first], a snapshot with every seat.
func _init(first: Dictionary) -> void:
	_snapshots.append(first)


func newest() -> Dictionary:
	return _snapshots[-1]


## Takes [param snapshot] in where its tick falls; true when it is the newest yet.
## One already held, or older than any kept, is ignored.
func add(snapshot: Dictionary) -> bool:
	var tick: int = snapshot["tick"]
	var index := _snapshots.size()
	while index > 0 and _snapshots[index - 1]["tick"] >= tick:
		if _snapshots[index - 1]["tick"] == tick:
			return false
		index -= 1
	if index == 0:
		return false
	_snapshots.insert(index, _whole(snapshot, _snapshots[index - 1]))
	var newer := index == _snapshots.size() - 1
	while _snapshots[0]["tick"] < newest()["tick"] - KEPT_TICKS:
		_snapshots.pop_front()
	return newer


## The match at [param tick] as the host had it: the snapshot of that tick, or the
## bodies and crates part of the way between the two either side of it — held at the
## oldest or the newest outside them. A copy whose top level and seat list may be
## changed.
func at(tick: int) -> Dictionary:
	var before := _snapshots[0]
	var after := before
	for snapshot: Dictionary in _snapshots:
		after = snapshot
		if snapshot["tick"] > tick:
			break
		before = snapshot
	var view := before.duplicate()
	var span: int = after["tick"] - before["tick"]
	if span <= 0 or tick <= before["tick"]:
		view["seats"] = (before["seats"] as Array).duplicate()
		return view
	var alpha := float(tick - before["tick"]) / span
	view["seats"] = _between(before["seats"], after["seats"], alpha)
	view["props"] = _between(before["props"], after["props"], alpha)
	return view


## [param snapshot] with every seat [param earlier] has that it leaves out, in seat
## order.
static func _whole(snapshot: Dictionary, earlier: Dictionary) -> Dictionary:
	var seats: Array[Dictionary] = []
	for entry: Dictionary in earlier["seats"]:
		seats.append(entry)
	for entry: Dictionary in snapshot["seats"]:
		var seat: int = entry["seat"]
		if seat < seats.size():
			seats[seat] = entry
	var whole := snapshot.duplicate()
	whole["seats"] = seats
	return whole


## Each entry of [param then] — seats or crates, in the same order as [param now] —
## [param alpha] of the way to [param now]'s: where it is, how fast and, for a seat,
## where it faces; the rest as [param then] has it.
static func _between(then: Array, now: Array, alpha: float) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in then.size():
		var from: Dictionary = then[index]
		var to: Dictionary = now[index]
		var entry := from.duplicate()
		entry["pos"] = (from["pos"] as Vector3).lerp(to["pos"], alpha)
		entry["vel"] = (from["vel"] as Vector3).lerp(to["vel"], alpha)
		if entry.has("facing"):
			entry["facing"] = lerp_angle(from["facing"], to["facing"], alpha)
		entries.append(entry)
	return entries
