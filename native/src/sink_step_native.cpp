// NativeSink's stages around the solves (#411), each a GDScript one line for line as in
// sink_native.cpp: every opening's share open (SinkStepper._share_out, open_share), the
// cells a step holds stiff (SinkStepper._hold_stiff, ShippedWater.ships), and what of
// her gives way (SinkFailures._heads_across, the loops of follow and gaps,
// _gives_way_gap). Sums and products run in the GDScript's order, minf, maxf and clampf
// are the engine's, and contraction is off (SConstruct).

#include "sink_native.h"

#include <cmath>
#include <limits>

using namespace godot;

namespace {
constexpr int32_t OUTSIDE = -1;
constexpr double INF = std::numeric_limits<double>::infinity();
// SinkStepper's.
constexpr double STIFF_HEAD = 1.0;
constexpr double STILL_HEAD = 5e-3;
// SinkFailures'.
constexpr double REACHED = 1e-3;
constexpr double GAVE_WAY = 1.0;

inline double min_f(double p_a, double p_b) {
	return p_a < p_b ? p_a : p_b;
}

inline double max_f(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}

inline double clamp_f(double p_value, double p_low, double p_high) {
	return p_value < p_low ? p_low : (p_value > p_high ? p_high : p_value);
}

template <typename T, typename P>
void take(std::vector<T> &r_to, const P &p_from) {
	r_to.assign(p_from.ptr(), p_from.ptr() + p_from.size());
}

// SinkStepper.open_share.
double open_share(double p_shut_time, double p_seconds, double p_opened) {
	if (p_shut_time < 0.0) {
		return p_opened;
	}
	if (p_shut_time == 0.0) {
		return 1.0;
	}
	return max_f(clamp_f(1.0 - p_seconds / p_shut_time, 0.0, 1.0), p_opened);
}
} // namespace

void NativeSink::shut_times(const PackedFloat64Array &p_shut_time) {
	take(shut_time_, p_shut_time);
}

// SinkStepper._share_out: every opening's share open p_since seconds after the hit, kept
// for the step's flows and given back.
PackedFloat64Array NativeSink::shares(double p_since, const PackedFloat64Array &p_opened) {
	const double *opened = p_opened.ptr();
	PackedFloat64Array found;
	found.resize(int64_t(shut_time_.size()));
	double *out = found.ptrw();
	for (size_t index = 0; index < shut_time_.size(); index++) {
		shares_[index] = open_share(shut_time_[index], p_since, opened[index]);
		out[index] = shares_[index];
	}
	return found;
}

void NativeSink::watched(const PackedInt32Array &p_index, const PackedInt32Array &p_first,
		const PackedInt32Array &p_second, const PackedFloat64Array &p_shut_time, const PackedFloat64Array &p_leak,
		const PackedFloat64Array &p_collapse, const PackedFloat64Array &p_leak_share,
		const PackedInt32Array &p_toward) {
	take(watched_index_, p_index);
	take(watched_first_, p_first);
	take(watched_second_, p_second);
	take(watched_shut_, p_shut_time);
	take(leak_, p_leak);
	take(collapse_, p_collapse);
	take(leak_share_, p_leak_share);
	take(toward_, p_toward);
}

// SinkStepper._hold_stiff up to its groups: the cells the step holds — a well its edges
// pass water for, a cell whose air is trapped, one whose openings would pass more than
// its room in the step — then every full cell next to a held one; p_held is _held as the
// step finds it, p_holding SinkAir's holding, p_widest SinkStepper._widest. The shares
// are the last given (shares), the wells' crest and lowest ends the step begun's.
PackedInt32Array NativeSink::stiff(const PackedFloat64Array &p_heads, const PackedFloat64Array &p_water,
		const PackedByteArray &p_held, const PackedByteArray &p_holding, const PackedFloat64Array &p_widest,
		double p_sea, double p_per_metre) const {
	const double *heads = p_heads.ptr();
	const double *water = p_water.ptr();
	const uint8_t *holding = p_holding.ptr();
	const double *widest = p_widest.ptr();
	std::vector<uint8_t> held(p_held.ptr(), p_held.ptr() + p_held.size());
	std::vector<int32_t> found;
	for (int64_t cell = 0; cell < cells(); cell++) {
		const double room = min_f(area_[cell] * STIFF_HEAD, capacity_[cell] - water[cell]);
		const bool trapped = holding[cell] == 1;
		const int32_t well = well_of_[cell];
		if (well != -1 && max_f(crest_, heads[cell]) > lowest_[well]) {
			found.push_back(int32_t(cell));
			held[cell] = 1;
			continue;
		}
		if (!trapped && (water[cell] <= 0.0 || widest[cell] * p_per_metre <= room)) {
			continue;
		}
		double passes = 0.0;
		bool moving = false;
		const double own = heads[cell];
		for (int32_t at = touch_from_[cell]; at < touch_from_[cell + 1]; at++) {
			const int32_t index = touching_[at];
			const int32_t other = first_[index] == cell ? second_[index] : first_[index];
			const double beyond = other == OUTSIDE ? p_sea : heads[other];
			const double bottom = opening_bottom_[index];
			if (own <= bottom && beyond <= bottom) {
				continue;
			}
			const double share = shares_[index];
			const double across = std::fabs(max_f(beyond, bottom) - max_f(own, bottom));
			passes += flow_area_[index] * share * std::sqrt(min_f(across, STIFF_HEAD) / STIFF_HEAD);
			moving = moving || (share > 0.0 && (trapped || across > STILL_HEAD));
		}
		if (moving && (trapped || passes * p_per_metre > room)) {
			found.push_back(int32_t(cell));
			held[cell] = 1;
		}
	}
	for (size_t at = 0; at < found.size(); at++) {
		const int32_t cell = found[at];
		for (int32_t touch = touch_from_[cell]; touch < touch_from_[cell + 1]; touch++) {
			const int32_t index = touching_[touch];
			const int32_t other = first_[index] == cell ? second_[index] : first_[index];
			if (other == OUTSIDE || held[other] == 1 || water[other] < capacity_[other]) {
				continue;
			}
			if (heads[cell] <= opening_bottom_[index] && heads[other] <= opening_bottom_[index]) {
				continue;
			}
			found.push_back(other);
			held[other] = 1;
		}
	}
	PackedInt32Array cells_held;
	cells_held.resize(int64_t(found.size()));
	int32_t *out = cells_held.ptrw();
	for (size_t at = 0; at < found.size(); at++) {
		out[at] = found[at];
	}
	return cells_held;
}

// SinkFailures._heads_across with _highest_surface: the head across every watched
// opening, each side's push — the sea's outside — lifted by its pocket's as SinkAir.lift
// lifts it, no higher than any surface in her, no lower than its sill. The pockets are
// SinkAir's as they stand (pockets()), their pushes worked out afresh at p_heads: the
// GDScript's memo of them gives the same.
PackedFloat64Array NativeSink::across(const PackedFloat64Array &p_heads, const PackedFloat64Array &p_water,
		double p_sea, const PackedFloat64Array &p_ceilings, const PackedFloat64Array &p_sills,
		const PackedInt32Array &p_pocket, const PackedFloat64Array &p_air, const PackedInt32Array &p_members_from,
		const PackedInt32Array &p_members_count, const PackedInt32Array &p_members) const {
	const double *heads = p_heads.ptr();
	const double *water = p_water.ptr();
	const double *ceilings = p_ceilings.ptr();
	const double *sills = p_sills.ptr();
	const int32_t *pocket = p_pocket.ptr();
	const double *air = p_air.ptr();
	const int32_t *members_from = p_members_from.ptr();
	const int32_t *members_count = p_members_count.ptr();
	const int32_t *members = p_members.ptr();
	double surface = p_sea;
	for (int64_t cell = 0; cell < p_heads.size(); cell++) {
		if (water[cell] > 0.0 && heads[cell] < ceilings[cell]) {
			surface = max_f(surface, heads[cell]);
		}
	}
	std::vector<double> pushes(size_t(cells()), 0.0);
	std::vector<uint8_t> known(size_t(cells()), 0);
	// SinkAir.lift, with _push.
	auto lift = [&](int32_t p_cell, int32_t p_other) -> double {
		if (p_cell == OUTSIDE) {
			return 0.0;
		}
		const int32_t first = pocket[p_cell];
		if (first == -1 || (p_other != OUTSIDE && pocket[p_other] == first)) {
			return 0.0;
		}
		const double pocket_air = air[first];
		if (pocket_air <= least_) {
			return 0.0;
		}
		if (known[first] == 0) {
			double room = 0.0;
			for (int32_t at = 0; at < members_count[first]; at++) {
				const int32_t cell = members[members_from[first] + at];
				room += max_f(capacity_[cell] - volume(cell, heads[cell]), 0.0);
			}
			pushes[first] = atmosphere_ * (pocket_air / max_f(room, least_) - 1.0);
			known[first] = 1;
		}
		return pushes[first];
	};
	PackedFloat64Array found;
	found.resize(int64_t(watched_index_.size()));
	double *out = found.ptrw();
	for (size_t watched = 0; watched < watched_index_.size(); watched++) {
		const int32_t first = watched_first_[watched];
		const int32_t second = watched_second_[watched];
		const double sill = sills[watched_index_[watched]];
		double pushing = first == OUTSIDE ? p_sea : min_f(heads[first], max_f(ceilings[first], surface));
		double pushed = second == OUTSIDE ? p_sea : min_f(heads[second], max_f(ceilings[second], surface));
		out[watched] = 0.0;
		if (pushing > sill || pushed > sill) {
			pushing = min_f(pushing + lift(first, second), surface);
			pushed = min_f(pushed + lift(second, first), surface);
			out[watched] = max_f(pushing, sill) - max_f(pushed, sill);
		}
	}
	return found;
}

// SinkFailures._gives_way_gap.
double NativeSink::gives_way_gap(int64_t p_watched, double p_across) const {
	const int32_t toward = toward_[p_watched];
	const bool with_flow = toward != 0 && p_across * double(toward) > 0.0;
	double head = collapse_[p_watched];
	if (with_flow && leak_[p_watched] > 0.0) {
		head = leak_[p_watched];
	}
	if (head <= 0.0) {
		return INF;
	}
	return head - std::fabs(p_across);
}

// SinkFailures.follow's openings: p_opened (FloodState.opened) with every watched one
// shut p_seconds after the hit given way or leaking at the heads p_across it.
PackedFloat64Array NativeSink::failed(const PackedFloat64Array &p_across, const PackedFloat64Array &p_opened,
		double p_seconds) const {
	const double *across = p_across.ptr();
	const double *before = p_opened.ptr();
	PackedFloat64Array found;
	found.resize(p_opened.size());
	double *opened = found.ptrw();
	for (int64_t at = 0; at < p_opened.size(); at++) {
		opened[at] = before[at];
	}
	for (size_t watched = 0; watched < watched_index_.size(); watched++) {
		const int32_t index = watched_index_[watched];
		if (before[index] >= GAVE_WAY) {
			continue;
		}
		const bool shut = open_share(watched_shut_[watched], p_seconds, 0.0) <= 0.0;
		if (!shut) {
			continue;
		}
		const double head = across[watched];
		if (gives_way_gap(int64_t(watched), head) <= REACHED) {
			opened[index] = GAVE_WAY;
		} else if (opened[index] == 0.0 && leak_[watched] > 0.0 && leak_[watched] - std::fabs(head) <= REACHED) {
			opened[index] = leak_share_[watched];
		}
	}
	return found;
}

// SinkFailures.gaps' openings: per watched one its leak's gap, then its giving way's.
PackedFloat64Array NativeSink::failure_gaps(const PackedFloat64Array &p_across) const {
	const double *across = p_across.ptr();
	PackedFloat64Array found;
	found.resize(int64_t(watched_index_.size() * 2));
	double *out = found.ptrw();
	for (size_t watched = 0; watched < watched_index_.size(); watched++) {
		const double head = std::fabs(across[watched]);
		const bool leaks = leak_[watched] > 0.0 && leak_share_[watched] > 0.0;
		out[watched * 2] = leaks ? leak_[watched] - head : INF;
		out[watched * 2 + 1] = gives_way_gap(int64_t(watched), across[watched]);
	}
	return found;
}
