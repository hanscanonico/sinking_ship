// The sea's ripple, shared by the sea (water.gdshader) and the lap line the ship
// draws where it meets it (ship.gdshaderinc), so the line rides the drawn water.
// Three sines of a few centimetres about the world plane y = 0 — the only water
// the rules know (D7) — so the drawn waterline never strays from the one the sim
// tests.

// The ripple's peak, in metres, all three sines together, and its pace.
const float SEA_RIPPLE_HEIGHT = 0.05;
const float SEA_RIPPLE_SPEED = 0.8;

// Zero-mean by construction: a sum of sines about 0.
float sea_ripple(vec2 xz, float time) {
	float t = time * SEA_RIPPLE_SPEED;
	float a = sin(dot(xz, vec2(0.82, 0.57)) * 0.9 + t * 1.3);
	float b = sin(dot(xz, vec2(-0.36, 0.93)) * 0.57 + t * 1.0);
	float c = sin(dot(xz, vec2(0.97, -0.24)) * 0.37 + t * 0.7);
	return (a + b + c) * SEA_RIPPLE_HEIGHT / 3.0;
}
