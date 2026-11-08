// A bot's way round by the floor in C++ (#410): Surfaces.under, and BotFloorWay._find with
// its _square and _stands, operation for operation, as contacts_native.cpp works the
// rest of Surfaces: a GDScript float is a double and a Vector2 or Vector3 floats, so a
// component read out of a vector is widened before it is summed, and a vector's own sums,
// products and lengths are worked in float32 by godot-cpp's vectors, the engine's code.
// The open set is WalkGraph.OpenSet's heap, ties to the lower square. Contraction is off
// (SConstruct).

#include "contacts_native.h"

#include <algorithm>
#include <cmath>
#include <limits>

using namespace godot;

namespace {
constexpr int32_t NONE = -1;
constexpr double INF = std::numeric_limits<double>::infinity();

// Each query's own lists, so one asked inside another's keeps its own.
thread_local std::vector<int32_t> under_near;
thread_local std::vector<int32_t> under_props;
thread_local std::vector<ContactHit> stands_found;

// WalkGraph.OpenSet: a binary heap of costs, ties to the lower square.
struct OpenSet {
	std::vector<double> costs;
	std::vector<int32_t> squares;

	bool empty() const { return squares.empty(); }

	void push(double p_cost, int32_t p_square) {
		size_t at = squares.size();
		costs.push_back(p_cost);
		squares.push_back(p_square);
		while (at > 0) {
			const size_t parent = (at - 1) >> 1;
			const double above = costs[parent];
			if (above < p_cost || (above == p_cost && squares[parent] < p_square)) {
				break;
			}
			costs[at] = above;
			squares[at] = squares[parent];
			at = parent;
		}
		costs[at] = p_cost;
		squares[at] = p_square;
	}

	int32_t pop() {
		const int32_t top = squares[0];
		const size_t last = squares.size() - 1;
		const double cost = costs[last];
		const int32_t square = squares[last];
		costs.resize(last);
		squares.resize(last);
		if (last == 0) {
			return top;
		}
		size_t at = 0;
		while (true) {
			size_t child = at * 2 + 1;
			if (child >= last) {
				break;
			}
			const size_t right = child + 1;
			if (right < last &&
					(costs[right] < costs[child] || (costs[right] == costs[child] && squares[right] < squares[child]))) {
				child = right;
			}
			if (cost < costs[child] || (cost == costs[child] && square < squares[child])) {
				break;
			}
			costs[at] = costs[child];
			squares[at] = squares[child];
			at = child;
		}
		costs[at] = cost;
		squares[at] = square;
		return top;
	}
};

// BotFloorWay's grid: from origin, width squares wide, each side across.
struct FloorGrid {
	Vector2 origin;
	int64_t width = 1;
	real_t side = 0.25;

	// BotFloorWay._middle.
	Vector2 middle(int64_t p_square) const {
		const Vector2 at(real_t(p_square % width), real_t(int64_t(std::floor(double(p_square) / double(width)))));
		return origin + (at + Vector2(0.5, 0.5)) * side;
	}

	// BotFloorWay._cell.
	int64_t square_of(const Vector2 &p_point) const {
		const Vector2 at = ((p_point - origin) / side).floor();
		return int64_t(at.y) * width + int64_t(at.x);
	}
};
} // namespace

void NativeSurfaces::floors(const PackedInt32Array &p_from, const PackedInt32Array &p_floors,
		const PackedFloat64Array &p_clearances) {
	floors_from_.assign(p_from.ptr(), p_from.ptr() + p_from.size());
	floors_.assign(p_floors.ptr(), p_floors.ptr() + p_floors.size());
	clearances_.assign(p_clearances.ptr(), p_clearances.ptr() + p_clearances.size());
}

// Surfaces.height_at, a crate's lid with her own surfaces.
double NativeSurfaces::height_on(int32_t p_surface, double p_x, double p_z) const {
	if (p_surface >= first_lid_) {
		const int32_t prop = p_surface - first_lid_;
		return double(stands_->foot(prop).y) + stands_->height(prop);
	}
	return height_at(p_surface, p_x, p_z);
}

// Surfaces.under: a floor the feet stand level on, clear of the rest of its cell, first;
// else the highest surface within p_step of the feet; then the crates' lids over them.
int32_t NativeSurfaces::under_at(const Vector3 &p_ship_point, double p_step, int32_t p_except_prop) const {
	int32_t best = NONE;
	double best_height = -INF;
	const double x = double(p_ship_point.x);
	const double z = double(p_ship_point.z);
	const double y = double(p_ship_point.y);
	const Vector2 at(p_ship_point.x, p_ship_point.z);
	const Vector2i cell_xy = grid_.cell_of(at);
	const int64_t cell = int64_t(cell_xy.y) * grid_.size_x + cell_xy.x;
	for (int32_t index = floors_from_[cell]; index < floors_from_[cell + 1]; index++) {
		const int32_t floor_surface = floors_[index];
		if (tops_[floor_surface] == y && p_step < clearances_[index] && gone_[floor_surface] == 0 &&
				contains(floor_surface, x, z)) {
			best = floor_surface;
			best_height = y;
			break;
		}
	}
	std::vector<int32_t> &near = under_near;
	near.clear();
	if (best == NONE) {
		grid_.near(at, at, y - p_step, y + p_step, near);
	}
	for (int32_t surface : near) {
		if (gone_[surface] == 1) {
			continue;
		}
		double height;
		const bool ramp = surface >= first_ramp_ && surface < first_top_;
		const bool round = surface >= first_top_ && round_[surface - first_top_] == 1;
		if (!ramp && !round) {
			// A level rectangle: its area and top are all there is to standing on it.
			if (!contains(surface, x, z)) {
				continue;
			}
			height = tops_[surface];
		} else if (holds(surface, x, z)) {
			height = height_at(surface, x, z);
		} else {
			continue;
		}
		if (std::fabs(height - y) <= p_step && height > best_height) {
			best = surface;
			best_height = height;
		}
	}
	std::vector<int32_t> &props = under_props;
	stands_->near_into(x, z, 0.0, p_except_prop, props);
	for (int32_t prop : props) {
		if (lids_[prop] == 0) {
			continue;
		}
		// PropStands.covers.
		const Vector3 &foot = stands_->foot(prop);
		if (!(double(Vector2(real_t(x - double(foot.x)), real_t(z - double(foot.z))).length()) <=
					stands_->radius(prop))) {
			continue;
		}
		const double height = double(foot.y) + stands_->height(prop);
		if (std::fabs(height - y) <= p_step && height > best_height) {
			best = first_lid_ + prop;
			best_height = height;
		}
	}
	return best;
}

int64_t NativeSurfaces::under(const Vector3 &p_ship_point, double p_step, int64_t p_except_prop) const {
	return under_at(p_ship_point, p_step, int32_t(p_except_prop));
}

// BotFloorWay._stands: on a floor, or a stair of p_keep, and nothing there holding a body
// p_radius round back — no obstacle, no railing.
bool NativeSurfaces::stands_at(const Vector3 &p_point, int32_t p_surface, const std::vector<int32_t> &p_keep,
		double p_radius, double p_step, double p_body_height, double p_crawl_height, double p_railing_height) const {
	if (p_surface == NONE) {
		return false;
	}
	if (p_surface >= first_ramp_ && p_surface < first_top_ &&
			std::find(p_keep.begin(), p_keep.end(), p_surface) == p_keep.end()) {
		return false;
	}
	const Vector3 feet(p_point.x, real_t(height_on(p_surface, double(p_point.x), double(p_point.z))), p_point.z);
	std::vector<ContactHit> &found = stands_found;
	obstacles(feet, p_radius, p_body_height, p_step, NONE, p_crawl_height, -1.0, found);
	if (!found.empty()) {
		return false;
	}
	rails(feet, p_radius, p_surface, p_step, p_railing_height, found);
	return found.empty();
}

// BotFloorWay._find: the shortest way round by the floor from p_from to p_end, a leg's
// entry or the bot's target, over the squares of a grid round the two that a body could
// stand on with its feet at p_from's height, eight ways and never across a corner, as
// points from the middle of its first square on to p_end; empty when the search settles its
// most squares, or all it can reach, before it comes within a square and a half of p_end. p_rules: the square's
// side, the margin round the box, the most squares settled, a square's body's radius, a
// step's height, a body's height, how low it crawls and a railing's height.
PackedVector3Array NativeSurfaces::floor_way(const Vector3 &p_from, const Vector3 &p_end,
		const PackedInt32Array &p_keep, const PackedFloat64Array &p_rules) const {
	const double side = p_rules[0];
	const double margin = p_rules[1];
	const int64_t most = int64_t(p_rules[2]);
	const double snug = p_rules[3];
	const double step = p_rules[4];
	const double body_height = p_rules[5];
	const double crawl_height = p_rules[6];
	const double railing_height = p_rules[7];
	const Vector2 start(p_from.x, p_from.z);
	const Vector2 goal(p_end.x, p_end.z);
	const Rect2 box = Rect2(start, Vector2()).expand(goal).grow(real_t(margin));
	FloorGrid grid;
	grid.side = real_t(side);
	grid.origin = (box.position / real_t(side)).floor() * real_t(side);
	const Vector2 box_end = box.get_end();
	grid.width = int64_t(std::ceil((double(box_end.x) - double(grid.origin.x)) / side));
	const int64_t height = int64_t(std::ceil((double(box_end.y) - double(grid.origin.y)) / side));
	const int64_t cells = grid.width * height;
	const int64_t first = grid.square_of(start);
	const double feet = double(p_from.y);
	const std::vector<int32_t> keep(p_keep.ptr(), p_keep.ptr() + p_keep.size());
	// Per square: 0 not yet asked, 1 a body stands there, 2 it does not.
	std::vector<uint8_t> stands(size_t(cells), 0);
	stands[size_t(first)] = 1;
	std::vector<double> cost(size_t(cells), INF);
	cost[size_t(first)] = 0.0;
	std::vector<int64_t> came(size_t(cells), -1);
	std::vector<uint8_t> done(size_t(cells), 0);
	// BotFloorWay._square.
	auto square = [&](int64_t p_square) -> bool {
		uint8_t &asked = stands[size_t(p_square)];
		if (asked == 0) {
			const Vector2 middle = grid.middle(p_square);
			const Vector3 point(middle.x, real_t(feet), middle.y);
			const int32_t surface = under_at(point, step, NONE);
			asked = stands_at(point, surface, keep, snug, step, body_height, crawl_height, railing_height) ? 1 : 2;
		}
		return asked == 1;
	};
	const double near_goal = side * 1.5;
	OpenSet open;
	open.push(double(start.distance_to(goal)), int32_t(first));
	int64_t settled = 0;
	int64_t reached = -1;
	while (!open.empty() && settled < most) {
		const int64_t cell = open.pop();
		if (done[size_t(cell)] == 1) {
			continue;
		}
		done[size_t(cell)] = 1;
		settled++;
		if (double(grid.middle(cell).distance_to(goal)) <= near_goal) {
			reached = cell;
			break;
		}
		const int64_t x = cell % grid.width;
		const int64_t z = int64_t(std::floor(double(cell) / double(grid.width)));
		for (int64_t dz = -1; dz <= 1; dz++) {
			for (int64_t dx = -1; dx <= 1; dx++) {
				const int64_t nx = x + dx;
				const int64_t nz = z + dz;
				if ((dx == 0 && dz == 0) || nx < 0 || nz < 0 || nx >= grid.width || nz >= height) {
					continue;
				}
				const int64_t next = nz * grid.width + nx;
				if (done[size_t(next)] == 1 || !square(next)) {
					continue;
				}
				// Never across a corner: both squares it passes between stand too.
				if (dx != 0 && dz != 0 && !(square(z * grid.width + nx) && square(nz * grid.width + x))) {
					continue;
				}
				const double through =
						cost[size_t(cell)] + side * double(Vector2(real_t(dx), real_t(dz)).length());
				if (through < cost[size_t(next)]) {
					cost[size_t(next)] = through;
					came[size_t(next)] = cell;
					open.push(through + double(grid.middle(next).distance_to(goal)), int32_t(next));
				}
			}
		}
	}
	PackedVector3Array way;
	if (reached == -1) {
		return way;
	}
	int64_t count = 1;
	for (int64_t back = reached; back != -1; back = came[size_t(back)]) {
		count++;
	}
	way.resize(count);
	Vector3 *write = way.ptrw();
	write[count - 1] = p_end;
	int64_t at = count - 2;
	for (int64_t back = reached; back != -1; back = came[size_t(back)]) {
		const Vector2 middle = grid.middle(back);
		write[at--] = Vector3(middle.x, p_from.y, middle.y);
	}
	return way;
}

// WalkPieces._read: per square of a grid from p_origin, p_width squares wide and p_depth
// deep, each p_side across, 1 where its middle lies in p_within and a body could stand
// with its feet there at p_height (BotFloorWay._stands, the stair it is on kept: a stair's
// end within a step of the floor is walked across), else 0, held by a floor's own railings
// only: on a stair none, as a room's pieces are read (#561). p_rules: a square's body's
// radius, a step's height, a body's height and how low it crawls.
PackedByteArray NativeSurfaces::stands_grid(const Vector2 &p_origin, int64_t p_width, int64_t p_depth,
		double p_side, double p_height, const Rect2 &p_within, const PackedFloat64Array &p_rules) const {
	const double radius = p_rules[0];
	const double step = p_rules[1];
	const double body_height = p_rules[2];
	const double crawl_height = p_rules[3];
	FloorGrid grid;
	grid.origin = p_origin;
	grid.width = p_width;
	grid.side = real_t(p_side);
	PackedByteArray stands;
	stands.resize(p_width * p_depth);
	uint8_t *write = stands.ptrw();
	for (int64_t square = 0; square < p_width * p_depth; square++) {
		const Vector2 middle = grid.middle(square);
		write[square] = 0;
		if (!p_within.has_point(middle)) {
			continue;
		}
		const Vector3 point(middle.x, real_t(p_height), middle.y);
		const int32_t surface = under_at(point, step, NONE);
		if (surface == NONE) {
			continue;
		}
		const Vector3 feet(point.x, real_t(height_on(surface, double(point.x), double(point.z))), point.z);
		std::vector<ContactHit> &found = stands_found;
		obstacles(feet, radius, body_height, step, NONE, crawl_height, -1.0, found);
		if (!found.empty()) {
			continue;
		}
		if (surface < first_ramp_ || surface >= first_top_) {
			rails(feet, radius, surface, step, 0.0, found);
		}
		write[square] = found.empty() ? 1 : 0;
	}
	return stands;
}
