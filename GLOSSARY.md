# Sinking Ship

A first-person battle-royale survival brawl on a sinking ship with rooms. The match is a
Node-free simulation that scenes only draw; the design of record is
`.lavish/sinking-ship-plan.html`, whose D-decisions stand in for ADRs.

## Language

### Setting up a match

**Match choices**:
What a player picks before a match: ship, seats, bot tier, seed, pace, goal and whether
bonuses come aboard, and, from the command line only, scenario and hit. A choice left unmade
means the match data's.
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
has may change — what holding the prop in its hands costs it, and its bonuses. Worked out
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
Bonuses add up: one taken replaces none the seat has, and a seat takes any number, of any
kind. Each further one of a kind gives more again, by less each time — a share of what the
one before it gave — so the rules a kind moves never pass a furthest; each Double life is a
whole spare meter. One nobody takes is lost when the sea gets to it: water at its
spot, her turned past its floor, or the piece of her it lies in gone.
_Avoid_: power-up, pickup, item, perk, buff, boon, loot, stores (a room's name and a flood
cell's kind)

**Bonus kind**:
What a kind of bonus is, the same for every one of it: its title, its size, its mark and its
icon, what it changes for its taker, and what each further one of it gives as a share of
the one before. One data file each, as prop kinds are.

**Bonus spot**:
A point on a floor in a room below her main deck, one per such room, put there by her
layout, where a bonus can come. The seed says which and when.

**Open spot**:
A bonus spot a planned bonus may come to now: no bonus lies there, no water stands anywhere
on its room's floor — as the water stands now, never as it will (D10) — and the piece of her
it lies in still stands, on her decks.
_Avoid_: free spot, empty spot

**Bonus plan**:
The bonuses a match plans to bring aboard, drawn once at its start from a seeded stream of
their own, on her sinking's clock: when each comes, its kind, and which open spot it takes.
A planned bonus with the most already aboard, or no spot open, never comes.
_Avoid_: spawn schedule, drop table, loot table

**Cold meter**:
The seconds a seat may swim before the cold puts it out: the water's on its body, draining
while it swims wherever its head is, and coming back slowly out of the sea. The HUD reads
it as warmth, and as frost at the screen's edges.
_Avoid_: health, air, oxygen

**Breath**:
The seconds a swimmer lasts with its head under the water — held down by a deck with no
air under it, or dunked by a dive: out of it, the seat drowns. It comes back fast with its
head in the air, afloat on the sea, in a pocket or on its feet. Never the cold meter's:
a head in the air keeps its breath and the body stays as cold.
_Avoid_: oxygen, air meter, health

**Spare meter**:
What Double life gives its taker: a second cold meter and a second breath, filling both
again as either runs out in the sea, once. Unspent, it counts as a full meter more of cold
left in the last swim.
_Avoid_: extra life, respawn

### Watching her again

**Replay**:
A finished local match watched again: the sim run from its input log (D4) and drawn as it
was played, through any seat's eyes or from the free camera, paused, sped up or sought to
any tick. Nothing of what happened is kept — the seed and the frames make it again.
_Avoid_: recording, video, save

**Free camera**:
The one detached view a player ever gets (D14): an out seat's in play, a watcher's and the
replay viewer's. Flown by hand round the decks, over the sea and under it, through
anything: down under her hull as deep as her sinking takes it, or to a shallower sea's
bottom. It opens over the sea, a watcher's and a replay's framing the whole ship.
**Following**, it trails the seat watched at the offset it locked on at, until flown by
hand or let go. The observer camera stays a tool.
_Avoid_: orbit camera, spectator camera, overhead, drone

**Ghost**:
The view that walks her decks as a seat in the match does, for whoever may fly the free
camera: an out seat, a watcher, the replay viewer. Its body moves by the living seat's own
rules through Surfaces — it walks, jumps, takes the stairs, is held by walls, doors and
railings and stands on the tilting deck, with a seat's eyes — but water neither slows nor
drowns it. It starts where the out seat went out while that spot is still on her, else at
the seat watched. Presentation only: never in the sim, a snapshot, a digest, a replay or on
the wire; nobody sees it, no rule or bot reads it, and it shoves and is shoved by nothing.
Off her, or once she is gone, the view falls back to the free camera.
_Avoid_: noclip, phantom, spirit

**Watch**:
A local match nobody plays, chosen from the menu in place of Play: bots take every seat,
and the watcher looks through any dry seat's eyes or from the free camera, switching at
will all match long — for a stream, say. Its results name who won; it is kept in the
replays like a match played. A member of an online room may watch too: they take no seat
when the host starts, bots and the other members play, and they see the room's match
with the same views and results; they count toward the room's players_per_room.
_Avoid_: observer (the observer camera is a tool), spectator (an out seat spectates)

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

**Language**:
What the game words its screens in: English, as the code and the scenes write it, or a
catalog under `locale/` keyed by that English — French and Spanish. The system's until
the player picks one in the settings. Presentation only: transcripts, logs and the
command line stay English.
_Avoid_: locale, translation (for the choice itself)
