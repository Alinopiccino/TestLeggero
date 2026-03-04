shader_type canvas_item;

uniform sampler2D mask_texture;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float mask = texture(mask_texture, UV).a;

    mask = 1.0 - mask;

    COLOR = vec4(color.rgb, color.a * mask);
}