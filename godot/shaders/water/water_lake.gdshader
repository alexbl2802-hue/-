// Вода озёр и рек: освещённая (блики солнца, вечером темнеет), рябь из двух карт нормалей,
// бегущих навстречу; у берега — светлее и прозрачнее, полосы пены набегают на песок.
// Глубина берётся из карты высот рельефа (буфер глубины в GL Compatibility недоступен).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

uniform vec3 deep_color : source_color = vec3(0.02, 0.12, 0.2);
uniform vec3 shallow_color : source_color = vec3(0.14, 0.34, 0.32);
uniform vec3 sky_color : source_color = vec3(0.36, 0.52, 0.64);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec4 height_rect = vec4(-450.0, -450.0, 900.0, 900.0);   // x, z угла и размеры карты высот
uniform bool use_height = false;
uniform float water_y = 0.0;
uniform float ripple = 0.55;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 0.35 + TIME * 0.9) * 0.03 + sin(wp.z * 0.5 - TIME * 1.1) * 0.025;
}

void fragment() {
	vec2 p = wp.xz;
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	vec3 a = texture(normal_tex, p * 0.07 + TIME * vec2(0.013, 0.008)).rgb * 2.0 - 1.0;
	vec3 b = texture(normal_tex, q * 0.13 - TIME * vec2(0.010, -0.015)).rgb * 2.0 - 1.0;
	vec3 c = texture(normal_tex, p * 0.018 + TIME * vec2(-0.004, 0.006)).rgb * 2.0 - 1.0;
	vec2 d = (a.xy + b.xy) * 0.5 + c.xy * 0.6;
	float dist = length(VERTEX);
	d *= ripple * mix(1.0, 0.35, smoothstep(30.0, 160.0, dist));
	vec3 wn = normalize(vec3(d.x, 1.0, d.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	float depth = 3.0;
	if (use_height) {
		depth = water_y - texture(height_tex, (p - height_rect.xy) / height_rect.zw).r;
	}
	float shallow = 1.0 - smoothstep(0.0, 0.9, depth);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(deep_color, shallow_color, shallow * 0.85);
	col = mix(col, sky_color, clamp(fres * 0.6, 0.0, 0.5));
	// Пена у кромки: полосы набегают к берегу и рвутся по узору ряби
	float edge = 1.0 - smoothstep(0.0, 0.45, depth);
	float bands = smoothstep(0.55, 0.95, sin(depth * 18.0 + TIME * 1.6) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, 1.1, depth));
	float brk = smoothstep(-0.15, 0.25, a.x + b.y);
	float foam = clamp(edge * 0.85 + bands * 0.6, 0.0, 1.0) * brk * step(0.0, depth);
	col = mix(col, vec3(0.92, 0.96, 0.98), foam);
	ALBEDO = col;
	ROUGHNESS = mix(0.14, 0.6, foam);
	SPECULAR = 0.2;
	ALPHA = clamp(mix(0.93, 0.5, shallow) + foam * 0.5, 0.0, 1.0);
}
