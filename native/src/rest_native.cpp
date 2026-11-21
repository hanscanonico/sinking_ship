// Hazards._stirring's rest test in C++: Pieces.piece_in and the test a crate at rest
// passes while its cell's water stands short of lifting it, operation for operation, as
// contacts_native.cpp works the rest of the cargo: a GDScript float is a double and a
// Vector2 or Vector3 floats, so a component read out of a vector is widened before it is
// summed, and vectors are compared exactly. Contraction is off (SConstruct).

#include "contacts_native.h"
#include "registry.h"

#include <godot_cpp/core/class_db.hpp>

#include <limits>

using namespace godot;

namespace {
constexpr double INF = std::numeric_limits<double>::infinity();
// Hazards.DRY_MARGIN, UNKNOWN_CELL and CellMap.NONE.
constexpr double DRY_MARGIN = 0.01;
constexpr int32_t UNKNOWN_CELL = -2;
constexpr int32_t NO_CELL = -1;
// PropState.Body's GROUNDED, LOST and HUNG; Hazards.Turn's RESTS.
constexpr int64_t GROUNDED = 0;
constexpr int64_t LOST = 2;
constexpr int64_t HUNG = 4;
constexpr uint8_t RESTS = 1;

const StringName &name_pos() {
	static const StringName name("pos");
	return name;
}
const StringName &name_vel() {
	static const StringName name("vel");
	return name;
}
const StringName &name_body() {
	static const StringName name("body");
	return name;
}
const StringName &name_surface() {
	static const StringName name("surface");
	return name;
}

// Pieces.piece_in.
int64_t piece_in(const PackedInt32Array &p_standing, const PackedVector2Array &p_spans, double p_x) {
	if (p_standing.size() == 1) {
		return p_standing[0];
	}
	for (int64_t at = 0; at < p_standing.size(); at++) {
		const Vector2 span = p_spans[at];
		if (p_x >= double(span.x) && p_x <= double(span.y)) {
			return p_standing[at];
		}
	}
	return -1;
}
} // namespace

void NativeRest::setup(const PackedFloat64Array &p_grips, const PackedFloat64Array &p_lifts) {
	grips_.assign(p_grips.ptr(), p_grips.ptr() + p_grips.size());
	lifts_.assign(p_lifts.ptr(), p_lifts.ptr() + p_lifts.size());
}

// p_numbers: the piece, whether she is broken, whether crates may rest (not never_rest),
// the deck's slope, whether every crate's grip holds on it, whether she stands upright
// past DRY_MARGIN, her basis's y.y, x.y and z.y, her origin's y, and whether the pose
// keeps cells.
Array NativeRest::stir(const Array &p_props, const PackedByteArray &p_gone, const PackedVector3Array &p_feet,
		const PackedInt32Array &p_rested_on, const PackedInt32Array &p_rest_cells,
		const PackedFloat64Array &p_rest_roofs, const PackedFloat64Array &p_levels,
		const PackedByteArray &p_aboard, const PackedInt32Array &p_standing, const PackedVector2Array &p_spans,
		const PackedFloat64Array &p_numbers) {
	const int64_t piece = int64_t(p_numbers[0]);
	const bool broken = p_numbers[1] != 0.0;
	const bool passing = p_numbers[2] != 0.0;
	const double slope = p_numbers[3];
	const bool all_hold = p_numbers[4] != 0.0;
	const bool upright = p_numbers[5] != 0.0;
	const double up = p_numbers[6];
	const double along_x = p_numbers[7];
	const double along_z = p_numbers[8];
	const double origin = p_numbers[9];
	const bool celled = p_numbers[10] != 0.0;
	const int64_t count = p_props.size();
	Array pending;
	loose_ = Array();
	aboard_ = p_aboard;
	turn_ = PackedByteArray();
	turn_.resize(count);
	turn_.fill(0);
	uint8_t *aboard = aboard_.ptrw();
	uint8_t *turn = turn_.ptrw();
	const uint8_t *gone = p_gone.ptr();
	const Vector3 *feet = p_feet.ptr();
	const int32_t *rested_on = p_rested_on.ptr();
	const int32_t *rest_cells = p_rest_cells.ptr();
	const double *rest_roofs = p_rest_roofs.ptr();
	const double *levels = p_levels.ptr();
	for (int64_t prop = 0; prop < count; prop++) {
		const Variant crate = p_props[prop];
		Object *read = crate;
		const int64_t body = read->get(name_body());
		Vector3 pos;
		bool has_pos = false;
		if (broken) {
			pos = read->get(name_pos());
			has_pos = true;
			aboard[prop] = piece_in(p_standing, p_spans, double(pos.x)) == piece ? 1 : 0;
		}
		const bool loose_here = body != LOST && body < HUNG;
		if (aboard[prop] == 0 || !loose_here) {
			pending.push_back(crate);
			continue;
		}
		loose_.push_back(crate);
		if (!passing || gone[prop] != 0 || !upright || body != GROUNDED) {
			pending.push_back(crate);
			continue;
		}
		if (!has_pos) {
			pos = read->get(name_pos());
		}
		const Vector3 vel = read->get(name_vel());
		const int64_t surface = read->get(name_surface());
		if (!(vel == Vector3() && pos == feet[prop] && surface == rested_on[prop] &&
					(all_hold || slope <= grips_[prop]))) {
			pending.push_back(crate);
			continue;
		}
		double level = 0.0;
		double roof = INF;
		if (celled) {
			const int32_t cell = rest_cells[prop];
			if (cell == UNKNOWN_CELL) {
				pending.push_back(crate);
				continue;
			}
			if (cell != NO_CELL) {
				level = levels[cell];
				roof = rest_roofs[prop];
			}
		}
		const double plane = along_x * double(pos.x) + along_z * double(pos.z) + origin;
		const bool short_of = level < plane + up * (double(pos.y) + lifts_[prop] - DRY_MARGIN) &&
				level < plane + up * roof - DRY_MARGIN;
		if (!short_of) {
			pending.push_back(crate);
			continue;
		}
		turn[prop] = RESTS;
	}
	return pending;
}

Array NativeRest::loose() const {
	return loose_;
}

PackedByteArray NativeRest::turn() const {
	return turn_;
}

PackedByteArray NativeRest::aboard() const {
	return aboard_;
}

SINKING_CLASS(NativeRest)

void NativeRest::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "grips", "lifts"), &NativeRest::setup);
	ClassDB::bind_method(D_METHOD("stir", "props", "gone", "feet", "rested_on", "rest_cells", "rest_roofs", "levels",
								 "aboard", "standing", "spans", "numbers"),
			&NativeRest::stir);
	ClassDB::bind_method(D_METHOD("loose"), &NativeRest::loose);
	ClassDB::bind_method(D_METHOD("turn"), &NativeRest::turn);
	ClassDB::bind_method(D_METHOD("aboard"), &NativeRest::aboard);
}
