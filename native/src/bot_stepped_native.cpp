// A bot's reckoning by the walks it has sent in C++: BotReckoning._stepped
// (ai/bot_reckoning.gd) up to its last check, operation for operation, asking the
// railings (walked_rails), the floor under it (under_at) and its height (height_on) as
// contacts_native.cpp and floor_way_native.cpp answer Surfaces. A GDScript float is a
// double and a Vector2 or Vector3 floats: a double times a vector is rounded to a float
// first, as the engine's operator takes it, and the vectors' own sums, products and
// lengths are worked in float32 by godot-cpp's vectors. Contraction is off (SConstruct).

#include "contacts_native.h"

#include <vector>

using namespace godot;

namespace {
constexpr int32_t NONE = -1;

// The railings each tick of the walk meets.
thread_local std::vector<ContactHit> stepped_found;

// maxf: the engine's MAX.
inline double max_of(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}
} // namespace

// From where the view shows the bot, p_seen_pos with its feet's velocity p_seen_vel on
// p_surface, every walk of p_moves sent since p_seen_tick (p_ticks: the tick each was
// sent on, a ring as BotReckoning keeps it), at p_pace, eased toward each by
// ground_accel or slowing by ground_friction when p_eased. p_rules: ground_accel,
// ground_friction, the tick's seconds, body_radius, step_height, railing_height.
Vector3 NativeSurfaces::stepped(const Vector3 &p_seen_pos, const Vector3 &p_seen_vel, int64_t p_surface,
		int64_t p_seen_tick, const PackedVector2Array &p_moves, const PackedInt32Array &p_ticks, double p_pace,
		bool p_eased, const PackedFloat64Array &p_rules) const {
	const double accel = p_rules[0];
	const double friction = p_rules[1];
	const double dt = p_rules[2];
	const double radius = p_rules[3];
	const double step = p_rules[4];
	const double railing = p_rules[5];
	const int64_t count = p_ticks.size();
	Vector2 vel(p_seen_vel.x, p_seen_vel.z);
	Vector3 at = p_seen_pos;
	int32_t surface = int32_t(p_surface);
	std::vector<ContactHit> &found = stepped_found;
	for (int64_t tick = p_seen_tick; tick < p_seen_tick + count; tick++) {
		const int64_t index = tick % count;
		if (int64_t(p_ticks[index]) != tick) {
			break;
		}
		const Vector2 wish = p_moves[index] * real_t(p_pace);
		if (p_eased) {
			const double rate = wish != Vector2() ? accel : friction;
			vel = vel.move_toward(wish, real_t(rate * dt));
		} else {
			vel = wish;
		}
		const Vector2 came(at.x, at.z);
		at += Vector3(vel.x, 0.0, vel.y) * real_t(dt);
		walked_rails(at, came, radius, surface, step, railing, found);
		for (const ContactHit &held : found) {
			at += Vector3(held.normal.x, 0.0, held.normal.y) * real_t(held.depth);
			vel += held.normal * real_t(max_of(-double(vel.dot(held.normal)), 0.0));
		}
		const int32_t under = under_at(at, step, NONE);
		if (under != NONE) {
			surface = under;
			at.y = real_t(height_on(under, double(at.x), double(at.z)));
		}
	}
	return at;
}
