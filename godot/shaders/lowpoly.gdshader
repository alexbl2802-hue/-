// Общий материал для деревьев, камней, построек и персонажей: плоские грани,
// цвет материала умножается на цвет экземпляра (MultiMesh) или вершины.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.9;
uniform float metallic = 0.0;

void fragment() {
	ALBEDO = albedo.rgb * pow(COLOR.rgb, vec3(2.2));
	// Нормаль грани из производных; разворачиваем к камере — так не зависит от ориентации экрана
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n, VIEW) < 0.0 ? -n : n;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission.rgb * emission_energy;
}
