shader_type canvas_item;

uniform float tilt_dir = 0.0;
uniform float border_size = 0.08;
uniform vec4 border_color : source_color = vec4(0.0,0.0,0.0,0.8);

void fragment() {

    float edge = 0.0;

    if (tilt_dir > 0.0) {
        edge = smoothstep(0.0, border_size, UV.x);
    }
    else if (tilt_dir < 0.0) {
        edge = smoothstep(0.0, border_size, 1.0 - UV.x);
    }

    COLOR = vec4(border_color.rgb, edge * border_color.a);
}