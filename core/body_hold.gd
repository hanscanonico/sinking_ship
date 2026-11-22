class_name BodyHold
extends RefCounted
## What holds a body back in the deck plane (Surfaces.obstacle_contacts, D6), asked the
## one way by all that move one: Movement, as a body walks, slides or is knocked on; and
## Hazards, as a crate runs into one or leans on it — her walls hold a body a crate pushes
## as they hold one that walks, so a crate never puts a body into a wall, to come out of
## its far side.


## What holds back [param player] of [param rules] with its feet at [param feet], as
## [param surfaces] has her: on its feet it ducks under whatever it has a floor to crawl
## under, and off them it is held by what its height where it is meets; in the air it
## steps onto nothing (Movement.AIR_STEP), and a swimmer steps [param swim_step].
static func contacts(
	surfaces: Surfaces, rules: BrawlRules, player: PlayerState, feet: Vector3, swim_step: float
) -> Array[Surfaces.Contact]:
	var step := rules.step_height
	var height := rules.body_height
	var crawl := rules.crawl_height
	if player.body != PlayerState.Body.GROUNDED:
		height = rules.height_at(surfaces, player.pos)
		crawl = INF
	if player.body == PlayerState.Body.AIRBORNE:
		step = Movement.AIR_STEP
	elif player.body == PlayerState.Body.SWIMMING:
		step = swim_step
	return surfaces.obstacle_contacts(feet, rules.body_radius, height, step, Surfaces.NONE, crawl)


## [param player], on its feet or in the air, just pushed by [param crate] — the two
## touching at [param reach] between their middles — is put back out of whatever of
## [param surfaces] holds it there but a crate (those part from it in their own turn):
## a wall, a blocker, a deck edge, a shut door. What the wall gives back the crate takes:
## it is moved out of the body, and keeps no more speed toward the body than the body
## keeps going on from it once the wall has taken what goes into it — against a body a
## wall holds, the crate stops as against the wall, and as against a wall it is given no
## speed: a body the wall leaves going at the crate meets it in its own move, as any body
## does (Movement). A body no wall holds is left as it is.
static func walled(
	surfaces: Surfaces, rules: BrawlRules, player: PlayerState, crate: PropState, reach: float
) -> void:
	var moving := player.held_vel if player.is_frozen() else player.vel
	var kept := Vector2(moving.x, moving.z)
	var held := false
	for contact: Surfaces.Contact in contacts(surfaces, rules, player, player.pos, 0.0):
		if contact.prop != -1:
			continue
		held = true
		player.pos += Vector3(contact.normal.x, 0.0, contact.normal.y) * contact.depth
		var into := -kept.dot(contact.normal)
		if into > 0.0:
			kept += contact.normal * into
	if not held:
		return
	var offset := Vector2(player.pos.x - crate.pos.x, player.pos.z - crate.pos.z)
	var distance := offset.length()
	if distance >= reach or distance == 0.0:
		return
	var normal := offset / distance
	crate.pos -= Vector3(normal.x, 0.0, normal.y) * (reach - distance)
	var planar := Vector2(crate.vel.x, crate.vel.z)
	var faster := planar.dot(normal) - maxf(kept.dot(normal), 0.0)
	if faster > 0.0:
		planar -= normal * faster
		crate.vel = Vector3(planar.x, crate.vel.y, planar.y)
