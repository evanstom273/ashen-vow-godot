shader_type canvas_item;
render_mode unshaded;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
void fragment() { COLOR.a *= fade; }
