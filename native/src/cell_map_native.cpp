// CellMap.cell_at line for line, as NativeWater.cells_at has it: a Vector3's parts are
// float32 widened to doubles where the GDScript reads them into floats, the frame's
// turn to ship space is the engine's Basis * Vector3 in float32, and HullSection.shell_at
// is NativeWater's copy. Contraction is off.

#include "cell_map_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <cmath>
#include <limits>

using namespace godot;

namespace {
constexpr int64_t NONE = -1;
constexpr double INF = std::numeric_limits<double>::infinity();

inline double max_f(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}

// HullSection.shell_at of the section whose outline runs from p_outline[0] to
// p_outline[p_count - 1].
double shell_at(const Vector2 *p_outline, int32_t p_count, double p_y, int p_side) {
	double outermost = -INF;
	for (int32_t index = 0; index < p_count; index++) {
		const Vector2 a = p_outline[index];
		const Vector2 b = p_outline[(index + 1) % p_count];
		if (a.y == b.y || (double(a.y) - p_y) * (double(b.y) - p_y) > 0.0) {
			continue;
		}
		const double z = double(a.x) + (double(b.x) - double(a.x)) * (p_y - double(a.y)) / (double(b.y) - double(a.y));
		outermost = max_f(outermost, z * p_side);
	}
	return outermost > -INF ? outermost * p_side : std::nan("");
}
} // namespace

void NativeCellMap::setup(const PackedVector3Array &p_low, const PackedVector3Array &p_high, const Vector3 &p_from,
		const Vector3 &p_to, double p_slot, const PackedInt32Array &p_slot_from,
		const PackedInt32Array &p_slot_cells, const PackedByteArray &p_poking,
		const PackedFloat64Array &p_inside_port, const PackedFloat64Array &p_inside_starboard,
		const PackedFloat64Array &p_section_x, const PackedFloat64Array &p_section_length,
		const PackedInt32Array &p_outline_from, const PackedVector2Array &p_outlines, const Basis &p_to_ship,
		bool p_framed) {
	low = p_low;
	high = p_high;
	from = p_from;
	to = p_to;
	slot = p_slot;
	slot_from = p_slot_from;
	slot_cells = p_slot_cells;
	poking = p_poking;
	inside_port = p_inside_port;
	inside_starboard = p_inside_starboard;
	section_x = p_section_x;
	section_length = p_section_length;
	outline_from = p_outline_from;
	outlines = p_outlines;
	to_ship = p_to_ship;
	framed = p_framed;
}

// CellMap.cell_at: the index of the cell p_point lies in, or NONE outside every one.
int64_t NativeCellMap::cell_at(const Vector3 &p_point) const {
	const Vector3 at = p_point;
	if (double(at.x) < double(from.x) || double(at.x) >= double(to.x) || double(at.y) < double(from.y)) {
		return NONE;
	}
	if (double(at.y) >= double(to.y) || double(at.z) < double(from.z) || double(at.z) >= double(to.z)) {
		return NONE;
	}
	const int64_t slots = slot_from.size() - 1;
	if (slots < 1) {
		return NONE;
	}
	int64_t at_slot = int64_t(std::floor((double(at.x) - double(from.x)) / slot));
	at_slot = at_slot < slots - 1 ? at_slot : slots - 1;
	const Vector3 *lows = low.ptr();
	const Vector3 *highs = high.ptr();
	const int32_t *starts = slot_from.ptr();
	const int32_t *cells = slot_cells.ptr();
	const uint8_t *pokes = poking.ptr();
	for (int32_t each_cell = starts[at_slot]; each_cell < starts[at_slot + 1]; each_cell++) {
		const int32_t index = cells[each_cell];
		if (at.x < lows[index].x || at.x >= highs[index].x) {
			continue;
		}
		if (at.y < lows[index].y || at.y >= highs[index].y) {
			continue;
		}
		if (at.z < lows[index].z || at.z >= highs[index].z) {
			continue;
		}
		if (pokes[index] == 1) {
			const Vector3 ship = framed ? to_ship.xform(at) : at;
			const double z = double(ship.z);
			const double inside = z >= 0.0 ? inside_starboard[index] : inside_port[index];
			if (std::fabs(z) > inside) {
				// CellMap._in_hull: ShipStructure.section_at, then _in_section.
				const double x = double(ship.x);
				const double *xs = section_x.ptr();
				const double *lengths = section_length.ptr();
				const int64_t sections = section_x.size();
				int64_t section = -1;
				for (int64_t each = 0; each < sections; each++) {
					const double half = lengths[each] * 0.5;
					if (x >= xs[each] - half && x < xs[each] + half) {
						section = each;
						break;
					}
				}
				if (section == -1) {
					continue;
				}
				const int32_t *outline_starts = outline_from.ptr();
				const int side = z >= 0.0 ? 1 : -1;
				const double shell = shell_at(outlines.ptr() + outline_starts[section],
						outline_starts[section + 1] - outline_starts[section], double(ship.y), side);
				if (std::isnan(shell) || !(z * side <= shell * side)) {
					continue;
				}
			}
		}
		return index;
	}
	return NONE;
}

void NativeCellMap::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "low", "high", "from", "to", "slot", "slot_from", "slot_cells",
								 "poking", "inside_port", "inside_starboard", "section_x", "section_length",
								 "outline_from", "outlines", "to_ship", "framed"),
			&NativeCellMap::setup);
	ClassDB::bind_method(D_METHOD("cell_at", "point"), &NativeCellMap::cell_at);
}
