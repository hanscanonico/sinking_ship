// See pose_native.h.

#include "pose_native.h"
#include "registry.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>

namespace godot {

SINKING_CLASS(NativePose)

void NativePose::_bind_methods() {
	ClassDB::bind_method(D_METHOD("hold", "heads", "pockets", "lits", "cells"), &NativePose::hold);
	ClassDB::bind_method(D_METHOD("pose", "at", "frame", "next", "weight", "rise"), &NativePose::pose);
}

void NativePose::hold(const PackedFloat64Array &p_heads, const PackedFloat64Array &p_pockets,
		const PackedByteArray &p_lits, int64_t p_cells) {
	heads_ = p_heads;
	pockets_ = p_pockets;
	lits_ = p_lits;
	cells_ = p_cells;
}

Array NativePose::pose(const PackedInt32Array &p_at, int64_t p_frame, int64_t p_next, double p_weight,
		double p_rise) const {
	const int64_t count = p_at.size();
	const int64_t states = cells_ > 0 ? heads_.size() / cells_ : 0;
	ERR_FAIL_COND_V(p_frame < 0 || p_next < 0 || p_frame >= states || p_next >= states, Array());
	ERR_FAIL_COND_V(pockets_.size() < states * cells_ || lits_.size() < states * cells_, Array());
	PackedFloat64Array levels;
	PackedFloat64Array pockets;
	PackedByteArray lit;
	levels.resize(count);
	pockets.resize(count);
	lit.resize(count);
	double *level_of = levels.ptrw();
	double *pocket_of = pockets.ptrw();
	uint8_t *lit_of = lit.ptrw();
	const int32_t *at_of = p_at.ptr();
	const double *heads = heads_.ptr();
	const double *held = pockets_.ptr();
	const uint8_t *lits = lits_.ptr();
	const int64_t from = p_frame * cells_;
	const int64_t to = p_next * cells_;
	for (int64_t cell = 0; cell < count; cell++) {
		const int64_t at = at_of[cell];
		ERR_FAIL_COND_V(at < 0 || at >= cells_, Array());
		// lerpf, then the rise added as the GDScript adds it.
		const double first = heads[from + at];
		const double head = first + (heads[to + at] - first) * p_weight;
		level_of[cell] = head + p_rise;
		// SinkTimeline._pocket_between: carried where both states hold one, else the first's.
		const double pocket = held[from + at];
		const double later = held[to + at];
		pocket_of[cell] = pocket > 0.0 && later > 0.0 ? pocket + (later - pocket) * p_weight : pocket;
		lit_of[cell] = lits[from + at];
	}
	Array made;
	made.append(levels);
	made.append(pockets);
	made.append(lit);
	return made;
}

} // namespace godot
