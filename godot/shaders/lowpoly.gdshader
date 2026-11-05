// Общий материал для деревьев, камней, построек и персонажей: плоские грани,
// цвет материала умножается на цвет экземпляра (MultiMesh) или вершины.
// detail > 0 — лёгкая фактура (кора, листва, камень) по мировым координатам.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.9;
uniform float metallic = 0.0;
uniform float detail = 0.0;
uniform float detail_scale = 0.8;
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float bump = 1.0;     // рельеф фактуры (detail > 0): кора, камень, доски выглядят объёмными
uniform float wind = 0.0;     // > 0 — качается на ветру (кроны деревьев)

varying vec3 world_pos;

void vertex() {
	if (wind > 0.0) {
		vec3 o = MODEL_MATRIX[3].xyz;
		float w = sin(TIME * 1.3 + o.x * 0.11 + o.z * 0.07) + 0.4 * sin(TIME * 2.9 + o.z * 0.5);
		VERTEX.xz += vec2(0.8, 0.6) * w * wind * (VERTEX.y + 1.0);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Нормаль грани из производных; разворачиваем к камере — так не зависит от ориентации экрана
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	n = dot(n, VIEW) < 0.0 ? -n : n;
	NORMAL = n;
	vec3 col = albedo.rgb * pow(COLOR.rgb, vec3(2.2));
	if (detail > 0.0) {
		vec3 wn = abs(normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz));
		vec3 p = world_pos * detail_scale;
		float t = texture(detail_tex, p.zy).r * wn.x + texture(detail_tex, p.xz).r * wn.y + texture(detail_tex, p.xy).r * wn.z;
		t /= (wn.x + wn.y + wn.z);
		col *= mix(1.0 - detail, 1.0 + detail, t);
		// Рельеф из фактуры: наклон нормали по изменению узора на экране (bump mapping по производным)
		if (bump > 0.0) {
			vec3 dpdx = dFdx(VERTEX);
			vec3 dpdy = dFdy(VERTEX);
			float h = t * detail * bump * 0.06;
			float dhdx = dFdx(h);
			float dhdy = dFdy(h);
			vec3 r1 = cross(dpdy, n);
			vec3 r2 = cross(n, dpdx);
			float det = dot(dpdx, r1);
			vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
			NORMAL = normalize(abs(det) * n - grad);
		}
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission.rgb * emission_energy;
}
