// See swing_native.h.

#include "swing_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

void NativeSwing::_bind_methods() {
	ClassDB::bind_method(D_METHOD("swing", "slots", "downs_of", "downs", "hang", "swing", "clock", "since", "at",
								 "rules"),
			&NativeSwing::swing);
}

// LampSwing.step for its lamps p_slots, each carried there, in order: lamp p_slots[k]
// swings toward p_downs[p_downs_of[k]], the world's down under the node it hangs from,
// by p_rules [delta, stiffness, damping, still] — its clock and its seconds since its
// power last dropped run on by delta — and comes to rest hanging straight down once it
// barely swings and barely leans off it (ShipLamp.still). Returns the hangs, swings,
// clocks and seconds since of every lamp, those swung changed; per lamp swung, whether
// it is still swinging (1) or comes to rest (0); its new basis, hung from straight
// down; and that basis at its point p_at, the transform its globe is drawn at.
Array NativeSwing::swing(const PackedInt32Array &p_slots, const PackedInt32Array &p_downs_of,
		const PackedVector3Array &p_downs, const PackedVector3Array &p_hang, const PackedVector3Array &p_swing,
		const PackedFloat64Array &p_clock, const PackedFloat64Array &p_since, const PackedVector3Array &p_at,
		const PackedFloat64Array &p_rules) const {
	const double delta = p_rules[0];
	const double stiffness = p_rules[1];
	const double damping = p_rules[2];
	const double still = p_rules[3];
	PackedVector3Array hangs = p_hang;
	PackedVector3Array swings = p_swing;
	PackedFloat64Array clocks = p_clock;
	PackedFloat64Array sinces = p_since;
	Vector3 *hang_of = hangs.ptrw();
	Vector3 *swing_of = swings.ptrw();
	double *clock_of = clocks.ptrw();
	double *since_of = sinces.ptrw();
	const Vector3 *downs = p_downs.ptr();
	const int32_t *downs_of = p_downs_of.ptr();
	const Vector3 *at = p_at.ptr();
	const int64_t count = p_slots.size();
	PackedByteArray on;
	on.resize(count);
	uint8_t *ons = on.ptrw();
	Array bases;
	bases.resize(count);
	Array placed;
	placed.resize(count);
	for (int64_t k = 0; k < count; k++) {
		const int32_t slot = p_slots[k];
		clock_of[slot] += delta;
		const Vector3 down = downs[downs_of[k]];
		Vector3 hang = hang_of[slot];
		Vector3 swing = swing_of[slot];
		// GDScript's Vector3 * float: the scalar as a real_t first.
		swing += ((down - hang) * real_t(stiffness) - swing * real_t(damping)) * real_t(delta);
		hang = (hang + swing * real_t(delta)).normalized();
		since_of[slot] += delta;
		bool going = true;
		if (swing.length() < still && (down - hang).length() < still) {
			hang = down;
			swing = Vector3();
			going = false;
		}
		hang_of[slot] = hang;
		swing_of[slot] = swing;
		ons[k] = going ? 1 : 0;
		const Basis hung = Basis(Quaternion(Vector3(0, -1, 0), hang));
		bases[k] = hung;
		placed[k] = Transform3D(hung, at[slot]);
	}
	Array found;
	found.push_back(hangs);
	found.push_back(swings);
	found.push_back(clocks);
	found.push_back(sinces);
	found.push_back(on);
	found.push_back(bases);
	found.push_back(placed);
	return found;
}

} // namespace godot
