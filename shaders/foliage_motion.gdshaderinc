// Explicit gameplay time, never TIME (which keeps advancing while paused).
global uniform float environment_time;
global uniform vec2 environment_wind;
uniform float wind_amplitude = 0.0;
uniform float wind_frequency = 1.0;
uniform float wind_flutter = 0.15;
uniform float wind_height = 1.0;
uniform float wind_phase = 0.0;
uniform bool wind_vertex_weights = false;

vec2 foliage_offset(vec2 vertex, vec2 uv, mat4 model) {
    vec2 world = (model * vec4(vertex, 0.0, 1.0)).xy;
    float flexibility = wind_vertex_weights ? uv.x : clamp(-vertex.y / wind_height, 0.0, 1.0);
    float phase = wind_vertex_weights ? uv.y : wind_phase + dot(model[3].xy, vec2(0.0011, 0.0007));
    float time = environment_time * wind_frequency * (0.9 + 0.1 * sin(phase * 1.37));
    float gust = 0.62 + 0.38 * sin(environment_time * 0.31 + dot(world, vec2(0.00013, 0.00009)));
    float sway = sin(time + phase) + sin(time * 2.71 + phase * 1.37) * wind_flutter;
    vec2 movement = environment_wind * (wind_amplitude * flexibility * flexibility * sway * gust * (0.88 + 0.12 * cos(phase)));
    // Convert the world displacement through the complete 2D basis (including rotation).
    float determinant = model[0].x * model[1].y - model[1].x * model[0].y;
    if (abs(determinant) < 0.00001) { return vec2(0.0); }
    return vec2(model[1].y * movement.x - model[1].x * movement.y,
                model[0].x * movement.y - model[0].y * movement.x) / determinant;
}
