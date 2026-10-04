shader_type canvas_item;
render_mode unshaded;
uniform float strength : hint_range(0.0, 0.2) = 0.12;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float edge = smoothstep(0.6, 1.42, length(p));
    COLOR = vec4(vec3(0.015, 0.025, 0.045), edge * strength);
}
