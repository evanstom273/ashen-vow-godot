shader_type canvas_item;
render_mode unshaded;
uniform float strength = 0.3;
uniform float elapsed = 0.0;
void fragment() {
    vec4 c = COLOR;
    c.rgb *= 0.85 + 0.15 * sin(elapsed * 1.8 + UV.y * 5.0);
    c.a *= strength;
    COLOR = c;
}
