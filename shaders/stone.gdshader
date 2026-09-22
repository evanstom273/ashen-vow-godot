shader_type canvas_item;
uniform float wetness = 0.10;
void fragment() {
    vec4 c = COLOR;
    float sheen = pow(max(0.0, sin(UV.x * 7.0 + UV.y * 5.0)), 12.0);
    c.rgb += vec3(0.13, 0.18, 0.20) * sheen * wetness;
    COLOR = c;
}
