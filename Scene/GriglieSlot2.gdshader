shader_type canvas_item;

uniform vec2 origin;
uniform float base_size_uv = 0.2;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform float sweep_width = 0.25;   // Larghezza finestra mobile (0.15 - 0.4 consigliato)
uniform float edge_softness = 0.01;
uniform float intensity = 1.0;
uniform vec4 glow_color : source_color = vec4(0.1, 1.0, 0.3, 1.0);

void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    vec2 local = UV - origin;
    float half_size = base_size_uv * 0.5;

    // ----------------------------
    // MASCHERA RETTANGOLO
    // ----------------------------
    float rect_dist = max(abs(local.x), abs(local.y)) - half_size;
    float rect_mask = 1.0 - smoothstep(0.0, edge_softness, rect_dist);
    rect_mask = clamp(rect_mask, 0.0, 1.0);

    // ----------------------------
    // CALCOLO ANGOLO
    // ----------------------------
    // 0 rad è in basso
    float angle = atan(local.x, local.y);
    float abs_angle = abs(angle);

    // Centro della finestra mobile
    float center_angle = progress * PI;

    // Larghezza finestra
    float half_width = sweep_width * PI;

    // Finestra angolare mobile (si apre e si richiude dietro)
    float angle_mask =
        smoothstep(center_angle - half_width, center_angle, abs_angle) *
        (1.0 - smoothstep(center_angle, center_angle + half_width, abs_angle));

    float final_mask = rect_mask * angle_mask;

    vec3 final_color = tex.rgb + glow_color.rgb * final_mask * intensity;

    COLOR = vec4(final_color, tex.a);
}