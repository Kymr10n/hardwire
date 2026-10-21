// Glass overlay (DESIGN: Glass, D-041): the screen seen through a powered-on monitor. A radial
// vignette always; scanlines, a slight bloom of bright pixels and a slow brightness flicker while
// `glass` is 1 (the "CRT glass" setting). Main.gd fills the uniforms from the theme.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
// The overlay's size in content pixels, so the line pitch follows the UI scale on every screen.
uniform vec2 content_size = vec2(1080.0, 1920.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float scanline : hint_range(0.0, 1.0) = 0.08;
uniform float scanline_px : hint_range(1.0, 8.0) = 4.0;
uniform float bloom : hint_range(0.0, 1.0) = 0.25;
uniform float flicker : hint_range(0.0, 0.1) = 0.02;
uniform float flicker_hz : hint_range(0.0, 3.0) = 1.3;
uniform float glass : hint_range(0.0, 1.0) = 1.0;

// Where the vignette starts and saturates (squared distance from the centre, scaled to 0..1).
const float VIGNETTE_FROM = 0.2;
const float VIGNETTE_TO = 0.9;
// Only pixels brighter than this bleed into their neighbours; taps are this many pixels away.
const float BLOOM_THRESHOLD = 0.45;
const float BLOOM_REACH = 2.0;

void fragment() {
	vec3 screen = texture(screen_tex, SCREEN_UV).rgb;
	vec3 glow = vec3(0.0);
	if (bloom * glass > 0.0) {
		vec2 px = SCREEN_PIXEL_SIZE * BLOOM_REACH;
		vec3 around = texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb
			+ texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb
			+ texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb;
		glow = max(around * 0.25 - BLOOM_THRESHOLD, 0.0) * bloom * glass;
	}
	// A cosine trough per scanline_px content pixels: no shimmer at fractional device pitches.
	float band = 0.5 - 0.5 * cos(TAU * UV.y * content_size.y / scanline_px);
	float dark = band * scanline * glass;
	vec2 d = UV - 0.5;
	dark += smoothstep(VIGNETTE_FROM, VIGNETTE_TO, dot(d, d) * 2.0) * vignette;
	dark += (0.5 + 0.5 * sin(TIME * flicker_hz * TAU)) * flicker * glass;
	COLOR = vec4(screen * (1.0 - dark) + glow, 1.0);
}
