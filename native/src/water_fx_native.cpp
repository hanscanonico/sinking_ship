// Each loop here is a GDScript one, line for line: a Vector3's component is a float32
// widened to a double where the GDScript reads it into a float, a Vector2 built from
// doubles rounds each to a float32, sums run in the same order, and minf, maxf, clampf
// and lerpf are the engine's (a < b ? a : b, a > b ? a : b, a + (b - a) * t).
// Contraction is off. Every product of float32s — a point set in the world, a dot of
// two vectors — the engine works before the call, as the GDScript has it work them.

#include "water_fx_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <cmath>

using namespace godot;

namespace {
constexpr int32_t SEA_OR_SKY = -1;
// CuePlanner.ON.
constexpr int32_t ON = -1;

inline double min_f(double p_a, double p_b) {
	return p_a < p_b ? p_a : p_b;
}

inline double max_f(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}

inline double clamp_f(double p_value, double p_low, double p_high) {
	return p_value < p_low ? p_low : (p_value > p_high ? p_high : p_value);
}

inline double abs_f(double p_value) {
	return std::fabs(p_value);
}

inline double lerp_f(double p_from, double p_to, double p_weight) {
	return p_from + (p_to - p_from) * p_weight;
}

// CellSurface.reach of a box whose middle stands at p_middle in the world and whose
// half size is p_half, under a turn whose |x.y|, |y.y| and |z.y| are p_spread: its
// lowest and its highest corner's heights, each a float32 (a Vector2).
inline void reach(double p_middle, const Vector3 &p_half, const double *p_spread, float &r_low,
		float &r_high) {
	const double spread = p_spread[0] * double(p_half.x) + p_spread[1] * double(p_half.y) +
			p_spread[2] * double(p_half.z);
	r_low = float(p_middle - spread);
	r_high = float(p_middle + spread);
}

// InnerWater.shows, its first water p_spread[3] and SHOWS p_spread[4].
inline bool shows(double p_level, float p_low, float p_high, const double *p_spread) {
	return p_level >= double(p_low) + p_spread[3] && p_level < double(p_high) - p_spread[4];
}

// InnerWater._may_show, STACK_SLACK p_spread[5].
inline bool may_show(double p_level, float p_low, float p_high, const double *p_spread) {
	return p_level >= double(p_low) + p_spread[3] - p_spread[5] &&
			p_level < double(p_high) - p_spread[4] + p_spread[5];
}

// CuePlanner._comes_on, over its p_heard and p_off_since.
bool comes_on(uint8_t *p_heard, int32_t *p_off_since, int64_t p_slot, bool p_was, bool p_now_on, int64_t p_tick,
		int64_t p_rearm) {
	if (p_now_on) {
		p_off_since[p_slot] = ON;
	} else if (p_off_since[p_slot] == ON) {
		p_off_since[p_slot] = int32_t(p_tick);
	} else if (p_heard[p_slot] == 1 && p_tick - p_off_since[p_slot] >= p_rearm) {
		p_heard[p_slot] = 0;
	}
	if (!p_now_on || p_heard[p_slot] == 1) {
		return false;
	}
	p_heard[p_slot] = 1;
	return !p_was;
}

// Whether CuePlanner._water_coming_on passes slot p_slot over unasked.
inline bool passed_over(bool p_on_now, const uint8_t *p_heard, const int32_t *p_off_since, int64_t p_slot,
		int64_t p_tick, int64_t p_rearm) {
	const int32_t off = p_off_since[p_slot];
	return !p_on_now && off != ON && (p_heard[p_slot] == 0 || p_tick - off < p_rearm);
}
} // namespace

// The lerpf of every cell's level from p_then to p_now, p_alpha of the way
// (InnerWater.show_water).
PackedFloat64Array NativeWaterFx::levels_between(const PackedFloat64Array &p_then, const PackedFloat64Array &p_now,
		double p_alpha) const {
	PackedFloat64Array levels;
	const int64_t count = p_then.size();
	levels.resize(count);
	double *out = levels.ptrw();
	const double *then = p_then.ptr();
	const double *now = p_now.ptr();
	for (int64_t cell = 0; cell < count; cell++) {
		out[cell] = lerp_f(then[cell], now[cell], p_alpha);
	}
	return levels;
}

// InnerWater._show_surface's choice for each drawn cell surface, the p_index-th over
// cell p_cells[index], whose box's middle stands at p_middles[index].y in the world and
// whose half size is p_halves[index]: each one to show, or shown (p_shown) and to hide,
// as index * 2 + 1 to show and index * 2 to hide, in order. p_spread is the turn's
// |x.y|, |y.y|, |z.y|, then the first water, SHOWS and STACK_SLACK.
PackedInt32Array NativeWaterFx::surfaces(const PackedFloat64Array &p_levels, const PackedInt32Array &p_cells,
		const PackedVector3Array &p_middles, const PackedVector3Array &p_halves,
		const PackedFloat64Array &p_spread, const PackedByteArray &p_shown) const {
	PackedInt32Array touched;
	const int64_t count = p_cells.size();
	const double *levels = p_levels.ptr();
	const int32_t *cells = p_cells.ptr();
	const Vector3 *middles = p_middles.ptr();
	const Vector3 *halves = p_halves.ptr();
	const double *spread = p_spread.ptr();
	const uint8_t *shown = p_shown.ptr();
	for (int64_t index = 0; index < count; index++) {
		float low;
		float high;
		reach(double(middles[index].y), halves[index], spread, low, high);
		const bool showing = shows(levels[cells[index]], low, high, spread);
		if (showing || shown[index] == 1) {
			touched.push_back(int32_t(index * 2 + (showing ? 1 : 0)));
		}
	}
	return touched;
}

// InnerWater.show_water's walk of the cells drawn in stacks: per stacked cell
// p_stack_cells[at], its stacks from p_stacks_from[at] to p_stacks_from[at + 1], passed
// over while none shows (p_stacks_shown) and its water may show in none
// (_may_show over its bounds' p_bound_middles and p_bound_halves); each stack of the
// rest as surfaces gives it, in p_middles, p_halves and p_shown. Gives the stacks
// touched, as surfaces does, and how many of each cell's show.
Array NativeWaterFx::stacks(const PackedFloat64Array &p_levels, const PackedInt32Array &p_stack_cells,
		const PackedInt32Array &p_stacks_from, const PackedVector3Array &p_bound_middles,
		const PackedVector3Array &p_bound_halves, const PackedInt32Array &p_stacks_shown,
		const PackedVector3Array &p_middles, const PackedVector3Array &p_halves,
		const PackedFloat64Array &p_spread, const PackedByteArray &p_shown) const {
	PackedInt32Array touched;
	PackedInt32Array stacks_shown = p_stacks_shown;
	int32_t *counts = stacks_shown.ptrw();
	const int64_t count = p_stack_cells.size();
	const double *levels = p_levels.ptr();
	const int32_t *stack_cells = p_stack_cells.ptr();
	const int32_t *from = p_stacks_from.ptr();
	const Vector3 *bound_middles = p_bound_middles.ptr();
	const Vector3 *bound_halves = p_bound_halves.ptr();
	const Vector3 *middles = p_middles.ptr();
	const Vector3 *halves = p_halves.ptr();
	const double *spread = p_spread.ptr();
	const uint8_t *shown = p_shown.ptr();
	for (int64_t at = 0; at < count; at++) {
		const double level = levels[stack_cells[at]];
		if (counts[at] == 0) {
			float low;
			float high;
			reach(double(bound_middles[at].y), bound_halves[at], spread, low, high);
			if (!may_show(level, low, high, spread)) {
				continue;
			}
		}
		int32_t showing_count = 0;
		for (int32_t index = from[at]; index < from[at + 1]; index++) {
			float low;
			float high;
			reach(double(middles[index].y), halves[index], spread, low, high);
			const bool showing = shows(level, low, high, spread);
			if (showing || shown[index] == 1) {
				touched.push_back(index * 2 + (showing ? 1 : 0));
			}
			showing_count += showing ? 1 : 0;
		}
		counts[at] = showing_count;
	}
	Array found;
	found.push_back(touched);
	found.push_back(stacks_shown);
	return found;
}

// InnerWater._find_wet's walk of the openings, from p_then's levels to p_now's (each
// cell's, the sea's 0 in the last slot of p_slots' reach) and the levels drawn now,
// p_heads (the sea's 0 last): each made (p_made) and drawn (p_drawn) one's sides
// p_slots[index * 2] and p_slots[index * 2 + 1], its middle's dot with the turn's row of
// heights at either pose p_middles_then[index].y and p_middles_now[index].y, the rises
// p_rises[0] and p_rises[1], its reach, and the heads its air was last told of
// p_last_heads. p_rises[2] and p_rises[3] are SHOWS and POURS. Gives the openings that
// may pour; those of the last p_wet that may not, whose pours to hide; those whose air
// to blow out, in order; and the heads last told, as the walk leaves them.
Array NativeWaterFx::find_wet(const PackedFloat64Array &p_then, const PackedFloat64Array &p_now,
		const PackedFloat64Array &p_heads, const PackedInt32Array &p_slots, const PackedByteArray &p_made,
		const PackedByteArray &p_drawn, const PackedVector3Array &p_middles_then,
		const PackedVector3Array &p_middles_now, const PackedFloat64Array &p_rises,
		const PackedFloat64Array &p_reaches, const PackedVector2Array &p_last_heads,
		const PackedInt32Array &p_wet) const {
	PackedInt32Array wet;
	PackedInt32Array hidden;
	PackedInt32Array blown;
	PackedVector2Array last_heads = p_last_heads;
	Vector2 *last = last_heads.ptrw();
	const int64_t sea = p_then.size();
	const double *at_then = p_then.ptr();
	const double *at_now = p_now.ptr();
	const double *heads = p_heads.ptr();
	const int32_t *slots = p_slots.ptr();
	const uint8_t *made = p_made.ptr();
	const uint8_t *drawn = p_drawn.ptr();
	const Vector3 *middles_then = p_middles_then.ptr();
	const Vector3 *middles_now = p_middles_now.ptr();
	const double *reaches = p_reaches.ptr();
	const double rise_then = p_rises[0];
	const double rise_now = p_rises[1];
	const double shows_by = p_rises[2];
	const double pours_by = p_rises[3];
	const int64_t count = p_made.size();
	PackedByteArray now_wet;
	now_wet.resize(count);
	now_wet.fill(0);
	uint8_t *is_wet = now_wet.ptrw();
	for (int64_t index = 0; index < count; index++) {
		if (made[index] == 0 || drawn[index] == 0) {
			continue;
		}
		const int32_t first = slots[index * 2];
		const int32_t second = slots[index * 2 + 1];
		const double first_then = first == sea ? 0.0 : at_then[first];
		const double first_now = first == sea ? 0.0 : at_now[first];
		const double second_then = second == sea ? 0.0 : at_then[second];
		const double second_now = second == sea ? 0.0 : at_now[second];
		const double middle_then = double(middles_then[index].y) + rise_then;
		const double middle_now = double(middles_now[index].y) + rise_now;
		const double lowest = min_f(middle_then, middle_now) - reaches[index];
		const double highest = max_f(middle_then, middle_now) + reaches[index];
		const bool pours =
				max_f(max_f(first_then, second_then), max_f(first_now, second_now)) > lowest + shows_by &&
				max_f(abs_f(first_then - second_then), abs_f(first_now - second_now)) >= pours_by &&
				min_f(min_f(first_then, second_then), min_f(first_now, second_now)) < highest - pours_by;
		const bool crosses =
				(first != sea && max_f(first_then, first_now) >= lowest && min_f(first_then, first_now) <= highest) ||
				(second != sea && max_f(second_then, second_now) >= lowest &&
						min_f(second_then, second_now) <= highest);
		if (pours || crosses) {
			wet.push_back(int32_t(index));
			is_wet[index] = 1;
			continue;
		}
		const Vector2 told = last[index];
		const double head_first = heads[first];
		const double head_second = heads[second];
		if (std::isfinite(double(told.x)) &&
				((first != sea && double(told.x) < highest && head_first >= lowest) ||
						(second != sea && double(told.y) < highest && head_second >= lowest))) {
			blown.push_back(int32_t(index));
		} else {
			last[index] = Vector2(float(head_first), float(head_second));
		}
	}
	const int32_t *was_wet = p_wet.ptr();
	for (int64_t at = 0; at < p_wet.size(); at++) {
		if (is_wet[was_wet[at]] == 0) {
			hidden.push_back(was_wet[at]);
		}
	}
	Array found;
	found.push_back(wet);
	found.push_back(hidden);
	found.push_back(blown);
	found.push_back(last_heads);
	return found;
}

// InnerWater._show_inflows' churn of each cell, from p_then's levels to p_now's over
// its middle's world height at either pose (p_middles_then[cell].y, p_middles_now's),
// eased from p_inflows; p_constants are the seconds of a tick, INFLOW_FULL, INFLOW_EASE
// and INFLOW_CALM. Gives every cell's churn and the cells whose churn changed.
Array NativeWaterFx::inflows(const PackedFloat64Array &p_then, const PackedFloat64Array &p_now,
		const PackedVector3Array &p_middles_then, const PackedVector3Array &p_middles_now,
		const PackedFloat64Array &p_inflows, const PackedFloat64Array &p_constants) const {
	PackedFloat64Array churns = p_inflows;
	PackedInt32Array changed;
	double *out = churns.ptrw();
	const double *then = p_then.ptr();
	const double *now = p_now.ptr();
	const Vector3 *middles_then = p_middles_then.ptr();
	const Vector3 *middles_now = p_middles_now.ptr();
	const double seconds = p_constants[0];
	const double full_rate = p_constants[1];
	const double ease = p_constants[2];
	const double calm = p_constants[3];
	for (int64_t cell = 0; cell < churns.size(); cell++) {
		const double was = then[cell] - double(middles_then[cell].y);
		const double is_now = now[cell] - double(middles_now[cell].y);
		double fresh = 0.0;
		if (!(seconds <= 0.0 || full_rate <= 0.0)) {
			fresh = clamp_f((is_now - was) / seconds / full_rate, 0.0, 1.0);
		}
		const double eased = lerp_f(out[cell], fresh, ease);
		const double churn = eased >= calm ? eased : 0.0;
		if (churn == out[cell]) {
			continue;
		}
		out[cell] = churn;
		changed.push_back(int32_t(cell));
	}
	Array found;
	found.push_back(churns);
	found.push_back(changed);
	return found;
}

// InnerWater._show_pockets' walk of the cells: those it has more to do for than let go
// of an air it never held — a pocket held (p_pockets), a surface (p_surfaced) whose glow
// (p_glows) changes, or an air of p_vents or more let go — in order, and the airs with
// every other cell's let go (-1).
Array NativeWaterFx::pockets(const PackedFloat64Array &p_pockets, const PackedByteArray &p_surfaced,
		const PackedFloat32Array &p_glows, const PackedFloat64Array &p_airs, double p_glow,
		double p_vents) const {
	PackedInt32Array asked;
	PackedFloat64Array airs = p_airs;
	double *air = airs.ptrw();
	const double *pockets = p_pockets.ptr();
	const int64_t pocket_count = p_pockets.size();
	const uint8_t *surfaced = p_surfaced.ptr();
	const float *glows = p_glows.ptr();
	for (int64_t cell = 0; cell < airs.size(); cell++) {
		const bool held = cell < pocket_count && pockets[cell] > 0.0;
		const double glow = held ? p_glow : 0.0;
		if (held || (surfaced[cell] == 1 && double(glows[cell]) != glow) || air[cell] >= p_vents) {
			asked.push_back(int32_t(cell));
			continue;
		}
		air[cell] = -1.0;
	}
	Array found;
	found.push_back(asked);
	found.push_back(airs);
	return found;
}

// CuePlanner._reading's geometry: per cell, 1 where its water (p_levels) stands SHOWS
// (p_shows) over its floor's lowest corner — its floor's middle dotted with the turn's
// row of heights p_floors[cell].y, less its reach down under the turn's |row| p_row over
// its half p_floor_halves[cell], and the rise p_rise; then per opening, 1 where its
// higher side holds water and one side's water stands over its bottom by SHOWS and over
// the other's by POURS (p_pours), its middle's dot p_centres[index].y — whether it is
// open the GDScript asks after.
PackedByteArray NativeWaterFx::reading(const PackedVector3Array &p_floors, const PackedVector3Array &p_floor_halves,
		const PackedFloat64Array &p_levels, const PackedFloat64Array &p_row, double p_rise,
		const PackedInt32Array &p_sides, const PackedVector3Array &p_centres,
		const PackedVector3Array &p_opening_halves, double p_shows, double p_pours) const {
	const int64_t cells = p_floors.size();
	const int64_t openings = p_centres.size();
	PackedByteArray found;
	found.resize(cells + openings);
	found.fill(0);
	uint8_t *out = found.ptrw();
	const double across = p_row[0];
	const double up = p_row[1];
	const double along = p_row[2];
	const Vector3 *floors = p_floors.ptr();
	const Vector3 *floor_halves = p_floor_halves.ptr();
	const double *levels = p_levels.ptr();
	for (int64_t cell = 0; cell < cells; cell++) {
		const Vector3 &half = floor_halves[cell];
		const double reach = across * double(half.x) + up * double(half.y) + along * double(half.z);
		const double floor_low = double(floors[cell].y) - reach + p_rise;
		out[cell] = levels[cell] > floor_low + p_shows ? 1 : 0;
	}
	const int32_t *sides = p_sides.ptr();
	const Vector3 *centres = p_centres.ptr();
	const Vector3 *opening_halves = p_opening_halves.ptr();
	for (int64_t index = 0; index < openings; index++) {
		const int32_t first = sides[index * 2];
		const int32_t second = sides[index * 2 + 1];
		const double first_level = first == SEA_OR_SKY ? 0.0 : levels[first];
		const double second_level = second == SEA_OR_SKY ? 0.0 : levels[second];
		const int32_t high = first_level >= second_level ? first : second;
		if (high != SEA_OR_SKY && out[high] == 0) {
			continue;
		}
		const Vector3 &half = opening_halves[index];
		const double reach = across * double(half.x) + up * double(half.y) + along * double(half.z);
		const double bottom = double(centres[index].y) - reach + p_rise;
		if (max_f(first_level, second_level) > bottom + p_shows &&
				abs_f(first_level - second_level) >= p_pours) {
			out[cells + index] = 1;
		}
	}
	return found;
}

// CuePlanner._water_coming_on's walk of the slots, each one's _comes_on: the cells' —
// the first p_cells of p_then and p_now, when they are readings (p_cells >= 0) — the
// platforms' (p_decks_then, p_decks_now, into p_platform_slots), and the openings' (the
// rest of the readings, after the cells'), over the heard p_heard and p_off_since at
// p_tick. Gives the heard, the off since and, in order, those heard coming on: a cell
// as its index, a platform as p_cells + its index — or its index alone with no cells
// read — and an opening as p_cells + the platforms + its index.
Array NativeWaterFx::coming_on(const PackedByteArray &p_then, const PackedByteArray &p_now, int64_t p_cells,
		const PackedByteArray &p_decks_then, const PackedByteArray &p_decks_now,
		const PackedInt32Array &p_platform_slots, const PackedByteArray &p_heard,
		const PackedInt32Array &p_off_since, int64_t p_tick, int64_t p_cell_rearm,
		int64_t p_pour_rearm) const {
	PackedByteArray heard_all = p_heard;
	PackedInt32Array off_all = p_off_since;
	PackedInt32Array came;
	uint8_t *heard = heard_all.ptrw();
	int32_t *off_since = off_all.ptrw();
	const bool cells = p_cells >= 0;
	const int64_t cell_count = cells ? p_cells : 0;
	const uint8_t *then = p_then.ptr();
	const uint8_t *now = p_now.ptr();
	for (int64_t cell = 0; cell < cell_count; cell++) {
		const bool on_now = now[cell] == 1;
		if (passed_over(on_now, heard, off_since, cell, p_tick, p_cell_rearm)) {
			continue;
		}
		if (comes_on(heard, off_since, cell, then[cell] == 1, on_now, p_tick, p_cell_rearm)) {
			came.push_back(int32_t(cell));
		}
	}
	const int64_t platforms = p_platform_slots.size();
	const int32_t *platform_slots = p_platform_slots.ptr();
	const uint8_t *decks_then = p_decks_then.ptr();
	const uint8_t *decks_now = p_decks_now.ptr();
	for (int64_t platform = 0; platform < platforms; platform++) {
		const int64_t slot = platform_slots[platform];
		const bool on_now = decks_now[platform] == 1;
		if (passed_over(on_now, heard, off_since, slot, p_tick, p_cell_rearm)) {
			continue;
		}
		if (comes_on(heard, off_since, slot, decks_then[platform] == 1, on_now, p_tick, p_cell_rearm)) {
			came.push_back(int32_t(cell_count + platform));
		}
	}
	if (cells) {
		const int64_t openings = p_now.size() - cell_count;
		for (int64_t index = 0; index < openings; index++) {
			const int64_t slot = cell_count + index;
			const bool on_now = now[cell_count + index] == 1;
			if (passed_over(on_now, heard, off_since, slot, p_tick, p_pour_rearm)) {
				continue;
			}
			if (comes_on(heard, off_since, slot, then[cell_count + index] == 1, on_now, p_tick, p_pour_rearm)) {
				came.push_back(int32_t(cell_count + platforms + index));
			}
		}
	}
	Array found;
	found.push_back(heard_all);
	found.push_back(off_all);
	found.push_back(came);
	return found;
}

// FxPlanner._waterlines' walk of the decks: each one some corner of which may stand
// within p_clear of the sea — its least corner's height p_lows[index].y, its plane's
// rise across it from the turn's x.y (p_x_rise) and z.y (p_z_rise) over its sizes — to
// find its line, in order; and the spray, every other deck's let go.
Array NativeWaterFx::waterlines(const PackedVector3Array &p_lows, double p_x_rise, double p_z_rise,
		const PackedFloat64Array &p_size_x, const PackedFloat64Array &p_size_z,
		const PackedFloat32Array &p_spray, double p_clear) const {
	PackedInt32Array crossing;
	PackedFloat32Array spray = p_spray;
	float *spray_at = spray.ptrw();
	const Vector3 *lows = p_lows.ptr();
	const double *size_x = p_size_x.ptr();
	const double *size_z = p_size_z.ptr();
	for (int64_t index = 0; index < p_lows.size(); index++) {
		const double low = double(lows[index].y);
		const double rise = abs_f(p_x_rise * size_x[index]) + abs_f(p_z_rise * size_z[index]);
		if (abs_f(low) > rise + p_clear) {
			spray_at[index * 2] = 0.0f;
			spray_at[index * 2 + 1] = 0.0f;
			continue;
		}
		crossing.push_back(int32_t(index));
	}
	Array found;
	found.push_back(crossing);
	found.push_back(spray);
	return found;
}

// FxPlanner._floods' walk of the decks: those flooded under the pose now (p_now) and
// not under the pose before (p_then), in order.
PackedInt32Array NativeWaterFx::risen(const PackedByteArray &p_now, const PackedByteArray &p_then) const {
	PackedInt32Array found;
	const uint8_t *now = p_now.ptr();
	const uint8_t *then = p_then.ptr();
	for (int64_t index = 0; index < p_now.size(); index++) {
		if (now[index] == 0 || then[index] == 1) {
			continue;
		}
		found.push_back(int32_t(index));
	}
	return found;
}

void NativeWaterFx::_bind_methods() {
	ClassDB::bind_method(D_METHOD("levels_between", "then", "now", "alpha"), &NativeWaterFx::levels_between);
	ClassDB::bind_method(D_METHOD("surfaces", "levels", "cells", "middles", "halves", "spread", "shown"),
			&NativeWaterFx::surfaces);
	ClassDB::bind_method(D_METHOD("stacks", "levels", "stack_cells", "stacks_from", "bound_middles",
								 "bound_halves", "stacks_shown", "middles", "halves", "spread", "shown"),
			&NativeWaterFx::stacks);
	ClassDB::bind_method(D_METHOD("find_wet", "then", "now", "heads", "slots", "made", "drawn", "middles_then",
								 "middles_now", "rises", "reaches", "last_heads", "wet"),
			&NativeWaterFx::find_wet);
	ClassDB::bind_method(D_METHOD("inflows", "then", "now", "middles_then", "middles_now", "inflows", "constants"),
			&NativeWaterFx::inflows);
	ClassDB::bind_method(D_METHOD("pockets", "pockets", "surfaced", "glows", "airs", "glow", "vents"),
			&NativeWaterFx::pockets);
	ClassDB::bind_method(D_METHOD("reading", "floors", "floor_halves", "levels", "row", "rise", "sides", "centres",
								 "opening_halves", "shows", "pours"),
			&NativeWaterFx::reading);
	ClassDB::bind_method(D_METHOD("coming_on", "then", "now", "cells", "decks_then", "decks_now", "platform_slots",
								 "heard", "off_since", "tick", "cell_rearm", "pour_rearm"),
			&NativeWaterFx::coming_on);
	ClassDB::bind_method(D_METHOD("waterlines", "lows", "x_rise", "z_rise", "size_x", "size_z", "spray", "clear"),
			&NativeWaterFx::waterlines);
	ClassDB::bind_method(D_METHOD("risen", "now", "then"), &NativeWaterFx::risen);
}
