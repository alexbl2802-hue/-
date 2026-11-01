shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

uniform vec4 water_color : source_color = vec4(0.04, 0.39, 0.53, 0.78);
uniform vec4 highlight_color : source_color = vec4(0.28, 0.77, 0.84, 1.0);
uniform float wave_speed : hint_range(0.0, 4.0) = 0.6;
uniform float wave_scale : hint_range(0.1, 12.0) = 3.0;
uniform float wave_height : hint_range(0.0, 0.3) = 0.035;

varying vec2 water_uv;
void vertex() {
    vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(wp.x * wave_scale + TIME * wave_speed) * wave_height;
    water_uv = wp.xz;
}
void fragment() {
    float ripple = sin(water_uv.x * wave_scale * 2.0 + TIME * wave_speed * 1.7)
                 * cos(water_uv.y * wave_scale * 1.4 - TIME * wave_speed);
    float streaks = smoothstep(0.72, 0.96, ripple);
    ALBEDO = mix(water_color.rgb, highlight_color.rgb, streaks * 0.35);
    ALPHA = water_color.a;
}
