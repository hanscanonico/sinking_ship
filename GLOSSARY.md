# Sinking Ship

A first-person battle-royale survival brawl on a sinking ship with rooms. The match is a
Node-free simulation that scenes only draw; the design of record is
`.lavish/sinking-ship-plan.html`, whose D-decisions stand in for ADRs.

## Language

### Setting up a match

**Match choices**:
What a player picks before a match: ship, seats, bot tier, seed, pace and goal, and, from the
command line only, scenario and hit. A choice left unmade means the match data's.
_Avoid_: match settings, picks, match request, lobby (a lobby is the arena's bot-tier mix)

### The match's truth

**Snapshot**:
The whole truth of a match at one tick: everything needed to continue it exactly, and all
that presentation, bots and remote players ever read (D5).
_Avoid_: state dump, save

**Digest**:
The fingerprint of a match's snapshots that proves two runs played the same match (D4).
_Avoid_: checksum, hash (the match hash is the build-and-data fingerprint the wire checks)

**Quantum**:
The precision a snapshot field is kept at: the digest rounds to it and the wire carries it.
_Avoid_: resolution, step
