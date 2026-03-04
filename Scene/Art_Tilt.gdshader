shader_type canvas_item;

uniform float tilt_x : hint_range(-1.0,1.0);
uniform float tilt_y : hint_range(-1.0,1.0);
uniform float perspective = 0.4;

void fragment() {

    vec2 uv = UV;
    vec2 center = vec2(0.5);

    vec2 offset = uv - center;

    offset.x += tilt_x * (offset.y * perspective);
    offset.y += tilt_y * (offset.x * perspective);

    uv = center + offset;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        discard;
    }

    COLOR = texture(TEXTURE, uv);
}