class_name SnapshotPacket
extends RefCounted
## A snapshot as one client receives it (D11): the snapshot itself — the seats it
## lists, by id, which may be only some of the match's — and what the host says of
## that client's input.

var snapshot: Dictionary
## The tick of the last frame of this client's the host applied, or -1.
var ack: int = -1
## The newest tick this client has sent a frame for that the host has heard, or -1.
var heard: int = -1
## How many ticks before its tick was stepped that newest frame arrived: below zero,
## it came late and was dropped.
var early: int


func _init(match_snapshot: Dictionary, acked: int, newest: int, ahead: int) -> void:
	snapshot = match_snapshot
	ack = acked
	heard = newest
	early = ahead
