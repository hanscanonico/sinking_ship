class_name ContactsNative
extends RefCounted
## The floating furniture's contacts in the game's extension (native/, #410): where her
## solid props stand (PropStands, a NativeStands), what holds a circle back in the deck
## plane (Surfaces.obstacle_contacts, a NativeSurfaces) and the cargo's contact passes
## (Hazards._move, a NativeCrates), each worked to the same answers bit for bit
## (test_contacts_native). The GDScript keeps every state and hands the extension a
## mirror of it. None where the extension is not loaded — the web, a checkout that never
## ran make native — and the GDScript answers itself.

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
