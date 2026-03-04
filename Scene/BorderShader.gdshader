shader_type canvas_item;

uniform float speed = 5;
uniform float intensity = 0.8;
uniform float scale = 4.0;
uniform float time_offset = 0.0;   // 👈 nuovo
uniform vec4 shine_color : source_color = vec4(1.0,1.0,1.0,1.0);

void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    float t = TIME * speed + time_offset;  // 👈 offset random

    float wave1 = sin(UV.x * scale + t);
    float wave2 = cos(UV.y * scale * 0.8 - t * 0.7);
    float wave3 = sin((UV.x + UV.y) * scale * 0.5 + t * 0.5);

    float shine = (wave1 + wave2 + wave3) * 0.33;

    shine = smoothstep(0.3, 0.8, shine);

    vec3 glow = shine_color.rgb * shine * intensity;

    COLOR.rgb = tex.rgb + glow;
    COLOR.a = tex.a;
}