// ShipMesh's face emission and IndoorGrid's reads of her rooms (art_native.h). Each
// expression keeps the GDScript's types and order: a Vector3 is three floats, scaled by
// a float, and a GDScript float a double, so a sum of two cuts is a double narrowed
// once to scale a Vector3, and every comparison against a constant is a double one.
// minf, maxf, clampi and floori are the engine's, and bsearch its bisection.

#include "art_native.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <algorithm>
#include <cmath>
#include <limits>

using namespace godot;

namespace {

// ShipMesh's constants.
constexpr int64_t RIM_U0 = 1;
constexpr int64_t RIM_U1 = 2;
constexpr int64_t RIM_V0 = 4;
constexpr int64_t RIM_V1 = 8;
constexpr int64_t RIM_ALL = 15;
constexpr int64_t TOP = 1;
constexpr int64_t BOTTOM = 2;
constexpr int64_t POS_X = 4;
constexpr int64_t NEG_X = 8;
constexpr int64_t POS_Z = 16;
constexpr int64_t NEG_Z = 32;
constexpr double RIM = 0.045;
const Vector3 CHUNK = Vector3(4.0f, 2.5f, 5.0f);
constexpr double PROBE = 0.15;
constexpr double NARROW = 0.3;
constexpr double SLIVER = 0.005;
constexpr double KEEP_MARGIN = 0.5;
// IndoorGrid's, and ShipSpace.INSIDE.
constexpr double CELL = 2.0;
constexpr double BAND = 1.0;
constexpr double SLACK = 0.25;
constexpr double INSIDE = 0.02;

inline double minf(double p_a, double p_b) {
	return p_a < p_b ? p_a : p_b;
}

inline double maxf(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}

inline int64_t clampi(int64_t p_value, int64_t p_min, int64_t p_max) {
	return p_value < p_min ? p_min : (p_value > p_max ? p_max : p_value);
}

inline int64_t floori(double p_value) {
	return (int64_t)std::floor(p_value);
}

// Packed*Array.bsearch(): the engine's bisection, the first index the value goes before
// (p_before) or after.
template <typename T>
int64_t bisect(const T *p_values, int64_t p_count, T p_value, bool p_before) {
	int64_t low = 0;
	int64_t high = p_count;
	if (p_before) {
		while (low < high) {
			const int64_t middle = (low + high) / 2;
			if (p_values[middle] < p_value) {
				low = middle + 1;
			} else {
				high = middle;
			}
		}
	} else {
		while (low < high) {
			const int64_t middle = (low + high) / 2;
			if (p_value < p_values[middle]) {
				high = middle;
			} else {
				low = middle + 1;
			}
		}
	}
	return low;
}

inline int64_t bisect(const std::vector<double> &p_values, double p_value, bool p_before) {
	return bisect(p_values.data(), (int64_t)p_values.size(), p_value, p_before);
}

// u * (cuts[i] + cuts[i + 1]) * 0.5: the cuts summed as doubles, the sum narrowed once.
inline Vector3 half_way(const Vector3 &p_edge, float p_from, float p_to) {
	return (p_edge * (float)((double)p_from + (double)p_to)) * 0.5f;
}

// ShipMesh._bands.
inline Vector2 bands(const Vector3 &p_point, double p_foot, double p_head) {
	return Vector2((float)(std::isnan(p_foot) ? 0.0 : (double)p_point.y - p_foot),
			(float)(std::isnan(p_head) ? 0.0 : p_head - (double)p_point.y));
}

// IndoorGrid._only_axis.
int only_axis(const Vector3 &p_vector) {
	int found = -1;
	for (int axis = 0; axis < 3; axis++) {
		if ((double)p_vector[axis] != 0.0) {
			if (found != -1) {
				return -1;
			}
			found = axis;
		}
	}
	return found;
}

// IndoorGrid.FaceProbes.pick.
inline Vector2i pick(int p_axis, const Vector2i &p_x, const Vector2i &p_y, const Vector2i &p_z) {
	if (p_axis == 0) {
		return p_x;
	}
	return p_axis == 1 ? p_y : p_z;
}

bool rises(const std::vector<double> &p_sequence) {
	for (size_t index = 1; index < p_sequence.size(); index++) {
		if (p_sequence[index] < p_sequence[index - 1]) {
			return false;
		}
	}
	return true;
}

// IndoorGrid._run_end.
int64_t run_end(const std::vector<int32_t> &p_cells, int64_t p_start, int64_t p_end) {
	int64_t at = p_start + 1;
	if (p_cells[p_start] == -1) {
		return at;
	}
	while (at < p_end && p_cells[at] == p_cells[p_start]) {
		at += 1;
	}
	return at;
}

// IndoorGrid._cells_along.
std::vector<int32_t> cells_along(
		const std::vector<double> &p_values, const Vector2i &p_span, const std::vector<double> &p_edges) {
	std::vector<int32_t> found(p_values.size(), 0);
	for (int64_t index = p_span.x; index < p_span.y; index++) {
		const int64_t at = bisect(p_edges, p_values[index], true);
		found[index] = at < (int64_t)p_edges.size() && p_edges[at] == p_values[index] ? -1 : (int32_t)at;
	}
	return found;
}

inline bool has_point(const AABB &p_box, const Vector3 &p_point) {
	return p_box.has_point(p_point);
}

// ShipMesh._chunk_axis.
int chunk_axis(const Vector3 &p_edge) {
	const double length = p_edge.length();
	for (int axis = 0; axis < 3; axis++) {
		if (std::abs((double)p_edge[axis]) >= length - SLIVER) {
			return axis;
		}
	}
	return -1;
}

// ShipMesh._on_chunk_line.
bool on_chunk_line(const Vector3 &p_origin, const Vector3 &p_edge, int p_axis, float p_fraction) {
	const double at = (double)p_origin[p_axis] + (double)p_edge[p_axis] * (double)p_fraction;
	const double step = CHUNK[p_axis];
	return std::abs(at - std::round(at / step) * step) < SLIVER;
}

// ShipMesh._between.
void between(const std::vector<float> &p_lines, double p_low, double p_high, std::vector<float> &r_found) {
	r_found.clear();
	r_found.push_back((float)p_low);
	const int64_t first = bisect(p_lines.data(), (int64_t)p_lines.size(), (float)(p_low + SLIVER), false);
	for (int64_t index = first; index < (int64_t)p_lines.size(); index++) {
		const double at = p_lines[index];
		if (at >= p_high - SLIVER) {
			break;
		}
		if (at > p_low + SLIVER) {
			r_found.push_back(p_lines[index]);
		}
	}
	r_found.push_back((float)p_high);
}

std::vector<float> floats_of(const PackedFloat32Array &p_array) {
	return std::vector<float>(p_array.ptr(), p_array.ptr() + p_array.size());
}

PackedFloat32Array packed_of(const std::vector<float> &p_values) {
	PackedFloat32Array packed;
	packed.resize((int64_t)p_values.size());
	if (!p_values.empty()) {
		std::copy(p_values.begin(), p_values.end(), packed.ptrw());
	}
	return packed;
}

} // namespace

// ---------------------------------------------------------------------------------------
// NativeIndoorGrid

void NativeIndoorGrid::setup(const Vector2 &p_origin, const Vector2i &p_size, double p_low, int64_t p_bands,
		const PackedFloat64Array &p_bounds, const PackedInt32Array &p_cells_from, const PackedInt32Array &p_cells,
		const Callable &p_ceiling_at, const Callable &p_edges_of) {
	_origin = p_origin;
	_size = p_size;
	_low = p_low;
	_bands = p_bands;
	_squares = (int64_t)p_size.x * (int64_t)p_size.y;
	_bounds.assign(p_bounds.ptr(), p_bounds.ptr() + p_bounds.size());
	_cells_from.assign(p_cells_from.ptr(), p_cells_from.ptr() + p_cells_from.size());
	_cells.assign(p_cells.ptr(), p_cells.ptr() + p_cells.size());
	_ceiling_at_call = p_ceiling_at;
	_edges_of = p_edges_of;
	const size_t rooms = _bounds.size() / 5;
	_ceilings.clear();
	_ceilings.resize(rooms);
	_seen.assign(rooms, 0);
	_seen_mark = 0;
}

int64_t NativeIndoorGrid::_band(double p_y) const {
	return clampi(floori((p_y - _low) / BAND), 0, _bands - 1);
}

Vector2i NativeIndoorGrid::_square_of(double p_x, double p_z) const {
	return Vector2i((int32_t)clampi(floori((p_x - (double)_origin.x) / CELL), 0, _size.x - 1),
			(int32_t)clampi(floori((p_z - (double)_origin.y) / CELL), 0, _size.y - 1));
}

int64_t NativeIndoorGrid::_square(double p_x, double p_z) const {
	const Vector2i at = _square_of(p_x, p_z);
	return (int64_t)at.y * _size.x + at.x;
}

const int32_t *NativeIndoorGrid::_near(int64_t p_cell, int64_t &r_count) const {
	r_count = _cells_from[p_cell + 1] - _cells_from[p_cell];
	return _cells.data() + _cells_from[p_cell];
}

NativeIndoorGrid::Ceilings &NativeIndoorGrid::_ceiling_cells(int64_t p_index) {
	Ceilings &cells = _ceilings[p_index];
	if (!cells.gathered) {
		cells.gathered = true;
		const Array edges = _edges_of.call(p_index);
		const PackedFloat64Array xs = edges[0];
		const PackedFloat64Array zs = edges[1];
		cells.xs.assign(xs.ptr(), xs.ptr() + xs.size());
		cells.zs.assign(zs.ptr(), zs.ptr() + zs.size());
	}
	return cells;
}

double NativeIndoorGrid::_ceiling_at(int64_t p_index, double p_x, double p_z) {
	return _ceiling_at_call.call(p_index, p_x, p_z);
}

double NativeIndoorGrid::_cell_ceiling(int64_t p_index, Ceilings &p_cells, int64_t p_cell, double p_x, double p_z) {
	const auto found = p_cells.cells.find(p_cell);
	double height = found == p_cells.cells.end() ? NAN : found->second;
	if (std::isnan(height)) {
		height = _ceiling_at(p_index, p_x, p_z);
		p_cells.cells[p_cell] = height;
	}
	return height;
}

double NativeIndoorGrid::ceiling(int64_t p_index, double p_x, double p_z) {
	Ceilings &cells = _ceiling_cells(p_index);
	const std::vector<double> &xs = cells.xs;
	const std::vector<double> &zs = cells.zs;
	const int64_t column = bisect(xs, p_x, true);
	const int64_t row = bisect(zs, p_z, true);
	bool on_edge = std::isnan(p_x) || std::isnan(p_z) || (column < (int64_t)xs.size() && xs[column] == p_x) ||
			(row < (int64_t)zs.size() && zs[row] == p_z);
	const double single_x = (float)p_x;
	const double single_z = (float)p_z;
	if (!on_edge && single_x != p_x) {
		const int64_t at = bisect(xs, single_x, true);
		on_edge = at < (int64_t)xs.size() && xs[at] == single_x;
	}
	if (!on_edge && single_z != p_z) {
		const int64_t at = bisect(zs, single_z, true);
		on_edge = at < (int64_t)zs.size() && zs[at] == single_z;
	}
	if (on_edge) {
		return _ceiling_at(p_index, p_x, p_z);
	}
	return _cell_ceiling(p_index, cells, column * ((int64_t)zs.size() + 1) + row, p_x, p_z);
}

namespace {

// IndoorGrid.outdoors over boxes read from a GDScript array or a C++ vector.
template <typename Boxes>
bool outdoors_among(const Vector3 &p_point, int64_t p_count, const int32_t *p_near, const Boxes &p_boxes,
		bool p_boxed_by, const std::vector<double> &p_bounds, NativeIndoorGrid *p_grid) {
	if (p_boxed_by) {
		bool boxed = false;
		for (int64_t at = 0; at < p_count; at++) {
			if (has_point(p_boxes(p_near[at]), p_point)) {
				boxed = true;
				break;
			}
		}
		if (!boxed) {
			return true;
		}
	}
	const double x = p_point.x;
	const double y = p_point.y;
	const double z = p_point.z;
	for (int64_t near = 0; near < p_count; near++) {
		const int64_t index = p_near[near];
		const int64_t at = index * 5;
		if (y < p_bounds[at]) {
			continue;
		}
		if (x < p_bounds[at + 1] || x > p_bounds[at + 2]) {
			continue;
		}
		if (z < p_bounds[at + 3] || z > p_bounds[at + 4]) {
			continue;
		}
		if (y <= p_grid->ceiling(index, x, z) + INSIDE) {
			return false;
		}
	}
	return true;
}

} // namespace

bool NativeIndoorGrid::outdoors_of(const Vector3 &p_point, const std::vector<AABB> &p_boxes) {
	const int64_t cell = _band(p_point.y) * _squares + _square(p_point.x, p_point.z);
	int64_t count = 0;
	const int32_t *near = _near(cell, count);
	return outdoors_among(
			p_point, count, near, [&](int32_t p_index) -> const AABB & { return p_boxes[p_index]; },
			!p_boxes.empty(), _bounds, this);
}

bool NativeIndoorGrid::outdoors(const Vector3 &p_point, const Array &p_boxes) {
	const int64_t cell = _band(p_point.y) * _squares + _square(p_point.x, p_point.z);
	int64_t count = 0;
	const int32_t *near = _near(cell, count);
	return outdoors_among(
			p_point, count, near, [&](int32_t p_index) -> AABB { return p_boxes[p_index]; }, !p_boxes.is_empty(),
			_bounds, this);
}

bool NativeIndoorGrid::Probes::order() {
	for (int axis = 0; axis < 3; axis++) {
		const std::vector<double> &own = values[axis];
		std::vector<double> negated;
		negated.reserve(own.size());
		for (double value : own) {
			negated.push_back(-value);
		}
		if (rises(own)) {
			rising[axis] = own;
			signs[axis] = 1.0;
		} else if (rises(negated)) {
			rising[axis] = negated;
			signs[axis] = -1.0;
		} else {
			return false;
		}
	}
	return true;
}

Vector3 NativeIndoorGrid::Probes::low() const {
	double least[3];
	for (int axis = 0; axis < 3; axis++) {
		least[axis] = INFINITY;
		for (double value : values[axis]) {
			least[axis] = minf(least[axis], value);
		}
	}
	return Vector3((float)least[0], (float)least[1], (float)least[2]);
}

Vector3 NativeIndoorGrid::Probes::high() const {
	double most[3];
	for (int axis = 0; axis < 3; axis++) {
		most[axis] = -INFINITY;
		for (double value : values[axis]) {
			most[axis] = maxf(most[axis], value);
		}
	}
	return Vector3((float)most[0], (float)most[1], (float)most[2]);
}

Vector2i NativeIndoorGrid::Probes::span(int p_axis, double p_low, double p_high) const {
	const std::vector<double> &along = rising[p_axis];
	if (signs[p_axis] > 0.0) {
		return Vector2i((int32_t)bisect(along, p_low, true), (int32_t)bisect(along, p_high, false));
	}
	return Vector2i((int32_t)bisect(along, -p_high, true), (int32_t)bisect(along, -p_low, false));
}

int NativeIndoorGrid::Probes::axis_of(int p_source) const {
	for (int axis = 0; axis < 3; axis++) {
		if (by[axis] == p_source) {
			return axis;
		}
	}
	return -1;
}

void NativeIndoorGrid::_rooms_reaching(const Vector3 &p_low, const Vector3 &p_high, std::vector<int32_t> &r_found) {
	r_found.clear();
	_seen_mark += 1;
	if (_seen_mark == 0) {
		std::fill(_seen.begin(), _seen.end(), 0);
		_seen_mark = 1;
	}
	const Vector2i first = _square_of(p_low.x, p_low.z);
	const Vector2i last = _square_of(p_high.x, p_high.z);
	const int64_t bottom = _band(p_low.y);
	const int64_t top = _band(p_high.y);
	for (int64_t band = bottom; band < top + 1; band++) {
		for (int64_t row = first.y; row < last.y + 1; row++) {
			for (int64_t column = first.x; column < last.x + 1; column++) {
				const int64_t square = row * _size.x + column;
				int64_t count = 0;
				const int32_t *near = _near(band * _squares + square, count);
				for (int64_t at = 0; at < count; at++) {
					const int32_t index = near[at];
					if (_seen[index] != _seen_mark) {
						_seen[index] = _seen_mark;
						r_found.push_back(index);
					}
				}
			}
		}
	}
}

void NativeIndoorGrid::_mark_box(const AABB &p_box, const Probes &p_face, std::vector<uint8_t> &r_marked) const {
	const Vector3 end = p_box.position + p_box.size;
	const Vector2i span_x = p_face.span(0, p_box.position.x, end.x);
	if (span_x.x >= span_x.y) {
		return;
	}
	const Vector2i span_y = p_face.span(1, p_box.position.y, end.y);
	if (span_y.x >= span_y.y) {
		return;
	}
	const Vector2i span_z = p_face.span(2, p_box.position.z, end.z);
	if (span_z.x >= span_z.y) {
		return;
	}
	const Vector2i u = pick(p_face.axis_of(0), span_x, span_y, span_z);
	const Vector2i v = pick(p_face.axis_of(1), span_x, span_y, span_z);
	const int64_t rows = p_face.rows;
	for (int64_t i = u.x; i < u.y; i++) {
		for (int64_t j = v.x; j < v.y; j++) {
			r_marked[i * rows + j] = 1;
		}
	}
}

void NativeIndoorGrid::_mark_room(int64_t p_index, const Probes &p_face, std::vector<uint8_t> &r_marked) {
	const int64_t at = p_index * 5;
	const Vector2i span_x = p_face.span(0, _bounds[at + 1], _bounds[at + 2]);
	if (span_x.x >= span_x.y) {
		return;
	}
	const Vector2i span_y = p_face.span(1, _bounds[at], INFINITY);
	if (span_y.x >= span_y.y) {
		return;
	}
	const Vector2i span_z = p_face.span(2, _bounds[at + 3], _bounds[at + 4]);
	if (span_z.x >= span_z.y) {
		return;
	}
	Ceilings &cells = _ceiling_cells(p_index);
	const std::vector<int32_t> columns = cells_along(p_face.values[0], span_x, cells.xs);
	const std::vector<int32_t> rows = cells_along(p_face.values[2], span_z, cells.zs);
	const Vector2i u = pick(p_face.axis_of(0), span_x, span_y, span_z);
	const Vector2i v = pick(p_face.axis_of(1), span_x, span_y, span_z);
	const int *by = p_face.by;
	if (by[1] == 2) {
		const int32_t spans[4] = { u.x, u.y, v.x, v.y };
		_mark_level(p_index, p_face, spans, columns, rows, r_marked);
		return;
	}
	const int along = by[0] != 2 ? 0 : 2;
	const std::vector<double> &x_at = p_face.values[0];
	const std::vector<double> &z_at = p_face.values[2];
	const int64_t depth = (int64_t)cells.zs.size() + 1;
	const double floor = _bounds[at];
	const int64_t face_rows = p_face.rows;
	const bool by_column = by[1] == 1;
	int64_t last_cell = -1;
	Vector2i under;
	const Vector2i spans_along = along == 0 ? span_x : span_z;
	for (int64_t k = spans_along.x; k < spans_along.y; k++) {
		const int64_t pick_x = by[0] != 2 ? k : 0;
		const int64_t pick_z = by[2] != 2 ? k : 0;
		const int64_t column = columns[pick_x];
		const int64_t row = rows[pick_z];
		if (column == -1 || row == -1) {
			last_cell = -1;
			const double height = _ceiling_at(p_index, x_at[pick_x], z_at[pick_z]);
			under = p_face.span(1, floor, height + INSIDE);
		} else if (column * depth + row != last_cell) {
			last_cell = column * depth + row;
			const double height = _cell_ceiling(p_index, cells, last_cell, x_at[pick_x], z_at[pick_z]);
			under = p_face.span(1, floor, height + INSIDE);
		}
		for (int64_t j = under.x; j < under.y; j++) {
			r_marked[by_column ? k * face_rows + j : j * face_rows + k] = 1;
		}
	}
}

void NativeIndoorGrid::_mark_level(int64_t p_index, const Probes &p_face, const int32_t p_spans[4],
		const std::vector<int32_t> &p_columns, const std::vector<int32_t> &p_rows, std::vector<uint8_t> &r_marked) {
	const double y = p_face.values[1][0];
	const bool x_by_column = p_face.by[0] == 0;
	const std::vector<double> &xs_at = p_face.values[0];
	const std::vector<double> &zs_at = p_face.values[2];
	const std::vector<int32_t> &across_i = x_by_column ? p_columns : p_rows;
	const std::vector<int32_t> &across_j = x_by_column ? p_rows : p_columns;
	Ceilings &cells = _ceiling_cells(p_index);
	const int64_t depth = (int64_t)cells.zs.size() + 1;
	const int64_t face_rows = p_face.rows;
	int64_t i = p_spans[0];
	while (i < p_spans[1]) {
		const int64_t i_end = run_end(across_i, i, p_spans[1]);
		int64_t j = p_spans[2];
		while (j < p_spans[3]) {
			const int64_t j_end = run_end(across_j, j, p_spans[3]);
			const int64_t column = x_by_column ? across_i[i] : across_j[j];
			const int64_t row = x_by_column ? across_j[j] : across_i[i];
			const double x = xs_at[x_by_column ? i : j];
			const double z = zs_at[x_by_column ? j : i];
			if (column != -1 && row != -1) {
				const double height = _cell_ceiling(p_index, cells, column * depth + row, x, z);
				if (y <= height + INSIDE) {
					for (int64_t at = i; at < i_end; at++) {
						for (int64_t on = j; on < j_end; on++) {
							r_marked[at * face_rows + on] = 1;
						}
					}
				}
			} else {
				for (int64_t at = i; at < i_end; at++) {
					for (int64_t on = j; on < j_end; on++) {
						const int64_t cell = at * face_rows + on;
						const double probe_x = xs_at[x_by_column ? at : on];
						const double probe_z = zs_at[x_by_column ? on : at];
						if (r_marked[cell] == 0) {
							if (y <= _ceiling_at(p_index, probe_x, probe_z) + INSIDE) {
								r_marked[cell] = 1;
							}
						}
					}
				}
			}
			j = j_end;
		}
		i = i_end;
	}
}

bool NativeIndoorGrid::outdoors_over_of(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
		const std::vector<float> &p_u_cuts, const std::vector<float> &p_v_cuts, const Vector3 &p_normal,
		double p_probe, const std::vector<AABB> &p_boxes, std::vector<uint8_t> &r_shows) {
	const int u_axis = only_axis(p_u);
	const int v_axis = only_axis(p_v);
	const int n_axis = only_axis(p_normal);
	if (u_axis == -1 || v_axis == -1 || n_axis == -1 || u_axis == v_axis) {
		return false;
	}
	if (n_axis == u_axis || n_axis == v_axis) {
		return false;
	}
	const int64_t columns = (int64_t)p_u_cuts.size() - 1;
	const int64_t rows = (int64_t)p_v_cuts.size() - 1;
	const Vector3 stepped = p_normal * (float)p_probe;
	const Vector3 first_u = half_way(p_u, p_u_cuts[0], p_u_cuts[1]);
	const Vector3 first_v = half_way(p_v, p_v_cuts[0], p_v_cuts[1]);
	Probes face;
	face.rows = rows;
	std::vector<double> &along_u = face.values[u_axis];
	along_u.resize(columns);
	for (int64_t i = 0; i < columns; i++) {
		along_u[i] = (((p_origin + half_way(p_u, p_u_cuts[i], p_u_cuts[i + 1])) + first_v) + stepped)[u_axis];
	}
	std::vector<double> &along_v = face.values[v_axis];
	along_v.resize(rows);
	const Vector3 from_u = p_origin + first_u;
	for (int64_t j = 0; j < rows; j++) {
		along_v[j] = ((from_u + half_way(p_v, p_v_cuts[j], p_v_cuts[j + 1])) + stepped)[v_axis];
	}
	face.values[n_axis].assign(1, ((from_u + first_v) + stepped)[n_axis]);
	face.by[u_axis] = 0;
	face.by[v_axis] = 1;
	face.by[n_axis] = 2;
	if (!face.order()) {
		return false;
	}
	std::vector<uint8_t> boxed(columns * rows, 0);
	std::vector<uint8_t> inside(columns * rows, 0);
	const Vector3 low = face.low();
	const Vector3 high = face.high();
	std::vector<int32_t> reaching;
	_rooms_reaching(low, high, reaching);
	for (int32_t index : reaching) {
		const int64_t at = (int64_t)index * 5;
		if (_bounds[at] > (double)high.y + SLACK) {
			continue;
		}
		if (_bounds[at + 1] > (double)high.x + SLACK || _bounds[at + 2] < (double)low.x - SLACK) {
			continue;
		}
		if (_bounds[at + 3] > (double)high.z + SLACK || _bounds[at + 4] < (double)low.z - SLACK) {
			continue;
		}
		if (!p_boxes.empty()) {
			_mark_box(p_boxes[index], face, boxed);
		}
		_mark_room(index, face, inside);
	}
	r_shows.resize(columns * rows);
	for (int64_t cell = 0; cell < columns * rows; cell++) {
		r_shows[cell] = inside[cell] == 0 || (!p_boxes.empty() && boxed[cell] == 0) ? 1 : 0;
	}
	return true;
}

Array NativeIndoorGrid::outdoors_over(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
		const PackedFloat32Array &p_u_cuts, const PackedFloat32Array &p_v_cuts, const Vector3 &p_normal,
		double p_probe, const Array &p_boxes) {
	std::vector<AABB> boxes;
	boxes.reserve(p_boxes.size());
	for (int64_t index = 0; index < p_boxes.size(); index++) {
		boxes.push_back(p_boxes[index]);
	}
	std::vector<uint8_t> shows;
	Array found;
	if (!outdoors_over_of(p_origin, p_u, p_v, floats_of(p_u_cuts), floats_of(p_v_cuts), p_normal, p_probe, boxes,
				shows)) {
		return found;
	}
	found.resize((int64_t)shows.size());
	for (size_t cell = 0; cell < shows.size(); cell++) {
		found[(int64_t)cell] = shows[cell] == 1;
	}
	return found;
}

void NativeIndoorGrid::set_columns(const PackedInt32Array &p_columns_from, const PackedInt32Array &p_columns) {
	_columns_from.assign(p_columns_from.ptr(), p_columns_from.ptr() + p_columns_from.size());
	_columns.assign(p_columns.ptr(), p_columns.ptr() + p_columns.size());
}

const int32_t *NativeIndoorGrid::rooms_over(double p_x, double p_z, int64_t &r_count) const {
	const int64_t square = _square(p_x, p_z);
	r_count = _columns_from[square + 1] - _columns_from[square];
	return _columns.data() + _columns_from[square];
}

void NativeIndoorGrid::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "origin", "size", "low", "bands", "bounds", "cells_from", "cells",
								 "ceiling_at", "edges_of"),
			&NativeIndoorGrid::setup);
	ClassDB::bind_method(D_METHOD("outdoors", "point", "boxes"), &NativeIndoorGrid::outdoors);
	ClassDB::bind_method(D_METHOD("outdoors_over", "origin", "u", "v", "u_cuts", "v_cuts", "normal", "probe", "boxes"),
			&NativeIndoorGrid::outdoors_over);
	ClassDB::bind_method(D_METHOD("ceiling", "index", "x", "z"), &NativeIndoorGrid::ceiling);
	ClassDB::bind_method(D_METHOD("set_columns", "columns_from", "columns"), &NativeIndoorGrid::set_columns);
}

// ---------------------------------------------------------------------------------------
// NativeLining

void NativeLining::setup(const Ref<NativeIndoorGrid> &p_grid, const PackedByteArray &p_lined, const Array &p_boxes,
		const Array &p_areas, const PackedFloat64Array &p_floors, const PackedInt32Array &p_parts,
		const Array &p_paints) {
	_grid = p_grid;
	_lined.assign(p_lined.ptr(), p_lined.ptr() + p_lined.size());
	_boxes.clear();
	_areas.clear();
	_lined_rooms.clear();
	for (int64_t index = 0; index < p_boxes.size(); index++) {
		_boxes.push_back(p_boxes[index]);
		_areas.push_back(p_areas[index]);
		if (_lined[index] == 1) {
			_lined_rooms.push_back((int32_t)index);
		}
	}
	_floors.assign(p_floors.ptr(), p_floors.ptr() + p_floors.size());
	_parts.assign(p_parts.ptr(), p_parts.ptr() + p_parts.size());
	_paints.assign(1, Paint());
	for (int64_t index = 0; index < p_paints.size(); index++) {
		const Array one = p_paints[index];
		_paints.push_back({ (int64_t)one[0], (Color)one[1], (int64_t)one[2], (Color)one[3] });
	}
}

// RoomDressing.lined_near: of the lined rooms, whether one's box meets the box.
bool NativeLining::lined_near(const AABB &p_box) const {
	for (int32_t index : _lined_rooms) {
		if (_boxes[index].intersects(p_box)) {
			return true;
		}
	}
	return false;
}

// RoomDressing.lining_lines.
void NativeLining::lining_lines(const AABB &p_box, std::vector<float> r_lines[3]) const {
	for (int axis = 0; axis < 3; axis++) {
		r_lines[axis].clear();
	}
	for (int32_t index : _lined_rooms) {
		if (_boxes[index].intersects(p_box)) {
			const Rect2 &area = _areas[index];
			const Vector2 end = area.position + area.size;
			r_lines[0].push_back(area.position.x);
			r_lines[0].push_back(end.x);
			r_lines[2].push_back(area.position.y);
			r_lines[2].push_back(end.y);
		}
	}
	std::sort(r_lines[0].begin(), r_lines[0].end());
	std::sort(r_lines[2].begin(), r_lines[2].end());
}

// RoomDressing.lining, by paint number: of the rooms over the point, in order, the first
// lined one holding it (RoomDressing._holds) gives its paint for the part.
int32_t NativeLining::lining(const Vector3 &p_point, int64_t p_part) const {
	int64_t count = 0;
	const int32_t *near = _grid->rooms_over(p_point.x, p_point.z, count);
	for (int64_t at = 0; at < count; at++) {
		const int32_t index = near[at];
		if (_lined[index] != 1) {
			continue;
		}
		const Rect2 &area = _areas[index];
		const Vector2 end = area.position + area.size;
		if (p_point.x < area.position.x || p_point.x > end.x) {
			continue;
		}
		if (p_point.z < area.position.y || p_point.z > end.y) {
			continue;
		}
		if ((double)p_point.y < _floors[index] - INSIDE) {
			continue;
		}
		if ((double)p_point.y <= _grid->ceiling(index, p_point.x, p_point.z) + INSIDE) {
			return _parts[index * 4 + p_part];
		}
	}
	return 0;
}

const NativeLining::Paint &NativeLining::paint(int32_t p_id) const {
	return _paints[p_id];
}

void NativeLining::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "grid", "lined", "boxes", "areas", "floors", "parts", "paints"),
			&NativeLining::setup);
}

// ---------------------------------------------------------------------------------------
// NativeShipMesh

bool NativeShipMesh::Place::operator<(const Place &p_other) const {
	if (finish != p_other.finish) {
		return finish < p_other.finish;
	}
	if (x != p_other.x) {
		return x < p_other.x;
	}
	if (y != p_other.y) {
		return y < p_other.y;
	}
	return z < p_other.z;
}

void NativeShipMesh::setup(const Array &p_cuts, const Callable &p_outdoors) {
	for (int axis = 0; axis < 3; axis++) {
		_cuts[axis] = floats_of(p_cuts[axis]);
	}
	_outdoors_call = p_outdoors;
}

void NativeShipMesh::set_cut_above(double p_cut_above) {
	_cut_above = p_cut_above;
}

void NativeShipMesh::set_keep(const Vector2 &p_keep) {
	_keep = p_keep;
}

void NativeShipMesh::set_fading(const Callable &p_fading) {
	_fading = p_fading;
}

void NativeShipMesh::set_outdoors_over(const Callable &p_outdoors_over) {
	_outdoors_over = p_outdoors_over;
}

void NativeShipMesh::set_grid(const Ref<NativeIndoorGrid> &p_grid, const Array &p_boxes) {
	_grid = p_grid;
	_boxes.clear();
	_boxes.reserve(p_boxes.size());
	for (int64_t index = 0; index < p_boxes.size(); index++) {
		_boxes.push_back(p_boxes[index]);
	}
}

namespace {

// RoofedIndoors.CELL.
constexpr double ROOF_CELL = 2.0;

inline std::pair<int64_t, int64_t> roof_square(double p_x, double p_z) {
	return { floori(p_x / ROOF_CELL), floori(p_z / ROOF_CELL) };
}

} // namespace

void NativeShipMesh::set_roofed(double p_weather_floor, const PackedFloat64Array &p_sections,
		const Array &p_outlines, const Array &p_areas, const PackedFloat64Array &p_heights) {
	_roofed = true;
	_weather_floor = p_weather_floor;
	std::shared_ptr<Roof> roof = std::make_shared<Roof>();
	for (int64_t index = 0; index < p_outlines.size(); index++) {
		roof->section_x.push_back(p_sections[index * 2]);
		roof->section_length.push_back(p_sections[index * 2 + 1]);
		const PackedVector2Array outline = p_outlines[index];
		roof->outlines.emplace_back(outline.ptr(), outline.ptr() + outline.size());
	}
	roof->platform_heights.assign(p_heights.ptr(), p_heights.ptr() + p_heights.size());
	for (int64_t index = 0; index < p_areas.size(); index++) {
		const Rect2 area = p_areas[index];
		roof->platform_areas.push_back(area);
		const Vector2 end = area.position + area.size;
		const auto first = roof_square(area.position.x, area.position.y);
		const auto last = roof_square(end.x, end.y);
		for (int64_t x = first.first; x < last.first + 1; x++) {
			for (int64_t z = first.second; z < last.second + 1; z++) {
				roof->platform_squares[{ x, z }].push_back((int32_t)index);
			}
		}
	}
	_roof = roof;
}

// ShipMesh.judge_like: judged as [param p_other] is — its grid, its rooms' boxes and its
// roofed space, the last shared, never copied.
void NativeShipMesh::judge_like(const Ref<NativeShipMesh> &p_other) {
	ERR_FAIL_COND(p_other.is_null());
	_grid = p_other->_grid;
	_boxes = p_other->_boxes;
	_roofed = p_other->_roofed;
	_weather_floor = p_other->_weather_floor;
	_roof = p_other->_roof;
}

// HullSection.shell_at, as a reach (ShipStructure._reach): how far out to side
// [param p_side] her shell reaches at height [param p_y]; 0 where it does not.
double NativeShipMesh::_reach(size_t p_section, double p_y, int64_t p_side) const {
	const std::vector<Vector2> &outline = _roof->outlines[p_section];
	double outermost = -INFINITY;
	for (size_t index = 0; index < outline.size(); index++) {
		const Vector2 a = outline[index];
		const Vector2 b = outline[(index + 1) % outline.size()];
		if (a.y == b.y || ((double)a.y - p_y) * ((double)b.y - p_y) > 0.0) {
			continue;
		}
		const double across = (double)a.x + ((double)b.x - (double)a.x) * (p_y - (double)a.y) / ((double)b.y - (double)a.y);
		outermost = maxf(outermost, across * (double)p_side);
	}
	return outermost > -INFINITY ? std::abs(outermost * (double)p_side) : 0.0;
}

// ShipStructure.half_breadth: her shell as her art lofts it, between the two sections
// whose middles stand either side of x, closing onto her stem past her last one's.
double NativeShipMesh::_half_breadth(double p_x, double p_y, int64_t p_side) const {
	const std::vector<double> &section_x = _roof->section_x;
	const std::vector<double> &section_length = _roof->section_length;
	const size_t count = section_x.size();
	if (count == 0) {
		return 0.0;
	}
	const double aft_end = section_x[0] - section_length[0] * 0.5;
	const double last_x = section_x[count - 1];
	const double last_length = section_length[count - 1];
	if (p_x < aft_end || p_x > last_x + last_length * 0.5) {
		return 0.0;
	}
	for (size_t index = 0; index < count; index++) {
		const double x = section_x[index];
		if (p_x > x && index < count - 1) {
			continue;
		}
		const double here = _reach(index, p_y, p_side);
		if (index == 0 && p_x <= x) {
			return here;
		}
		if (p_x > x) {
			return here * (1.0 - (p_x - x) / (last_length * 0.5));
		}
		const double before = section_x[index - 1];
		const double t = (p_x - before) / (x - before);
		const double from = _reach(index - 1, p_y, p_side);
		return from + (here - from) * t;
	}
	return 0.0;
}

// RoofedIndoors.holds: below her lowest weather deck, inside her shell at the point's x
// and height as her art lofts it (_half_breadth), under a deck.
bool NativeShipMesh::_holds(const Vector3 &p_point) const {
	const double x = p_point.x;
	const double y = p_point.y;
	const double z = p_point.z;
	if (y >= _weather_floor) {
		return false;
	}
	const int64_t side = z >= 0.0 ? 1 : -1;
	const double breadth = _half_breadth(x, y, side);
	if (breadth <= 0.0 || z * (double)side > breadth) {
		return false;
	}
	const auto found = _roof->platform_squares.find(roof_square(x, z));
	if (found == _roof->platform_squares.end()) {
		return false;
	}
	for (int32_t index : found->second) {
		const Rect2 &area = _roof->platform_areas[index];
		const Vector2 end = area.position + area.size;
		if (_roof->platform_heights[index] > y && x >= area.position.x && x <= end.x && z >= area.position.y &&
				z <= end.y) {
			return true;
		}
	}
	return false;
}

bool NativeShipMesh::_kept(double p_aft, double p_fore) const {
	return p_fore >= (double)_keep.x - KEEP_MARGIN && p_aft <= (double)_keep.y + KEEP_MARGIN;
}

bool NativeShipMesh::_outdoors(const Vector3 &p_point) {
	if (_grid.is_valid()) {
		// RoofedIndoors.outdoors: holds() is false at or over the weather floor.
		const bool outdoors = _grid->outdoors_of(p_point, _boxes);
		if (outdoors && _roofed) {
			return !_holds(p_point);
		}
		return outdoors;
	}
	return _outdoors_call.call(p_point);
}

int64_t NativeShipMesh::_batch_for(
		const Vector3 &p_middle, const Vector3 &p_normal, int64_t p_finish, int64_t p_finish_in) {
	_last_outdoors = _outdoors(p_middle + p_normal * (float)PROBE);
	const int64_t finish = _last_outdoors ? p_finish : p_finish_in;
	const int32_t none = std::numeric_limits<int32_t>::min();
	Place place = { finish, none, none, none };
	if (!_last_outdoors) {
		const Vector3 chunk = (p_middle / CHUNK).floor();
		place.x = (int32_t)chunk.x;
		place.y = (int32_t)chunk.y;
		place.z = (int32_t)chunk.z;
	}
	const auto found = _placed.find(place);
	if (found != _placed.end()) {
		return found->second;
	}
	Batch batch;
	batch.finish = finish;
	if (_last_outdoors) {
		batch.key = String::num_int64(finish) + " out";
	} else {
		batch.key = String::num_int64(finish) + " in " + String::num_int64(place.x) + " " +
				String::num_int64(place.y) + " " + String::num_int64(place.z);
	}
	const int64_t at = (int64_t)_batches.size();
	_batches.push_back(std::move(batch));
	_placed[place] = at;
	return at;
}

void NativeShipMesh::_emit(int64_t p_batch, const int32_t *p_order, int64_t p_order_count, const Vector3 *p_points,
		const Vector3 *p_normals, int64_t p_count, const Color &p_colour, const Vector2 *p_uvs,
		const Vector2 *p_uv2s) {
	Batch &batch = _batches[p_batch];
	const int32_t base = (int32_t)batch.vertices.size();
	batch.vertices.insert(batch.vertices.end(), p_points, p_points + p_count);
	batch.normals.insert(batch.normals.end(), p_normals, p_normals + p_count);
	batch.colours.insert(batch.colours.end(), (size_t)p_count, p_colour);
	batch.uvs.insert(batch.uvs.end(), p_uvs, p_uvs + p_count);
	batch.uv2s.insert(batch.uv2s.end(), p_uv2s, p_uv2s + p_count);
	for (int64_t index = 0; index < p_order_count; index++) {
		batch.indices.push_back(p_order[index] + base);
	}
	if (!_fading.is_valid()) {
		return;
	}
	if (_reached.empty()) {
		_piece = AABB(p_points[0], Vector3());
	}
	for (int64_t index = 0; index < p_count; index++) {
		_piece = _piece.expand(p_points[index]);
	}
	if (std::find(_reached.begin(), _reached.end(), p_batch) == _reached.end()) {
		_reached.push_back(p_batch);
	}
	if (_depth == 0) {
		_seal();
	}
}

void NativeShipMesh::_seal() {
	const Vector3 middle = _piece.get_center();
	const Vector3 half = _piece.size * 0.5f;
	const bool fades = _fading.call(_piece);
	const float piece[4] = { middle.x, middle.y, middle.z, fades ? 1.0f : 0.0f };
	const float size[3] = { half.x, half.y, half.z };
	for (int64_t reached : _reached) {
		Batch &batch = _batches[reached];
		const int64_t count = (int64_t)batch.vertices.size() - (int64_t)batch.halves.size() / 3;
		for (int64_t index = 0; index < count; index++) {
			batch.pieces.insert(batch.pieces.end(), piece, piece + 4);
			batch.halves.insert(batch.halves.end(), size, size + 3);
		}
	}
	_reached.clear();
}

void NativeShipMesh::open() {
	_depth += 1;
}

void NativeShipMesh::close() {
	_depth -= 1;
	if (_depth == 0 && !_reached.empty()) {
		_seal();
	}
}

void NativeShipMesh::_quad(const Vector3 &p_a, const Vector3 &p_b, const Vector3 &p_c, const Vector3 &p_d,
		const Vector3 &p_normal, const Paint &p_paint, int64_t p_rims, double p_foot, double p_head) {
	if (minf(minf(p_a.y, p_b.y), minf(p_c.y, p_d.y)) >= _cut_above) {
		return;
	}
	if (!_kept(minf(minf(p_a.x, p_b.x), minf(p_c.x, p_d.x)), maxf(maxf(p_a.x, p_b.x), maxf(p_c.x, p_d.x)))) {
		return;
	}
	const int64_t batch = _batch_for((p_a + p_c) * 0.5f, p_normal, p_paint.finish, p_paint.finish_in);
	const bool outdoors = _last_outdoors;
	const Color colour = outdoors ? p_paint.colour : p_paint.colour_in;
	const float flag = outdoors ? 1.0f : 0.0f;
	const bool clockwise = (double)(p_b - p_a).cross(p_d - p_a).dot(p_normal) < 0.0;
	if (p_rims == 0) {
		const Vector3 corners[4] = { p_a, p_b, p_c, p_d };
		Vector2 uvs[4];
		Vector2 uv2s[4];
		const Vector3 normals[4] = { p_normal, p_normal, p_normal, p_normal };
		for (int index = 0; index < 4; index++) {
			uvs[index] = bands(corners[index], p_foot, p_head);
			uv2s[index] = Vector2(0.0f, flag);
		}
		static const int32_t CLOCKWISE[6] = { 0, 1, 2, 0, 2, 3 };
		static const int32_t COUNTER[6] = { 0, 2, 1, 0, 3, 2 };
		_emit(batch, clockwise ? CLOCKWISE : COUNTER, 6, corners, normals, 4, colour, uvs, uv2s);
		return;
	}
	const double u_length = minf(p_a.distance_to(p_b), p_d.distance_to(p_c));
	const double v_length = minf(p_a.distance_to(p_d), p_b.distance_to(p_c));
	const double ru = minf(RIM, u_length / 3.0) / maxf(u_length, SLIVER);
	const double rv = minf(RIM, v_length / 3.0) / maxf(v_length, SLIVER);
	float us[4];
	int columns = 0;
	us[columns++] = 0.0f;
	if (p_rims & RIM_U0) {
		us[columns++] = (float)ru;
	}
	if (p_rims & RIM_U1) {
		us[columns++] = (float)(1.0 - ru);
	}
	us[columns++] = 1.0f;
	float vs[4];
	int rows = 0;
	vs[rows++] = 0.0f;
	if (p_rims & RIM_V0) {
		vs[rows++] = (float)rv;
	}
	if (p_rims & RIM_V1) {
		vs[rows++] = (float)(1.0 - rv);
	}
	vs[rows++] = 1.0f;
	Vector3 points[16];
	Vector3 normals[16];
	Vector2 uvs[16];
	Vector2 uv2s[16];
	int count = 0;
	for (int j = 0; j < rows; j++) {
		for (int i = 0; i < columns; i++) {
			const Vector3 point = p_a.lerp(p_b, us[i]).lerp(p_d.lerp(p_c, us[i]), vs[j]);
			const bool on_edge = (i == 0 && (p_rims & RIM_U0)) || (i == columns - 1 && (p_rims & RIM_U1)) ||
					(j == 0 && (p_rims & RIM_V0)) || (j == rows - 1 && (p_rims & RIM_V1));
			points[count] = point;
			normals[count] = p_normal;
			uvs[count] = bands(point, p_foot, p_head);
			uv2s[count] = Vector2(on_edge ? 1.0f : 0.0f, flag);
			count++;
		}
	}
	int32_t order[54];
	int order_count = 0;
	for (int j = 0; j < rows - 1; j++) {
		for (int i = 0; i < columns - 1; i++) {
			const int32_t p00 = j * columns + i;
			const int32_t p10 = p00 + 1;
			const int32_t p01 = p00 + columns;
			const int32_t p11 = p01 + 1;
			if (clockwise) {
				const int32_t six[6] = { p00, p10, p11, p00, p11, p01 };
				std::copy(six, six + 6, order + order_count);
			} else {
				const int32_t six[6] = { p00, p11, p10, p00, p01, p11 };
				std::copy(six, six + 6, order + order_count);
			}
			order_count += 6;
		}
	}
	_emit(batch, order, order_count, points, normals, count, colour, uvs, uv2s);
}

void NativeShipMesh::_splits(
		const Vector3 &p_origin, const Vector3 &p_edge, const std::vector<float> *p_lines, std::vector<float> &r_kept) {
	const double length = p_edge.length();
	r_kept.assign({ 0.0f, 1.0f });
	if (length < SLIVER) {
		return;
	}
	int axis = -1;
	for (int candidate = 0; candidate < 3; candidate++) {
		if (std::abs((double)p_edge[candidate]) >= length - SLIVER) {
			axis = candidate;
		}
	}
	if (axis == -1) {
		return;
	}
	const double start = p_origin[axis];
	const double end = start + (double)p_edge[axis];
	const double low = minf(start, end);
	const double high = maxf(start, end);
	std::vector<float> crossed;
	between(p_lines[axis], low, high, crossed);
	const double step = CHUNK[axis];
	double line = std::ceil(low / step) * step;
	while (line < high) {
		crossed.push_back((float)line);
		line += step;
	}
	if (crossed.size() == 2 && length > SLIVER) {
		return;
	}
	std::sort(crossed.begin(), crossed.end());
	std::vector<float> cut;
	cut.reserve(crossed.size() + 2);
	cut.push_back(0.0f);
	for (float at : crossed) {
		const double fraction = ((double)at - start) / (end - start);
		if (fraction * length > SLIVER && (1.0 - fraction) * length > SLIVER) {
			cut.push_back((float)fraction);
		}
	}
	cut.push_back(1.0f);
	std::sort(cut.begin(), cut.end());
	r_kept.assign(1, cut[0]);
	for (float fraction : cut) {
		if (((double)fraction - (double)r_kept.back()) * length > SLIVER) {
			r_kept.push_back(fraction);
		}
	}
	if ((double)r_kept.back() < 1.0) {
		r_kept.back() = 1.0f;
	}
}

template <typename Differs>
void NativeShipMesh::_needed_by(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
		const std::vector<float> &p_u_cuts, const std::vector<float> &p_v_cuts, Differs p_differs,
		std::vector<float> &r_u, std::vector<float> &r_v) {
	const int64_t columns = (int64_t)p_u_cuts.size() - 1;
	const int64_t rows = (int64_t)p_v_cuts.size() - 1;
	const int u_axis = chunk_axis(p_u);
	const int v_axis = chunk_axis(p_v);
	r_u.assign(1, 0.0f);
	for (int64_t i = 1; i < columns; i++) {
		bool keep = u_axis != -1 && on_chunk_line(p_origin, p_u, u_axis, p_u_cuts[i]);
		for (int64_t j = 0; j < rows; j++) {
			if (keep) {
				break;
			}
			keep = p_differs((i - 1) * rows + j, i * rows + j);
		}
		if (keep) {
			r_u.push_back(p_u_cuts[i]);
		}
	}
	r_u.push_back(1.0f);
	r_v.assign(1, 0.0f);
	for (int64_t j = 1; j < rows; j++) {
		bool keep = v_axis != -1 && on_chunk_line(p_origin, p_v, v_axis, p_v_cuts[j]);
		for (int64_t i = 0; i < columns; i++) {
			if (keep) {
				break;
			}
			keep = p_differs(i * rows + j - 1, i * rows + j);
		}
		if (keep) {
			r_v.push_back(p_v_cuts[j]);
		}
	}
	r_v.push_back(1.0f);
}

void NativeShipMesh::_needed(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
		const std::vector<float> &p_u_cuts, const std::vector<float> &p_v_cuts, const uint8_t *p_shows,
		std::vector<float> &r_u, std::vector<float> &r_v) {
	_needed_by(
			p_origin, p_u, p_v, p_u_cuts, p_v_cuts,
			[p_shows](int64_t p_one, int64_t p_other) { return p_shows[p_one] != p_shows[p_other]; }, r_u, r_v);
}

void NativeShipMesh::_face(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v, const Paint &p_paint,
		int64_t p_rims, double p_foot, double p_head) {
	const Vector3 normal = p_u.cross(p_v).normalized();
	const bool narrow = minf(p_u.length(), p_v.length()) < NARROW;
	std::vector<float> u_cuts;
	std::vector<float> v_cuts;
	if (narrow) {
		u_cuts.assign({ 0.0f, 1.0f });
		v_cuts.assign({ 0.0f, 1.0f });
	} else {
		_splits(p_origin, p_u, _cuts, u_cuts);
		_splits(p_origin, p_v, _cuts, v_cuts);
	}
	if (u_cuts.size() > 2 || v_cuts.size() > 2) {
		std::vector<uint8_t> shows;
		bool found = false;
		if (_grid.is_valid()) {
			found = _grid->outdoors_over_of(p_origin, p_u, p_v, u_cuts, v_cuts, normal, PROBE, _boxes, shows);
			// RoofedIndoors.outdoors_over: each piece called outdoors asked of holds().
			if (found && _roofed && !std::isinf(_weather_floor)) {
				const size_t rows = v_cuts.size() - 1;
				for (size_t i = 0; i + 1 < u_cuts.size(); i++) {
					for (size_t j = 0; j < rows; j++) {
						if (shows[i * rows + j] == 1) {
							const Vector3 middle = (p_origin + half_way(p_u, u_cuts[i], u_cuts[i + 1])) +
									half_way(p_v, v_cuts[j], v_cuts[j + 1]);
							const Vector3 point = middle + normal * (float)PROBE;
							if (_holds(point)) {
								shows[i * rows + j] = 0;
							}
						}
					}
				}
			}
		} else if (_outdoors_over.is_valid()) {
			const Array over =
					_outdoors_over.call(p_origin, p_u, p_v, packed_of(u_cuts), packed_of(v_cuts), normal, PROBE);
			if (!over.is_empty()) {
				found = true;
				shows.resize(over.size());
				for (int64_t cell = 0; cell < over.size(); cell++) {
					shows[cell] = (bool)over[cell] ? 1 : 0;
				}
			}
		}
		if (!found) {
			shows.clear();
			for (size_t i = 0; i + 1 < u_cuts.size(); i++) {
				for (size_t j = 0; j + 1 < v_cuts.size(); j++) {
					const Vector3 middle = (p_origin + half_way(p_u, u_cuts[i], u_cuts[i + 1])) +
							half_way(p_v, v_cuts[j], v_cuts[j + 1]);
					shows.push_back(_outdoors(middle + normal * (float)PROBE) ? 1 : 0);
				}
			}
		}
		std::vector<float> kept_u;
		std::vector<float> kept_v;
		_needed(p_origin, p_u, p_v, u_cuts, v_cuts, shows.data(), kept_u, kept_v);
		u_cuts.swap(kept_u);
		v_cuts.swap(kept_v);
	}
	open();
	const size_t columns = u_cuts.size() - 1;
	const size_t rows = v_cuts.size() - 1;
	for (size_t i = 0; i < columns; i++) {
		for (size_t j = 0; j < rows; j++) {
			const Vector3 a = (p_origin + p_u * u_cuts[i]) + p_v * v_cuts[j];
			const Vector3 b = (p_origin + p_u * u_cuts[i + 1]) + p_v * v_cuts[j];
			const Vector3 c = (p_origin + p_u * u_cuts[i + 1]) + p_v * v_cuts[j + 1];
			const Vector3 d = (p_origin + p_u * u_cuts[i]) + p_v * v_cuts[j + 1];
			const int64_t edges = (i == 0 ? p_rims & RIM_U0 : 0) | (i == columns - 1 ? p_rims & RIM_U1 : 0) |
					(j == 0 ? p_rims & RIM_V0 : 0) | (j == rows - 1 ? p_rims & RIM_V1 : 0);
			_quad(a, b, c, d, normal, p_paint, edges, p_foot, p_head);
		}
	}
	close();
}

void NativeShipMesh::box(const Rect2 &p_area, double p_bottom, double p_top, int64_t p_finish, const Color &p_colour,
		int64_t p_finish_in, const Color &p_colour_in, int64_t p_faces, double p_foot, double p_head) {
	if (p_top - p_bottom < SLIVER || (double)p_area.size.x < SLIVER || (double)p_area.size.y < SLIVER) {
		return;
	}
	const Vector2 end = p_area.position + p_area.size;
	if (!_kept(p_area.position.x, end.x)) {
		return;
	}
	const double foot = std::isnan(p_foot) ? p_bottom : p_foot;
	const double head = std::isnan(p_head) ? p_top : p_head;
	const Paint paint = { p_finish, p_colour, p_finish_in, p_colour_in };
	open();
	const float x0 = p_area.position.x;
	const float x1 = end.x;
	const float z0 = p_area.position.y;
	const float z1 = end.y;
	const float top = (float)p_top;
	const float bottom = (float)p_bottom;
	const Vector3 dx = Vector3(p_area.size.x, 0.0f, 0.0f);
	const Vector3 dy = Vector3(0.0f, (float)(p_top - p_bottom), 0.0f);
	const Vector3 dz = Vector3(0.0f, 0.0f, p_area.size.y);
	if (p_faces & TOP) {
		_face(Vector3(x0, top, z0), dz, dx, paint, RIM_ALL, foot, head);
	}
	if (p_faces & BOTTOM) {
		_face(Vector3(x0, bottom, z0), dx, dz, paint, RIM_ALL, foot, head);
	}
	if (p_faces & POS_X) {
		_face(Vector3(x1, bottom, z0), dy, dz, paint, RIM_ALL, foot, head);
	}
	if (p_faces & NEG_X) {
		_face(Vector3(x0, bottom, z0), dz, dy, paint, RIM_ALL, foot, head);
	}
	if (p_faces & POS_Z) {
		_face(Vector3(x0, bottom, z1), dx, dy, paint, RIM_ALL, foot, head);
	}
	if (p_faces & NEG_Z) {
		_face(Vector3(x0, bottom, z0), dy, dx, paint, RIM_ALL, foot, head);
	}
	close();
}

void NativeShipMesh::face(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v, int64_t p_finish,
		const Color &p_colour, int64_t p_finish_in, const Color &p_colour_in, int64_t p_rims, double p_foot,
		double p_head) {
	_face(p_origin, p_u, p_v, { p_finish, p_colour, p_finish_in, p_colour_in }, p_rims, p_foot, p_head);
}

void NativeShipMesh::quad(const Vector3 &p_a, const Vector3 &p_b, const Vector3 &p_c, const Vector3 &p_d,
		const Vector3 &p_normal, int64_t p_finish, const Color &p_colour, int64_t p_finish_in,
		const Color &p_colour_in, int64_t p_rims, double p_foot, double p_head) {
	_quad(p_a, p_b, p_c, p_d, p_normal, { p_finish, p_colour, p_finish_in, p_colour_in }, p_rims, p_foot, p_head);
}

void NativeShipMesh::turned_box(const Transform3D &p_place, const Vector3 &p_size, int64_t p_finish,
		const Color &p_colour, int64_t p_finish_in, const Color &p_colour_in, int64_t p_rims) {
	const Paint paint = { p_finish, p_colour, p_finish_in, p_colour_in };
	const Vector3 half = p_size * 0.5f;
	const Basis &b = p_place.basis;
	const Vector3 bx = b.get_column(0);
	const Vector3 by = b.get_column(1);
	const Vector3 bz = b.get_column(2);
	const Vector3 x = bx * p_size.x;
	const Vector3 y = by * p_size.y;
	const Vector3 z = bz * p_size.z;
	const Vector3 low = p_place.xform(-half);
	const Vector3 high = p_place.xform(half);
	const double foot = low.y;
	const double head = high.y;
	open();
	_quad(low, low + z, (low + z) + x, low + x, -by, paint, p_rims, foot, head);
	_quad(high, high - x, (high - x) - z, high - z, by, paint, p_rims, foot, head);
	_quad(low, low + y, (low + y) + z, low + z, -bx, paint, p_rims, foot, head);
	_quad(high, high - z, (high - z) - y, high - y, bx, paint, p_rims, foot, head);
	_quad(low, low + x, (low + x) + y, low + y, -bz, paint, p_rims, foot, head);
	_quad(high, high - y, (high - y) - x, high - x, bz, paint, p_rims, foot, head);
	close();
}

void NativeShipMesh::model_surface(const Transform3D &p_place, const Basis &p_turn, bool p_mirrored,
		const PackedVector3Array &p_points, const PackedVector3Array &p_normals, const PackedInt32Array &p_order,
		const PackedColorArray &p_inks, int64_t p_finish, const Color &p_colour, int64_t p_finish_in,
		const Color &p_colour_in, double p_foot, double p_head) {
	const int64_t count = p_points.size();
	const Vector3 *points = p_points.ptr();
	const Vector3 *normals = p_normals.ptr();
	std::vector<Vector3> placed(count);
	std::vector<Vector3> turned(count);
	for (int64_t index = 0; index < count; index++) {
		placed[index] = p_place.xform(points[index]);
		turned[index] = p_turn.xform(normals[index]).normalized();
	}
	// Each batch's triangles, as the model's corners, in the order the batches are
	// first reached, and whether each batch is outdoors (ShipMesh.model).
	std::vector<int64_t> batches;
	std::vector<std::vector<int32_t>> corners;
	std::vector<bool> outdoors;
	const int32_t *order = p_order.ptr();
	const double least = SLIVER * SLIVER * SLIVER * SLIVER;
	for (int64_t index = 0; index + 2 < p_order.size(); index += 3) {
		const int32_t a = order[index];
		const int32_t b = order[index + (p_mirrored ? 2 : 1)];
		const int32_t c = order[index + (p_mirrored ? 1 : 2)];
		if (minf(placed[a].y, minf(placed[b].y, placed[c].y)) >= _cut_above) {
			continue;
		}
		const double aft = minf(placed[a].x, minf(placed[b].x, placed[c].x));
		if (!_kept(aft, maxf(placed[a].x, maxf(placed[b].x, placed[c].x)))) {
			continue;
		}
		const Vector3 facing = (placed[c] - placed[a]).cross(placed[b] - placed[a]);
		if ((double)facing.length_squared() < least) {
			continue;
		}
		const Vector3 middle = ((placed[a] + placed[b]) + placed[c]) / 3.0f;
		const int64_t batch = _batch_for(middle, facing.normalized(), p_finish, p_finish_in);
		size_t at = std::find(batches.begin(), batches.end(), batch) - batches.begin();
		if (at == batches.size()) {
			batches.push_back(batch);
			corners.emplace_back();
			outdoors.push_back(_last_outdoors);
		}
		corners[at].push_back(a);
		corners[at].push_back(b);
		corners[at].push_back(c);
	}
	const Color *inks = p_inks.ptr();
	std::vector<int32_t> placed_at(count);
	for (size_t at = 0; at < batches.size(); at++) {
		const float flag = outdoors[at] ? 1.0f : 0.0f;
		std::fill(placed_at.begin(), placed_at.end(), -1);
		std::vector<int32_t> indices;
		std::vector<Vector3> points_in;
		std::vector<Vector3> normals_in;
		std::vector<Vector2> uvs;
		std::vector<Vector2> uv2s;
		indices.reserve(corners[at].size());
		for (int32_t corner : corners[at]) {
			if (placed_at[corner] == -1) {
				placed_at[corner] = (int32_t)points_in.size();
				points_in.push_back(placed[corner]);
				normals_in.push_back(turned[corner]);
				uvs.push_back(bands(placed[corner], p_foot, p_head));
				uv2s.push_back(Vector2(inks[corner].r, flag));
			}
			indices.push_back(placed_at[corner]);
		}
		_emit(batches[at], indices.data(), (int64_t)indices.size(), points_in.data(), normals_in.data(),
				(int64_t)points_in.size(), outdoors[at] ? p_colour : p_colour_in, uvs.data(), uv2s.data());
	}
}

void NativeShipMesh::lined_face(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v, int64_t p_finish,
		const Color &p_colour, int64_t p_finish_in, const Color &p_colour_in, int64_t p_part, double p_foot,
		double p_head, const Ref<NativeLining> &p_lining) {
	const Paint own = { p_finish, p_colour, p_finish_in, p_colour_in };
	const bool narrow = minf(p_u.length(), p_v.length()) < NARROW;
	const AABB box = AABB(p_origin, Vector3()).expand((p_origin + p_u) + p_v).grow((float)PROBE);
	if (!narrow && (p_part == -1 || !p_lining->lined_near(box))) {
		_face(p_origin, p_u, p_v, own, RIM_ALL, p_foot, p_head);
		return;
	}
	std::vector<float> lines[3];
	if (p_part != -1) {
		p_lining->lining_lines(box, lines);
	}
	std::vector<float> u_cuts;
	std::vector<float> v_cuts;
	_splits(p_origin, p_u, lines, u_cuts);
	_splits(p_origin, p_v, lines, v_cuts);
	const Vector3 probe = p_u.cross(p_v).normalized() * (float)PROBE;
	// LinedFaces._lining, by paint number.
	auto lining_of = [&](size_t p_i, size_t p_j) -> int32_t {
		if (p_part == -1) {
			return 0;
		}
		Vector3 middle = p_origin + half_way(p_u, u_cuts[p_i], u_cuts[p_i + 1]);
		middle += half_way(p_v, v_cuts[p_j], v_cuts[p_j + 1]);
		return p_lining->lining(middle + probe, p_part);
	};
	std::vector<int32_t> shows;
	for (size_t i = 0; i + 1 < u_cuts.size(); i++) {
		for (size_t j = 0; j + 1 < v_cuts.size(); j++) {
			shows.push_back(lining_of(i, j));
		}
	}
	std::vector<float> kept_u;
	std::vector<float> kept_v;
	_needed_by(
			p_origin, p_u, p_v, u_cuts, v_cuts,
			[&shows](int64_t p_one, int64_t p_other) { return shows[p_one] != shows[p_other]; }, kept_u, kept_v);
	u_cuts.swap(kept_u);
	v_cuts.swap(kept_v);
	const size_t columns = u_cuts.size() - 1;
	const size_t rows = v_cuts.size() - 1;
	for (size_t i = 0; i < columns; i++) {
		for (size_t j = 0; j < rows; j++) {
			const Vector3 at = (p_origin + p_u * u_cuts[i]) + p_v * v_cuts[j];
			const Vector3 piece_u = p_u * (float)((double)u_cuts[i + 1] - (double)u_cuts[i]);
			const Vector3 piece_v = p_v * (float)((double)v_cuts[j + 1] - (double)v_cuts[j]);
			const int32_t lining = lining_of(i, j);
			const int64_t rims = (i == 0 ? RIM_U0 : 0) | (i == columns - 1 ? RIM_U1 : 0) | (j == 0 ? RIM_V0 : 0) |
					(j == rows - 1 ? RIM_V1 : 0);
			if (lining == 0) {
				_face(at, piece_u, piece_v, own, rims, p_foot, p_head);
			} else {
				const NativeLining::Paint &paint = p_lining->paint(lining);
				_face(at, piece_u, piece_v, { paint.finish, paint.colour, paint.finish_in, paint.colour_in }, rims,
						p_foot, p_head);
			}
		}
	}
}

int64_t NativeShipMesh::batch_for(
		const Vector3 &p_middle, const Vector3 &p_normal, int64_t p_finish, int64_t p_finish_in) {
	return _batch_for(p_middle, p_normal, p_finish, p_finish_in);
}

bool NativeShipMesh::last_outdoors() const {
	return _last_outdoors;
}

void NativeShipMesh::emit(int64_t p_batch, const PackedInt32Array &p_order, const PackedVector3Array &p_points,
		const PackedVector3Array &p_normals, const Color &p_colour, const PackedVector2Array &p_uvs,
		const PackedVector2Array &p_uv2s) {
	_emit(p_batch, p_order.ptr(), p_order.size(), p_points.ptr(), p_normals.ptr(), p_points.size(), p_colour,
			p_uvs.ptr(), p_uv2s.ptr());
}

Array NativeShipMesh::batches() const {
	Array found;
	for (const Batch &batch : _batches) {
		PackedInt32Array indices;
		indices.resize((int64_t)batch.indices.size());
		std::copy(batch.indices.begin(), batch.indices.end(), indices.ptrw());
		PackedVector3Array vertices;
		vertices.resize((int64_t)batch.vertices.size());
		std::copy(batch.vertices.begin(), batch.vertices.end(), vertices.ptrw());
		PackedVector3Array normals;
		normals.resize((int64_t)batch.normals.size());
		std::copy(batch.normals.begin(), batch.normals.end(), normals.ptrw());
		PackedColorArray colours;
		colours.resize((int64_t)batch.colours.size());
		std::copy(batch.colours.begin(), batch.colours.end(), colours.ptrw());
		PackedVector2Array uvs;
		uvs.resize((int64_t)batch.uvs.size());
		std::copy(batch.uvs.begin(), batch.uvs.end(), uvs.ptrw());
		PackedVector2Array uv2s;
		uv2s.resize((int64_t)batch.uv2s.size());
		std::copy(batch.uv2s.begin(), batch.uv2s.end(), uv2s.ptrw());
		Array entry;
		entry.push_back(batch.key);
		entry.push_back(batch.finish);
		entry.push_back(indices);
		entry.push_back(vertices);
		entry.push_back(normals);
		entry.push_back(colours);
		entry.push_back(uvs);
		entry.push_back(uv2s);
		entry.push_back(packed_of(batch.pieces));
		entry.push_back(packed_of(batch.halves));
		found.push_back(entry);
	}
	return found;
}

void NativeShipMesh::clear() {
	_batches.clear();
	_placed.clear();
}

PackedFloat32Array NativeShipMesh::splits(const Vector3 &p_origin, const Vector3 &p_edge, const Array &p_lines) const {
	std::vector<float> lines[3];
	for (int axis = 0; axis < 3; axis++) {
		lines[axis] = floats_of(p_lines[axis]);
	}
	std::vector<float> kept;
	_splits(p_origin, p_edge, lines, kept);
	return packed_of(kept);
}

Array NativeShipMesh::needed(const Vector3 &p_origin, const Vector3 &p_u, const Vector3 &p_v,
		const PackedFloat32Array &p_u_cuts, const PackedFloat32Array &p_v_cuts, const Array &p_shows) const {
	std::vector<float> kept_u;
	std::vector<float> kept_v;
	_needed_by(
			p_origin, p_u, p_v, floats_of(p_u_cuts), floats_of(p_v_cuts),
			[&p_shows](int64_t p_one, int64_t p_other) { return p_shows[p_one] != p_shows[p_other]; }, kept_u,
			kept_v);
	Array kept;
	kept.push_back(packed_of(kept_u));
	kept.push_back(packed_of(kept_v));
	return kept;
}

void NativeShipMesh::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "cuts", "outdoors"), &NativeShipMesh::setup);
	ClassDB::bind_method(D_METHOD("set_cut_above", "cut_above"), &NativeShipMesh::set_cut_above);
	ClassDB::bind_method(D_METHOD("set_keep", "keep"), &NativeShipMesh::set_keep);
	ClassDB::bind_method(D_METHOD("set_fading", "fading"), &NativeShipMesh::set_fading);
	ClassDB::bind_method(D_METHOD("set_outdoors_over", "outdoors_over"), &NativeShipMesh::set_outdoors_over);
	ClassDB::bind_method(D_METHOD("set_grid", "grid", "boxes"), &NativeShipMesh::set_grid);
	ClassDB::bind_method(D_METHOD("set_roofed", "weather_floor", "sections", "outlines", "areas", "heights"),
			&NativeShipMesh::set_roofed);
	ClassDB::bind_method(D_METHOD("judge_like", "other"), &NativeShipMesh::judge_like);
	ClassDB::bind_method(D_METHOD("box", "area", "bottom", "top", "finish", "colour", "finish_in", "colour_in",
								 "faces", "foot", "head"),
			&NativeShipMesh::box);
	ClassDB::bind_method(D_METHOD("face", "origin", "u", "v", "finish", "colour", "finish_in", "colour_in", "rims",
								 "foot", "head"),
			&NativeShipMesh::face);
	ClassDB::bind_method(D_METHOD("quad", "a", "b", "c", "d", "normal", "finish", "colour", "finish_in",
								 "colour_in", "rims", "foot", "head"),
			&NativeShipMesh::quad);
	ClassDB::bind_method(D_METHOD("turned_box", "place", "size", "finish", "colour", "finish_in", "colour_in",
								 "rims"),
			&NativeShipMesh::turned_box);
	ClassDB::bind_method(D_METHOD("model_surface", "place", "turn", "mirrored", "points", "normals", "order", "inks",
								 "finish", "colour", "finish_in", "colour_in", "foot", "head"),
			&NativeShipMesh::model_surface);
	ClassDB::bind_method(D_METHOD("lined_face", "origin", "u", "v", "finish", "colour", "finish_in", "colour_in",
								 "part", "foot", "head", "lining"),
			&NativeShipMesh::lined_face);
	ClassDB::bind_method(D_METHOD("batch_for", "middle", "normal", "finish", "finish_in"), &NativeShipMesh::batch_for);
	ClassDB::bind_method(D_METHOD("last_outdoors"), &NativeShipMesh::last_outdoors);
	ClassDB::bind_method(D_METHOD("emit", "batch", "order", "points", "normals", "colour", "uvs", "uv2s"),
			&NativeShipMesh::emit);
	ClassDB::bind_method(D_METHOD("open"), &NativeShipMesh::open);
	ClassDB::bind_method(D_METHOD("close"), &NativeShipMesh::close);
	ClassDB::bind_method(D_METHOD("batches"), &NativeShipMesh::batches);
	ClassDB::bind_method(D_METHOD("clear"), &NativeShipMesh::clear);
	ClassDB::bind_method(D_METHOD("splits", "origin", "edge", "lines"), &NativeShipMesh::splits);
	ClassDB::bind_method(D_METHOD("needed", "origin", "u", "v", "u_cuts", "v_cuts", "shows"), &NativeShipMesh::needed);
}
