shader_type canvas_item;
render_mode blend_mix;
#include "res://shaders/foliage_motion.gdshaderinc"

void vertex() {
    VERTEX += foliage_offset(VERTEX, UV, MODEL_MATRIX);
}
