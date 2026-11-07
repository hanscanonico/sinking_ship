// core/prop_stands.gd, Surfaces.obstacle_contacts, rail_contacts and
// airborne_rail_contacts (with SpatialIndex.near, PlaneShapes, DoorLeaves.contacts and
// FallenFunnels.contacts) and Hazards._move's contact passes, operation for operation:
// a GDScript float is a double and a Vector2 or Vector3 floats, so a component read out
// of a vector is widened before it is summed, and a vector's own sums, products,
// lengths and dots are worked in float32 by godot-cpp's vectors, which are the engine's
// code. minf, maxf and clampf are the engine's (a < b ? a : b, …). Contraction is off
// (SConstruct).

#include "contacts_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <algorithm>
#include <cmath>
#include <limits>

using namespace godot;

namespace {
constexpr int32_t NONE = -1;
constexpr int32_t UNASKED = -2;
constexpr double INF = std::numeric_limits<double>::infinity();
// SpatialIndex.ROUNDING; PropStands.CELL and SLACK; PlaneShapes.CLIMB_MARGIN.
constexpr double ROUNDING = 0.000001;
constexpr double STANDS_CELL = 2.0;
constexpr double STANDS_SLACK = 0.001;
constexpr double CLIMB_MARGIN = 0.001;
// PropState.Body.
constexpr int32_t BODY_AIRBORNE = 1;
constexpr int32_t BODY_LOST = 2;
constexpr int32_t BODY_HUNG = 4;
// Hazards.Turn.
constexpr uint8_t TURN_RESTS = 1;
constexpr uint8_t TURN_STEPS = 2;

inline double min_f(double p_a, double p_b) {
	return p_a < p_b ? p_a : p_b;
}

inline double max_f(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}

inline double clamp_f(double p_value, double p_low, double p_high) {
	return p_value < p_low ? p_low : (p_value > p_high ? p_high : p_value);
}

inline int64_t clamp_i(int64_t p_value, int64_t p_low, int64_t p_high) {
	return p_value < p_low ? p_low : (p_value > p_high ? p_high : p_value);
}

inline int64_t floor_i(double p_value) {
	return int64_t(std::floor(p_value));
}

template <typename T, typename P>
void take_all(std::vector<T> &r_to, const P &p_from) {
	r_to.assign(p_from.ptr(), p_from.ptr() + p_from.size());
}

// PlaneShapes.rect_contact over the rectangle at p_position, p_size.
bool rect_contact(const Vector2 &p_position, const Vector2 &p_size, const Vector2 &p_point, double p_radius,
		ContactHit &r_hit) {
	const Vector2 end = p_position + p_size;
	const Vector2 closest = p_point.clamp(p_position, end);
	const Vector2 offset = p_point - closest;
	const real_t distance = offset.length();
	if (double(distance) > 0.0) {
		if (double(distance) < p_radius) {
			r_hit = ContactHit();
			r_hit.normal = offset / distance;
			r_hit.depth = p_radius - double(distance);
			return true;
		}
		return false;
	}
	// The centre is inside: out through the nearest side.
	const double sides[4] = {
		double(p_point.x) - double(p_position.x),
		double(end.x) - double(p_point.x),
		double(p_point.y) - double(p_position.y),
		double(end.y) - double(p_point.y),
	};
	const Vector2 normals[4] = { Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1) };
	int nearest = 0;
	for (int side = 0; side < 4; side++) {
		if (sides[side] < sides[nearest]) {
			nearest = side;
		}
	}
	r_hit = ContactHit();
	r_hit.normal = normals[nearest];
	r_hit.depth = sides[nearest] + p_radius;
	return true;
}

// PlaneShapes.circle_contact.
bool circle_contact(const Vector2 &p_centre, double p_circle_radius, const Vector2 &p_point, double p_radius,
		ContactHit &r_hit) {
	const Vector2 offset = p_point - p_centre;
	const real_t distance = offset.length();
	if (double(distance) >= p_circle_radius + p_radius) {
		return false;
	}
	r_hit = ContactHit();
	r_hit.normal = double(distance) > 0.0 ? offset / distance : Vector2(1, 0);
	r_hit.depth = p_circle_radius + p_radius - double(distance);
	return true;
}

// PlaneShapes.deepest_per_direction, in place.
void deepest_per_direction(std::vector<ContactHit> &r_contacts) {
	if (r_contacts.size() < 2) {
		return;
	}
	size_t kept = 0;
	for (size_t index = 0; index < r_contacts.size(); index++) {
		const ContactHit contact = r_contacts[index];
		bool merged = false;
		for (size_t other = 0; other < kept; other++) {
			ContactHit &into = r_contacts[other];
			if (into.normal.is_equal_approx(contact.normal)) {
				if (contact.depth > into.depth) {
					into.depth = contact.depth;
					into.railing = contact.railing;
					into.prop = contact.prop;
				}
				merged = true;
				break;
			}
		}
		if (!merged) {
			r_contacts[kept] = contact;
			kept++;
		}
	}
	r_contacts.resize(kept);
}

PackedFloat64Array packed(const std::vector<ContactHit> &p_contacts) {
	PackedFloat64Array found;
	found.resize(int64_t(p_contacts.size()) * 5);
	double *out = found.ptrw();
	for (const ContactHit &contact : p_contacts) {
		*out++ = double(contact.normal.x);
		*out++ = double(contact.normal.y);
		*out++ = contact.depth;
		*out++ = double(contact.railing);
		*out++ = double(contact.prop);
	}
	return found;
}

// Each query's own lists, so a query asked inside another's loop keeps its own.
thread_local std::vector<int32_t> near_outer;
thread_local std::vector<int32_t> near_inner;
thread_local std::vector<int32_t> near_props;
thread_local std::vector<ContactHit> contacts_found;
thread_local std::vector<ContactHit> rails_found;
thread_local std::vector<int32_t> landing_found;
} // namespace

// --- SpatialIndex ---

void ContactGrid::take(const Array &p_layout) {
	origin = p_layout[0];
	side = p_layout[1];
	const Vector2i size = p_layout[2];
	size_x = size.x;
	size_y = size.y;
	low = p_layout[3];
	band = p_layout[4];
	bands = int32_t(int64_t(p_layout[5]));
	scan_over = p_layout[6];
	take_all(columns_from, PackedInt32Array(p_layout[7]));
	take_all(columns, PackedInt32Array(p_layout[8]));
	take_all(cells_from, PackedInt32Array(p_layout[9]));
	take_all(cells, PackedInt32Array(p_layout[10]));
	take_all(all, PackedInt32Array(p_layout[11]));
}

Vector2i ContactGrid::cell_of(const Vector2 &p_point) const {
	const Vector2 at = (p_point - origin) / real_t(side);
	return Vector2i(int32_t(clamp_i(floor_i(double(at.x)), 0, size_x - 1)),
			int32_t(clamp_i(floor_i(double(at.y)), 0, size_y - 1)));
}

int32_t ContactGrid::band_of(double p_height) const {
	if (bands == 1) {
		return 0;
	}
	return int32_t(floor_i(clamp_f((p_height - low) / band, 0.0, double(bands - 1))));
}

void ContactGrid::near(const Vector2 &p_position, const Vector2 &p_end, double p_bottom, double p_top,
		std::vector<int32_t> &r_found) const {
	r_found.clear();
	const Vector2i low_cell = cell_of(p_position);
	const Vector2i high_cell = cell_of(p_end);
	int32_t first = band_of(p_bottom - ROUNDING);
	int32_t last = band_of(p_top + ROUNDING);
	const int64_t reached = int64_t(high_cell.x - low_cell.x + 1) * int64_t(high_cell.y - low_cell.y + 1) *
			int64_t(last - first + 1);
	if (double(reached) > scan_over) {
		r_found = all;
		return;
	}
	const std::vector<int32_t> *from = &cells_from;
	const std::vector<int32_t> *items = &cells;
	if (last - first + 1 == bands) {
		// Every band over a cell holds nothing its column does not.
		from = &columns_from;
		items = &columns;
		first = 0;
		last = 0;
	}
	int filled = 0;
	for (int32_t band_at = first; band_at <= last; band_at++) {
		for (int32_t row = low_cell.y; row <= high_cell.y; row++) {
			for (int32_t column = low_cell.x; column <= high_cell.x; column++) {
				const int64_t cell = (int64_t(band_at) * size_y + row) * size_x + column;
				const int32_t start = (*from)[cell];
				const int32_t stop = (*from)[cell + 1];
				if (start == stop) {
					continue;
				}
				filled++;
				r_found.insert(r_found.end(), items->begin() + start, items->begin() + stop);
			}
		}
	}
	if (filled > 1) {
		std::sort(r_found.begin(), r_found.end());
		r_found.erase(std::unique(r_found.begin(), r_found.end()), r_found.end());
	}
}

// --- PropStands ---

void NativeStands::setup(const PackedFloat64Array &p_radii, const PackedFloat64Array &p_heights,
		const Vector2 &p_origin, int64_t p_columns, int64_t p_rows) {
	take_all(radii_, p_radii);
	take_all(heights_, p_heights);
	widest_ = 0.0;
	for (double radius : radii_) {
		widest_ = max_f(widest_, radius);
	}
	feet_.assign(radii_.size(), Vector3());
	gone_.assign(radii_.size(), 1);
	cell_of_.assign(radii_.size(), -1);
	origin_ = p_origin;
	columns_ = int32_t(p_columns);
	rows_ = int32_t(p_rows);
	cells_.assign(size_t(columns_) * size_t(rows_), std::vector<int32_t>());
	round_.assign(cells_.size(), 0);
}

Vector2i NativeStands::cell_xz(double p_x, double p_z) const {
	return Vector2i(int32_t(clamp_i(floor_i((p_x - double(origin_.x)) / STANDS_CELL), 0, columns_ - 1)),
			int32_t(clamp_i(floor_i((p_z - double(origin_.y)) / STANDS_CELL), 0, rows_ - 1)));
}

int32_t NativeStands::cell(double p_x, double p_z) const {
	const Vector2i at = cell_xz(p_x, p_z);
	return at.y * columns_ + at.x;
}

void NativeStands::count_round(int32_t p_cell, int32_t p_by) {
	const int32_t column = p_cell % columns_;
	const int32_t row = p_cell / columns_;
	for (int32_t near_row = std::max(row - 1, 0); near_row < std::min(row + 2, rows_); near_row++) {
		for (int32_t near_column = std::max(column - 1, 0); near_column < std::min(column + 2, columns_);
				near_column++) {
			round_[near_row * columns_ + near_column] += p_by;
		}
	}
}

void NativeStands::put(int64_t p_prop, const Vector3 &p_at) {
	feet_[p_prop] = p_at;
	gone_[p_prop] = 0;
	const int32_t at = cell(double(p_at.x), double(p_at.z));
	const int32_t was = cell_of_[p_prop];
	if (at == was) {
		return;
	}
	if (was != -1) {
		std::vector<int32_t> &props = cells_[was];
		props.erase(std::lower_bound(props.begin(), props.end(), int32_t(p_prop)));
		count_round(was, -1);
	}
	std::vector<int32_t> &props = cells_[at];
	props.insert(std::lower_bound(props.begin(), props.end(), int32_t(p_prop)), int32_t(p_prop));
	count_round(at, 1);
	cell_of_[p_prop] = at;
}

void NativeStands::take(int64_t p_prop) {
	if (gone_[p_prop] == 1) {
		return;
	}
	gone_[p_prop] = 1;
	const int32_t was = cell_of_[p_prop];
	std::vector<int32_t> &props = cells_[was];
	props.erase(std::lower_bound(props.begin(), props.end(), int32_t(p_prop)));
	count_round(was, -1);
	cell_of_[p_prop] = -1;
}

void NativeStands::clear() {
	for (size_t prop = 0; prop < radii_.size(); prop++) {
		take(int64_t(prop));
	}
}

void NativeStands::near_into(double p_x, double p_z, double p_reach, int32_t p_except,
		std::vector<int32_t> &r_found) const {
	r_found.clear();
	const double out = p_reach + widest_ + STANDS_SLACK;
	if (out <= STANDS_CELL - STANDS_SLACK) {
		if (round_[cell(p_x, p_z)] == 0) {
			return;
		}
	}
	const Vector2i from = cell_xz(p_x - out, p_z - out);
	const Vector2i to = cell_xz(p_x + out, p_z + out);
	int cells = 0;
	for (int32_t row = from.y; row <= to.y; row++) {
		for (int32_t column = from.x; column <= to.x; column++) {
			const std::vector<int32_t> &props = cells_[row * columns_ + column];
			if (props.empty()) {
				continue;
			}
			cells++;
			for (int32_t prop : props) {
				const Vector3 &at = feet_[prop];
				const double within = radii_[prop] + p_reach + STANDS_SLACK;
				if (prop != p_except && std::fabs(double(at.x) - p_x) <= within &&
						std::fabs(double(at.z) - p_z) <= within) {
					r_found.push_back(prop);
				}
			}
		}
	}
	// Each cell is in index order; cells after cells are not.
	if (cells > 1) {
		std::sort(r_found.begin(), r_found.end());
	}
}

PackedInt32Array NativeStands::near(double p_x, double p_z, double p_reach, int64_t p_except) const {
	std::vector<int32_t> &found = near_props;
	near_into(p_x, p_z, p_reach, int32_t(p_except), found);
	PackedInt32Array out;
	out.resize(int64_t(found.size()));
	std::copy(found.begin(), found.end(), out.ptrw());
	return out;
}

PackedVector3Array NativeStands::feet_of(const PackedInt32Array &p_props) const {
	PackedVector3Array out;
	out.resize(p_props.size());
	Vector3 *write = out.ptrw();
	for (int64_t index = 0; index < p_props.size(); index++) {
		write[index] = feet_[p_props[index]];
	}
	return out;
}

PackedByteArray NativeStands::gone_of(const PackedInt32Array &p_props) const {
	PackedByteArray out;
	out.resize(p_props.size());
	uint8_t *write = out.ptrw();
	for (int64_t index = 0; index < p_props.size(); index++) {
		write[index] = gone_[p_props[index]];
	}
	return out;
}

void NativeStands::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "radii", "heights", "origin", "columns", "rows"), &NativeStands::setup);
	ClassDB::bind_method(D_METHOD("put", "prop", "at"), &NativeStands::put);
	ClassDB::bind_method(D_METHOD("take", "prop"), &NativeStands::take);
	ClassDB::bind_method(D_METHOD("clear"), &NativeStands::clear);
	ClassDB::bind_method(D_METHOD("near", "x", "z", "reach", "except_prop"), &NativeStands::near);
	ClassDB::bind_method(D_METHOD("feet_of", "props"), &NativeStands::feet_of);
	ClassDB::bind_method(D_METHOD("gone_of", "props"), &NativeStands::gone_of);
}

// --- Surfaces ---

void NativeSurfaces::setup(const PackedInt32Array &p_firsts, const PackedVector2Array &p_areas,
		const PackedFloat64Array &p_bottoms, const PackedFloat64Array &p_tops, const PackedByteArray &p_gone,
		const PackedByteArray &p_round, const PackedVector2Array &p_centres, const PackedFloat64Array &p_radii,
		const PackedByteArray &p_ramp_x, const PackedFloat64Array &p_ramp_heights, const Array &p_grid,
		const Ref<NativeStands> &p_stands) {
	first_ramp_ = p_firsts[0];
	first_top_ = p_firsts[1];
	first_lid_ = p_firsts[2];
	const int64_t count = p_bottoms.size();
	area_position_.resize(count);
	area_size_.resize(count);
	for (int64_t surface = 0; surface < count; surface++) {
		area_position_[surface] = p_areas[surface * 2];
		area_size_[surface] = p_areas[surface * 2 + 1];
	}
	take_all(bottoms_, p_bottoms);
	take_all(tops_, p_tops);
	take_all(gone_, p_gone);
	take_all(round_, p_round);
	take_all(centres_, p_centres);
	take_all(radii_, p_radii);
	take_all(ramp_x_, p_ramp_x);
	ramp_start_.resize(ramp_x_.size());
	ramp_end_.resize(ramp_x_.size());
	for (size_t ramp = 0; ramp < ramp_x_.size(); ramp++) {
		ramp_start_[ramp] = p_ramp_heights[int64_t(ramp) * 2];
		ramp_end_[ramp] = p_ramp_heights[int64_t(ramp) * 2 + 1];
	}
	grid_.take(p_grid);
	stands_ = p_stands;
}

void NativeSurfaces::railings(const PackedVector2Array &p_ends, const PackedVector2Array &p_normals,
		const PackedInt32Array &p_platforms, const PackedInt32Array &p_platform_rails_from,
		const PackedInt32Array &p_platform_rails, const PackedByteArray &p_gone, const Array &p_grid) {
	const int64_t count = p_normals.size();
	rail_from_.resize(count);
	rail_to_.resize(count);
	for (int64_t index = 0; index < count; index++) {
		rail_from_[index] = p_ends[index * 2];
		rail_to_[index] = p_ends[index * 2 + 1];
	}
	take_all(rail_normals_, p_normals);
	take_all(rail_platforms_, p_platforms);
	take_all(platform_rails_from_, p_platform_rails_from);
	take_all(platform_rails_, p_platform_rails);
	take_all(rail_gone_, p_gone);
	rail_grid_.take(p_grid);
}

void NativeSurfaces::doors(const PackedInt32Array &p_axes, const PackedFloat64Array &p_planes,
		const PackedFloat64Array &p_jambs, const PackedFloat64Array &p_widths, const PackedFloat64Array &p_sills,
		const PackedFloat64Array &p_heads) {
	take_all(door_axes_, p_axes);
	take_all(door_planes_, p_planes);
	take_all(door_jambs_, p_jambs);
	take_all(door_widths_, p_widths);
	take_all(door_sills_, p_sills);
	take_all(door_heads_, p_heads);
	door_shut_.assign(door_axes_.size(), 0.0);
}

void NativeSurfaces::shut(const PackedFloat64Array &p_shut) {
	take_all(door_shut_, p_shut);
}

void NativeSurfaces::felled(const PackedVector3Array &p_bases, const PackedFloat64Array &p_sizes,
		const PackedVector2Array &p_along) {
	take_all(fall_bases_, p_bases);
	take_all(fall_along_, p_along);
	fall_radii_.resize(fall_bases_.size());
	fall_heights_.resize(fall_bases_.size());
	for (size_t fall = 0; fall < fall_bases_.size(); fall++) {
		fall_radii_[fall] = p_sizes[int64_t(fall) * 2];
		fall_heights_[fall] = p_sizes[int64_t(fall) * 2 + 1];
	}
}

void NativeSurfaces::masked(const PackedByteArray &p_gone, const PackedByteArray &p_rail_gone) {
	take_all(gone_, p_gone);
	take_all(rail_gone_, p_rail_gone);
}

void NativeSurfaces::topped(const PackedFloat64Array &p_tops) {
	take_all(tops_, p_tops);
}

void NativeSurfaces::lidded(const PackedByteArray &p_lids) {
	take_all(lids_, p_lids);
}

// ShipRamp.height_at.
double NativeSurfaces::ramp_height(int32_t p_surface, double p_x, double p_z) const {
	const int32_t ramp = p_surface - first_ramp_;
	const bool x_axis = ramp_x_[ramp] == 1;
	const Vector2 &position = area_position_[p_surface];
	const Vector2 &size = area_size_[p_surface];
	const double along_at = x_axis ? p_x : p_z;
	const double start = x_axis ? double(position.x) : double(position.y);
	const double length = x_axis ? double(size.x) : double(size.y);
	const double weight = clamp_f((along_at - start) / length, 0.0, 1.0);
	const double from = ramp_start_[ramp];
	return from + (ramp_end_[ramp] - from) * weight;
}

// Surfaces.height_at, for her own surfaces.
double NativeSurfaces::height_at(int32_t p_surface, double p_x, double p_z) const {
	if (p_surface >= first_ramp_ && p_surface < first_top_) {
		return ramp_height(p_surface, p_x, p_z);
	}
	return tops_[p_surface];
}

// Surfaces._contains, for a platform or a ramp.
bool NativeSurfaces::contains(int32_t p_surface, double p_x, double p_z) const {
	const Vector2 &position = area_position_[p_surface];
	const Vector2 end = position + area_size_[p_surface];
	return p_x >= double(position.x) && p_x <= double(end.x) && p_z >= double(position.y) &&
			p_z <= double(end.y);
}

// Surfaces._contains, for any surface of hers: a round blocker's top by its circle.
bool NativeSurfaces::holds(int32_t p_surface, double p_x, double p_z) const {
	if (p_surface >= first_top_ && round_[p_surface - first_top_] == 1) {
		const int32_t blocker = p_surface - first_top_;
		return double(Vector2(p_x, p_z).distance_to(centres_[blocker])) <= radii_[blocker];
	}
	return contains(p_surface, p_x, p_z);
}

// Surfaces.landing: _highest_at_or_below over every surface, the crates' lids after hers
// in number order (_with_lids), never p_except_prop's.
int64_t NativeSurfaces::landing(const Vector3 &p_ship_point, int64_t p_except_prop) const {
	std::vector<int32_t> &near = landing_found;
	const double x = double(p_ship_point.x);
	const double z = double(p_ship_point.z);
	const double height_y = double(p_ship_point.y);
	const Vector2 at(p_ship_point.x, p_ship_point.z);
	grid_.near(at, at, -INF, height_y, near);
	const size_t ships = near.size();
	std::vector<int32_t> &props = near_props;
	stands_->near_into(x, z, 0.0, int32_t(p_except_prop), props);
	for (int32_t prop : props) {
		if (lids_[prop] == 0) {
			continue;
		}
		// PropStands.covers.
		const Vector3 &foot = stands_->foot(prop);
		if (double(Vector2(real_t(x - double(foot.x)), real_t(z - double(foot.z))).length()) <=
				stands_->radius(prop)) {
			near.push_back(first_lid_ + prop);
		}
	}
	int32_t best = NONE;
	double best_height = -INF;
	for (size_t index = 0; index < near.size(); index++) {
		const int32_t surface = near[index];
		double height;
		if (index >= ships) {
			// A lid: covered, as asked above; PropStands.top.
			const int32_t prop = surface - first_lid_;
			height = double(stands_->foot(prop).y) + stands_->height(prop);
		} else {
			if (gone_[surface] == 1 || !holds(surface, x, z)) {
				continue;
			}
			height = height_at(surface, x, z);
		}
		if (height <= height_y && height > best_height) {
			best = surface;
			best_height = height;
		}
	}
	return best;
}

// Surfaces.ceiling: the lowest underside (_underside) more than p_clearance over the feet.
double NativeSurfaces::ceiling(const Vector3 &p_ship_point, double p_clearance) const {
	std::vector<int32_t> &near = landing_found;
	const double x = double(p_ship_point.x);
	const double z = double(p_ship_point.z);
	const double over = double(p_ship_point.y) + p_clearance;
	const Vector2 at(p_ship_point.x, p_ship_point.z);
	grid_.near(at, at, over, INF, near);
	double lowest = INF;
	for (int32_t surface : near) {
		if (gone_[surface] == 1 || !holds(surface, x, z)) {
			continue;
		}
		const double underside = surface >= first_ramp_ ? bottoms_[surface] : tops_[surface];
		if (underside > over) {
			lowest = min_f(lowest, underside);
		}
	}
	return lowest;
}

// Surfaces._highest_at_or_below(p_ship_point, _first_top): her platforms and ramps.
int32_t NativeSurfaces::highest_ship(const Vector3 &p_ship_point) const {
	std::vector<int32_t> &near = near_inner;
	const Vector2 at(p_ship_point.x, p_ship_point.z);
	const double height_y = double(p_ship_point.y);
	grid_.near(at, at, -INF, height_y, near);
	int32_t best = NONE;
	double best_height = -INF;
	for (int32_t surface : near) {
		if (surface >= first_top_) {
			break;
		}
		if (gone_[surface] == 1 || !contains(surface, double(p_ship_point.x), double(p_ship_point.z))) {
			continue;
		}
		const double height = height_at(surface, double(p_ship_point.x), double(p_ship_point.z));
		if (height <= height_y && height > best_height) {
			best = surface;
			best_height = height;
		}
	}
	return best;
}

int32_t NativeSurfaces::stair_under(const Vector2 &p_point, double p_feet, double p_step) const {
	const Vector3 at(p_point.x, real_t(p_feet + p_step), p_point.y);
	const int32_t stand = highest_ship(at);
	if (stand < first_ramp_ || height_at(stand, double(at.x), double(at.z)) < p_feet - p_step) {
		return NONE;
	}
	return stand;
}

double NativeSurfaces::along(int32_t p_stair, const Vector2 &p_at, double p_feet) const {
	if (p_stair == NONE) {
		return p_feet;
	}
	return ramp_height(p_stair, double(p_at.x), double(p_at.y));
}

bool NativeSurfaces::crawls_under(int32_t p_surface, const Vector2 &p_point, double p_reach, double p_feet,
		double p_step, double p_crawl_height, int32_t p_stair) const {
	const double underside = bottoms_[p_surface];
	if (underside < p_feet + p_crawl_height && p_stair == NONE) {
		return false;
	}
	const Vector2 &position = area_position_[p_surface];
	const Vector2 closest = p_point.clamp(position, position + area_size_[p_surface]);
	Vector2 under_it = closest;
	if (closest != p_point) {
		under_it += (closest - p_point).normalized() * real_t(p_reach);
	}
	const double low = min_f(along(p_stair, under_it, p_feet), p_feet);
	if (underside < low + p_crawl_height) {
		return false;
	}
	const Vector3 at(under_it.x, real_t(p_feet + p_step), under_it.y);
	const int32_t ground = highest_ship(at);
	if (ground == NONE) {
		return false;
	}
	const double height = height_at(ground, double(at.x), double(at.z));
	return height >= low - p_step && underside - height >= p_crawl_height;
}

// PlaneShapes.climb_contact.
bool NativeSurfaces::climb_contact(int32_t p_surface, const Vector2 &p_point, double p_radius, double p_reach,
		ContactHit &r_hit) const {
	const int32_t ramp = p_surface - first_ramp_;
	const bool x_axis = ramp_x_[ramp] == 1;
	const Vector2 &position = area_position_[p_surface];
	const Vector2 &size = area_size_[p_surface];
	const double length = x_axis ? double(size.x) : double(size.y);
	const double along_at = x_axis ? double(p_point.x) - double(position.x) : double(p_point.y) - double(position.y);
	const double start = ramp_start_[ramp];
	const double rise = (ramp_end_[ramp] - start) / length;
	const Vector2 outward = x_axis ? Vector2(1, 0) : Vector2(0, 1);
	const Vector2 high_end = rise > 0.0 ? outward : -outward;
	// A hair under the reach, so the feet find the ramp within a step when grounded.
	const double limit = clamp_f((p_reach - CLIMB_MARGIN - start) / rise, 0.0, length);
	r_hit = ContactHit();
	r_hit.normal = -high_end;
	r_hit.depth = std::fabs(along_at - limit) + CLIMB_MARGIN / std::fabs(rise);
	const Vector2 end = position + size;
	const double sides[4] = {
		double(p_point.x) - double(position.x),
		double(end.x) - double(p_point.x),
		double(p_point.y) - double(position.y),
		double(end.y) - double(p_point.y),
	};
	const Vector2 normals[4] = { Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1) };
	for (int side = 0; side < 4; side++) {
		if (normals[side] == high_end) {
			continue;
		}
		if (sides[side] + p_radius < r_hit.depth) {
			r_hit.normal = normals[side];
			r_hit.depth = sides[side] + p_radius;
		}
	}
	return true;
}

void NativeSurfaces::obstacles(const Vector3 &p_ship_point, double p_radius, double p_body_height, double p_step,
		int32_t p_except_prop, double p_crawl_height, double p_crawl_reach,
		std::vector<ContactHit> &r_found) const {
	r_found.clear();
	const Vector2 point(p_ship_point.x, p_ship_point.z);
	const double feet = double(p_ship_point.y);
	// _overlaps' two heights, once.
	const double reach_up = feet + p_step;
	const double head = feet + p_body_height;
	const double reach_in = p_crawl_reach < 0.0 ? p_radius : p_crawl_reach;
	const Vector2 corner = Vector2(real_t(p_radius), real_t(p_radius));
	const Vector2 box_position = point - corner;
	const Vector2 box_end = box_position + corner * real_t(2.0);
	std::vector<int32_t> &near = near_outer;
	grid_.near(box_position, box_end, reach_up, head, near);
	int32_t stair = UNASKED;
	ContactHit hit;
	for (int32_t surface : near) {
		if (surface < first_top_) {
			continue;
		}
		if (!(reach_up < tops_[surface] && head > bottoms_[surface])) {
			continue;
		}
		if (stair == UNASKED) {
			stair = stair_under(point, feet, p_step);
		}
		if (crawls_under(surface, point, reach_in, feet, p_step, p_crawl_height, stair)) {
			continue;
		}
		const int32_t blocker = surface - first_top_;
		bool met;
		if (round_[blocker] == 0) {
			const Vector2 &position = area_position_[surface];
			const Vector2 &size = area_size_[surface];
			const Vector2 nearest = point.clamp(position, position + size);
			if (tops_[surface] <= along(stair, nearest, feet) + p_step) {
				continue;
			}
			met = rect_contact(position, size, point, p_radius, hit);
		} else {
			met = circle_contact(centres_[blocker], radii_[blocker], point, p_radius, hit);
		}
		if (met) {
			r_found.push_back(hit);
		}
	}
	for (int32_t surface : near) {
		if (surface >= first_top_) {
			break;
		}
		if (gone_[surface] == 1) {
			continue;
		}
		const Vector2 &position = area_position_[surface];
		const Vector2 &size = area_size_[surface];
		const Vector2 closest = point.clamp(position, position + size);
		const double top = height_at(surface, double(closest.x), double(closest.y));
		if (!(reach_up < top && head > bottoms_[surface])) {
			continue;
		}
		if (stair == UNASKED) {
			stair = stair_under(point, feet, p_step);
		}
		if (surface < first_ramp_ && top <= along(stair, closest, feet) + p_step) {
			continue;
		}
		if (crawls_under(surface, point, reach_in, feet, p_step, p_crawl_height, stair)) {
			continue;
		}
		bool met;
		if (surface >= first_ramp_ && closest == point) {
			met = climb_contact(surface, point, p_radius, reach_up, hit);
		} else {
			met = rect_contact(position, size, point, p_radius, hit);
		}
		if (met) {
			r_found.push_back(hit);
		}
	}
	const NativeStands *stands = stands_.ptr();
	std::vector<int32_t> &props = near_props;
	stands->near_into(double(point.x), double(point.y), p_radius, p_except_prop, props);
	for (int32_t prop : props) {
		const Vector3 &under_it = stands->foot(prop);
		if (!(reach_up < double(under_it.y) + stands->height(prop) && head > double(under_it.y))) {
			continue;
		}
		const Vector2 centre(under_it.x, under_it.z);
		if (circle_contact(centre, stands->radius(prop), point, p_radius, hit)) {
			hit.prop = prop;
			r_found.push_back(hit);
		}
	}
	// DoorLeaves.contacts.
	for (size_t door = 0; door < door_axes_.size(); door++) {
		if (door_shut_[door] <= 0.0 || reach_up >= door_heads_[door] || head <= door_sills_[door]) {
			continue;
		}
		const bool x_axis = door_axes_[door] == 0;
		const double across = (x_axis ? double(point.x) : double(point.y)) - door_planes_[door];
		const double along_at = x_axis ? double(point.y) : double(point.x);
		const double from = door_jambs_[door];
		const double to = from + door_widths_[door] * door_shut_[door];
		const double off = max_f(max_f(from - along_at, along_at - to), 0.0);
		if (off >= p_radius) {
			continue;
		}
		const double reach = std::sqrt(p_radius * p_radius - off * off);
		if (std::fabs(across) >= reach) {
			continue;
		}
		const double side = across >= 0.0 ? 1.0 : -1.0;
		hit = ContactHit();
		hit.normal = x_axis ? Vector2(real_t(side), 0.0) : Vector2(0.0, real_t(side));
		hit.depth = reach - std::fabs(across);
		r_found.push_back(hit);
	}
	// FallenFunnels.contacts.
	for (size_t fall = 0; fall < fall_bases_.size(); fall++) {
		const Vector3 &base = fall_bases_[fall];
		const double radius = fall_radii_[fall];
		if (reach_up >= double(base.y) + radius * 2.0 || head <= double(base.y)) {
			continue;
		}
		const Vector2 &along_way = fall_along_[fall];
		const Vector2 off = point - Vector2(base.x, base.z);
		const Vector2 local(off.dot(along_way),
				real_t(double(off.x) * double(along_way.y) - double(off.y) * double(along_way.x)));
		const Vector2 strip_position(0.0, real_t(-radius));
		const Vector2 strip_size(real_t(fall_heights_[fall]), real_t(radius * 2.0));
		if (rect_contact(strip_position, strip_size, local, p_radius, hit)) {
			const Vector2 normal = hit.normal;
			hit.normal = along_way * normal.x + Vector2(along_way.y, -along_way.x) * normal.y;
			r_found.push_back(hit);
		}
	}
	deepest_per_direction(r_found);
}

PackedFloat64Array NativeSurfaces::obstacle_contacts(const Vector3 &p_ship_point, double p_radius,
		double p_body_height, double p_step, int64_t p_except_prop, double p_crawl_height,
		double p_crawl_reach) const {
	std::vector<ContactHit> &found = contacts_found;
	obstacles(p_ship_point, p_radius, p_body_height, p_step, int32_t(p_except_prop), p_crawl_height, p_crawl_reach,
			found);
	return packed(found);
}

// Surfaces._rail_contact.
bool NativeSurfaces::rail_contact(int32_t p_index, const Vector2 &p_point, double p_radius,
		ContactHit &r_hit) const {
	const Vector2 offset = p_point - rail_from_[p_index];
	// Clear of its line first: most railings a body is asked about are.
	const double inside = double(offset.dot(rail_normals_[p_index]));
	if (std::fabs(inside) >= p_radius) {
		return false;
	}
	const Vector2 span = rail_to_[p_index] - rail_from_[p_index];
	const double along_at = double(offset.dot(span)) / double(span.length_squared());
	if (along_at < 0.0 || along_at > 1.0) {
		return false;
	}
	r_hit = ContactHit();
	r_hit.normal = rail_normals_[p_index];
	r_hit.depth = p_radius - inside;
	r_hit.railing = p_index;
	return true;
}

void NativeSurfaces::rails(const Vector3 &p_ship_point, double p_radius, int32_t p_surface,
		std::vector<ContactHit> &r_found) const {
	r_found.clear();
	if (p_surface < 0 || p_surface >= first_ramp_) {
		return;
	}
	const Vector2 point(p_ship_point.x, p_ship_point.z);
	ContactHit hit;
	for (int32_t at = platform_rails_from_[p_surface]; at < platform_rails_from_[p_surface + 1]; at++) {
		const int32_t index = platform_rails_[at];
		if (rail_gone_[index] == 1) {
			continue;
		}
		if (rail_contact(index, point, p_radius, hit)) {
			r_found.push_back(hit);
		}
	}
	deepest_per_direction(r_found);
}

void NativeSurfaces::airborne_rails(const Vector3 &p_ship_point, const Vector2 &p_came_from, double p_radius,
		double p_body_height, double p_railing_height, std::vector<ContactHit> &r_found) const {
	r_found.clear();
	const Vector2 point(p_ship_point.x, p_ship_point.z);
	const Vector2 corner = Vector2(real_t(p_radius), real_t(p_radius));
	const Vector2 box_position = point - corner;
	const Vector2 box_end = box_position + corner * real_t(2.0);
	const double feet = double(p_ship_point.y);
	const double low = feet - p_railing_height;
	std::vector<int32_t> &near = near_inner;
	rail_grid_.near(box_position, box_end, low, feet + p_body_height, near);
	ContactHit hit;
	for (int32_t index : near) {
		if (rail_gone_[index] == 1) {
			continue;
		}
		const double deck = tops_[rail_platforms_[index]];
		if (feet >= deck + p_railing_height || feet + p_body_height <= deck) {
			continue;
		}
		if (double((p_came_from - rail_from_[index]).dot(rail_normals_[index])) < 0.0) {
			continue;
		}
		if (rail_contact(index, point, p_radius, hit)) {
			r_found.push_back(hit);
		}
	}
	deepest_per_direction(r_found);
}

PackedFloat64Array NativeSurfaces::rail_contacts(const Vector3 &p_ship_point, double p_radius,
		int64_t p_surface) const {
	std::vector<ContactHit> &found = rails_found;
	rails(p_ship_point, p_radius, int32_t(p_surface), found);
	return packed(found);
}

PackedFloat64Array NativeSurfaces::airborne_rail_contacts(const Vector3 &p_ship_point, const Vector2 &p_came_from,
		double p_radius, double p_body_height, double p_railing_height) const {
	std::vector<ContactHit> &found = rails_found;
	airborne_rails(p_ship_point, p_came_from, p_radius, p_body_height, p_railing_height, found);
	return packed(found);
}

void NativeSurfaces::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "firsts", "areas", "bottoms", "tops", "gone", "round", "centres", "radii",
								 "ramp_x", "ramp_heights", "grid", "stands"),
			&NativeSurfaces::setup);
	ClassDB::bind_method(D_METHOD("railings", "ends", "normals", "platforms", "platform_rails_from",
								 "platform_rails", "gone", "grid"),
			&NativeSurfaces::railings);
	ClassDB::bind_method(D_METHOD("doors", "axes", "planes", "jambs", "widths", "sills", "heads"),
			&NativeSurfaces::doors);
	ClassDB::bind_method(D_METHOD("shut", "shut"), &NativeSurfaces::shut);
	ClassDB::bind_method(D_METHOD("felled", "bases", "sizes", "along"), &NativeSurfaces::felled);
	ClassDB::bind_method(D_METHOD("masked", "gone", "rail_gone"), &NativeSurfaces::masked);
	ClassDB::bind_method(D_METHOD("topped", "tops"), &NativeSurfaces::topped);
	ClassDB::bind_method(D_METHOD("lidded", "lids"), &NativeSurfaces::lidded);
	ClassDB::bind_method(D_METHOD("landing", "ship_point", "except_prop"), &NativeSurfaces::landing);
	ClassDB::bind_method(D_METHOD("ceiling", "ship_point", "clearance"), &NativeSurfaces::ceiling);
	ClassDB::bind_method(D_METHOD("obstacle_contacts", "ship_point", "radius", "body_height", "step", "except_prop",
								 "crawl_height", "crawl_reach"),
			&NativeSurfaces::obstacle_contacts);
	ClassDB::bind_method(D_METHOD("rail_contacts", "ship_point", "radius", "surface"), &NativeSurfaces::rail_contacts);
	ClassDB::bind_method(D_METHOD("airborne_rail_contacts", "ship_point", "came_from", "radius", "body_height",
								 "railing_height"),
			&NativeSurfaces::airborne_rail_contacts);
	ClassDB::bind_method(D_METHOD("floors", "from", "floors", "clearances"), &NativeSurfaces::floors);
	ClassDB::bind_method(D_METHOD("under", "ship_point", "step", "except_prop"), &NativeSurfaces::under);
	ClassDB::bind_method(D_METHOD("floor_way", "from", "end", "keep", "rules"), &NativeSurfaces::floor_way);
}

// --- Hazards._move's contact passes ---

namespace {
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
const StringName &name_shoved_by() {
	static const StringName name("shoved_by");
	return name;
}
const StringName &name_shoved_at() {
	static const StringName name("shoved_at");
	return name;
}
} // namespace

void NativeCrates::setup(const Ref<NativeSurfaces> &p_surfaces, const Ref<NativeStands> &p_at_rest,
		const PackedFloat64Array &p_radii, const PackedFloat64Array &p_heights, const PackedFloat64Array &p_masses,
		const PackedByteArray &p_solid, const PackedByteArray &p_harmless, const PackedFloat64Array &p_rules) {
	surfaces_ = p_surfaces;
	at_rest_ = p_at_rest;
	take_all(radii_, p_radii);
	take_all(heights_, p_heights);
	take_all(masses_, p_masses);
	take_all(solid_, p_solid);
	take_all(harmless_, p_harmless);
	step_height_ = p_rules[0];
	railing_height_ = p_rules[1];
	railing_break_speed_ = p_rules[2];
	crate_impact_speed_ = p_rules[3];
	crate_restitution_ = p_rules[4];
	credit_window_ticks_ = int64_t(p_rules[5]);
	contact_passes_ = int64_t(p_rules[6]);
}

NativeCrates::Crate &NativeCrates::crate(int32_t p_prop) {
	Crate &found = state_[p_prop];
	if (read_[p_prop] == 0) {
		read_[p_prop] = 1;
		Object *prop = (*props_)[p_prop];
		found.pos = prop->get(name_pos());
		found.vel = prop->get(name_vel());
		found.body = int32_t(int64_t(prop->get(name_body())));
		found.surface = int32_t(int64_t(prop->get(name_surface())));
		found.shoved_by = prop->get(name_shoved_by());
		found.shoved_at = prop->get(name_shoved_at());
	}
	return found;
}

// What the passes change of each crate, back on its PropState: the body and surface
// they never change.
void NativeCrates::write_back() const {
	for (int32_t prop : crates_) {
		const Crate &found = state_[prop];
		Object *object = (*props_)[prop];
		object->set(name_pos(), found.pos);
		object->set(name_vel(), found.vel);
		object->set(name_shoved_by(), found.shoved_by);
		object->set(name_shoved_at(), found.shoved_at);
	}
}

// Hazards._stand_one, for the whole ship (PropStands.stand).
void NativeCrates::stand_one(int32_t p_prop) {
	const Crate &found = state_[p_prop];
	NativeStands *stands = surfaces_->stands();
	const bool loose = found.body != BODY_LOST && found.body < BODY_HUNG;
	if (loose && solid_[p_prop] == 1) {
		stands->put(p_prop, found.pos);
	} else {
		stands->take(p_prop);
	}
}

void NativeCrates::wake(int32_t p_other) {
	if (turn_[p_other] != TURN_RESTS) {
		return;
	}
	turn_[p_other] = TURN_STEPS;
	at_rest_->take(p_other);
	const Crate &other = crate(p_other);
	feet_before_[p_other] = double(other.pos.y);
	came_from_[p_other] = Vector2(other.pos.x, other.pos.z);
	woken_.push_back(p_other);
	size_t at = crates_.size();
	while (at > 0 && crates_[at - 1] > p_other) {
		at--;
	}
	crates_.insert(crates_.begin() + int64_t(at), p_other);
}

void NativeCrates::stir_near(int32_t p_prop) {
	if (solid_[p_prop] == 0) {
		return;
	}
	const Crate &found = state_[p_prop];
	std::vector<int32_t> near;
	at_rest_->near_into(double(found.pos.x), double(found.pos.z), radii_[p_prop], p_prop, near);
	for (int32_t index : near) {
		if (turn_[index] == TURN_RESTS) {
			wake(index);
		}
	}
}

int32_t NativeCrates::after(int32_t p_at, int32_t p_prop) const {
	if (crates_[p_at] == p_prop) {
		return p_at + 1;
	}
	return int32_t(std::find(crates_.begin(), crates_.end(), p_prop) - crates_.begin()) + 1;
}

void NativeCrates::hold(Crate &r_crate, const ContactHit &p_contact) const {
	r_crate.pos += Vector3(p_contact.normal.x, 0.0, p_contact.normal.y) * real_t(p_contact.depth);
	Vector2 planar(r_crate.vel.x, r_crate.vel.z);
	const double into = -double(planar.dot(p_contact.normal));
	if (into > 0.0) {
		planar += p_contact.normal * real_t(into);
		r_crate.vel = Vector3(planar.x, r_crate.vel.y, planar.y);
	}
}

void NativeCrates::knock(int32_t p_prop, int32_t p_other, const ContactHit &p_contact) {
	Crate &mover = state_[p_prop];
	Crate &other = crate(p_other);
	const Vector2 normal = p_contact.normal;
	mover.pos += Vector3(normal.x, 0.0, normal.y) * real_t(p_contact.depth);
	Vector2 mine(mover.vel.x, mover.vel.z);
	Vector2 theirs(other.vel.x, other.vel.z);
	const double toward = -double(mine.dot(normal));
	const double back = double(theirs.dot(normal));
	const double meeting = toward + back;
	if (meeting <= 0.0) {
		return;
	}
	const bool impact = meeting >= crate_impact_speed_;
	const double parting = 1.0 + (impact ? crate_restitution_ : 0.0);
	const double mass = masses_[p_prop];
	const double other_mass = masses_[p_other];
	const double total = mass + other_mass;
	mine += normal * real_t(parting * other_mass / total * meeting);
	theirs -= normal * real_t(parting * mass / total * meeting);
	mover.vel = Vector3(mine.x, mover.vel.y, mine.y);
	other.vel = Vector3(theirs.x, other.vel.y, theirs.y);
	if (!impact) {
		return;
	}
	Crate &hitter = toward >= back ? mover : other;
	Crate &struck = toward >= back ? other : mover;
	if (hitter.shoved_by != -1 && tick_ - hitter.shoved_at < credit_window_ticks_) {
		struck.shoved_by = hitter.shoved_by;
		struck.shoved_at = tick_;
	}
}

bool NativeCrates::blockers(int32_t p_prop) {
	const Crate &mover = state_[p_prop];
	const Vector3 feet(mover.pos.x, real_t(feet_before_[p_prop]), mover.pos.z);
	std::vector<ContactHit> contacts;
	surfaces_->obstacles(feet, radii_[p_prop], heights_[p_prop], step_height_, p_prop, INF, -1.0, contacts);
	for (const ContactHit &contact : contacts) {
		if (contact.prop == -1) {
			hold(state_[p_prop], contact);
		} else {
			wake(contact.prop);
			knock(p_prop, contact.prop, contact);
		}
	}
	return !contacts.empty();
}

bool NativeCrates::railings(int32_t p_prop, const Callable &p_damage) {
	std::vector<ContactHit> contacts;
	{
		const Crate &mover = state_[p_prop];
		if (mover.body == BODY_AIRBORNE) {
			surfaces_->airborne_rails(mover.pos, came_from_[p_prop], radii_[p_prop], heights_[p_prop],
					railing_height_, contacts);
		} else {
			surfaces_->rails(mover.pos, radii_[p_prop], mover.surface, contacts);
		}
	}
	bool held = false;
	for (const ContactHit &contact : contacts) {
		Crate &mover = state_[p_prop];
		const double into = -double(Vector2(mover.vel.x, mover.vel.z).dot(contact.normal));
		if (into >= railing_break_speed_ && solid_[p_prop] == 1 && harmless_[p_prop] == 0) {
			// Hazards.damage, in the GDScript: the crates as they stand now first.
			write_back();
			const bool broke = p_damage.call(contact.railing, p_prop);
			if (broke) {
				continue;
			}
		}
		hold(state_[p_prop], contact);
		held = true;
	}
	return held;
}

PackedInt32Array NativeCrates::move(const Array &p_props, const PackedInt32Array &p_crates, int64_t p_steps,
		double p_dt, int64_t p_tick, const PackedByteArray &p_turn, const PackedFloat64Array &p_feet_before,
		const PackedVector2Array &p_came_from, const Callable &p_damage) {
	props_ = &p_props;
	tick_ = p_tick;
	const size_t count = size_t(p_props.size());
	state_.resize(count);
	read_.assign(count, 0);
	take_all(turn_, p_turn);
	take_all(feet_before_, p_feet_before);
	take_all(came_from_, p_came_from);
	take_all(crates_, p_crates);
	woken_.clear();
	for (int32_t prop : crates_) {
		crate(prop);
	}
	const real_t dt = real_t(p_dt);
	for (int64_t step = 0; step < p_steps; step++) {
		int32_t at = 0;
		while (at < int32_t(crates_.size())) {
			const int32_t prop = crates_[at];
			Crate &mover = state_[prop];
			mover.pos += mover.vel * dt;
			if (mover.vel != Vector3()) {
				stand_one(prop);
				stir_near(prop);
			}
			at = after(at, prop);
		}
		// Each crate meets the others where they stand now, the earlier ones moved.
		for (int64_t contact_pass = 0; contact_pass < contact_passes_; contact_pass++) {
			bool held = false;
			at = 0;
			while (at < int32_t(crates_.size())) {
				const int32_t prop = crates_[at];
				const bool blocked = blockers(prop);
				const bool railed = railings(prop, p_damage);
				if (blocked || railed) {
					stand_one(prop);
					stir_near(prop);
					held = true;
				}
				at = after(at, prop);
			}
			if (!held) {
				break;
			}
		}
	}
	write_back();
	props_ = nullptr;
	PackedInt32Array out;
	out.resize(int64_t(crates_.size()));
	std::copy(crates_.begin(), crates_.end(), out.ptrw());
	return out;
}

PackedInt32Array NativeCrates::moving() const {
	PackedInt32Array out;
	out.resize(int64_t(crates_.size()));
	std::copy(crates_.begin(), crates_.end(), out.ptrw());
	return out;
}

PackedInt32Array NativeCrates::woken() const {
	PackedInt32Array out;
	out.resize(int64_t(woken_.size()));
	std::copy(woken_.begin(), woken_.end(), out.ptrw());
	return out;
}

PackedFloat64Array NativeCrates::feet_before() const {
	PackedFloat64Array out;
	out.resize(int64_t(woken_.size()));
	for (size_t index = 0; index < woken_.size(); index++) {
		out.set(int64_t(index), feet_before_[woken_[index]]);
	}
	return out;
}

PackedVector2Array NativeCrates::came_from() const {
	PackedVector2Array out;
	out.resize(int64_t(woken_.size()));
	for (size_t index = 0; index < woken_.size(); index++) {
		out.set(int64_t(index), came_from_[woken_[index]]);
	}
	return out;
}

void NativeCrates::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "surfaces", "at_rest", "radii", "heights", "masses", "solid", "harmless",
								 "rules"),
			&NativeCrates::setup);
	ClassDB::bind_method(D_METHOD("move", "props", "crates", "steps", "dt", "tick", "turn", "feet_before",
								 "came_from", "damage"),
			&NativeCrates::move);
	ClassDB::bind_method(D_METHOD("moving"), &NativeCrates::moving);
	ClassDB::bind_method(D_METHOD("woken"), &NativeCrates::woken);
	ClassDB::bind_method(D_METHOD("feet_before"), &NativeCrates::feet_before);
	ClassDB::bind_method(D_METHOD("came_from"), &NativeCrates::came_from);
}
