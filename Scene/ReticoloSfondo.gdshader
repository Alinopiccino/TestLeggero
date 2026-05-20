shader_type canvas_item;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.25;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.15;
uniform float speed : hint_range(0.0, 5.0) = 0.25;

uniform float glitch_strength : hint_range(0.0, 1.0) = 0.22;
uniform float glitch_line_strength : hint_range(0.0, 1.0) = 0.35;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.18;
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.18;

uniform vec3 main_color : source_color = vec3(0.0, 0.55, 0.45);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	float wave = sin((uv.y * 18.0) + t) * 0.003;
	uv.x += wave;

	float glitch_time = floor(TIME * 7.0);
	float glitch_trigger = step(0.72, hash(vec2(glitch_time, 9.13)));

	float row_id = floor(uv.y * 42.0);

	float glitch_band = step(0.82, hash(vec2(row_id, glitch_time)));
	float glitch_offset = (hash(vec2(row_id, glitch_time + 3.7)) - 0.5) * 0.09;

	uv.x += glitch_offset * glitch_band * glitch_trigger * glitch_strength;

	// Righe orizzontali glitch
	float glitch_line_id = floor(uv.y * 90.0);
	float glitch_line_random = hash(vec2(glitch_line_id, glitch_time + 12.4));
	float glitch_line_mask = step(0.93, glitch_line_random) * glitch_trigger;

	float glitch_line = smoothstep(0.0, 0.08, fract(uv.y * 90.0));
	glitch_line *= 1.0 - smoothstep(0.08, 0.18, fract(uv.y * 90.0));
	glitch_line *= glitch_line_mask * glitch_line_strength;

	// Piccola distorsione verticale sulle righe glitch
	uv.y += glitch_line * 0.01 * glitch_strength;

	float grid_x = smoothstep(0.985, 1.0, fract(uv.x * 18.0));
	float grid_y = smoothstep(0.985, 1.0, fract(uv.y * 10.0));
	float grid = max(grid_x, grid_y) * grid_strength;

	float scanlines = sin(uv.y * 500.0 + t * 3.0);
	scanlines = 0.5 + 0.5 * scanlines;
	scanlines *= scanline_strength;

	float dist = distance(uv, vec2(0.5));
	float pulse = 1.0 + sin(TIME * 1.35) * pulse_strength;
	float glow = smoothstep(0.75, 0.1, dist) * glow_strength * pulse;

	float ambient =
		sin(uv.x * 7.0 + TIME * 0.35) *
		sin(uv.y * 5.0 - TIME * 0.25);

	ambient = 0.5 + 0.5 * ambient;
	ambient = smoothstep(0.35, 1.0, ambient);
	ambient *= ambient_strength;

	float flicker = 0.97 + sin(TIME * 2.0) * 0.012;
	flicker += (hash(vec2(TIME * 18.0, 1.0)) - 0.5) * 0.01;

	vec3 color = main_color * (grid + scanlines + glow + ambient + glitch_line) * flicker;

	color *= 0.05;

	COLOR = vec4(color, 1.0);
}