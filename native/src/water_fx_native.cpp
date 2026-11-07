// Each loop here is a GDScript one, line for line: a Vector3's component is a float32
// widened to a double where the GDScript reads it into a float, a Vector2 built from
// doubles rounds each to a float32, sums run in the same order, and minf, maxf and
// lerpf are the engine's (a < b ? a : b, a > b ? a : b, a + (b - a) * t).
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

inline double abs_f(double p_value) {
	return std::fabs(p_value);
}

// clampf: under the least the least, over the most the most.
inline double clamp_f(double p_value, double p_least, double p_most) {
	return p_value < p_least ? p_least : (p_value > p_most ? p_most : p_value);
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

// InnerWater._held_in's walk of the cells: those of the first p_count holding a
// pocket's air (p_pockets over 0), in order.
PackedInt32Array NativeWaterFx::held(const PackedFloat64Array &p_pockets, int64_t p_count) const {
	PackedInt32Array found;
	const double *pockets = p_pockets.ptr();
	const int64_t count = p_count < p_pockets.size() ? p_count : p_pockets.size();
	for (int64_t cell = 0; cell < count; cell++) {
		if (pockets[cell] > 0.0) {
			found.push_back(int32_t(cell));
		}
	}
	return found;
}

// CellSurface.placed for each drawn sheet p_touched shows (index * 2 + 1; one to hide,
// index * 2, is passed over): the p_index-th over cell p_cells[index], its box's middle
// p_middles[index] standing at p_world_middles[index].y in the world, its half size
// p_halves[index], at that cell's level p_levels[cell], laid level by p_level's columns
// (across, up, along). Gives a Transform3D per sheet shown, in order.
Array NativeWaterFx::placed(const PackedInt32Array &p_touched, const PackedInt32Array &p_cells,
		const PackedFloat64Array &p_levels, const PackedVector3Array &p_middles,
		const PackedVector3Array &p_world_middles, const PackedVector3Array &p_halves,
		const Basis &p_level) const {
	Array found;
	const Vector3 across = p_level.get_column(0);
	const Vector3 up = p_level.get_column(1);
	const Vector3 along = p_level.get_column(2);
	const int32_t *touched = p_touched.ptr();
	const int32_t *cells = p_cells.ptr();
	const double *levels = p_levels.ptr();
	const Vector3 *middles = p_middles.ptr();
	const Vector3 *world_middles = p_world_middles.ptr();
	const Vector3 *halves = p_halves.ptr();
	for (int64_t at = 0; at < p_touched.size(); at++) {
		if ((touched[at] & 1) == 0) {
			continue;
		}
		const int32_t index = touched[at] >> 1;
		const Vector3 &half = halves[index];
		const double wide = abs_f(double(across.x)) * double(half.x) + abs_f(double(across.y)) * double(half.y) +
				abs_f(double(across.z)) * double(half.z);
		const double deep = abs_f(double(along.x)) * double(half.x) + abs_f(double(along.y)) * double(half.y) +
				abs_f(double(along.z)) * double(half.z);
		const Basis basis(across * real_t(2.0) * real_t(wide), up, along * real_t(2.0) * real_t(deep));
		const double rise = levels[cells[index]] - double(world_middles[index].y);
		found.push_back(Transform3D(basis, middles[index] + up * real_t(rise)));
	}
	return found;
}

// InnerWater._show_pour's reckoning, line for line, for each opening p_wet names, but
// what the engine works and every node it sets: the cells' water at world heights
// p_levels (the sea at 0); per opening its two sides p_sides (-1 for the sea), its
// middle p_centres and size p_sizes, which way it faces p_facings, whether it is drawn
// pouring p_drawn, whether it has a crossing p_crossed, its box's middle in the world
// p_span_middles and half size p_span_halves, its middle in the world p_world_centres,
// the points under it on its two sides' floors in the world p_world_unders, and its
// sides' last heads p_last_heads; per opening of p_wet, how far open it stands p_open
// and the water through it p_flow (-1 for none); per cell its corners p_cell_lows and
// p_cell_highs; her six axes laid level with the world p_flats (+x, +y, +z, -x, -y,
// -z); and p_spread: the turn's |x.y|, |y.y|, |z.y|, then SHOWS, POURS, FLOOD,
// FLOW_FULL, THINNEST, OFF_WALL, OFF_SHELL, MOST_THROW, LANDING.x and LANDING.y.
// Gives, per opening of p_wet, 0 to hide it apart from her (dry or never drawn), 1 to
// hide it where it stands, 2 to draw it; per one drawn, its middle and the point its
// landing is thrown to — each before it is set at its height (_at_height) — its sheet's
// across and normal laid level, and its from, to, width, short side, thrown, strength,
// the landing's spread, outdoor, its crossing (0 none, 1 through a deck, 2 a round jet)
// and how tall it falls; then the heads last told, and the air blown out (_blow), each
// as opening * 2 + side, at that side's height.
Array NativeWaterFx::pours(const PackedInt32Array &p_wet, const PackedFloat64Array &p_levels,
		const PackedInt32Array &p_sides, const PackedVector3Array &p_centres, const PackedVector3Array &p_sizes,
		const PackedInt32Array &p_facings, const PackedByteArray &p_drawn, const PackedByteArray &p_crossed,
		const PackedVector3Array &p_span_middles, const PackedVector3Array &p_span_halves,
		const PackedVector3Array &p_world_centres, const PackedVector3Array &p_world_unders,
		const PackedVector2Array &p_last_heads, const PackedFloat64Array &p_open, const PackedFloat64Array &p_flow,
		const PackedVector3Array &p_cell_lows, const PackedVector3Array &p_cell_highs,
		const PackedVector3Array &p_flats, const PackedFloat64Array &p_spread) const {
	PackedInt32Array codes;
	PackedVector3Array points;
	PackedVector3Array axes;
	PackedFloat64Array values;
	PackedInt32Array blown;
	PackedFloat64Array blown_at;
	PackedVector2Array last_heads = p_last_heads;
	Vector2 *last = last_heads.ptrw();
	const double *levels = p_levels.ptr();
	const int32_t *sides = p_sides.ptr();
	const Vector3 *centres = p_centres.ptr();
	const Vector3 *sizes = p_sizes.ptr();
	const int32_t *facings = p_facings.ptr();
	const uint8_t *drawn = p_drawn.ptr();
	const uint8_t *crossed = p_crossed.ptr();
	const Vector3 *span_middles = p_span_middles.ptr();
	const Vector3 *span_halves = p_span_halves.ptr();
	const Vector3 *world_centres = p_world_centres.ptr();
	const Vector3 *world_unders = p_world_unders.ptr();
	const Vector3 *lows = p_cell_lows.ptr();
	const Vector3 *highs = p_cell_highs.ptr();
	const Vector3 *flats = p_flats.ptr();
	const double *spread = p_spread.ptr();
	const double shows_by = spread[3];
	const double pours_by = spread[4];
	const double flood = spread[5];
	const double flow_full = spread[6];
	const double thinnest = spread[7];
	const double off_wall = spread[8];
	const double off_shell = spread[9];
	const double most_throw = spread[10];
	const double landing_least = spread[11];
	const double landing_most = spread[12];
	for (int64_t at = 0; at < p_wet.size(); at++) {
		const int32_t index = p_wet[at];
		const int32_t first = sides[index * 2];
		const int32_t second = sides[index * 2 + 1];
		const double heights[2] = { first == SEA_OR_SKY ? 0.0 : levels[first],
			second == SEA_OR_SKY ? 0.0 : levels[second] };
		float bottom_f;
		float top_f;
		reach(double(span_middles[index].y), span_halves[index], spread, bottom_f, top_f);
		const double bottom = bottom_f;
		const double top = top_f;
		if (drawn[index] == 1) {
			// _blow: the heads told, then each side's water that has just reached the top.
			const Vector2 told = last[index];
			last[index] = Vector2(float(heights[0]), float(heights[1]));
			for (int side = 0; side < 2; side++) {
				const int32_t cell = sides[index * 2 + side];
				const double was = double(side == 0 ? told.x : told.y);
				if (cell == SEA_OR_SKY || !(was < top && heights[side] >= top && std::isfinite(was))) {
					continue;
				}
				blown.push_back(index * 2 + side);
				blown_at.push_back(heights[side]);
			}
		}
		if (drawn[index] == 0 || max_f(heights[0], heights[1]) <= bottom + shows_by) {
			codes.push_back(0);
			continue;
		}
		const int32_t axis = facings[index];
		const double open = p_open[at];
		const int high = heights[0] >= heights[1] ? 0 : 1;
		const int low = 1 - high;
		const int32_t side_high = high == 0 ? first : second;
		const int32_t side_low = high == 0 ? second : first;
		const double floor_under = side_low == SEA_OR_SKY ? -INFINITY : double(world_unders[index * 2 + low].y);
		const double drop = heights[high] - max_f(heights[low], floor_under);
		if (open <= 0.0 || heights[high] <= bottom + shows_by || heights[high] - heights[low] < pours_by) {
			codes.push_back(1);
			continue;
		}
		double from = min_f(heights[high], top);
		const double to = max_f(heights[low], floor_under);
		const Vector3 &size = sizes[index];
		const double opening_width =
				axis == 1 ? max_f(double(size.x), double(size.z)) : double(axis == 0 ? size.z : size.x);
		const double flow = p_flow[at];
		double strength;
		if (flow < 0.0) {
			strength = clamp_f(drop / flood, thinnest, 1.0);
		} else {
			strength = clamp_f(flow / (max_f(opening_width, 0.1) * flow_full), thinnest, 1.0);
		}
		Vector3 centre = centres[index];
		double width = 0.0;
		int across_axis;
		int normal_axis;
		double normal_sign = 1.0;
		if (axis == 1) {
			const bool over = side_high == SEA_OR_SKY || double(lows[side_high].y) >= double(centre.y) - 0.01;
			if (!over) {
				codes.push_back(1);
				continue;
			}
			from = double(world_centres[index].y);
			const int long_axis = size.x >= size.z ? 0 : 2;
			width = double(size[long_axis]);
			across_axis = long_axis;
			normal_axis = 2 - long_axis;
		} else {
			const int along = axis == 0 ? 2 : 0;
			width = double(size[along]) * open;
			across_axis = along;
			normal_axis = axis;
			const double middle = side_low == SEA_OR_SKY ?
					1e3 :
					(double(lows[side_low][axis]) + double(highs[side_low][axis])) * 0.5;
			const double offset = middle - double(centre[axis]);
			normal_sign = offset > 0.0 ? 1.0 : (offset < 0.0 ? -1.0 : 0.0);
			Vector3 normal;
			normal[axis] = real_t(normal_sign);
			centre += normal * real_t(side_high == SEA_OR_SKY ? off_shell : off_wall);
			centre[along] = real_t(double(centre[along]) + double(size[along]) * (1.0 - open) * 0.5);
		}
		if (from - to < pours_by || width <= 0.0) {
			codes.push_back(1);
			continue;
		}
		const double tall = from - to;
		double thrown = 0.0;
		if (axis != 1) {
			const double head = max_f(heights[high] - (from + max_f(bottom, heights[low])) * 0.5, 0.0);
			thrown = min_f(2.0 * std::sqrt(head * tall), most_throw);
		}
		// normal.abs().max_axis_index(), the normal a unit along normal_axis or none.
		Vector3 normal_abs;
		normal_abs[normal_axis] = real_t(std::fabs(normal_sign));
		const double short_side = double(size[int(normal_abs.max_axis_index())]);
		const Vector3 across = flats[across_axis];
		const Vector3 normal =
				normal_sign > 0.0 ? flats[normal_axis] : (normal_sign < 0.0 ? flats[normal_axis + 3] : Vector3());
		const double outdoor = axis == 1 && side_high == SEA_OR_SKY ? 1.0 : 0.0;
		const double landing_spread = lerp_f(landing_least, landing_most, strength);
		const int crossing = crossed[index] == 0 ? 0 : (axis == 1 ? 1 : 2);
		codes.push_back(2);
		points.push_back(centre);
		points.push_back(centre + normal * real_t(thrown));
		axes.push_back(across);
		axes.push_back(normal);
		values.push_back(from);
		values.push_back(to);
		values.push_back(width);
		values.push_back(short_side);
		values.push_back(thrown);
		values.push_back(strength);
		values.push_back(landing_spread);
		values.push_back(outdoor);
		values.push_back(double(crossing));
		values.push_back(tall);
	}
	Array found;
	found.push_back(codes);
	found.push_back(points);
	found.push_back(axes);
	found.push_back(values);
	found.push_back(last_heads);
	found.push_back(blown);
	found.push_back(blown_at);
	return found;
}

// InnerWater._show_inflows' walk of the cells, from p_then's levels to p_now's: each
// cell's water over its middle, whose heights in the world at either pose are
// p_middles_then[cell].y and p_middles_now[cell].y, climbing in p_seconds as a share of
// p_full (InnerWater.inflow), its churn p_inflows eased p_ease of the way to it, none
// under p_calm (eased_inflow). Gives the cells whose churn changed and their churns, in
// order.
Array NativeWaterFx::inflows(const PackedFloat64Array &p_then, const PackedFloat64Array &p_now,
		const PackedVector3Array &p_middles_then, const PackedVector3Array &p_middles_now,
		const PackedFloat64Array &p_inflows, double p_seconds, double p_full, double p_ease, double p_calm) const {
	PackedInt32Array cells;
	PackedFloat64Array churns;
	const double *then = p_then.ptr();
	const double *now = p_now.ptr();
	const Vector3 *middles_then = p_middles_then.ptr();
	const Vector3 *middles_now = p_middles_now.ptr();
	const double *inflows = p_inflows.ptr();
	for (int64_t cell = 0; cell < p_inflows.size(); cell++) {
		const double was = then[cell] - double(middles_then[cell].y);
		const double is_now = now[cell] - double(middles_now[cell].y);
		double fresh = 0.0;
		if (!(p_seconds <= 0.0 || p_full <= 0.0)) {
			fresh = clamp_f((is_now - was) / p_seconds / p_full, 0.0, 1.0);
		}
		const double eased = lerp_f(inflows[cell], fresh, p_ease);
		const double churn = eased >= p_calm ? eased : 0.0;
		if (churn == inflows[cell]) {
			continue;
		}
		cells.push_back(int32_t(cell));
		churns.push_back(churn);
	}
	Array found;
	found.push_back(cells);
	found.push_back(churns);
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
	ClassDB::bind_method(D_METHOD("reading", "floors", "floor_halves", "levels", "row", "rise", "sides", "centres",
								 "opening_halves", "shows", "pours"),
			&NativeWaterFx::reading);
	ClassDB::bind_method(D_METHOD("coming_on", "then", "now", "cells", "decks_then", "decks_now", "platform_slots",
								 "heard", "off_since", "tick", "cell_rearm", "pour_rearm"),
			&NativeWaterFx::coming_on);
	ClassDB::bind_method(D_METHOD("risen", "now", "then"), &NativeWaterFx::risen);
	ClassDB::bind_method(D_METHOD("held", "pockets", "count"), &NativeWaterFx::held);
	ClassDB::bind_method(D_METHOD("placed", "touched", "cells", "levels", "middles", "world_middles", "halves",
								 "level"),
			&NativeWaterFx::placed);
	ClassDB::bind_method(D_METHOD("pours", "wet", "levels", "sides", "centres", "sizes", "facings", "drawn",
								 "crossed", "span_middles", "span_halves", "world_centres", "world_unders",
								 "last_heads", "open", "flow", "cell_lows", "cell_highs", "flats", "spread"),
			&NativeWaterFx::pours);
	ClassDB::bind_method(D_METHOD("inflows", "then", "now", "middles_then", "middles_now", "inflows", "seconds",
								 "full", "ease", "calm"),
			&NativeWaterFx::inflows);
}
