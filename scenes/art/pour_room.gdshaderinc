// The room a pour falls into, and the froth where it lands (spill.gdshader,
// froth.gdshader): a sheet is hung level with the world across its opening's whole
// width and falls along the world's down, so on a ship that leans, a wide opening's
// sheet leaves her — a hatch's stands over the deck at its low end, a hold's lining's
// runs out through her deck and her bottom — and, drawn over the sea, shows through it.
// Each is drawn only inside the box of the cell it falls into (InnerWater), as a cell's
// own water is drawn only inside its own (inner_water.gdshader).

// The world to her ship space, as drawn this frame (InnerWater): the global of its slot,
// set once a frame for every sheet, or with none free (slot -1) its own; and the box it
// is kept in there — everywhere, for one that falls into the sea or is kept in none.
global uniform mat4 inner_water_to_ship_0;
global uniform mat4 inner_water_to_ship_1;
global uniform mat4 inner_water_to_ship_2;
global uniform mat4 inner_water_to_ship_3;
uniform int slot = -1;
uniform mat4 world_to_ship = mat4(1.0);
uniform vec3 room_low = vec3(-1e9);
uniform vec3 room_high = vec3(1e9);

// Where this point of the sheet stands in her ship space.
varying vec3 in_ship;

// The world point [world] in her ship space.
vec3 pour_in_ship(vec3 world) {
	mat4 to_ship = world_to_ship;
	if (slot == 0) {
		to_ship = inner_water_to_ship_0;
	} else if (slot == 1) {
		to_ship = inner_water_to_ship_1;
	} else if (slot == 2) {
		to_ship = inner_water_to_ship_2;
	} else if (slot == 3) {
		to_ship = inner_water_to_ship_3;
	}
	return (to_ship * vec4(world, 1.0)).xyz;
}

// Whether the ship-space point [ship] stands outside the room.
bool pour_out_of_room(vec3 ship) {
	return any(lessThan(ship, room_low)) || any(greaterThan(ship, room_high));
}
