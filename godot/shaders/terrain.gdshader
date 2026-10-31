// Рельеф: цвета из вершин и «гранёное» освещение, как в низкополигональном стиле
shader_type spatial;
render_mode cull_back;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	// Нормаль грани из производных; разворачиваем к камере — так не зависит от ориентации экрана
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n, VIEW) < 0.0 ? -n : n;
	ROUGHNESS = 0.95;
}
