shader_type canvas_item;
render_mode unshaded;
uniform float danger = 0.0;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float edge = smoothstep(0.35, 1.45, length(p));
    COLOR = vec4(mix(vec3(0.015, 0.025, 0.045), vec3(0.32, 0.015, 0.025), danger), edge * (0.28 + danger * 0.15));
}
