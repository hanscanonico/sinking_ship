// ai/walk_search.gd, operation for operation: the same types (a GDScript float is a
// double, a Vector3 floats), the same order, the same heap and its ties to the lower
// zone. Built with floating-point contraction off (SConstruct), so no a * b + c fuses
// where GDScript rounds twice.

#include "walk_search_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <limits>

using namespace godot;

namespace {
constexpr int32_t NONE = -1;
constexpr double INF = std::numeric_limits<double>::infinity();
} // namespace

void NativeWalkGraph::build(const Array &p_out, const PackedInt32Array &p_portal_to,
		const PackedVector3Array &p_portal_entry, const PackedVector3Array &p_portal_exit,
		const PackedFloat64Array &p_portal_length, const PackedFloat64Array &p_pace) {
	const int64_t zones = p_out.size();
	out_start.assign(1, 0);
	out_portals.clear();
	for (int64_t zone = 0; zone < zones; zone++) {
		const PackedInt32Array portals = p_out[zone];
		const int32_t *read = portals.ptr();
		out_portals.insert(out_portals.end(), read, read + portals.size());
		out_start.push_back(int32_t(out_portals.size()));
	}
	portal_to.assign(p_portal_to.ptr(), p_portal_to.ptr() + p_portal_to.size());
	portal_entry.assign(p_portal_entry.ptr(), p_portal_entry.ptr() + p_portal_entry.size());
	portal_exit.assign(p_portal_exit.ptr(), p_portal_exit.ptr() + p_portal_exit.size());
	portal_length.assign(p_portal_length.ptr(), p_portal_length.ptr() + p_portal_length.size());
	pace.assign(p_pace.ptr(), p_pace.ptr() + p_pace.size());
}

int64_t NativeWalkGraph::zone_count() const {
	return int64_t(out_start.size()) - 1;
}

Ref<NativeWalkSearch> NativeWalkGraph::start(int64_t p_zones) {
	Ref<NativeWalkSearch> search;
	search.instantiate();
	search->setup(Ref<NativeWalkGraph>(this), p_zones);
	return search;
}

void NativeWalkGraph::_bind_methods() {
	ClassDB::bind_method(D_METHOD("build", "out", "portal_to", "portal_entry", "portal_exit",
								 "portal_length", "pace"),
			&NativeWalkGraph::build);
	ClassDB::bind_method(D_METHOD("zone_count"), &NativeWalkGraph::zone_count);
	ClassDB::bind_method(D_METHOD("start", "zones"), &NativeWalkGraph::start);
}

void NativeWalkSearch::setup(const Ref<NativeWalkGraph> &p_graph, int64_t p_zones) {
	graph = p_graph;
	zones = int32_t(p_zones);
	cost.resize(zones);
	cost.fill(INF);
	came_by.assign(zones, NONE);
	came_from.assign(zones, NONE);
	arrived.assign(zones, Vector3());
	done.assign(zones, 0);
}

void NativeWalkSearch::reach(int64_t p_zone, double p_cost, const Vector3 &p_at, int64_t p_portal) {
	const int32_t zone = int32_t(p_zone);
	const int32_t at = slot(zone);
	if (p_cost >= cost[at]) {
		return;
	}
	cost.set(at, p_cost);
	came_by[at] = int32_t(p_portal);
	arrived[at] = p_at;
	seeds.push_back(zone);
	push(p_cost, zone);
}

void NativeWalkSearch::walk(const PackedByteArray &p_closed) {
	closed = p_closed;
}

bool NativeWalkSearch::is_empty() const {
	return zones == 0;
}

bool NativeWalkSearch::reaches(int64_t p_zone) {
	return p_zone >= 0 && p_zone < zones && reached()[p_zone] == 1;
}

PackedByteArray NativeWalkSearch::reached() {
	if (asked) {
		return reach_;
	}
	asked = true;
	reach_.resize(zones);
	reach_.fill(0);
	uint8_t *reach = reach_.ptrw();
	const uint8_t *shut = closed.ptr();
	const NativeWalkGraph &walked = **graph;
	std::vector<int32_t> queue = seeds;
	for (const int32_t zone : queue) {
		reach[slot(zone)] = 1;
	}
	size_t next = 0;
	while (next < queue.size()) {
		const int32_t zone = slot(queue[next]);
		next++;
		for (int32_t k = walked.out_start[zone]; k < walked.out_start[zone + 1]; k++) {
			const int32_t index = walked.out_portals[k];
			const int32_t other = walked.portal_to[index];
			if (shut[index] == 1 || reach[other] == 1) {
				continue;
			}
			reach[other] = 1;
			queue.push_back(other);
		}
	}
	return reach_;
}

double NativeWalkSearch::cost_to(int64_t p_zone, double p_within) {
	if (!reaches(p_zone)) {
		return INF;
	}
	settle(int32_t(p_zone), p_within);
	const double found = cost[p_zone];
	return done[p_zone] == 1 && found <= p_within ? found : INF;
}

PackedFloat64Array NativeWalkSearch::costs() {
	settle(NONE, INF);
	return cost;
}

PackedInt32Array NativeWalkSearch::way_to(int64_t p_zone) {
	PackedInt32Array legs;
	if (cost_to(p_zone, INF) == INF) {
		return legs;
	}
	int32_t zone = int32_t(p_zone);
	while (came_by[slot(zone)] != NONE) {
		legs.push_back(came_by[slot(zone)]);
		zone = came_from[slot(zone)];
		if (zone == NONE) {
			break;
		}
	}
	legs.reverse();
	return legs;
}

void NativeWalkSearch::push(double p_cost, int32_t p_zone) {
	size_t up = heap_zones.size();
	heap_costs.push_back(p_cost);
	heap_zones.push_back(p_zone);
	while (up > 0) {
		const size_t parent = (up - 1) >> 1;
		const double above = heap_costs[parent];
		if (above < p_cost || (above == p_cost && heap_zones[parent] < p_zone)) {
			break;
		}
		heap_costs[up] = above;
		heap_zones[up] = heap_zones[parent];
		up = parent;
	}
	heap_costs[up] = p_cost;
	heap_zones[up] = p_zone;
}

void NativeWalkSearch::settle(int32_t p_goal, double p_within) {
	const NativeWalkGraph &walked = **graph;
	const uint8_t *shut = closed.ptr();
	double *cst = cost.ptrw();
	while (!heap_zones.empty() && heap_costs[0] <= p_within) {
		if (p_goal != NONE && done[p_goal] == 1) {
			break;
		}
		const int32_t zone = heap_zones[0];
		const size_t last = heap_zones.size() - 1;
		const double sift_cost = heap_costs[last];
		const int32_t sift_zone = heap_zones[last];
		heap_costs.pop_back();
		heap_zones.pop_back();
		if (last > 0) {
			size_t down = 0;
			while (true) {
				size_t child = down * 2 + 1;
				if (child >= last) {
					break;
				}
				const size_t right = child + 1;
				if (right < last &&
						(heap_costs[right] < heap_costs[child] ||
								(heap_costs[right] == heap_costs[child] &&
										heap_zones[right] < heap_zones[child]))) {
					child = right;
				}
				if (sift_cost < heap_costs[child] ||
						(sift_cost == heap_costs[child] && sift_zone < heap_zones[child])) {
					break;
				}
				heap_costs[down] = heap_costs[child];
				heap_zones[down] = heap_zones[child];
				down = child;
			}
			heap_costs[down] = sift_cost;
			heap_zones[down] = sift_zone;
		}
		const int32_t here = slot(zone);
		if (done[here] == 1) {
			continue;
		}
		done[here] = 1;
		const double so_far = cst[here];
		const Vector3 at = arrived[here];
		const double pace = walked.pace[here];
		for (int32_t k = walked.out_start[here]; k < walked.out_start[here + 1]; k++) {
			const int32_t index = walked.out_portals[k];
			const int32_t other = walked.portal_to[index];
			if (done[other] == 1 || shut[index] == 1) {
				continue;
			}
			// GDScript: so_far + at.distance_to(entry) * pace + length — a float32
			// distance widened to a double, then two double roundings, left to right.
			const double distance = double(at.distance_to(walked.portal_entry[index]));
			const double paced = distance * pace;
			const double walked_to = so_far + paced;
			const double through = walked_to + walked.portal_length[index];
			if (through < cst[other]) {
				cst[other] = through;
				came_by[other] = index;
				came_from[other] = zone;
				arrived[other] = walked.portal_exit[index];
				push(through, other);
			}
		}
	}
}

void NativeWalkSearch::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "graph", "zones"), &NativeWalkSearch::setup);
	ClassDB::bind_method(D_METHOD("reach", "zone", "cost", "at", "portal"), &NativeWalkSearch::reach);
	ClassDB::bind_method(D_METHOD("walk", "closed"), &NativeWalkSearch::walk);
	ClassDB::bind_method(D_METHOD("is_empty"), &NativeWalkSearch::is_empty);
	ClassDB::bind_method(D_METHOD("reaches", "zone"), &NativeWalkSearch::reaches);
	ClassDB::bind_method(D_METHOD("reached"), &NativeWalkSearch::reached);
	ClassDB::bind_method(D_METHOD("cost_to", "zone", "within"), &NativeWalkSearch::cost_to);
	ClassDB::bind_method(D_METHOD("costs"), &NativeWalkSearch::costs);
	ClassDB::bind_method(D_METHOD("way_to", "zone"), &NativeWalkSearch::way_to);
}
