// Wear overlay (DESIGN: Texture & wear): static plastic grain, uneven yellowing towards the
// corners and a few shallow scuffs, drawn over every screen. Keep it subtle: if the wear is the
// first thing you notice, halve the amplitudes.
shader_type canvas_item;

uniform float grain : hint_range(0.0, 0.2) = 0.035;
uniform float yellowing : hint_range(0.0, 0.5) = 0.12;
uniform vec3 yellow_tint : source_color = vec3(0.35, 0.25, 0.05);
uniform float scuff : hint_range(0.0, 0.5) = 0.07;
uniform int scuff_count : hint_range(0, 12) = 5;
uniform float scuff_width = 0.0012;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Alpha-composite `src` over `dst`.
vec4 over(vec4 dst, vec4 src) {
	return vec4(mix(dst.rgb, src.rgb, src.a), dst.a + src.a * (1.0 - dst.a));
}

void fragment() {
	vec4 c = vec4(0.0);
	// Grain: a static light or dark speck per pixel.
	float n = hash(floor(FRAGCOORD.xy));
	c = over(c, vec4(vec3(step(0.5, n)), grain));
	// Yellowing: the corners darken towards a warm tint.
	vec2 d = UV - 0.5;
	float v = smoothstep(0.15, 0.7, dot(d, d) * 2.0);
	c = over(c, vec4(yellow_tint, v * yellowing));
	// Scuffs: short light streaks at shallow angles from hashed seeds.
	for (int i = 0; i < scuff_count; i++) {
		float f = float(i) + 1.0;
		vec2 a = vec2(hash(vec2(f, 1.0)), hash(vec2(f, 2.0)));
		float ang = (hash(vec2(f, 3.0)) - 0.5) * 0.6;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 r = UV - a;
		float along = dot(r, dir);
		float across = abs(dot(r, vec2(-dir.y, dir.x)));
		float len = 0.08 + 0.2 * hash(vec2(f, 4.0));
		float s = (1.0 - smoothstep(0.0, scuff_width, across)) * step(0.0, along) * step(along, len);
		c = over(c, vec4(1.0, 1.0, 1.0, s * scuff));
	}
	COLOR = c;
}
