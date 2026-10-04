shader_type canvas_item;
uniform float flash : hint_range(0.0,1.0) = 0.0;
uniform float dissolve : hint_range(0.0,1.0) = 0.0;
uniform vec4 ash_color : source_color = vec4(0.38,0.4,0.47,1.0);
varying vec2 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    vec4 c = COLOR;
    float grain = fract(sin(dot(floor(local_position / 2.5), vec2(127.1,311.7))) * 43758.5453);
    float threshold = mix(-0.12,1.12,dissolve);
    float coverage = smoothstep(threshold,threshold+0.09,grain);
    float edge = (1.0-smoothstep(threshold+0.09,threshold+0.22,grain))*coverage;
    c.rgb = mix(c.rgb,vec3(1.0,0.91,0.70),flash);
    c.rgb = mix(c.rgb,ash_color.rgb,edge*0.8);
    c.a *= coverage;
    COLOR = c;
}
