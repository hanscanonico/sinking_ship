// What every grain of the sinking's effects (SinkingFx) shares. It fades out as it
// nears the eye, from clear_to in to clear_from, so nothing it draws stands in the
// eye's face. The sea plane (y = 0) cuts it: drawn after the sea, which writes no
// depth, a grain fallen under it would show over it from above, and one over it
// through it from below; the part on the eye's far side of the plane is not drawn.
// A shaped grain's picture holds the distance to its edge in alpha, 0.5 on it
// (FxGrains.shape), so its silhouette stays hard at any size; glow lifts its colour
// past white, so white water and steam stay white through the tonemap.

uniform float clear_from = 0.9;
uniform float clear_to = 3.0;
uniform float glow = 1.0;

// The world height of the part of the grain drawn here.
varying float height;

// Whether the part of a grain at [at] lies across the sea plane from the eye at
// [eye_height].
bool past_the_sea(float at, float eye_height) {
	return (at < 0.0) != (eye_height < 0.0);
}

// How much of a grain whose fragment lies at view-space [vertex] shows.
float near_fade(vec3 vertex) {
	return smoothstep(clear_from, clear_to, length(vertex));
}

// How much of a shaped grain covers the fragment where its picture's distance is
// [field], its edge moved in to [edge]: crisp, one pixel of smoothing.
float shape_edge(float field, float edge) {
	float soft = max(fwidth(field), 0.0001) * 0.75;
	return smoothstep(edge - soft, edge + soft, field);
}
