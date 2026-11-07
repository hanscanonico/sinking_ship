// Each function here is a LevelHull or HullGirder one, line for line, named for it: sums
// and products run in the same order, absf is the engine's, and contraction is off
// (SConstruct). A Dictionary of floats keeps the first of equal keys (0.0 and -0.0 are
// one), then the keys are sorted: here equal heights are dropped after their first.

#include "hull_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>
#include <utility>

using namespace godot;

namespace {

// The distinct values of p_values, the first of each kept, ascending.
std::vector<double> distinct_sorted(const std::vector<double> &p_values) {
	std::vector<std::pair<double, size_t>> ordered;
	ordered.reserve(p_values.size());
	for (size_t index = 0; index < p_values.size(); index++) {
		ordered.emplace_back(p_values[index], index);
	}
	std::sort(ordered.begin(), ordered.end(), [](const std::pair<double, size_t> &p_a, const std::pair<double, size_t> &p_b) {
		if (p_a.first < p_b.first) {
			return true;
		}
		if (p_b.first < p_a.first) {
			return false;
		}
		return p_a.second < p_b.second;
	});
	std::vector<double> found;
	for (size_t index = 0; index < ordered.size(); index++) {
		if (index > 0 && ordered[index].first == ordered[index - 1].first) {
			continue;
		}
		found.push_back(ordered[index].first);
	}
	return found;
}

// LevelHull._breadth.
double breadth(const Vector2 *p_outline, int64_t p_size, double p_height, std::vector<double> &r_crossings) {
	r_crossings.clear();
	for (int64_t index = 0; index < p_size; index++) {
		const Vector2 &a = p_outline[index];
		const Vector2 &b = p_outline[(index + 1) % p_size];
		const double ax = double(a.x);
		const double ay = double(a.y);
		const double bx = double(b.x);
		const double by = double(b.y);
		if ((ay - p_height) * (by - p_height) < 0.0) {
			r_crossings.push_back(ax + (bx - ax) * (p_height - ay) / (by - ay));
		}
	}
	std::sort(r_crossings.begin(), r_crossings.end());
	double found = 0.0;
	const size_t pairs = r_crossings.size() / 2;
	for (size_t pair = 0; pair < pairs; pair++) {
		found += r_crossings[pair * 2 + 1] - r_crossings[pair * 2];
	}
	return found;
}

// LevelHull._breadth_lines: per stretch its foot, breadth there and growth, then a last
// height.
void breadth_lines(const Vector2 *p_outline, int64_t p_size, std::vector<double> &r_line,
		std::vector<double> &r_crossings) {
	std::vector<double> ys;
	ys.reserve(p_size);
	for (int64_t index = 0; index < p_size; index++) {
		ys.push_back(double(p_outline[index].y));
	}
	const std::vector<double> heights = distinct_sorted(ys);
	r_line.clear();
	for (size_t index = 0; index + 1 < heights.size(); index++) {
		const double foot = heights[index];
		const double rise = heights[index + 1] - foot;
		const double low = breadth(p_outline, p_size, foot + rise * 0.25, r_crossings);
		const double high = breadth(p_outline, p_size, foot + rise * 0.75, r_crossings);
		const double growth = (high - low) / (rise * 0.5);
		r_line.push_back(foot);
		r_line.push_back(low - growth * rise * 0.25);
		r_line.push_back(growth);
	}
	r_line.push_back(heights.back());
	r_line.push_back(0.0);
	r_line.push_back(0.0);
}

} // namespace

// LevelHull._init: the sections' points one after another, section s's from p_first[s] to
// p_first[s + 1], and each one's length. Gives the count of heights, then the heights,
// the stretches' areas and growths, and the volumes under the heights.
PackedFloat64Array NativeLevelHull::build(const PackedVector2Array &p_points, const PackedInt32Array &p_first,
		const PackedFloat64Array &p_length) const {
	const int64_t sections = p_length.size();
	const Vector2 *points = p_points.ptr();
	const int32_t *first = p_first.ptr();
	const double *length = p_length.ptr();
	std::vector<std::vector<double>> lines(sections);
	std::vector<double> crossings;
	std::vector<double> corners;
	for (int64_t section = 0; section < sections; section++) {
		breadth_lines(points + first[section], first[section + 1] - first[section], lines[section], crossings);
		for (size_t index = 0; index < lines[section].size(); index += 3) {
			corners.push_back(lines[section][index]);
		}
	}
	const std::vector<double> heights = distinct_sorted(corners);
	const int64_t count = int64_t(heights.size());
	PackedFloat64Array found;
	found.resize(1 + count * 4 - 2);
	double *made = found.ptrw();
	made[0] = double(count);
	double *out_heights = made + 1;
	double *areas = out_heights + count;
	double *growths = areas + (count - 1);
	double *volumes = growths + (count - 1);
	for (int64_t index = 0; index < count; index++) {
		out_heights[index] = heights[index];
	}
	std::vector<size_t> at(sections, 0);
	volumes[0] = 0.0;
	for (int64_t index = 0; index < count - 1; index++) {
		const double foot = heights[index];
		double area = 0.0;
		double growth = 0.0;
		for (int64_t section = 0; section < sections; section++) {
			const std::vector<double> &line = lines[section];
			// Each section's stretches run up the global heights in step with them.
			while (at[section] + 3 < line.size() && line[at[section] + 3] <= foot) {
				at[section] += 3;
			}
			const size_t from = at[section];
			if (from + 3 >= line.size() || line[from] > foot) {
				continue;
			}
			area += (line[from + 1] + line[from + 2] * (foot - line[from])) * length[section];
			growth += line[from + 2] * length[section];
		}
		areas[index] = area;
		growths[index] = growth;
		const double rise = heights[index + 1] - foot;
		volumes[index + 1] = volumes[index] + area * rise + growth * rise * rise * 0.5;
	}
	return found;
}

void NativeLevelHull::_bind_methods() {
	ClassDB::bind_method(D_METHOD("build", "points", "first", "length"), &NativeLevelHull::build);
}

void NativeGirder::setup(const PackedFloat64Array &p_own, const PackedInt32Array &p_first,
		const PackedInt32Array &p_counts, const PackedInt32Array &p_starts, const PackedFloat64Array &p_shares,
		const PackedFloat64Array &p_bounds, double p_hog, double p_sag) {
	own_.assign(p_own.ptr(), p_own.ptr() + p_own.size());
	first_.assign(p_first.ptr(), p_first.ptr() + p_first.size());
	counts_.assign(p_counts.ptr(), p_counts.ptr() + p_counts.size());
	starts_.assign(p_starts.ptr(), p_starts.ptr() + p_starts.size());
	shares_.assign(p_shares.ptr(), p_shares.ptr() + p_shares.size());
	bounds_.assign(p_bounds.ptr(), p_bounds.ptr() + p_bounds.size());
	hog_ = p_hog;
	sag_ = p_sag;
}

// HullGirder.measure past her lift, each section's in p_lift, and HullGirder.moments:
// gives her worst share, where it is, then the moment at each station's ends.
PackedFloat64Array NativeGirder::measure(const PackedFloat64Array &p_lift, const PackedFloat64Array &p_water,
		double p_across) const {
	const int64_t count = int64_t(own_.size());
	std::vector<double> loads(own_);
	const double *water = p_water.ptr();
	for (int64_t cell = 0; cell < p_water.size(); cell++) {
		const double held = water[cell];
		if (held <= 0.0) {
			continue;
		}
		const int32_t from = starts_[cell];
		for (int32_t at = 0; at < counts_[cell]; at++) {
			loads[first_[cell] + at] += held * shares_[from + at];
		}
	}
	const double *lift = p_lift.ptr();
	for (int64_t station = 0; station < count; station++) {
		loads[station] = (loads[station] - lift[station]) * p_across;
	}
	PackedFloat64Array found;
	found.resize(2 + count + 1);
	double *made = found.ptrw();
	double *moment = made + 2;
	std::vector<double> shear(count + 1, 0.0);
	moment[0] = 0.0;
	for (int64_t station = 0; station < count; station++) {
		const double length = bounds_[station + 1] - bounds_[station];
		const double before = shear[station];
		shear[station + 1] = before + loads[station];
		moment[station + 1] = moment[station] + before * length + loads[station] * length * 0.5;
	}
	const double start = bounds_[0];
	const double span = bounds_[count] - start;
	const double left_shear = shear[count];
	const double left_moment = moment[count] - left_shear * span * 0.5;
	for (int64_t at = 0; at < count + 1; at++) {
		const double along = bounds_[at] - start;
		moment[at] -= left_shear * along * along / (2.0 * span) + left_moment * along / span;
	}
	double worst = 0.0;
	double where = 0.0;
	for (int64_t at = 0; at < count + 1; at++) {
		const double share = moment[at] >= 0.0 ? moment[at] / hog_ : moment[at] / sag_;
		if (std::fabs(share) > std::fabs(worst)) {
			worst = share;
			where = bounds_[at];
		}
	}
	made[0] = worst;
	made[1] = where;
	return found;
}

void NativeGirder::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "own", "first", "counts", "starts", "shares", "bounds", "hog", "sag"),
			&NativeGirder::setup);
	ClassDB::bind_method(D_METHOD("measure", "lift", "water", "across"), &NativeGirder::measure);
}
