shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.55, 0.62, 0.55);
uniform vec4 deep_color : source_color = vec4(0.015, 0.16, 0.27, 0.85);
uniform vec4 foam_color : source_color = vec4(0.85, 0.96, 0.96, 1.0);
uniform float wave_height : hint_range(0.0, 0.5) = 0.09;
uniform float wave_scale : hint_range(0.1, 10.0) = 2.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.8;
uniform float depth_distance : hint_range(0.1, 20.0) = 4.0;
uniform float foam_distance : hint_range(0.01, 2.0) = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.13;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 world_pos;

void vertex() {
    vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float t = TIME * wave_speed;
    VERTEX.y += (sin(wp.x * wave_scale + t) + cos(wp.z * wave_scale * 0.8 + t * 1.13)) * wave_height * 0.5;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float t = TIME * wave_speed;
    float a = world_pos.x * wave_scale + t;
    float b = world_pos.z * wave_scale * 0.8 + t * 1.13;
    vec3 n = normalize(vec3(-cos(a) * wave_height * wave_scale * 0.5, 1.0, sin(b) * wave_height * wave_scale * 0.4));
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

    float raw_depth = texture(depth_texture, SCREEN_UV).r;
    vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
    scene_view.xyz /= max(scene_view.w, 0.00001);
    float water_depth = -VERTEX.z;
    float delta = max(0.0, -scene_view.z - water_depth);
    float deep_factor = clamp(delta / depth_distance, 0.0, 1.0);
    float foam = (1.0 - smoothstep(0.0, foam_distance, delta)) * (0.65 + 0.35 * sin(a * 2.5 + b));
    vec4 water = mix(shallow_color, deep_color, deep_factor);
    ALBEDO = mix(water.rgb, foam_color.rgb, foam);
    ALPHA = clamp(water.a + foam * 0.25, 0.0, 1.0);
    ROUGHNESS = roughness_value;
    SPECULAR = 0.8;
    METALLIC = 0.0;
}
