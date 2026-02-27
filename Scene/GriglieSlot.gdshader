shader_type canvas_item;

uniform vec2 origin = vec2(0.5, 0.5);
uniform vec2 rect_size = vec2(0.1, 0.15);
uniform float expansion = 0.0;
uniform float intensity = 1.0;
uniform float irregularity = 0.0; // aumenta col tempo
uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.2, 1.0);


float hash(vec2 p) {
    return fract(sin(dot(p ,vec2(127.1,311.7))) * 43758.5453);
}

float noise(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f*f*(3.0-2.0*f);

    return mix(a, b, u.x) +
           (c - a)* u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

void fragment() {

    vec4 tex = texture(TEXTURE, UV);

    vec2 half_size = rect_size * 0.5 + expansion;

    vec2 local = UV - origin;

    // distanza dal centro
    float center_dist = length(local);

    // 👇 controlla quanto velocemente si dissolve
    float falloff = 1.0 - smoothstep(0.0, 0.4, center_dist);

    // noise che aumenta col tempo
    float n = noise(UV * 15.0) * irregularity;

    vec2 d = abs(local) - (half_size + n);

    float dist = max(d.x, d.y);

    float glow = 1.0 - smoothstep(0.0, 0.02 + irregularity * 0.03, dist);
    glow = clamp(glow, 0.0, 1.0);

    // 👇 applico il falloff
    glow *= falloff;

    vec3 final_color = tex.rgb + glow_color.rgb * glow * intensity;

    COLOR = vec4(final_color, tex.a);
}