shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.024, 0.106, 0.243, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.024, 0.365, 0.612, 1.0);
uniform vec4 glow_color : source_color = vec4(0.208, 0.678, 0.95, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.55;
uniform float beam_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
    vec2 uv = UV;
    vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

    vec2 p = uv - vec2(0.26, 0.74);
    float glow = exp(-dot(p, p) * 7.0);
    col += glow_color.rgb * glow * glow_strength;

    float beam = sin((uv.x * 1.15 + uv.y * 0.85) * 6.28318 + 0.7);
    col += vec3(0.06, 0.20, 0.32) * smoothstep(0.55, 1.0, beam) * beam_strength;

    float beam2 = sin((uv.x * 2.1 - uv.y * 1.4) * 6.28318 + 2.2);
    col += vec3(0.03, 0.12, 0.22) * smoothstep(0.75, 1.0, beam2) * beam_strength * 0.7;

    vec2 c = uv - vec2(0.5);
    col *= 1.0 - dot(c, c) * 0.55;
    COLOR = vec4(col, 1.0);
}
