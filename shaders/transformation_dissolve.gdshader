shader_type canvas_item;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ash_color : source_color = vec4(0.38, 0.4, 0.47, 1.0);
varying vec2 fragment_position;
void vertex() {
    fragment_position = VERTEX;
}
void fragment() {
    vec2 cell = floor(fragment_position / 2.5);
    float grain = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
    float threshold = mix(-0.12, 1.12, dissolve);
    float coverage = smoothstep(threshold, threshold + 0.09, grain);
    float edge = (1.0 - smoothstep(threshold + 0.09, threshold + 0.22, grain)) * coverage;
    COLOR.rgb = mix(COLOR.rgb, ash_color.rgb, edge * 0.8);
    COLOR.a *= coverage;
}
