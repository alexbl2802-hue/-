// Рельеф: цвета из вершин, «гранёное» освещение и детализация:
// мелкая зернистость травы и почвы, крупные пятна, трещины камня на склонах.
shader_type spatial;
render_mode cull_back;

uniform sampler2D detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	// Нормаль грани из производных; разворачиваем к камере — так не зависит от ориентации экрана
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	n = dot(n, VIEW) < 0.0 ? -n : n;
	NORMAL = n;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float m = texture(macro, world_pos.xz * 0.018).r;
	float g = texture(detail, world_pos.xz * 0.3).r * 0.6 + texture(detail, world_pos.xz * 1.4).r * 0.4;
	float cr = mix(texture(rock, world_pos.xy * 0.22).r, texture(rock, world_pos.zy * 0.22).r, abs(wn.x));
	float rocky = smoothstep(0.22, 0.45, slope);
	float fine = mix(mix(0.8, 1.2, g), mix(0.68, 1.22, cr), rocky);
	// Вдали мелкие детали гаснут, чтобы не рябило
	fine = mix(fine, 1.0, smoothstep(50.0, 150.0, length(VERTEX)));
	ALBEDO = base * fine * mix(0.86, 1.12, m);
	ROUGHNESS = 0.95;
}
