shader_type canvas_item;
// Cel-shaded elemental effects, drawn to match the inked characters: hard
// colour bands (dark, mid, light, core) over a shape that churns with scrolling
// noise, inside a dark ink rim.
//
// Every shape gives two values per pixel: `d`, a distance-like field that is
// negative inside the shape (in units of the quad's height), and `heat`, 0 at
// the edge of the body to 1 at its hottest point, which picks the colour band.
//
// The quad's UV runs x 0..1 along the direction of travel (1 = front) and
// y 0..1 top to bottom. Shapes:
//   0 ball     a round head at the front with a flame tail streaming behind
//   1 column   a pillar rising from the bottom edge, tongues licking off the top
//   2 burst    a row of flame tongues rising from the bottom edge
//   3 wave     a crest of water rolling forward along the bottom edge
//   4 droplet  a slick round head with a short smooth tail (water)

uniform int shape = 0;
uniform vec4 ink : source_color = vec4(0.12, 0.04, 0.03, 1.0);
uniform vec4 dark : source_color = vec4(0.78, 0.16, 0.05, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 light : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.98, 0.82, 1.0);
// Width of the quad over its height, so circles stay round.
uniform float aspect = 1.6;
// How strongly the noise eats into the shape (0 = a smooth shape).
uniform float churn = 1.0;
// Scroll speed of the noise.
uniform float speed = 1.0;
// 0..1: how far an eruption has risen, and its opacity as it dies down.
uniform float grow = 1.0;
uniform float fade = 1.0;
uniform float seed = 0.0;
uniform float time_offset = 0.0;
// Thickness of the ink rim, in units of the quad's height.
uniform float ink_width = 0.03;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.618);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v / 0.9625 - 0.5;   // about -0.5 .. 0.5
}

void fragment() {
	float t = TIME * speed + time_offset;
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float d = 1.0;
	float heat = 0.0;

	if (shape == 0 || shape == 4) {
		bool water = shape == 4;
		float r = water ? 0.36 : 0.33;
		vec2 c = vec2(aspect - r - 0.06, 0.5);
		float n = fbm(vec2(p.x * 3.0 + t * 5.0, p.y * 3.0));
		float along = clamp((c.x - p.x) / max(0.01, c.x - 0.04), 0.0, 1.0);
		float wobble = water ? 0.0 : sin(along * 6.0 - t * 10.0) * 0.07 * along;
		float tail_r = r * (water ? 0.85 : 0.95) * pow(1.0 - along, water ? 1.6 : 0.9);
		float dy = p.y - 0.5 - wobble;
		float head = length(p - c) - r;
		float tail = p.x < c.x ? abs(dy) - tail_r : 1.0;
		d = min(head, tail) + n * (water ? 0.03 : 0.12) * churn * (0.35 + along);
		float head_heat = 1.0 - length(p - c - (water ? vec2(0.08, -0.09) : vec2(0.03, 0.0))) / r;
		float tail_heat = p.x < c.x ? (1.0 - abs(dy) / max(tail_r, 0.001)) * (1.0 - along) * 0.85 : 0.0;
		heat = max(head_heat, tail_heat) + fbm(p * 4.0 + vec2(t * 3.0, -t)) * 0.18 * churn;
	} else if (shape == 1) {
		float h = (1.0 - uv.y) / max(grow, 0.001);
		float dx = p.x - aspect * 0.5;
		float n = fbm(vec2(p.x * 5.0, uv.y * 3.5 + t * 4.0));
		float width = aspect * 0.34 * (1.0 - 0.75 * smoothstep(0.45, 1.0, h));
		d = abs(dx) - width + n * 0.16 * churn * (0.25 + h);
		d = max(d, (h - 1.0) * 0.6 + n * 0.04 * churn);
		heat = (1.0 - abs(dx) / max(width, 0.001)) * (1.0 - 0.55 * h) + n * 0.25 * churn;
	} else if (shape == 2) {
		float lanes = max(1.0, floor(aspect * 2.4));
		float lane = uv.x * lanes;
		float k = floor(lane);
		float f = fract(lane) - 0.5;
		float tall = (0.6 + 0.4 * hash(vec2(k, 7.0))) * grow;
		float h = (1.0 - uv.y) / max(tall, 0.001);
		float sway = sin(t * 7.0 + k * 2.3) * 0.18 * h;
		float w = 0.62 * pow(max(0.0, 1.0 - h), 0.8) * (1.0 + 0.6 * h);
		float n = fbm(vec2(uv.x * 7.0, uv.y * 4.0 + t * 5.0));
		d = (abs(f - sway) - w) / lanes * aspect + n * 0.05 * churn * (1.0 - h);
		d = max(d, (h - 1.0) * 0.4);
		heat = (1.0 - abs(f - sway) / max(w, 0.001)) * (1.0 - 0.7 * h) + n * 0.2 * churn;
		// A glowing seam along the ground ties the tongues together.
		float seam = (1.0 - uv.y) - 0.12 * grow;
		if (seam < d) {
			d = seam;
			heat = max(heat, 0.45);
		}
	} else if (shape == 3) {
		float x = uv.x;
		float n = fbm(vec2(p.x * 3.0 - t * 3.0, uv.y * 3.0));
		// Height of the water surface above the bottom edge.
		float rise = smoothstep(0.0, 0.72, x) * (1.0 - smoothstep(0.86, 1.0, x));
		float crest = grow * (0.18 + 0.7 * rise) + sin(x * 10.0 - t * 8.0) * 0.025;
		float top = 1.0 - crest;
		d = top - uv.y + n * 0.05 * churn;
		// The curling lip: a disc hanging forward off the crest, hollowed underneath.
		vec2 lip = vec2(aspect * 0.8, top + 0.02);
		float lip_r = 0.15 * grow;
		d = min(d, length(p - lip) - lip_r);
		vec2 hollow_c = vec2(aspect * 0.88, top + lip_r * 1.6);
		d = max(d, lip_r * 0.9 - length(p - hollow_c));
		// Foam is white at the surface and the lip, deep blue underneath.
		float depth = clamp((uv.y - top) / max(0.05, crest), 0.0, 1.0);
		heat = 1.0 - depth * 1.3 + n * 0.2;
		heat = max(heat, 1.0 - length(p - lip) / max(lip_r, 0.001));
	}

	if (d > 0.0) {
		discard;
	}
	vec4 c;
	if (d > -ink_width) {
		c = ink;
	} else if (heat < 0.22) {
		c = dark;
	} else if (heat < 0.45) {
		c = mid;
	} else if (heat < 0.68) {
		c = light;
	} else {
		c = core;
	}
	c.a *= fade;
	COLOR = c;
}
