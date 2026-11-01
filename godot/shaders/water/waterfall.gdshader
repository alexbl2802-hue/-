shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, double_sided;

uniform vec4 water_color : source_color = vec4(0.13, 0.58, 0.75, 0.72);
uniform vec4 foam_color : source_color = vec4(0.85, 0.96, 1.0, 0.95);
uniform float flow_speed : hint_range(0.0, 10.0) = 2.0;
uniform float streak_density : hint_range(1.0, 50.0) = 16.0;
uniform float foam_strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
    vec2 uv = UV;
    float flow = uv.y * 12.0 - TIME * flow_speed;
    float streak = sin(uv.x * streak_density + sin(flow * 0.65) * 0.9);
    float detail = sin(flow * 2.7 + uv.x * streak_density * 0.4);
    float foam = smoothstep(0.4, 0.95, streak * 0.65 + detail * 0.35) * foam_strength;
    ALBEDO = mix(water_color.rgb, foam_color.rgb, foam);
    ALPHA = clamp(water_color.a + foam * 0.2, 0.0, 1.0);
}
