// Трава: пучок тонких травинок, качается на ветру. Чем выше точка травинки — тем сильнее;
// фаза зависит от места пучка, поэтому по лугу бегут волны ветра.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.6;
uniform vec2 wind_dir = vec2(0.8, 0.6);

varying float tip;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	tip = clamp(VERTEX.y / 0.8, 0.0, 1.0);
	float w = sin(TIME * wind_speed + dot(wp.xz, wind_dir) * 0.15) * 0.7
		+ sin(TIME * wind_speed * 2.3 + wp.x * 0.9 + wp.z * 0.7) * 0.3;
	float bend = (w * 0.6 + 0.4) * wind_strength * tip * tip;
	// Ветер в мировых координатах переводим в систему пучка
	vec3 off = (inverse(mat3(MODEL_MATRIX)) * vec3(wind_dir.x, 0.0, wind_dir.y)) * bend;
	VERTEX += off;
	VERTEX.y -= bend * bend * 0.5;
}

void fragment() {
	vec3 col = albedo.rgb * pow(COLOR.rgb, vec3(2.2));
	// У земли травинки темнее, кончики светлее
	ALBEDO = col * mix(0.55, 1.15, tip);
	ROUGHNESS = 0.85;
	// Освещаем травинку как обращённую вверх — без тёмной обратной стороны
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
