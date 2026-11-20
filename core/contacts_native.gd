class_name ContactsNative
extends RefCounted
## The floating furniture's contacts in the game's extension (native/, #410): where her
## solid props stand (PropStands, a NativeStands), what holds a circle back in the deck
## plane (Surfaces.obstacle_contacts, a NativeSurfaces), the cargo's contact passes
## (Hazards._move, a NativeCrates) and its rest test (Hazards._stirring, a NativeRest),
## each worked to the same answers bit for bit (test_contacts_native, test_rest_native).
## The GDScript keeps every state and hands the extension a mirror of it. None where the
## extension is not loaded — the web, a checkout that never ran make native — and the
## GDScript answers itself.

## For tests: every PropStands, Surfaces and Hazards made while this is set answers in
## GDScript, as where the extension is not loaded — the twin a cross-check holds the
## extension's answers to.
static var off := false


## Whether what is made now asks the extension.
static func loaded() -> bool:
	return not off and ClassDB.class_exists(&"NativeCrates")


## A new object of the extension's class [param name].
static func made(name: StringName) -> Object:
	return ClassDB.instantiate(name)


## A NativeCrates working the contact passes of crates [param props] under
## [param rules] over [param surfaces] (a NativeSurfaces) with those at rest standing in
## [param at_rest] (a NativeStands).
static func crates(
	surfaces: Object, at_rest: Object, props: Array[ShipProp], rules: BrawlRules
) -> Object:
	var native := made(&"NativeCrates")
	var radii := PackedFloat64Array()
	var heights := PackedFloat64Array()
	var masses := PackedFloat64Array()
	var solid := PackedByteArray()
	var harmless := PackedByteArray()
	for prop: ShipProp in props:
		var kind := prop.prop_kind()
		radii.append(prop.radius)
		heights.append(prop.height)
		masses.append(prop.mass)
		solid.append(1 if kind.solid else 0)
		harmless.append(1 if kind.harmless else 0)
	var numbers := PackedFloat64Array(
		[
			rules.step_height,
			rules.railing_height,
			rules.railing_break_speed,
			rules.crate_impact_speed,
			rules.crate_restitution,
			Ticks.from_seconds(rules.credit_window),
			Movement.CONTACT_PASSES,
		]
	)
	native.setup(surfaces, at_rest, radii, heights, masses, solid, harmless, numbers)
	return native


## A NativeRest deciding Hazards._stirring's crates at rest, theirs [param grips] and
## [param lifts]; null where the extension, or a build of it this new, is not loaded.
static func rest(grips: PackedFloat64Array, lifts: PackedFloat64Array) -> Object:
	if not loaded() or not ClassDB.class_exists(&"NativeRest"):
		return null
	var native := made(&"NativeRest")
	native.setup(grips, lifts)
	return native


## [param found], the extension's contacts five numbers each — normal x and z, depth,
## railing, prop — as Surfaces hands them out.
static func contacts_of(found: PackedFloat64Array) -> Array[Surfaces.Contact]:
	var contacts: Array[Surfaces.Contact] = []
	var at := 0
	while at < found.size():
		var contact := Surfaces.Contact.new(
			Vector2(found[at], found[at + 1]), found[at + 2], int(found[at + 3])
		)
		contact.prop = int(found[at + 4])
		contacts.append(contact)
		at += 5
	return contacts
