shader_type canvas_item;

uniform float speed = 0.2;
uniform float vertical_speed = 0.1;

uniform float thickness = 0.001;   // ora puoi scendere molto
uniform float perspective = 2.0;

uniform float density_x = 8.0;
uniform float density_y = 40.0;

uniform float time_scale = 0.1;

void fragment() {
    vec2 uv = UV;
    uv.x = uv.x * 2.0 - 1.0;

    float depth = 1.0 - uv.y;

    float perspective_scale = 1.0 / (depth * perspective + 0.4);

    float t = TIME * time_scale;

    vec2 grid;
    grid.x = uv.x * perspective_scale * density_x + t * vertical_speed;
    grid.y = (uv.y * perspective_scale - t * speed) * density_y;

    float fx = abs(fract(grid.x) - 0.5);
    float fy = abs(fract(grid.y) - 0.5);

    // 👇 Anti-aliasing GPU corretto
    float aaX = fwidth(grid.x);
    float aaY = fwidth(grid.y);

    float lineX = 1.0 - smoothstep(thickness - aaX, thickness + aaX, fx);
    float lineY = 1.0 - smoothstep(thickness - aaY, thickness + aaY, fy);

    float line = max(lineX, lineY);

    vec3 soft_green = vec3(0.08, 0.55, 0.28);
    float fade = depth;

    COLOR = vec4(soft_green, line * fade);
}