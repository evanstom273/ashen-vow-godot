shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float elapsed = 0.0;
uniform float distortion = 0.0;
uniform float chromatic = 0.0;
uniform float brightness = 0.0;
uniform float contrast = 0.0;
uniform vec4 wash : source_color = vec4(0.0);
void fragment() {
    vec2 uv = SCREEN_UV;
    // No spatial distortion or colour separation: sample the original pixel once.
    vec3 base = texture(screen_texture, uv).rgb;
    base = (base - vec3(0.5)) * (1.0 + contrast) + vec3(0.5 + brightness);
    COLOR = vec4(mix(base, wash.rgb, clamp(wash.a, 0.0, 0.08)), 1.0);
}
