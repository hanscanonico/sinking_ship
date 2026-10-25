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

### Bodies aboard her

**Headroom**:
The height from a body's floor, a deck or a stair (never a blocker's top or a crate's lid),
up to the lowest underside over it.
_Avoid_: clearance, ceiling height

**Crawl space**:
Wherever a floor has headroom to crawl but not to stand: less than the rules'
`body_height`, at least their `crawl_height`. A body there crawls, `crawl_height` tall, at
`crawl_speed`, and cannot jump; it follows from where the body is, never from a button. A
room holding one is marked a crawl space for the lint and the bots' routes.
_Avoid_: crouch, crawlway, duct

**Seat rules**:
The rules as they stand for one seat: the brawl rules, but for the few that what the seat
has may change — what holding the prop in its hands costs it, and its bonus. Worked out
from what the seat has, never kept in the snapshot.
_Avoid_: stats, modifiers, buffs

### What she carries

**Prop**:
A loose thing of hers that the match moves and keeps in the snapshot: a crate of cargo, a
light crate, a lifebuoy, a bottle, a bucket, a deck chair, a laid saloon's dining tables
and chairs. Each is put there by her layout (where it starts and faces, its size, mass and
grip) as one of a prop kind, and none comes back once the sea has it. Modelled art that
only dresses her — the hero props and the rest of the furniture of `assets/models` — is
dressing, not props: never in the snapshot, never held.
_Avoid_: item, pickup, object, loot

**Prop kind**:
What a kind of prop is, the same for every one of it: whether a Grab press takes it and
what holding it costs, whether it is solid — a blocker, a shove's target, its top a lid or
not — how it meets the water and bodies while loose, and what it does in the sea. One data
file each, as the bot tiers are.
_Avoid_: item type, prop class

**Furniture**:
A prop of a kind that floats aboard and gives way: a laid saloon's dining tables and
chairs. The water lifts a piece only at its own draft and it rides that deep, pressed
under a ceiling rather than lost; a body walking into it pushes it before it; a chair is
harmless — it never staggers anyone — and has no lid.
_Avoid_: decor, object, debris

**Holder**:
The seat holding a prop, kept on the prop and nowhere else: what a seat holds is asked of
the props.
_Avoid_: owner, carrier, wielder

**Knocked loose**:
Out of its holder's hands by a hit, at its feet: a lifebuoy only by a landed charged shove.
Letting go by a Grab press is not being knocked loose; a bot that steals knocks a ring
loose so as to take it.
_Avoid_: disarmed, dropped

### What comes aboard

**Bonus**:
Something that comes aboard during a match at a bonus spot in a dry room below her main
deck. A Grab press takes it and uses it up at once, giving the seat that took it an edge,
through a rule there already is, until that seat is out (Double life: until it is spent).
A seat has one at a time.
_Avoid_: power-up, pickup, item, perk, buff, boon, loot, stores (a room's name and a flood
cell's kind)

**Bonus kind**:
What a kind of bonus is, the same for every one of it: its title, its size and mark, and
what it changes for its taker. One data file each, as prop kinds are.

**Bonus spot**:
A point on a floor in a room below her main deck, one per such room, put there by her
layout, where a bonus can come. The seed says which and when.

### Watching her again

**Replay**:
A finished local match watched again: the sim run from its input log (D4) and drawn as it
was played, through any seat's eyes or from the orbit camera, paused, sped up or sought to
any tick. Nothing of what happened is kept — the seed and the frames make it again.
_Avoid_: recording, video, save

**Orbit camera**:
The replay viewer's elevated view: an eye orbiting a pivot — the seat watched, or wherever
it was panned — over the sea and outside her hull. The one elevated view a player ever
gets (D14); the observer camera stays a tool, and the free camera is an out seat's in play.
_Avoid_: spectator camera, overhead, drone

### Her hull and the ways into her

**Fitted**:
Said of a platform, ramp or blocker that stands inside a hull's lines where they already
leave room for it: her drawn hull is lofted round everything else, never round it, so her
sections stay as they are. The spaces in the steamer's old voids are fitted (#148).
_Avoid_: inset, internal

**Scuttle**:
A small hatch into a space under a deck, battened and dogged watertight: shut in the flood
model, never weeping or giving way, so the space under it floods as it did before it was a
place, while bodies pass through it as through a doorway (#148). A manhole in a tank top
is one.
_Avoid_: trapdoor
