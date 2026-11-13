// Each function here is a GDScript one, line for line, named for it: sums and products
// run in the same order, minf, maxf and clampf are the engine's (a < b ? a : b,
// a > b ? a : b, a < lo ? lo : (a > hi ? hi : a)), a sort is the engine's insertion
// sort, and contraction is off (SConstruct). The GDScript keeps three memos — a box's
// last height, a solve's flows, a pocket's push — that give what working it out again
// gives, to the last bit; only the push's is kept here.

#include "sink_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>
#include <limits>

using namespace godot;

namespace {
constexpr int32_t OUTSIDE = -1;
constexpr double INF = std::numeric_limits<double>::infinity();
constexpr double NAN_ = std::numeric_limits<double>::quiet_NaN();
// SinkStepper's.
constexpr double LEVEL_HEAD = 1e-2;
constexpr double SURPLUS_TOLERANCE = 1e-2;
constexpr int NEWTON_TRIES = 25;
constexpr int HALVINGS = 12;
constexpr double NUDGE = 1e-7;
constexpr double HEAD_TOLERANCE = 1e-9;
constexpr int TRIES = 60;
constexpr double REACH = 1e-3;
// TiltedBox's.
constexpr double NARROW_THREE = 1e-9;
constexpr double NARROW_TWO = 1e-8;
constexpr double TOLERANCE = 1e-12;
constexpr int SOLVE_STEPS = 60;
// SinkAir's.
constexpr double SQRT_HALF = 0.7071067811865476;
// ShippedWater's.
constexpr double LEVEL_STRETCH = 1e-6;

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

template <typename T, typename P>
void take(std::vector<T> &r_to, const P &p_from) {
	r_to.assign(p_from.ptr(), p_from.ptr() + p_from.size());
}

// PackedFloat64Array.sort: the engine's SortArray, which for so few is its insertion
// sort (linear_insert), by a < b.
void sort_few(double *p_values, int64_t p_count) {
	for (int64_t last = 1; last < p_count; last++) {
		const double value = p_values[last];
		if (value < p_values[0]) {
			for (int64_t at = last; at > 0; at--) {
				p_values[at] = p_values[at - 1];
			}
			p_values[0] = value;
			continue;
		}
		int64_t at = last;
		int64_t next = last - 1;
		while (value < p_values[next]) {
			p_values[at] = p_values[next];
			at = next;
			next--;
		}
		p_values[at] = value;
	}
}
} // namespace

void NativeSink::setup(const PackedInt32Array &p_first, const PackedInt32Array &p_second,
		const PackedByteArray &p_in_floor, const PackedFloat64Array &p_middle, const PackedFloat64Array &p_half,
		const PackedFloat64Array &p_flow_area, const PackedFloat64Array &p_frames,
		const PackedFloat64Array &p_capacity, const PackedFloat64Array &p_full_area,
		const PackedFloat64Array &p_constants) {
	take(first_, p_first);
	take(second_, p_second);
	take(in_floor_, p_in_floor);
	take(middle_, p_middle);
	take(half_, p_half);
	take(flow_area_, p_flow_area);
	take(frames_, p_frames);
	take(capacity_, p_capacity);
	take(full_area_, p_full_area);
	g_ = p_constants[0];
	discharge_ = p_constants[1];
	atmosphere_ = p_constants[2];
	least_ = p_constants[3];
	const size_t cell_count = capacity_.size();
	const size_t opening_count = first_.size();
	for (std::vector<double> *per_cell : { &bottom_, &top_, &shift_, &a_, &b_, &c_, &area_, &pocket_air_,
				 &pushed_, &pushed_at_ }) {
		per_cell->assign(cell_count, 0.0);
	}
	counted_.assign(cell_count, 1);
	pocket_.assign(cell_count, -1);
	members_from_.assign(cell_count, 0);
	members_count_.assign(cell_count, 0);
	holding_.assign(cell_count, 0);
	alone_.assign(cell_count, 1);
	well_of_.assign(cell_count, -1);
	edges_from_.assign(1, 0);
	touch_from_.assign(cell_count + 1, 0);
	for (std::vector<double> *per_opening : { &opening_bottom_, &opening_top_, &opening_size_, &shares_ }) {
		per_opening->assign(opening_count, 0.0);
	}
}

void NativeSink::wells(const PackedInt32Array &p_well_of, const PackedInt32Array &p_edges_from,
		const PackedFloat64Array &p_ends, const PackedFloat64Array &p_lengths, double p_rate) {
	take(well_of_, p_well_of);
	take(edges_from_, p_edges_from);
	take(ends_, p_ends);
	take(lengths_, p_lengths);
	edge_heights_.assign(lengths_.size() * 2, 0.0);
	ship_rate_ = p_rate;
}

void NativeSink::touched(const PackedInt32Array &p_from, const PackedInt32Array &p_touching) {
	take(touch_from_, p_from);
	take(touching_, p_touching);
}

void NativeSink::faces(const PackedInt32Array &p_axis, const PackedFloat64Array &p_facing) {
	take(axis_, p_axis);
	take(facing_, p_facing);
	upward_.resize(int64_t(axis_.size()));
}

// TiltedBox.turn of every cell, then SinkStepper._turn's floors, ceilings, average
// surfaces and openings, with SinkAir.turned's: what the stepper reads of them, per
// cell its floor, ceiling and average surface, per opening its bottom, top, width or
// area and highest corner, each in turn.
PackedFloat64Array NativeSink::turned(const PackedFloat64Array &p_up) {
	const double up_x = p_up[0];
	const double up_y = p_up[1];
	const double up_z = p_up[2];
	const int64_t cell_count = cells();
	const int64_t opening_count = int64_t(first_.size());
	PackedFloat64Array found;
	found.resize(cell_count * 3 + opening_count * 4);
	double *out = found.ptrw();
	for (int64_t cell = 0; cell < cell_count; cell++) {
		const double *frame = &frames_[cell * 6];
		const double reach_x = up_x * frame[3];
		const double reach_y = up_y * frame[4];
		const double reach_z = up_z * frame[5];
		const double widths[3] = { abs_f(reach_x), abs_f(reach_y), abs_f(reach_z) };
		const double bottom = up_x * frame[0] + up_y * frame[1] + up_z * frame[2] + min_f(reach_x, 0.0) +
				min_f(reach_y, 0.0) + min_f(reach_z, 0.0);
		bottom_[cell] = bottom;
		top_[cell] = bottom + widths[0] + widths[1] + widths[2];
		int a = 0;
		int b = 1;
		int c = 2;
		if (widths[b] > widths[a]) {
			a = 1;
			b = 0;
		}
		if (widths[c] > widths[b]) {
			int swap = b;
			b = c;
			c = swap;
			if (widths[b] > widths[a]) {
				swap = a;
				a = b;
				b = swap;
			}
		}
		const double wa = widths[a];
		const double wb = widths[b];
		const double wc = widths[c];
		a_[cell] = wa;
		b_[cell] = wb;
		c_[cell] = wc;
		if (wb * wc * wc >= NARROW_THREE * wa * wa * wa) {
			counted_[cell] = 3;
			shift_[cell] = 0.0;
		} else if (wb * wb >= NARROW_TWO * wa * wa) {
			counted_[cell] = 2;
			shift_[cell] = wc * 0.5;
		} else {
			counted_[cell] = 1;
			shift_[cell] = (wb + wc) * 0.5;
		}
		area_[cell] = capacity_[cell] / (top_[cell] - bottom_[cell]);
		out[cell] = bottom_[cell];
		out[cell_count + cell] = top_[cell];
		out[cell_count * 2 + cell] = area_[cell];
	}
	double *opening_out = out + cell_count * 3;
	for (size_t index = 0; index < first_.size(); index++) {
		const size_t at = index * 3;
		const double middle = up_x * middle_[at] + up_y * middle_[at + 1] + up_z * middle_[at + 2];
		const double reach = abs_f(up_x) * half_[at] + abs_f(up_y) * half_[at + 1] + abs_f(up_z) * half_[at + 2];
		if (in_floor_[index] == 1) {
			opening_bottom_[index] = middle;
			opening_top_[index] = middle;
			opening_size_[index] = flow_area_[index];
		} else {
			opening_bottom_[index] = middle - reach;
			opening_top_[index] = middle + reach;
			opening_size_[index] = flow_area_[index] / (reach * 2.0);
		}
		opening_out[index] = opening_bottom_[index];
		opening_out[opening_count + index] = opening_top_[index];
		opening_out[opening_count * 2 + index] = opening_size_[index];
		opening_out[opening_count * 3 + index] = middle + reach;
		if (index < axis_.size()) {
			const double rise = axis_[index] >= 0 ? p_up[axis_[index]] * facing_[index] : 0.0;
			upward_.set(int64_t(index), rise > SQRT_HALF ? -1 : (rise < -SQRT_HALF ? 1 : 0));
		}
	}
	return found;
}

PackedInt32Array NativeSink::upward() const {
	return upward_;
}

// TiltedBox.height of every cell holding p_water.
PackedFloat64Array NativeSink::heights(const PackedFloat64Array &p_water) const {
	PackedFloat64Array found;
	found.resize(cells());
	double *out = found.ptrw();
	const double *water = p_water.ptr();
	for (int64_t cell = 0; cell < cells(); cell++) {
		out[cell] = height(cell, water[cell]);
	}
	return found;
}

// SinkAir.begin's pockets, and ShippedWater.begin's edges with each well's lowest end:
// p_surface is the crest, the trough and the world's up in the ship's axes.
void NativeSink::began(const PackedInt32Array &p_pocket, const PackedFloat64Array &p_air,
		const PackedInt32Array &p_members_from, const PackedInt32Array &p_members_count,
		const PackedInt32Array &p_members, const PackedByteArray &p_holding, const PackedByteArray &p_alone,
		const PackedFloat64Array &p_surface) {
	take(pocket_, p_pocket);
	take(pocket_air_, p_air);
	take(members_from_, p_members_from);
	take(members_count_, p_members_count);
	take(members_, p_members);
	take(holding_, p_holding);
	take(alone_, p_alone);
	pushed_at_.assign(cells(), NAN_);
	crest_ = p_surface[0];
	trough_ = p_surface[1];
	const double up[3] = { p_surface[2], p_surface[3], p_surface[4] };
	for (size_t end = 0; end < edge_heights_.size(); end++) {
		const size_t at = end * 3;
		edge_heights_[end] = up[0] * ends_[at] + up[1] * ends_[at + 1] + up[2] * ends_[at + 2];
	}
	lowest_.assign(edges_from_.size() - 1, INF);
	for (size_t well = 0; well + 1 < edges_from_.size(); well++) {
		double lowest = INF;
		for (int32_t end = edges_from_[well] * 2; end < edges_from_[well + 1] * 2; end++) {
			lowest = min_f(lowest, edge_heights_[end]);
		}
		lowest_[well] = lowest;
	}
}

// TiltedBox.volume.
double NativeSink::volume(int64_t p_cell, double p_height) const {
	if (p_height <= bottom_[p_cell]) {
		return 0.0;
	}
	if (p_height >= top_[p_cell]) {
		return capacity_[p_cell] + full_area_[p_cell] * (p_height - top_[p_cell]);
	}
	return capacity_[p_cell] * share_of(p_cell, p_height - bottom_[p_cell] - shift_[p_cell]);
}

// TiltedBox._share.
double NativeSink::share_of(int64_t p_cell, double p_t) const {
	if (p_t <= 0.0) {
		return 0.0;
	}
	const double a = a_[p_cell];
	if (counted_[p_cell] == 1) {
		return min_f(p_t / a, 1.0);
	}
	const double b = b_[p_cell];
	const double t = p_t;
	if (counted_[p_cell] == 2) {
		double square = t * t;
		double past = t - a;
		square -= past > 0.0 ? past * past : 0.0;
		past = t - b;
		square -= past > 0.0 ? past * past : 0.0;
		past = t - a - b;
		square += past > 0.0 ? past * past : 0.0;
		return square / (2.0 * a * b);
	}
	const double c = c_[p_cell];
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

// TiltedBox._share_rising: the share, and its rate in r_slope.
double NativeSink::share_rising(int64_t p_cell, double p_t, double &r_slope) const {
	const double a = a_[p_cell];
	const double b = b_[p_cell];
	const double c = c_[p_cell];
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

// TiltedBox._height (height, whose memo gives the same).
double NativeSink::height(int64_t p_cell, double p_water) const {
	const double bottom = bottom_[p_cell];
	const double capacity = capacity_[p_cell];
	if (p_water <= 0.0) {
		return bottom;
	}
	if (p_water >= capacity) {
		return top_[p_cell] + (p_water - capacity) / full_area_[p_cell];
	}
	const double share = p_water / capacity;
	const double a = a_[p_cell];
	const double shift = shift_[p_cell];
	if (counted_[p_cell] == 1) {
		return bottom + shift + share * a;
	}
	const double b = b_[p_cell];
	if (counted_[p_cell] == 2) {
		double t = 0.0;
		if (share * 2.0 * a <= b) {
			t = std::sqrt(2.0 * a * b * share);
		} else if (share <= 1.0 - b / (2.0 * a)) {
			t = share * a + b * 0.5;
		} else {
			t = a + b - std::sqrt(2.0 * a * b * (1.0 - share));
		}
		return bottom + shift + t;
	}
	const double spread = b + c_[p_cell];
	if (a >= spread && share * 2.0 * a >= spread && (1.0 - share) * 2.0 * a >= spread) {
		return bottom + share * a + spread * 0.5;
	}
	double low = 0.0;
	double high = top_[p_cell] - bottom;
	const double close = TOLERANCE * high;
	double at = share * high;
	for (int step = 0; step < SOLVE_STEPS; step++) {
		double slope = 0.0;
		const double off = share_rising(p_cell, at, slope) - share;
		if (off < 0.0) {
			low = at;
		} else {
			high = at;
		}
		double next = slope > 0.0 ? at - off / slope : NAN_;
		next = next > low && next < high ? next : (low + high) * 0.5;
		const double moved = next - at;
		at = next;
		if ((moved < close && moved > -close) || high - low < close) {
			break;
		}
	}
	return bottom + at;
}

// TiltedBox.common_level.
double NativeSink::common_level(int64_t p_a, int64_t p_b, const PackedFloat64Array &p_breaks, double p_total) const {
	double breaks[4];
	const int64_t count = p_breaks.size() < 4 ? p_breaks.size() : 4;
	for (int64_t at = 0; at < count; at++) {
		breaks[at] = p_breaks[at];
	}
	return level_of(p_a, p_b, breaks, count, p_total);
}

// TiltedBox.common_level, p_breaks sorted in place as the engine sorts them.
double NativeSink::level_of(int64_t p_a, int64_t p_b, double *p_breaks, int64_t p_count, double p_total) const {
	sort_few(p_breaks, p_count);
	double below = p_breaks[0];
	double held = 0.0;
	for (int64_t index = 0; index < p_count; index++) {
		const double at = p_breaks[index];
		const double holds = volume(p_a, at) + volume(p_b, at);
		if (holds >= p_total) {
			if (holds <= held) {
				return at;
			}
			return between(p_a, p_b, p_total, below, held, at, holds);
		}
		below = at;
		held = holds;
	}
	return below + (p_total - held) / (full_area_[p_a] + full_area_[p_b]);
}

// TiltedBox._between.
double NativeSink::between(int64_t p_a, int64_t p_b, double p_total, double p_low, double p_low_held,
		double p_high, double p_high_held) const {
	double low = p_low;
	double high = p_high;
	double low_off = p_low_held - p_total;
	double high_off = p_high_held - p_total;
	double at = low;
	int stale = 0;
	for (int step = 0; step < SOLVE_STEPS; step++) {
		at = low + (high - low) * low_off / (low_off - high_off);
		const double off = volume(p_a, at) + volume(p_b, at) - p_total;
		if (abs_f(off) <= TOLERANCE * p_total) {
			return at;
		}
		if (off < 0.0) {
			low = at;
			low_off = off;
			if (stale == -1) {
				high_off *= 0.5;
			}
			stale = -1;
		} else {
			high = at;
			high_off = off;
			if (stale == 1) {
				low_off *= 0.5;
			}
			stale = 1;
		}
	}
	return at;
}

// SinkAir._push, its memo as the GDScript's.
double NativeSink::push(int32_t p_first, const double *p_heads) {
	const double air = pocket_air_[p_first];
	if (air <= least_) {
		return 0.0;
	}
	const int32_t *members = members_.data() + members_from_[p_first];
	const int32_t count = members_count_[p_first];
	bool same = true;
	for (int32_t at = 0; at < count; at++) {
		same = same && p_heads[members[at]] == pushed_at_[members[at]];
	}
	if (same) {
		return pushed_[p_first];
	}
	double room = 0.0;
	for (int32_t at = 0; at < count; at++) {
		const int32_t cell = members[at];
		room += max_f(capacity_[cell] - volume(cell, p_heads[cell]), 0.0);
		pushed_at_[cell] = p_heads[cell];
	}
	pushed_[p_first] = atmosphere_ * (air / max_f(room, least_) - 1.0);
	return pushed_[p_first];
}

// SinkAir.lift.
double NativeSink::lift(int32_t p_cell, int32_t p_other, const double *p_heads) {
	if (p_cell == OUTSIDE) {
		return 0.0;
	}
	const int32_t pocket = pocket_[p_cell];
	if (pocket == -1 || (p_other != OUTSIDE && pocket_[p_other] == pocket)) {
		return 0.0;
	}
	return push(pocket, p_heads);
}

// SinkStepper._transfer, its memo of a solve's flows left out.
double NativeSink::flow_of(int64_t p_index, const double *p_heads, const double *p_following) {
	const int32_t first = first_[p_index];
	const int32_t second = second_[p_index];
	double first_head = first == OUTSIDE ? sea_ : p_heads[first];
	double second_head = second == OUTSIDE ? sea_ : p_heads[second];
	const double bottom = opening_bottom_[p_index];
	if (first_head <= bottom && second_head <= bottom) {
		return 0.0;
	}
	const double share = shares_[p_index];
	if (share <= 0.0) {
		return 0.0;
	}
	const double size = opening_size_[p_index] * share;
	double first_lift = 0.0;
	if (first != OUTSIDE && holding_[first] == 1) {
		first_lift = lift(first, second, p_heads);
	}
	double second_lift = 0.0;
	if (second != OUTSIDE && holding_[second] == 1) {
		second_lift = lift(second, first, p_heads);
	}
	first_head += first_lift;
	second_head += second_lift;
	if (first_head <= bottom && second_head <= bottom) {
		return 0.0;
	}
	const bool in_floor = in_floor_[p_index] == 1;
	if (in_floor) {
		second_head = max_f(second_head, bottom);
	}
	const bool forward = first_head > second_head;
	const int32_t up = forward ? first : second;
	const int32_t down = forward ? second : first;
	const double high = max_f(first_head, second_head);
	const double low = min_f(first_head, second_head);
	const bool up_held = up == OUTSIDE || held_[up] == 1;
	const bool down_held = down == OUTSIDE || held_[down] == 1;
	const double give = up_held ? 0.0 : 1.0 / area_[up];
	double amount = 0.0;
	if (in_floor) {
		if (first_head >= bottom) {
			const double gives = give + (down_held ? 0.0 : 1.0 / area_[down]);
			amount = orifice(size, high - low, gives);
		} else {
			amount = orifice(size, high - bottom, give);
		}
	} else {
		const double top = opening_top_[p_index];
		if (low >= top) {
			const double gives = give + (down_held ? 0.0 : 1.0 / area_[down]);
			amount = orifice(size * (top - bottom), high - low, gives);
		} else if (low <= bottom && high <= top) {
			amount = weir(size, high - bottom, give);
		} else {
			amount = flow(size, bottom, top, high, low) * seconds_;
		}
	}
	if (up_held && down_held) {
		amount = min_f(amount, INF);
	} else {
		const double lifted = forward ? first_lift - second_lift : -(first_lift - second_lift);
		double most = levelling(up, down, p_heads, bottom, lifted);
		if (up_held && p_following != nullptr) {
			// Past its box, no higher than the held side's push where the sweep brought it.
			const double room = capacity_[down] - volume(down, p_following[down]);
			most = min_f(most, max_f(levelling(up, down, p_following, bottom, lifted), room));
		}
		amount = min_f(amount, most);
	}
	return forward ? amount : -amount;
}

// SinkStepper._root.
static double root_of(double p_difference) {
	if (p_difference >= LEVEL_HEAD) {
		return std::sqrt(p_difference);
	}
	return p_difference / std::sqrt(LEVEL_HEAD);
}

// SinkStepper._orifice.
double NativeSink::orifice(double p_area, double p_difference, double p_give) const {
	const double rate = discharge_ * p_area * std::sqrt(2.0 * g_);
	if (p_give <= 0.0) {
		return rate * root_of(p_difference) * seconds_;
	}
	const double root = std::sqrt(p_difference) - rate * p_give * seconds_ * 0.5;
	const double left = root > 0.0 ? root * root : 0.0;
	return (p_difference - left) / p_give;
}

// SinkStepper._weir.
double NativeSink::weir(double p_width, double p_depth, double p_give) const {
	const double rate = 2.0 / 3.0 * discharge_ * p_width * std::sqrt(2.0 * g_);
	if (p_give <= 0.0) {
		return rate * p_depth * std::sqrt(p_depth) * seconds_;
	}
	const double inverse_root = 1.0 / std::sqrt(p_depth) + rate * p_give * seconds_ * 0.5;
	return (p_depth - 1.0 / (inverse_root * inverse_root)) / p_give;
}

// SinkStepper._flow.
double NativeSink::flow(double p_width, double p_bottom, double p_top, double p_high, double p_low) const {
	const double rate = discharge_ * p_width * std::sqrt(2.0 * g_);
	double flow = 0.0;
	const double under = min_f(p_low, p_top) - p_bottom;
	if (under > 0.0) {
		flow += rate * under * root_of(p_high - p_low);
	}
	const double from = max_f(p_bottom, p_low);
	const double to = min_f(p_top, p_high);
	if (to > from) {
		const double deep = p_high - from;
		const double shallow = p_high - to;
		flow += rate * 2.0 / 3.0 * (deep * std::sqrt(deep) - shallow * std::sqrt(shallow));
	}
	return flow;
}

// SinkStepper._levelling.
double NativeSink::levelling(int32_t p_up, int32_t p_down, const double *p_heads, double p_sill, double p_lifted) const {
	const bool up_held = p_up == OUTSIDE || held_[p_up] == 1;
	const bool down_held = p_down == OUTSIDE || held_[p_down] == 1;
	if (up_held && down_held) {
		return INF;
	}
	if (up_held) {
		const double high = (p_up == OUTSIDE ? sea_ : p_heads[p_up]) + p_lifted;
		return max_f(volume(p_down, high) - volume(p_down, p_heads[p_down]), 0.0);
	}
	const double water = volume(p_up, p_heads[p_up]);
	double level = (p_down == OUTSIDE ? sea_ : p_heads[p_down]) - p_lifted;
	if (!down_held) {
		double breaks[4] = { bottom_[p_up], top_[p_up], bottom_[p_down], top_[p_down] };
		const double total = water + volume(p_down, p_heads[p_down]);
		level = level_of(p_up, p_down, breaks, 4, total);
	}
	return max_f(water - volume(p_up, max_f(level, p_sill)), 0.0);
}

// ShippedWater.over and _summed.
static double summed(double p_u, double p_most) {
	if (p_u <= 0.0) {
		return 0.0;
	}
	if (p_u <= p_most) {
		return 0.4 * p_u * p_u * std::sqrt(p_u);
	}
	return 0.4 * p_most * p_most * std::sqrt(p_most) + p_most * std::sqrt(p_most) * (p_u - p_most);
}

static double over(double p_from, double p_to, double p_length, double p_high, double p_low) {
	const double most = p_high - p_low;
	if (most <= 0.0) {
		return 0.0;
	}
	const double u0 = p_high - p_from;
	const double u1 = p_high - p_to;
	if (abs_f(u1 - u0) < LEVEL_STRETCH) {
		const double depth = clamp_f((u0 + u1) * 0.5, 0.0, most);
		return p_length * depth * std::sqrt(depth);
	}
	return p_length * (summed(u1, most) - summed(u0, most)) / (u1 - u0);
}

// ShippedWater.into.
double NativeSink::ship_into(int64_t p_cell, double p_level) const {
	const int32_t well = well_of_[p_cell];
	if (well == -1) {
		return 0.0;
	}
	double depth = 0.0;
	for (int32_t edge = edges_from_[well]; edge < edges_from_[well + 1]; edge++) {
		const double from = edge_heights_[edge * 2];
		const double to = edge_heights_[edge * 2 + 1];
		depth += over(from, to, lengths_[edge], crest_, p_level);
		depth -= over(from, to, lengths_[edge], p_level, trough_);
	}
	return ship_rate_ * depth;
}

// ShippedWater.highest.
double NativeSink::ship_highest(int64_t p_cell) const {
	return well_of_[p_cell] != -1 ? crest_ : -INF;
}

// SinkStepper._surplus.
double NativeSink::surplus_of(int64_t p_cell, double p_at, double p_water, double *p_heads) {
	const double was = p_heads[p_cell];
	p_heads[p_cell] = p_at;
	double into = 0.0;
	for (int32_t at = touch_from_[p_cell]; at < touch_from_[p_cell + 1]; at++) {
		const int32_t index = touching_[at];
		const int32_t other = first_[index] == p_cell ? second_[index] : first_[index];
		const double bottom = opening_bottom_[index];
		if (p_at <= bottom && (other == OUTSIDE ? sea_ : p_heads[other]) <= bottom) {
			continue;
		}
		const double amount = flow_of(index, p_heads);
		into += second_[index] == p_cell ? amount : -amount;
	}
	// A full well is the sea's own: nothing comes over its edges (ShippedWater.ship).
	if (p_water < capacity_[p_cell]) {
		into += ship_into(p_cell, p_at) * seconds_;
	}
	p_heads[p_cell] = was;
	return into - (volume(p_cell, p_at) - p_water);
}

// SinkStepper._balanced.
double NativeSink::balance(int64_t p_cell, double p_water, double *p_heads) {
	double low = bottom_[p_cell];
	double high = max_f(height(p_cell, p_water), ship_highest(p_cell));
	for (int32_t at = touch_from_[p_cell]; at < touch_from_[p_cell + 1]; at++) {
		const int32_t index = touching_[at];
		const int32_t other = first_[index] == p_cell ? second_[index] : first_[index];
		high = max_f(high, other == OUTSIDE ? sea_ : p_heads[other]);
	}
	const double start = clamp_f(p_heads[p_cell], low, high);
	const double at_start = surplus_of(p_cell, start, p_water, p_heads);
	if (abs_f(at_start) <= SURPLUS_TOLERANCE) {
		return start;
	}
	const bool rising = at_start > 0.0;
	const double end = rising ? high : low;
	const double slope = (surplus_of(p_cell, start + NUDGE, p_water, p_heads) - at_start) / NUDGE;
	double reach = slope < 0.0 ? abs_f(at_start / slope) : REACH;
	double near = start;
	double at_near = at_start;
	double far = start;
	double at_far = at_start;
	while (at_far * at_start > 0.0) {
		if (far == end) {
			return end;
		}
		near = far;
		at_near = at_far;
		far = rising ? min_f(near + reach, high) : max_f(near - reach, low);
		at_far = surplus_of(p_cell, far, p_water, p_heads);
		if (abs_f(at_far) <= SURPLUS_TOLERANCE) {
			return far;
		}
		reach *= 4.0;
	}
	double at_low = rising ? at_near : at_far;
	double at_high = rising ? at_far : at_near;
	low = rising ? near : far;
	high = rising ? far : near;
	int kept = 0;
	for (int attempt = 0; attempt < TRIES; attempt++) {
		if (high - low <= HEAD_TOLERANCE) {
			break;
		}
		const double at = low + (high - low) * at_low / (at_low - at_high);
		const double surplus = surplus_of(p_cell, at, p_water, p_heads);
		if (abs_f(surplus) <= SURPLUS_TOLERANCE) {
			return at;
		}
		if (surplus > 0.0) {
			low = at;
			at_low = surplus;
			if (kept == 1) {
				at_high *= 0.5;
			}
			kept = 1;
		} else {
			high = at;
			at_high = surplus;
			if (kept == -1) {
				at_low *= 0.5;
			}
			kept = -1;
		}
	}
	return low + (high - low) * at_low / (at_low - at_high);
}

static double largest(const std::vector<double> &p_values) {
	double most = 0.0;
	for (const double value : p_values) {
		most = max_f(most, abs_f(value));
	}
	return most;
}

// SinkStepper._newton.
bool NativeSink::solve_together(const std::vector<int32_t> &p_held, const double *p_water, double *p_heads) {
	const int64_t count = int64_t(p_held.size());
	std::vector<int32_t> rows(cells(), -1);
	double highest = sea_;
	for (int64_t row = 0; row < count; row++) {
		rows[p_held[row]] = int32_t(row);
		highest = max_f(highest, ship_highest(p_held[row]));
	}
	for (int64_t cell = 0; cell < cells(); cell++) {
		highest = max_f(highest, p_heads[cell]);
	}
	std::vector<double> surplus(count);
	for (int64_t row = 0; row < count; row++) {
		const int32_t cell = p_held[row];
		surplus[row] = surplus_of(cell, p_heads[cell], p_water[cell], p_heads);
	}
	double worst = largest(surplus);
	std::vector<double> slopes(count * count);
	std::vector<double> started(count);
	std::vector<double> change(count);
	std::vector<double> matrix;
	std::vector<double> values;
	std::vector<double> tried(count);
	std::vector<uint8_t> reached(cells());
	for (int attempt = 0; attempt < NEWTON_TRIES; attempt++) {
		if (worst <= SURPLUS_TOLERANCE) {
			return true;
		}
		std::fill(slopes.begin(), slopes.end(), 0.0);
		for (int64_t column = 0; column < count; column++) {
			const int32_t cell = p_held[column];
			const double was = p_heads[cell];
			p_heads[cell] = was + NUDGE;
			slopes[column * count + column] =
					(surplus_of(cell, p_heads[cell], p_water[cell], p_heads) - surplus[column]) / NUDGE;
			if (alone_[cell] == 0) {
				// SinkAir.reached.
				std::fill(reached.begin(), reached.end(), 0);
				const int32_t pocket = pocket_[cell];
				if (pocket != -1) {
					const int32_t *members = members_.data() + members_from_[pocket];
					for (int32_t at = 0; at < members_count_[pocket]; at++) {
						const int32_t member = members[at];
						reached[member] = 1;
						for (int32_t touch = touch_from_[member]; touch < touch_from_[member + 1]; touch++) {
							const int32_t index = touching_[touch];
							const int32_t other = first_[index] == member ? second_[index] : first_[index];
							if (other != OUTSIDE) {
								reached[other] = 1;
							}
						}
					}
				}
				for (int64_t row = 0; row < count; row++) {
					if (row == column || reached[p_held[row]] == 0) {
						continue;
					}
					const int32_t other = p_held[row];
					const double nudged = surplus_of(other, p_heads[other], p_water[other], p_heads);
					slopes[row * count + column] = (nudged - surplus[row]) / NUDGE;
				}
				p_heads[cell] = was;
				continue;
			}
			for (int32_t touch = touch_from_[cell]; touch < touch_from_[cell + 1]; touch++) {
				const int32_t index = touching_[touch];
				const int32_t other = first_[index] == cell ? second_[index] : first_[index];
				if (other == OUTSIDE || rows[other] < 0) {
					continue;
				}
				const double nudged = flow_of(index, p_heads);
				p_heads[cell] = was;
				const double before = flow_of(index, p_heads);
				p_heads[cell] = was + NUDGE;
				const double into_other = second_[index] == other ? 1.0 : -1.0;
				slopes[rows[other] * count + column] += into_other * (nudged - before) / NUDGE;
			}
			p_heads[cell] = was;
		}
		matrix = slopes;
		values = surplus;
		solve(matrix, values, count, change);
		for (int64_t row = 0; row < count; row++) {
			started[row] = p_heads[p_held[row]];
		}
		double share = 1.0;
		bool improved = false;
		for (int halving = 0; halving < HALVINGS; halving++) {
			for (int64_t row = 0; row < count; row++) {
				const int32_t cell = p_held[row];
				p_heads[cell] = clamp_f(started[row] - share * change[row], bottom_[cell], highest);
			}
			for (int64_t row = 0; row < count; row++) {
				const int32_t cell = p_held[row];
				tried[row] = surplus_of(cell, p_heads[cell], p_water[cell], p_heads);
			}
			const double tried_worst = largest(tried);
			if (tried_worst < worst) {
				surplus = tried;
				worst = tried_worst;
				improved = true;
				break;
			}
			share *= 0.5;
		}
		if (!improved) {
			for (int64_t row = 0; row < count; row++) {
				p_heads[p_held[row]] = started[row];
			}
			return false;
		}
	}
	return worst <= SURPLUS_TOLERANCE;
}

// LinearSystem.solved, on r_matrix and r_values in place.
void NativeSink::solve(std::vector<double> &r_matrix, std::vector<double> &r_values, int64_t p_count,
		std::vector<double> &r_x) const {
	double *m = r_matrix.data();
	double *v = r_values.data();
	const int64_t count = p_count;
	std::vector<int64_t> filled;
	filled.reserve(count);
	for (int64_t column = 0; column < count; column++) {
		int64_t pivot = column;
		for (int64_t row = column + 1; row < count; row++) {
			if (abs_f(m[row * count + column]) > abs_f(m[pivot * count + column])) {
				pivot = row;
			}
		}
		if (pivot != column) {
			for (int64_t at = 0; at < count; at++) {
				const double kept = m[column * count + at];
				m[column * count + at] = m[pivot * count + at];
				m[pivot * count + at] = kept;
			}
			const double kept_value = v[column];
			v[column] = v[pivot];
			v[pivot] = kept_value;
		}
		const double lead = m[column * count + column];
		if (lead == 0.0) {
			continue;
		}
		const bool known = !std::isnan(lead);
		const int64_t from = column * count;
		filled.clear();
		for (int64_t at = column; at < count; at++) {
			if (m[from + at] != 0.0) {
				filled.push_back(at);
			}
		}
		for (int64_t row = column + 1; row < count; row++) {
			const int64_t to = row * count;
			if (known && m[to + column] == 0.0) {
				continue;
			}
			const double factor = m[to + column] / lead;
			if (factor == 0.0) {
				continue;
			}
			if (std::isfinite(factor)) {
				for (const int64_t at : filled) {
					m[to + at] -= factor * m[from + at];
				}
			} else {
				for (int64_t at = column; at < count; at++) {
					m[to + at] -= factor * m[from + at];
				}
			}
			v[row] -= factor * v[column];
		}
	}
	r_x.assign(count, 0.0);
	for (int64_t row = count - 1; row >= 0; row--) {
		double sum = v[row];
		for (int64_t at = row + 1; at < count; at++) {
			sum -= m[row * count + at] * r_x[at];
		}
		const double lead = m[row * count + row];
		r_x[row] = lead != 0.0 ? sum / lead : 0.0;
	}
}

void NativeSink::begin_call(const PackedByteArray &p_held, double p_sea, double p_seconds) {
	held_ = p_held.ptr();
	sea_ = p_sea;
	seconds_ = p_seconds;
}

double NativeSink::transfer(int64_t p_index, const PackedFloat64Array &p_heads, const PackedByteArray &p_held,
		double p_sea, double p_seconds) {
	begin_call(p_held, p_sea, p_seconds);
	return flow_of(p_index, p_heads.ptr());
}

double NativeSink::surplus(int64_t p_cell, double p_at, double p_water, const PackedFloat64Array &p_heads,
		const PackedByteArray &p_held, double p_sea, double p_seconds) {
	begin_call(p_held, p_sea, p_seconds);
	std::vector<double> heads(p_heads.ptr(), p_heads.ptr() + p_heads.size());
	return surplus_of(p_cell, p_at, p_water, heads.data());
}

double NativeSink::balanced(int64_t p_cell, double p_water, const PackedFloat64Array &p_heads,
		const PackedByteArray &p_held, double p_sea, double p_seconds) {
	begin_call(p_held, p_sea, p_seconds);
	std::vector<double> heads(p_heads.ptr(), p_heads.ptr() + p_heads.size());
	return balance(p_cell, p_water, heads.data());
}

// Whether the solve closed (1 or 0), then each of p_group's heads as it left them.
PackedFloat64Array NativeSink::newton(const PackedInt32Array &p_group, const PackedFloat64Array &p_water,
		const PackedFloat64Array &p_heads, const PackedByteArray &p_held, double p_sea, double p_seconds) {
	begin_call(p_held, p_sea, p_seconds);
	std::vector<double> heads(p_heads.ptr(), p_heads.ptr() + p_heads.size());
	std::vector<int32_t> group(p_group.ptr(), p_group.ptr() + p_group.size());
	const bool closed = solve_together(group, p_water.ptr(), heads.data());
	PackedFloat64Array found;
	found.resize(group.size() + 1);
	double *out = found.ptrw();
	out[0] = closed ? 1.0 : 0.0;
	for (size_t row = 0; row < group.size(); row++) {
		out[row + 1] = heads[group[row]];
	}
	return found;
}

// SinkStepper.step's sweep of the openings, turning round when p_reverse: every
// opening's water moved, then each cell's water, then each cell's head, then the sea's
// account.
PackedFloat64Array NativeSink::sweep(bool p_reverse, const PackedFloat64Array &p_heads,
		const PackedFloat64Array &p_water, const PackedByteArray &p_held, double p_sea, double p_seconds,
		double p_sea_given) {
	begin_call(p_held, p_sea, p_seconds);
	const int64_t count = int64_t(first_.size());
	const int64_t cell_count = cells();
	PackedFloat64Array found;
	found.resize(count + cell_count * 2 + 1);
	double *moved = found.ptrw();
	double *water = moved + count;
	double *heads = water + cell_count;
	for (int64_t cell = 0; cell < cell_count; cell++) {
		water[cell] = p_water[cell];
		heads[cell] = p_heads[cell];
	}
	const std::vector<double> solved(p_heads.ptr(), p_heads.ptr() + p_heads.size());
	double sea_given = p_sea_given;
	const uint8_t *held = held_;
	// Every opening in turn, then those whose held giver was short of what its solve
	// said, again while anything has passed since every flow waiting began to wait.
	std::vector<int64_t> order;
	size_t waiting = 0;
	order.reserve(size_t(count) * 2);
	for (int64_t turn = 0; turn < count; turn++) {
		order.push_back(p_reverse ? count - 1 - turn : turn);
	}
	for (size_t at = 0; at < order.size(); at++) {
		const int64_t index = order[at];
		const int32_t first = first_[index];
		const int32_t second = second_[index];
		const double bottom = opening_bottom_[index];
		const bool by_held = (first >= 0 && held[first] == 1) || (second >= 0 && held[second] == 1);
		const double *standing = by_held ? solved.data() : heads;
		if ((first == OUTSIDE ? p_sea : standing[first]) <= bottom &&
				(second == OUTSIDE ? p_sea : standing[second]) <= bottom) {
			moved[index] = 0.0;
			continue;
		}
		// A held cell's neighbour the sweep has filled first takes no more than levels them.
		double amount = flow_of(index, standing, heads);
		const int32_t giver = amount > 0.0 ? first : second;
		if (giver != OUTSIDE && by_held) {
			const double holds = max_f(water[giver], 0.0);
			if (abs_f(amount) > holds && (at < size_t(count) || waiting < order.size() - at - 1)) {
				order.push_back(index);
				waiting++;
				continue;
			}
			amount = clamp_f(amount, -holds, holds);
		}
		moved[index] = amount;
		if (amount == 0.0) {
			continue;
		}
		waiting = 0;
		// SinkStepper._give_to, the first side then the second.
		const int32_t sides[2] = { first, second };
		const double given[2] = { -amount, amount };
		for (int side = 0; side < 2; side++) {
			const int32_t to = sides[side];
			if (to == OUTSIDE) {
				sea_given -= given[side];
				continue;
			}
			water[to] += given[side];
			if (held[to] == 0) {
				heads[to] = height(to, water[to]);
			}
		}
	}
	found.set(count + cell_count * 2, sea_given);
	return found;
}

PackedFloat64Array NativeSink::solved(const PackedFloat64Array &p_matrix, const PackedFloat64Array &p_values,
		int64_t p_count) const {
	std::vector<double> matrix(p_matrix.ptr(), p_matrix.ptr() + p_matrix.size());
	std::vector<double> values(p_values.ptr(), p_values.ptr() + p_values.size());
	std::vector<double> x;
	solve(matrix, values, p_count, x);
	PackedFloat64Array found;
	found.resize(p_count);
	for (int64_t row = 0; row < p_count; row++) {
		found.set(row, x[row]);
	}
	return found;
}

void NativeSink::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "first", "second", "in_floor", "middle", "half", "flow_area", "frames",
								 "capacity", "full_area", "constants"),
			&NativeSink::setup);
	ClassDB::bind_method(D_METHOD("wells", "well_of", "edges_from", "ends", "lengths", "rate"), &NativeSink::wells);
	ClassDB::bind_method(D_METHOD("touched", "from", "touching"), &NativeSink::touched);
	ClassDB::bind_method(D_METHOD("faces", "axis", "facing"), &NativeSink::faces);
	ClassDB::bind_method(D_METHOD("turned", "up"), &NativeSink::turned);
	ClassDB::bind_method(D_METHOD("upward"), &NativeSink::upward);
	ClassDB::bind_method(D_METHOD("heights", "water"), &NativeSink::heights);
	ClassDB::bind_method(D_METHOD("shut_times", "shut_time"), &NativeSink::shut_times);
	ClassDB::bind_method(D_METHOD("shares", "since", "opened"), &NativeSink::shares);
	ClassDB::bind_method(D_METHOD("watched", "index", "first", "second", "shut_time", "leak", "collapse",
								 "leak_share", "toward"),
			&NativeSink::watched);
	ClassDB::bind_method(D_METHOD("began", "pocket", "air", "members_from", "members_count", "members", "holding",
								 "alone", "surface"),
			&NativeSink::began);
	ClassDB::bind_method(D_METHOD("transfer", "index", "heads", "held", "sea", "seconds"), &NativeSink::transfer);
	ClassDB::bind_method(D_METHOD("surplus", "cell", "at", "water", "heads", "held", "sea", "seconds"),
			&NativeSink::surplus);
	ClassDB::bind_method(D_METHOD("balanced", "cell", "water", "heads", "held", "sea", "seconds"),
			&NativeSink::balanced);
	ClassDB::bind_method(D_METHOD("newton", "group", "water", "heads", "held", "sea", "seconds"), &NativeSink::newton);
	ClassDB::bind_method(D_METHOD("sweep", "reverse", "heads", "water", "held", "sea", "seconds", "sea_given"),
			&NativeSink::sweep);
	ClassDB::bind_method(D_METHOD("stiff", "heads", "water", "held", "holding", "sea", "per_metre"),
			&NativeSink::stiff);
	ClassDB::bind_method(D_METHOD("across", "heads", "water", "sea", "ceilings", "sills", "pocket", "air",
								 "members_from", "members_count", "members"),
			&NativeSink::across);
	ClassDB::bind_method(D_METHOD("failed", "across", "opened", "seconds"), &NativeSink::failed);
	ClassDB::bind_method(D_METHOD("failure_gaps", "across"), &NativeSink::failure_gaps);
	ClassDB::bind_method(D_METHOD("volume", "cell", "height"), &NativeSink::volume);
	ClassDB::bind_method(D_METHOD("height", "cell", "water"), &NativeSink::height);
	ClassDB::bind_method(D_METHOD("common_level", "a", "b", "breaks", "total"), &NativeSink::common_level);
	ClassDB::bind_method(D_METHOD("solved", "matrix", "values", "count"), &NativeSink::solved);
}
