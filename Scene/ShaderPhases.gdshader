shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1,1.0,0.5,1.0);
uniform float outline_size = 2.5;
uniform float glow_strength = 1.2;
uniform float speed = 2.0;

void fragment() {

	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a;

	// ------------------------
	// OUTLINE DETECTION
	// ------------------------
	float outline = 0.0;

	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;

	outline += texture(TEXTURE, UV + vec2(px.x,0)).a;
	outline += texture(TEXTURE, UV - vec2(px.x,0)).a;
	outline += texture(TEXTURE, UV + vec2(0,px.y)).a;
	outline += texture(TEXTURE, UV - vec2(0,px.y)).a;

	outline += texture(TEXTURE, UV + px).a;
	outline += texture(TEXTURE, UV - px).a;
	outline += texture(TEXTURE, UV + vec2(px.x,-px.y)).a;
	outline += texture(TEXTURE, UV + vec2(-px.x,px.y)).a;

	outline = clamp(outline,0.0,1.0);

	// solo fuori dalla sprite
	outline *= (1.0 - alpha);

	// ------------------------
	// LIGHT MOVEMENT
	// ------------------------
	float t = TIME * speed;

	float wave = sin((UV.x + UV.y) * 2.0 + t * 3.0);
	wave = smoothstep(0.0,1.0,wave * 0.5 + 0.5);

	// glow finale
	vec3 glow = glow_color.rgb * wave * glow_strength * outline;

	vec3 final_color = tex.rgb + glow;

	float final_alpha = max(alpha, outline * glow_color.a);

	COLOR = vec4(final_color, final_alpha);
}