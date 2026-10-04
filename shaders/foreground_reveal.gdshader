shader_type canvas_item;
render_mode blend_mix;
#include "res://shaders/foliage_motion.gdshaderinc"

// World-space distance remains circular through camera motion and zoom.
uniform vec2 reveal_center = vec2(0.0);
uniform float reveal_radius : hint_range(1.0, 200.0) = 58.0;
uniform float edge_softness : hint_range(0.1, 100.0) = 26.0;
uniform float minimum_opacity : hint_range(0.0, 1.0) = 0.08;
uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;
varying vec2 world_position;

void vertex() {
    VERTEX += foliage_offset(VERTEX, UV, MODEL_MATRIX);
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    float radius = max(reveal_radius, 0.1);
    float inner_radius = max(0.0, radius - edge_softness);
    float outside = smoothstep(inner_radius, radius, distance(world_position, reveal_center));
    float mask = mix(minimum_opacity, 1.0, outside);
    // Keep the object's existing texture, vertex colour, modulation and lighting.
    COLOR.a *= mix(1.0, mask, reveal_amount);
}
