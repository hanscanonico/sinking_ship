// Each loop here is a GDScript one, line for line: a Vector3's y is a float32 widened
// to a double where the GDScript reads it into a float, sums run in the same order,
// minf and maxf are the engine's (a < b ? a : b, a > b ? a : b). Contraction is off.

#include "water_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <cmath>
#include <limits>
#include <vector>

using namespace godot;

namespace {
constexpr int32_t NONE = -1;
constexpr double INF = std::numeric_limits<double>::infinity();

inline double min_f(double p_a, double p_b) {
	return p_a < p_b ? p_a : p_b;
}

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

// StillPoints.wet_all.
PackedByteArray NativeWater::wet_all(const PackedVector3Array &p_world, const PackedInt32Array &p_cells,
		bool p_keeps, const PackedFloat64Array &p_levels, const PackedVector3Array &p_world_own_floors,
		double p_highest, double p_dry) const {
	PackedByteArray found;
	const int64_t count = p_world.size();
	found.resize(count);
	found.fill(0);
	uint8_t *out = found.ptrw();
	const Vector3 *world = p_world.ptr();
	const int32_t *cells = p_cells.ptr();
	const double *levels = p_levels.ptr();
	const Vector3 *own = p_world_own_floors.ptr();
	for (int64_t index = 0; index < count; index++) {
		const double height = double(world[index].y);
		if (height >= p_highest) {
			continue;
		}
		const int32_t cell = p_keeps ? cells[index] : NONE;
		if (cell == NONE) {
			out[index] = height < 0.0 ? 1 : 0;
			continue;
		}
		const double level = levels[cell];
		if (height < level && level > double(own[index].y) + p_dry) {
			out[index] = 1;
		}
	}
	return found;
}

// CellMap.cells_under of every point, in her own frame: per point, from
// [0][point] to [0][point + 1], the cells under it in [1] and the points of their floors
// under it in [2] (StillPoints._chain). The slots, the cells' boxes and her sections
// are CellMap's and ShipStructure's own, flattened: section_at is its scan, the first
// section in order whose stretch holds x.
Array NativeWater::chains_under(const PackedVector3Array &p_points, const PackedVector3Array &p_low,
		const PackedVector3Array &p_high, const Vector3 &p_from, const Vector3 &p_to, double p_slot,
		const PackedInt32Array &p_slot_from, const PackedInt32Array &p_slot_cells,
		const PackedByteArray &p_poking, const PackedFloat64Array &p_inside_port,
		const PackedFloat64Array &p_inside_starboard, const PackedFloat64Array &p_section_x,
		const PackedFloat64Array &p_section_length, const PackedInt32Array &p_outline_from,
		const PackedVector2Array &p_outlines, double p_dry) const {
	PackedInt32Array chain_from;
	PackedInt32Array chain_cells;
	PackedVector3Array chain_points;
	const int64_t count = p_points.size();
	const Vector3 *points = p_points.ptr();
	const Vector3 *low = p_low.ptr();
	const Vector3 *high = p_high.ptr();
	const int32_t *slot_from = p_slot_from.ptr();
	const int32_t *slot_cells = p_slot_cells.ptr();
	const int64_t slots = p_slot_from.size() - 1;
	const uint8_t *poking = p_poking.ptr();
	const double *inside_port = p_inside_port.ptr();
	const double *inside_starboard = p_inside_starboard.ptr();
	const double *section_x = p_section_x.ptr();
	const double *section_length = p_section_length.ptr();
	const int64_t sections = p_section_x.size();
	const int32_t *outline_from = p_outline_from.ptr();
	const Vector2 *outlines = p_outlines.ptr();
	std::vector<int32_t> column;
	for (int64_t point = 0; point < count; point++) {
		chain_from.push_back(int32_t(chain_cells.size()));
		const Vector3 at = points[point];
		if (double(at.x) < double(p_from.x) || double(at.x) >= double(p_to.x)) {
			continue;
		}
		if (double(at.z) < double(p_from.z) || double(at.z) >= double(p_to.z)) {
			continue;
		}
		column.clear();
		int64_t slot = int64_t(std::floor((double(at.x) - double(p_from.x)) / p_slot));
		slot = slot < slots - 1 ? slot : slots - 1;
		for (int32_t at_slot = slot_from[slot]; at_slot < slot_from[slot + 1]; at_slot++) {
			const int32_t index = slot_cells[at_slot];
			if (at.x < low[index].x || at.x >= high[index].x) {
				continue;
			}
			if (at.z < low[index].z || at.z >= high[index].z) {
				continue;
			}
			column.push_back(index);
		}
		int64_t section = -1;
		bool sought = false;
		Vector3 under = at;
		int32_t cell = 0;
		while (cell != NONE) {
			cell = NONE;
			for (const int32_t index : column) {
				if (under.y < low[index].y || under.y >= high[index].y) {
					continue;
				}
				if (poking[index] == 1) {
					const double z = double(under.z);
					const double inside = z >= 0.0 ? inside_starboard[index] : inside_port[index];
					if (std::fabs(z) > inside) {
						if (!sought) {
							const double x = double(under.x);
							for (int64_t each = 0; each < sections; each++) {
								const double half = section_length[each] * 0.5;
								if (x >= section_x[each] - half && x < section_x[each] + half) {
									section = each;
									break;
								}
							}
							sought = true;
						}
						// CellMap._in_section.
						if (section == -1) {
							continue;
						}
						const int side = z >= 0.0 ? 1 : -1;
						const double shell = shell_at(outlines + outline_from[section],
								outline_from[section + 1] - outline_from[section], double(under.y), side);
						if (std::isnan(shell) || !(z * side <= shell * side)) {
							continue;
						}
					}
				}
				cell = index;
				break;
			}
			if (cell != NONE) {
				chain_cells.push_back(cell);
				chain_points.push_back(Vector3(at.x, low[cell].y, at.z));
				under.y = low[cell].y;
				under.y = real_t(double(under.y) - p_dry);
			}
		}
	}
	chain_from.push_back(int32_t(chain_cells.size()));
	Array found;
	found.push_back(chain_from);
	found.push_back(chain_cells);
	found.push_back(chain_points);
	return found;
}

// CellMap.cell_at of every point, in her own frame: per point, its cell in [0] and the
// point on that cell's floor under it in [1], the point itself for none
// (StillPoints._locate). Her slots, boxes and sections flattened as chains_under has
// them.
Array NativeWater::cells_at(const PackedVector3Array &p_points, const PackedVector3Array &p_low,
		const PackedVector3Array &p_high, const Vector3 &p_from, const Vector3 &p_to, double p_slot,
		const PackedInt32Array &p_slot_from, const PackedInt32Array &p_slot_cells,
		const PackedByteArray &p_poking, const PackedFloat64Array &p_inside_port,
		const PackedFloat64Array &p_inside_starboard, const PackedFloat64Array &p_section_x,
		const PackedFloat64Array &p_section_length, const PackedInt32Array &p_outline_from,
		const PackedVector2Array &p_outlines) const {
	const int64_t count = p_points.size();
	PackedInt32Array cells;
	PackedVector3Array own_floors;
	cells.resize(count);
	own_floors.resize(count);
	int32_t *found = cells.ptrw();
	Vector3 *floors = own_floors.ptrw();
	const Vector3 *points = p_points.ptr();
	const Vector3 *low = p_low.ptr();
	const Vector3 *high = p_high.ptr();
	const int32_t *slot_from = p_slot_from.ptr();
	const int32_t *slot_cells = p_slot_cells.ptr();
	const int64_t slots = p_slot_from.size() - 1;
	const uint8_t *poking = p_poking.ptr();
	const double *inside_port = p_inside_port.ptr();
	const double *inside_starboard = p_inside_starboard.ptr();
	const double *section_x = p_section_x.ptr();
	const double *section_length = p_section_length.ptr();
	const int64_t sections = p_section_x.size();
	const int32_t *outline_from = p_outline_from.ptr();
	const Vector2 *outlines = p_outlines.ptr();
	for (int64_t point = 0; point < count; point++) {
		const Vector3 at = points[point];
		found[point] = NONE;
		floors[point] = at;
		if (double(at.x) < double(p_from.x) || double(at.x) >= double(p_to.x) || double(at.y) < double(p_from.y)) {
			continue;
		}
		if (double(at.y) >= double(p_to.y) || double(at.z) < double(p_from.z) || double(at.z) >= double(p_to.z)) {
			continue;
		}
		int64_t slot = int64_t(std::floor((double(at.x) - double(p_from.x)) / p_slot));
		slot = slot < slots - 1 ? slot : slots - 1;
		for (int32_t at_slot = slot_from[slot]; at_slot < slot_from[slot + 1]; at_slot++) {
			const int32_t index = slot_cells[at_slot];
			if (at.x < low[index].x || at.x >= high[index].x) {
				continue;
			}
			if (at.y < low[index].y || at.y >= high[index].y) {
				continue;
			}
			if (at.z < low[index].z || at.z >= high[index].z) {
				continue;
			}
			if (poking[index] == 1) {
				const double z = double(at.z);
				const double inside = z >= 0.0 ? inside_starboard[index] : inside_port[index];
				if (std::fabs(z) > inside) {
					// CellMap._in_hull: ShipStructure.section_at, then _in_section.
					const double x = double(at.x);
					int64_t section = -1;
					for (int64_t each = 0; each < sections; each++) {
						const double half = section_length[each] * 0.5;
						if (x >= section_x[each] - half && x < section_x[each] + half) {
							section = each;
							break;
						}
					}
					if (section == -1) {
						continue;
					}
					const int side = z >= 0.0 ? 1 : -1;
					const double shell = shell_at(outlines + outline_from[section],
							outline_from[section + 1] - outline_from[section], double(at.y), side);
					if (std::isnan(shell) || !(z * side <= shell * side)) {
						continue;
					}
				}
			}
			found[point] = index;
			floors[point] = Vector3(at.x, low[index].y, at.z);
			break;
		}
	}
	Array located;
	located.push_back(cells);
	located.push_back(own_floors);
	return located;
}

// Per group of points, from p_groups[group] to p_groups[group + 1], the least of their
// StillPoints.above_water (ShipPose.above_water_seen) — WalkGraph._floor_lowest of
// every zone.
PackedFloat64Array NativeWater::lowest_of(const PackedInt32Array &p_groups, const PackedVector3Array &p_world,
		const PackedInt32Array &p_chain_from, const PackedInt32Array &p_chain_cells,
		const PackedVector3Array &p_world_floors, const PackedFloat64Array &p_levels, double p_dry) const {
	PackedFloat64Array lowest_all;
	const int64_t groups = p_groups.size() - 1;
	if (groups <= 0) {
		return lowest_all;
	}
	lowest_all.resize(groups);
	double *out = lowest_all.ptrw();
	const int32_t *from = p_groups.ptr();
	const Vector3 *world = p_world.ptr();
	const int32_t *chain_from = p_chain_from.ptr();
	const int32_t *chain_cells = p_chain_cells.ptr();
	const Vector3 *floors = p_world_floors.ptr();
	const double *levels = p_levels.ptr();
	const bool dry_pose = p_levels.is_empty();
	for (int64_t group = 0; group < groups; group++) {
		double lowest = INF;
		for (int32_t corner = from[group]; corner < from[group + 1]; corner++) {
			const double height = double(world[corner].y);
			double above = height;
			if (!dry_pose) {
				for (int32_t at = chain_from[corner]; at < chain_from[corner + 1]; at++) {
					const int32_t cell = chain_cells[at];
					if (levels[cell] > double(floors[at].y) + p_dry) {
						above = height - levels[cell];
						break;
					}
				}
			}
			lowest = min_f(lowest, above);
		}
		out[group] = lowest;
	}
	return lowest_all;
}

// WalkGraph.world_height of every zone: a room by its middle, an open deck by the
// highest middle of its platforms.
PackedFloat64Array NativeWater::heights(int64_t p_rooms, const PackedVector3Array &p_middles,
		const PackedInt32Array &p_platforms_from, const PackedInt32Array &p_platforms,
		const PackedVector3Array &p_centres) const {
	PackedFloat64Array heights_all;
	const int64_t zones = p_platforms_from.size() - 1;
	if (zones <= 0) {
		return heights_all;
	}
	heights_all.resize(zones);
	double *out = heights_all.ptrw();
	const Vector3 *middles = p_middles.ptr();
	const int32_t *from = p_platforms_from.ptr();
	const int32_t *platforms = p_platforms.ptr();
	const Vector3 *centres = p_centres.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (zone < p_rooms) {
			out[zone] = double(middles[zone].y);
			continue;
		}
		double height = -INF;
		for (int32_t at = from[zone]; at < from[zone + 1]; at++) {
			height = max_f(height, double(centres[platforms[at]].y));
		}
		out[zone] = height;
	}
	return heights_all;
}

// WalkGraph._flood_every_zone: 2 for flooded, 1 for not, what is known kept.
PackedByteArray NativeWater::flooded(const PackedByteArray &p_known, int64_t p_rooms,
		const PackedByteArray &p_middles_wet, const PackedInt32Array &p_platforms_from,
		const PackedInt32Array &p_platforms, const PackedByteArray &p_platforms_wet) const {
	PackedByteArray flooded_all = p_known;
	const int64_t zones = flooded_all.size();
	uint8_t *out = flooded_all.ptrw();
	const uint8_t *middles = p_middles_wet.ptr();
	const int32_t *from = p_platforms_from.ptr();
	const int32_t *platforms = p_platforms.ptr();
	const uint8_t *decks = p_platforms_wet.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (out[zone] != 0) {
			continue;
		}
		bool under = true;
		if (zone < p_rooms) {
			under = middles[zone] == 1;
		} else {
			for (int32_t at = from[zone]; at < from[zone + 1]; at++) {
				if (decks[platforms[at]] != 1) {
					under = false;
					break;
				}
			}
		}
		out[zone] = under ? 2 : 1;
	}
	return flooded_all;
}

// WalkGraph._wet_every_portal, every portal's shut known already.
PackedByteArray NativeWater::portals_wet(const PackedByteArray &p_known, const PackedByteArray &p_ends_wet,
		const PackedByteArray &p_shut) const {
	PackedByteArray wet_all = p_known;
	const int64_t portals = wet_all.size();
	uint8_t *out = wet_all.ptrw();
	const uint8_t *ends = p_ends_wet.ptr();
	const uint8_t *shut = p_shut.ptr();
	for (int64_t index = 0; index < portals; index++) {
		if (out[index] != 0) {
			continue;
		}
		const bool wet = ends[index * 2] == 1 || ends[index * 2 + 1] == 1;
		out[index] = wet || shut[index] == 2 ? 2 : 1;
	}
	return wet_all;
}

// WalkGraph._closed_ways' loop: 1 where a search may not go through the portal.
PackedByteArray NativeWater::closed(const PackedInt32Array &p_portal_to, bool p_falling,
		const PackedByteArray &p_doomed, bool p_swim, bool p_wade, const PackedByteArray &p_flooded,
		const PackedByteArray &p_shut, const PackedByteArray &p_portal_wet) const {
	PackedByteArray closed_all;
	const int64_t portals = p_portal_to.size();
	closed_all.resize(portals);
	closed_all.fill(0);
	uint8_t *out = closed_all.ptrw();
	const int32_t *to = p_portal_to.ptr();
	const uint8_t *doomed = p_doomed.ptr();
	const uint8_t *flooded = p_flooded.ptr();
	const uint8_t *shut = p_shut.ptr();
	const uint8_t *wet = p_portal_wet.ptr();
	for (int64_t index = 0; index < portals; index++) {
		const int32_t other = to[index];
		if ((p_falling && doomed[other] == 2) ||
				(!p_swim && (flooded[other] == 2 || shut[index] == 2)) ||
				(!p_swim && !p_wade && wet[index] == 2)) {
			out[index] = 1;
		}
	}
	return closed_all;
}

// WalkGraph.highest_in's loop: the highest zone reached and not giving way, or NONE.
int64_t NativeWater::highest(const PackedByteArray &p_reached, bool p_falling, const PackedByteArray &p_doomed,
		const PackedFloat64Array &p_heights) const {
	int64_t best = NONE;
	double best_height = -INF;
	const int64_t zones = p_reached.size();
	const uint8_t *reached = p_reached.ptr();
	const uint8_t *doomed = p_doomed.ptr();
	const double *heights = p_heights.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (reached[zone] == 0 || (p_falling && doomed[zone] == 2)) {
			continue;
		}
		const double height = heights[zone];
		if (height > best_height) {
			best = zone;
			best_height = height;
		}
	}
	return best;
}

// BotRefuge.choose's loop: [best, its height, the kept one's height (-INF for none)],
// each zone's height marked down by its rise (BotRefuge._rise) times p_rise_seconds.
PackedFloat64Array NativeWater::refuge(const PackedByteArray &p_reached, bool p_falling,
		const PackedByteArray &p_doomed, const PackedFloat64Array &p_heights, bool p_rising,
		const PackedFloat64Array &p_then, const PackedFloat64Array &p_now, double p_seconds,
		double p_rise_seconds, int64_t p_kept) const {
	int64_t best = NONE;
	double best_height = -INF;
	double kept_height = -INF;
	const int64_t zones = p_reached.size();
	const uint8_t *reached = p_reached.ptr();
	const uint8_t *doomed = p_doomed.ptr();
	const double *heights = p_heights.ptr();
	const double *then = p_then.ptr();
	const double *now = p_now.ptr();
	for (int64_t zone = 0; zone < zones; zone++) {
		if (reached[zone] == 0 || (p_falling && doomed[zone] == 2)) {
			continue;
		}
		double rise = 0.0;
		if (p_rising) {
			const double fallen = then[zone] - now[zone];
			rise = max_f(fallen / p_seconds, 0.0);
		}
		const double marked = rise * p_rise_seconds;
		const double height = heights[zone] - marked;
		if (zone == p_kept) {
			kept_height = height;
		}
		if (height > best_height) {
			best = zone;
			best_height = height;
		}
	}
	PackedFloat64Array found;
	found.push_back(double(best));
	found.push_back(best_height);
	found.push_back(kept_height);
	return found;
}

// WalkGraph.flooded_share's sum: each platform's area, and its area again where under.
double NativeWater::share(const PackedFloat64Array &p_areas, const PackedByteArray &p_under) const {
	double flooded = 0.0;
	double whole = 0.0;
	const int64_t platforms = p_areas.size();
	const double *areas = p_areas.ptr();
	const uint8_t *under = p_under.ptr();
	for (int64_t platform = 0; platform < platforms; platform++) {
		const double area = areas[platform];
		whole += area;
		flooded += under[platform] == 1 ? area : 0.0;
	}
	return whole > 0.0 ? flooded / whole : 0.0;
}

// LampPower._changed: per lamp in a cell (p_cells, NONE for none), its power p_lit[cell]
// and whether the cell's water p_levels[cell] has reached it, standing at p_world[index].y,
// as power * 2 + drowned; the lamps whose state differs from p_shown, in order, and every
// lamp's state after.
Array NativeWater::lamps_shown(const PackedInt32Array &p_cells, const PackedByteArray &p_lit,
		const PackedFloat64Array &p_levels, const PackedVector3Array &p_world, const PackedInt32Array &p_shown) const {
	PackedInt32Array changed;
	PackedInt32Array shown = p_shown;
	int32_t *out = shown.ptrw();
	const int32_t *cells = p_cells.ptr();
	const uint8_t *lit = p_lit.ptr();
	const double *levels = p_levels.ptr();
	const Vector3 *world = p_world.ptr();
	for (int64_t index = 0; index < p_cells.size(); index++) {
		const int32_t cell = cells[index];
		if (cell == NONE) {
			continue;
		}
		const bool drowned = levels[cell] >= double(world[index].y);
		const int32_t state = int32_t(lit[cell]) * 2 + (drowned ? 1 : 0);
		if (state == out[index]) {
			continue;
		}
		out[index] = state;
		changed.push_back(int32_t(index));
	}
	Array found;
	found.push_back(changed);
	found.push_back(shown);
	return found;
}

void NativeWater::_bind_methods() {
	ClassDB::bind_method(D_METHOD("lamps_shown", "cells", "lit", "levels", "world", "shown"),
			&NativeWater::lamps_shown);
	ClassDB::bind_method(D_METHOD("wet_all", "world", "cells", "keeps", "levels", "world_own_floors", "highest",
								 "dry"),
			&NativeWater::wet_all);
	ClassDB::bind_method(D_METHOD("chains_under", "points", "low", "high", "from", "to", "slot", "slot_from",
								 "slot_cells", "poking", "inside_port", "inside_starboard", "section_x",
								 "section_length", "outline_from", "outlines", "dry"),
			&NativeWater::chains_under);
	ClassDB::bind_method(D_METHOD("cells_at", "points", "low", "high", "from", "to", "slot", "slot_from",
								 "slot_cells", "poking", "inside_port", "inside_starboard", "section_x",
								 "section_length", "outline_from", "outlines"),
			&NativeWater::cells_at);
	ClassDB::bind_method(D_METHOD("lowest_of", "groups", "world", "chain_from", "chain_cells", "world_floors",
								 "levels", "dry"),
			&NativeWater::lowest_of);
	ClassDB::bind_method(D_METHOD("heights", "rooms", "middles", "platforms_from", "platforms", "centres"),
			&NativeWater::heights);
	ClassDB::bind_method(D_METHOD("flooded", "known", "rooms", "middles_wet", "platforms_from", "platforms",
								 "platforms_wet"),
			&NativeWater::flooded);
	ClassDB::bind_method(D_METHOD("portals_wet", "known", "ends_wet", "shut"), &NativeWater::portals_wet);
	ClassDB::bind_method(D_METHOD("closed", "portal_to", "falling", "doomed", "swim", "wade", "flooded", "shut",
								 "portal_wet"),
			&NativeWater::closed);
	ClassDB::bind_method(D_METHOD("highest", "reached", "falling", "doomed", "heights"), &NativeWater::highest);
	ClassDB::bind_method(D_METHOD("refuge", "reached", "falling", "doomed", "heights", "rising", "then", "now",
								 "seconds", "rise_seconds", "kept"),
			&NativeWater::refuge);
	ClassDB::bind_method(D_METHOD("share", "areas", "under"), &NativeWater::share);
}
