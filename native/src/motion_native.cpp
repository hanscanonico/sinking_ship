// Each function here is a ShipMotion or TiltedBox one, line for line, named for it: sums
// and products run in the same order, minf, maxf and clampf are the engine's (a < b ? a :
// b, a > b ? a : b, a < lo ? lo : (a > hi ? hi : a)), the crossings' sort is the
// GDScript's insertion sort, and contraction is off (SConstruct). A box's memo of its
// last height gives what working it out again gives, so none is kept here.

#include "motion_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <cmath>
#include <limits>

using namespace godot;

namespace {
constexpr double INF = std::numeric_limits<double>::infinity();
// ShipMotion's.
constexpr double EPSILON = 1e-12;
// ShipMotion.Lift's places, and how many.
constexpr int VOLUME = 0;
constexpr int X = 1;
constexpr int Y = 2;
constexpr int Z = 3;
constexpr int HIGHEST = 4;
constexpr int AREA = 5;
constexpr int LIFT_SIZE = 11;
// TiltedBox's.
constexpr double NARROW_THREE = 1e-9;
constexpr double NARROW_TWO = 1e-8;
constexpr double TOLERANCE = 1e-12;
constexpr int SOLVE_STEPS = 60;
constexpr double NAN_ = std::numeric_limits<double>::quiet_NaN();

inline double min_f(double p_a, double p_b) {
	return p_a < p_b ? p_a : p_b;
}

inline double max_f(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}

// Attitude.ahead and Attitude.abeam.
inline double ahead(const double *p_rotation, double p_x, double p_y, double p_z) {
	return p_rotation[0] * p_x + p_rotation[1] * p_y + p_rotation[2] * p_z;
}

inline double abeam(const double *p_rotation, double p_x, double p_y, double p_z) {
	return p_rotation[6] * p_x + p_rotation[7] * p_y + p_rotation[8] * p_z;
}

inline double clamp_f(double p_value, double p_low, double p_high) {
	return p_value < p_low ? p_low : (p_value > p_high ? p_high : p_value);
}

template <typename T, typename A>
std::vector<T> copied(const A &p_array) {
	return std::vector<T>(p_array.ptr(), p_array.ptr() + p_array.size());
}

// A TiltedBox turned to one attitude: what TiltedBox.turn keeps of it.
struct Turned {
	const double *low = nullptr;
	const double *size = nullptr;
	double capacity = 0.0;
	double full_area = 0.0;
	double sideways = 1.0;
	bool rising[3] = { true, true, true };
	double bottom = 0.0;
	double top = 0.0;
	int order[3] = { 1, 0, 2 };
	double a = 0.0;
	double b = 0.0;
	double c = 0.0;
	int counted = 1;
	double shift = 0.0;

	// TiltedBox.turn.
	void turn(double p_up_x, double p_up_y, double p_up_z) {
		const double reach_x = p_up_x * size[0];
		const double reach_y = p_up_y * size[1];
		const double reach_z = p_up_z * size[2];
		rising[0] = reach_x >= 0.0;
		rising[1] = reach_y >= 0.0;
		rising[2] = reach_z >= 0.0;
		const double widths[3] = { std::fabs(reach_x), std::fabs(reach_y), std::fabs(reach_z) };
		bottom = p_up_x * low[0] + p_up_y * low[1] + p_up_z * low[2] + min_f(reach_x, 0.0) + min_f(reach_y, 0.0) +
				min_f(reach_z, 0.0);
		top = bottom + widths[0] + widths[1] + widths[2];
		int wa = 0;
		int wb = 1;
		int wc = 2;
		if (widths[wb] > widths[wa]) {
			wa = 1;
			wb = 0;
		}
		if (widths[wc] > widths[wb]) {
			int swap = wb;
			wb = wc;
			wc = swap;
			if (widths[wb] > widths[wa]) {
				swap = wa;
				wa = wb;
				wb = swap;
			}
		}
		order[0] = wa;
		order[1] = wb;
		order[2] = wc;
		a = widths[wa];
		b = widths[wb];
		c = widths[wc];
		if (b * c * c >= NARROW_THREE * a * a * a) {
			counted = 3;
			shift = 0.0;
		} else if (b * b >= NARROW_TWO * a * a) {
			counted = 2;
			shift = c * 0.5;
		} else {
			counted = 1;
			shift = (b + c) * 0.5;
		}
	}

	// TiltedBox._share.
	double share(double p_t) const {
		if (p_t <= 0.0) {
			return 0.0;
		}
		const double t = p_t;
		if (counted == 1) {
			return min_f(t / a, 1.0);
		}
		if (counted == 2) {
			double square = t * t;
			double past = t - a;
			square -= past > 0.0 ? past * past : 0.0;
			past = t - b;
			square -= past > 0.0 ? past * past : 0.0;
			past = t - a - b;
			square += past > 0.0 ? past * past : 0.0;
			return square / (2.0 * a * b);
		}
		double cube = t * t * t;
		double past = t - a;
		cube -= past > 0.0 ? past * past * past : 0.0;
		past = t - b;
		cube -= past > 0.0 ? past * past * past : 0.0;
		past = t - c;
		cube -= past > 0.0 ? past * past * past : 0.0;
		past = t - a - b;
		cube += past > 0.0 ? past * past * past : 0.0;
		past = t - a - c;
		cube += past > 0.0 ? past * past * past : 0.0;
		past = t - b - c;
		cube += past > 0.0 ? past * past * past : 0.0;
		past = t - a - b - c;
		cube -= past > 0.0 ? past * past * past : 0.0;
		return cube / (6.0 * a * b * c);
	}

	// TiltedBox._rise.
	double rise(double p_t) const {
		double flat = p_t > 0.0 ? p_t : 0.0;
		double past = p_t - a;
		flat -= past > 0.0 ? past : 0.0;
		past = p_t - b;
		flat -= past > 0.0 ? past : 0.0;
		past = p_t - a - b;
		flat += past > 0.0 ? past : 0.0;
		return flat / (a * b);
	}

	// TiltedBox._share_rising: the share, and its rate in r_slope.
	double share_rising(double p_t, double &r_slope) const {
		const double t = p_t;
		double square = t > 0.0 ? t * t : 0.0;
		double cube = t * t * t;
		double past = t - a;
		if (past > 0.0) {
			square -= past * past;
			cube -= past * past * past;
		}
		past = t - b;
		if (past > 0.0) {
			square -= past * past;
			cube -= past * past * past;
		}
		past = t - c;
		if (past > 0.0) {
			square -= past * past;
			cube -= past * past * past;
		}
		past = t - a - b;
		if (past > 0.0) {
			square += past * past;
			cube += past * past * past;
		}
		past = t - a - c;
		if (past > 0.0) {
			square += past * past;
			cube += past * past * past;
		}
		past = t - b - c;
		if (past > 0.0) {
			square += past * past;
			cube += past * past * past;
		}
		past = t - a - b - c;
		if (past > 0.0) {
			square -= past * past;
			cube -= past * past * past;
		}
		r_slope = square / (2.0 * a * b * c);
		return t > 0.0 ? cube / (6.0 * a * b * c) : 0.0;
	}

	// TiltedBox._height.
	double height(double p_water) const {
		if (p_water <= 0.0) {
			return bottom;
		}
		if (p_water >= capacity) {
			return top + (p_water - capacity) / full_area;
		}
		const double share_of = p_water / capacity;
		if (counted == 1) {
			return bottom + shift + share_of * a;
		}
		if (counted == 2) {
			double t = 0.0;
			if (share_of * 2.0 * a <= b) {
				t = std::sqrt(2.0 * a * b * share_of);
			} else if (share_of <= 1.0 - b / (2.0 * a)) {
				t = share_of * a + b * 0.5;
			} else {
				t = a + b - std::sqrt(2.0 * a * b * (1.0 - share_of));
			}
			return bottom + shift + t;
		}
		const double spread_bc = b + c;
		if (a >= spread_bc && share_of * 2.0 * a >= spread_bc && (1.0 - share_of) * 2.0 * a >= spread_bc) {
			return bottom + share_of * a + spread_bc * 0.5;
		}
		double low_at = 0.0;
		double high_at = top - bottom;
		const double close = TOLERANCE * high_at;
		double at = share_of * high_at;
		for (int step = 0; step < SOLVE_STEPS; step++) {
			double slope = 0.0;
			const double off = share_rising(at, slope) - share_of;
			if (off < 0.0) {
				low_at = at;
			} else {
				high_at = at;
			}
			double next = slope > 0.0 ? at - off / slope : NAN_;
			next = next > low_at && next < high_at ? next : (low_at + high_at) * 0.5;
			const double moved = next - at;
			at = next;
			if ((moved < close && moved > -close) || high_at - low_at < close) {
				break;
			}
		}
		return bottom + at;
	}

	// TiltedBox._spread.
	void spread(double *r_along, double p_t) const {
		double area = 0.0;
		double moment_a = 0.0;
		double moment_b = 0.0;
		for (int corner = 0; corner < 4; corner++) {
			const int on_a = corner & 1;
			const int on_b = corner >> 1;
			const double past = p_t - double(on_a) * a - double(on_b) * b;
			if (past <= 0.0) {
				continue;
			}
			const double sign = (on_a + on_b) % 2 == 0 ? 1.0 : -1.0;
			const double square = past * past * 0.5;
			const double tip = square * past / 3.0;
			area += sign * square;
			moment_a += sign * (double(on_a) * a * square + tip);
			moment_b += sign * (double(on_b) * b * square + tip);
		}
		r_along[order[0]] = moment_a / (area * a);
		r_along[order[1]] = moment_b / (area * b);
	}

	// TiltedBox._spreads.
	void spreads(double *r_along, double p_t) const {
		double volume = 0.0;
		double moment_a = 0.0;
		double moment_b = 0.0;
		double moment_c = 0.0;
		for (int corner = 0; corner < 8; corner++) {
			const int on_a = corner & 1;
			const int on_b = (corner >> 1) & 1;
			const int on_c = corner >> 2;
			const double past = p_t - double(on_a) * a - double(on_b) * b - double(on_c) * c;
			if (past <= 0.0) {
				continue;
			}
			const double sign = (on_a + on_b + on_c) % 2 == 0 ? 1.0 : -1.0;
			const double cube = past * past * past / 6.0;
			const double tip = cube * past * 0.25;
			volume += sign * cube;
			moment_a += sign * (double(on_a) * a * cube + tip);
			moment_b += sign * (double(on_b) * b * cube + tip);
			moment_c += sign * (double(on_c) * c * cube + tip);
		}
		r_along[order[0]] = moment_a / (volume * a);
		r_along[order[1]] = moment_b / (volume * b);
		r_along[order[2]] = moment_c / (volume * c);
	}

	// TiltedBox.centre, into r_found.
	void centre(double p_height, double *r_found) const {
		double along[3] = { 0.5, 0.5, 0.5 };
		const double t = p_height - bottom - shift;
		if (p_height > bottom && p_height < top && t > 0.0) {
			if (counted == 3) {
				spreads(along, t);
			} else {
				const double share_t = share(t);
				double rate = 0.0;
				if (counted == 1) {
					along[order[0]] = min_f(t, a) / (2.0 * a);
					rate = t < a ? 1.0 / a : 0.0;
				} else {
					spread(along, t);
					rate = rise(t);
				}
				for (int narrow = counted; narrow < 3; narrow++) {
					const double width = narrow == 1 ? b : c;
					along[order[narrow]] = clamp_f(0.5 - width * rate / (12.0 * share_t), 0.0, 1.0);
				}
			}
		}
		for (int axis = 0; axis < 3; axis++) {
			double share_of = rising[axis] ? along[axis] : 1.0 - along[axis];
			if (axis == 2 && sideways != 1.0) {
				share_of = 0.5 + (share_of - 0.5) * sideways;
			}
			r_found[axis] = low[axis] + size[axis] * share_of;
		}
	}
};
} // namespace

void NativeMotion::setup(const PackedFloat64Array &p_x, const PackedFloat64Array &p_length,
		const PackedInt32Array &p_first, const PackedInt32Array &p_count, const PackedFloat64Array &p_points,
		const PackedFloat64Array &p_whole, const PackedInt32Array &p_corner_first,
		const PackedInt32Array &p_corner_count, const PackedFloat64Array &p_corners,
		const PackedFloat64Array &p_centre) {
	x_ = copied<double>(p_x);
	length_ = copied<double>(p_length);
	first_ = copied<int32_t>(p_first);
	count_ = copied<int32_t>(p_count);
	points_ = copied<double>(p_points);
	whole_ = copied<double>(p_whole);
	corner_first_ = copied<int32_t>(p_corner_first);
	corner_count_ = copied<int32_t>(p_corner_count);
	corners_ = copied<double>(p_corners);
	for (int axis = 0; axis < 3; axis++) {
		centre_[axis] = p_centre[axis];
	}
}

// ShipMotion.lift_under's working out, past its memo: what it gives (ShipMotion.Lift's
// places) and then each section's share of the volume.
PackedFloat64Array NativeMotion::lift_under(const PackedFloat64Array &p_rotation, double p_sea) {
	const int64_t sections = int64_t(x_.size());
	PackedFloat64Array found;
	found.resize(LIFT_SIZE + sections);
	double *made = found.ptrw();
	for (int64_t index = 0; index < LIFT_SIZE + sections; index++) {
		made[index] = 0.0;
	}
	double *by_section = made + LIFT_SIZE;
	const double *rotation = p_rotation.ptr();
	const double ux = rotation[3];
	const double uy = rotation[4];
	const double uz = rotation[5];
	const double across = uy * uy + uz * uz;
	double volume = 0.0;
	double mx = 0.0;
	double my = 0.0;
	double mz = 0.0;
	double highest = -INF;
	double plane[6] = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
	for (int64_t section = 0; section < sections; section++) {
		const double x = x_[section];
		const double level = p_sea - ux * x;
		double low = INF;
		double high = -INF;
		const int32_t corner = corner_first_[section];
		for (int32_t index = 0; index < corner_count_[section]; index++) {
			const double off = uz * corners_[corner + index * 2] + uy * corners_[corner + index * 2 + 1];
			low = min_f(low, off);
			high = max_f(high, off);
		}
		highest = max_f(highest, high - level);
		by_section[section] = 0.0;
		if (low > level) {
			continue;
		}
		if (high <= level) {
			const double whole = whole_[section * 3];
			const double piece = whole * 0.5 * length_[section];
			by_section[section] = piece;
			volume += piece;
			mx += piece * x;
			mz += piece * whole_[section * 3 + 1] / (3.0 * whole);
			my += piece * whole_[section * 3 + 2] / (3.0 * whole);
			continue;
		}
		const int32_t from = first_[section];
		const int32_t count = count_[section];
		double twice = 0.0;
		double sum_z = 0.0;
		double sum_y = 0.0;
		double first_z = 0.0;
		double first_y = 0.0;
		double last_z = 0.0;
		double last_y = 0.0;
		bool started = false;
		crossings_.clear();
		double z0 = points_[from + (count - 1) * 2];
		double y0 = points_[from + (count - 1) * 2 + 1];
		double f0 = uz * z0 + uy * y0 - level;
		for (int32_t index = 0; index < count; index++) {
			const double z1 = points_[from + index * 2];
			const double y1 = points_[from + index * 2 + 1];
			const double f1 = uz * z1 + uy * y1 - level;
			if ((f0 <= 0.0) != (f1 <= 0.0)) {
				const double t = f0 / (f0 - f1);
				const double cz = z0 + (z1 - z0) * t;
				const double cy = y0 + (y1 - y0) * t;
				crossings_.push_back(uy * cz - uz * cy);
				crossings_.push_back(cz);
				crossings_.push_back(cy);
				if (started) {
					const double cross = last_z * cy - cz * last_y;
					twice += cross;
					sum_z += (last_z + cz) * cross;
					sum_y += (last_y + cy) * cross;
				} else {
					first_z = cz;
					first_y = cy;
					started = true;
				}
				last_z = cz;
				last_y = cy;
			}
			if (f1 <= 0.0) {
				if (started) {
					const double cross = last_z * y1 - z1 * last_y;
					twice += cross;
					sum_z += (last_z + z1) * cross;
					sum_y += (last_y + y1) * cross;
				} else {
					first_z = z1;
					first_y = y1;
					started = true;
				}
				last_z = z1;
				last_y = y1;
			}
			z0 = z1;
			y0 = y1;
			f0 = f1;
		}
		if (!started) {
			continue;
		}
		const double closing = last_z * first_y - first_z * last_y;
		twice += closing;
		sum_z += (last_z + first_z) * closing;
		sum_y += (last_y + first_y) * closing;
		if (twice > EPSILON) {
			const double part = twice * 0.5 * length_[section];
			by_section[section] = part;
			volume += part;
			mx += part * x;
			mz += part * sum_z / (3.0 * twice);
			my += part * sum_y / (3.0 * twice);
		}
		if (crossings_.size() >= 6 && across > EPSILON) {
			strips(rotation, section, across, plane);
		}
	}
	made[HIGHEST] = highest;
	for (int index = 0; index < 6; index++) {
		made[AREA + index] = plane[index];
	}
	if (volume > EPSILON) {
		made[VOLUME] = volume;
		made[X] = mx / volume;
		made[Y] = my / volume;
		made[Z] = mz / volume;
	}
	return found;
}

// ShipMotion._strips.
void NativeMotion::strips(const double *p_rotation, int64_t p_section, double p_across, double *r_plane) {
	const int64_t pairs = int64_t(crossings_.size()) / 3;
	if (pairs > 2) {
		sort_crossings();
	}
	const double x = x_[p_section] - centre_[0];
	const double length = length_[p_section];
	const double sweep = -p_rotation[3] * length / p_across;
	const double sweep_y = sweep * p_rotation[4];
	const double sweep_z = sweep * p_rotation[5];
	const double s_ahead = ahead(p_rotation, length, sweep_y, sweep_z);
	const double s_abeam = abeam(p_rotation, length, sweep_y, sweep_z);
	const double *crossings = crossings_.data();
	for (int64_t pair = 0; pair < pairs / 2; pair++) {
		const double y1 = crossings[pair * 6 + 2] - centre_[1];
		const double z1 = crossings[pair * 6 + 1] - centre_[2];
		const double y2 = crossings[pair * 6 + 5] - centre_[1];
		const double z2 = crossings[pair * 6 + 4] - centre_[2];
		const double c_ahead = ahead(p_rotation, 0.0, y2 - y1, z2 - z1);
		const double c_abeam = abeam(p_rotation, 0.0, y2 - y1, z2 - z1);
		const double area = std::fabs(c_ahead * s_abeam - c_abeam * s_ahead);
		const double m_ahead = ahead(p_rotation, x, (y1 + y2) * 0.5, (z1 + z2) * 0.5);
		const double m_abeam = abeam(p_rotation, x, (y1 + y2) * 0.5, (z1 + z2) * 0.5);
		r_plane[0] += area;
		r_plane[1] += area * m_ahead;
		r_plane[2] += area * m_abeam;
		r_plane[3] += area * (m_ahead * m_ahead + (c_ahead * c_ahead + s_ahead * s_ahead) / 12.0);
		r_plane[4] += area * (m_ahead * m_abeam + (c_ahead * c_abeam + s_ahead * s_abeam) / 12.0);
		r_plane[5] += area * (m_abeam * m_abeam + (c_abeam * c_abeam + s_abeam * s_abeam) / 12.0);
	}
}

// ShipMotion._sort_crossings.
void NativeMotion::sort_crossings() {
	const int64_t count = int64_t(crossings_.size()) / 3;
	double *crossings = crossings_.data();
	for (int64_t index = 1; index < count; index++) {
		int64_t at = index;
		while (at > 0 && crossings[(at - 1) * 3] > crossings[at * 3]) {
			for (int field = 0; field < 3; field++) {
				const double swap = crossings[at * 3 + field];
				crossings[at * 3 + field] = crossings[(at - 1) * 3 + field];
				crossings[(at - 1) * 3 + field] = swap;
			}
			at -= 1;
		}
	}
}

// ShipMotion.highest.
double NativeMotion::highest(const PackedFloat64Array &p_rotation, double p_sea) const {
	const double ux = p_rotation[3];
	const double uy = p_rotation[4];
	const double uz = p_rotation[5];
	double most = -INF;
	for (int64_t section = 0; section < int64_t(x_.size()); section++) {
		const double along = ux * x_[section] - p_sea;
		const int32_t from = corner_first_[section];
		for (int32_t index = 0; index < corner_count_[section]; index++) {
			const double height = along + uz * corners_[from + index * 2] + uy * corners_[from + index * 2 + 1];
			if (height > most) {
				most = height;
			}
		}
	}
	return most;
}

void NativeMotion::boxes(const PackedFloat64Array &p_frames, const PackedFloat64Array &p_capacity,
		const PackedFloat64Array &p_full_area, const PackedFloat64Array &p_sideways) {
	frames_ = copied<double>(p_frames);
	capacity_ = copied<double>(p_capacity);
	full_area_ = copied<double>(p_full_area);
	sideways_ = copied<double>(p_sideways);
}

// ShipMotion._loaded: each wet cell's box turned to p_rotation, but a full one, which
// the GDScript leaves as it stood: its height stands at or over its top (or is not a
// number), where its centre is its middle whichever way it is turned. Gives her water's
// volume, then its moments about her origin, x, y, z.
PackedFloat64Array NativeMotion::loaded(const PackedFloat64Array &p_rotation, const PackedFloat64Array &p_water) const {
	const double *rotation = p_rotation.ptr();
	const double *water = p_water.ptr();
	double sums[4] = { 0.0, 0.0, 0.0, 0.0 };
	Turned box;
	for (int64_t cell = 0; cell < p_water.size(); cell++) {
		const double volume = water[cell];
		if (volume <= 0.0) {
			continue;
		}
		box.low = &frames_[cell * 6];
		box.size = &frames_[cell * 6 + 3];
		box.capacity = capacity_[cell];
		box.full_area = full_area_[cell];
		box.sideways = sideways_[cell];
		double middle[3];
		if (volume < box.capacity) {
			box.turn(rotation[3], rotation[4], rotation[5]);
			box.centre(box.height(volume), middle);
		} else {
			box.centre(NAN_, middle);
		}
		sums[0] += volume;
		for (int axis = 0; axis < 3; axis++) {
			sums[axis + 1] += volume * middle[axis];
		}
	}
	PackedFloat64Array found;
	found.resize(4);
	for (int index = 0; index < 4; index++) {
		found[index] = sums[index];
	}
	return found;
}

void NativeMotion::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "x", "length", "first", "count", "points", "whole", "corner_first",
								 "corner_count", "corners", "centre"),
			&NativeMotion::setup);
	ClassDB::bind_method(D_METHOD("lift_under", "rotation", "sea"), &NativeMotion::lift_under);
	ClassDB::bind_method(D_METHOD("highest", "rotation", "sea"), &NativeMotion::highest);
	ClassDB::bind_method(D_METHOD("boxes", "frames", "capacity", "full_area", "sideways"), &NativeMotion::boxes);
	ClassDB::bind_method(D_METHOD("loaded", "rotation", "water"), &NativeMotion::loaded);
}
