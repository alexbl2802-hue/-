// Небо: плавный переход цветов, солнечный диск с ореолом, звёзды ночью и облака,
// которые медленно плывут. Цвета и яркость задаёт смена дня и ночи (day_night.gd).
shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.24, 0.5, 0.82);
uniform vec3 sky_horizon_color : source_color = vec3(0.81, 0.89, 0.93);
uniform vec3 ground_horizon_color : source_color = vec3(0.81, 0.89, 0.93);
uniform vec3 ground_bottom_color : source_color = vec3(0.42, 0.35, 0.23);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float daylight = 1.0;            // 1 — день, 0 — ночь
uniform float cloud_cover = 0.5;
uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float up = d.y;
	vec3 col;
	if (up >= 0.0) {
		col = mix(sky_horizon_color, sky_top_color, pow(clamp(up, 0.0, 1.0), 0.55));
	} else {
		col = mix(ground_horizon_color, ground_bottom_color, clamp(-up * 3.0, 0.0, 1.0));
	}
	if (!AT_CUBEMAP_PASS) {
		// Звёзды ночью
		if (up > 0.0 && daylight < 0.6) {
			vec2 g = floor(d.xz / (up + 0.3) * 160.0);
			float st = step(0.998, hash(g));
			col += vec3(st) * (1.0 - daylight / 0.6) * smoothstep(0.12, 0.4, up) * 0.9;
		}
	}
	// Солнце: диск и мягкий ореол
	if (LIGHT0_ENABLED) {
		float sa = dot(d, normalize(LIGHT0_DIRECTION));
		col += sun_color * pow(max(sa, 0.0), 300.0) * 6.0 * daylight;
		col += sun_color * pow(max(sa, 0.0), 8.0) * 0.25 * daylight;
	}
	// Облака на куполе: проекция на высокую плоскость, два слоя плывут с разной скоростью
	if (up > 0.0) {
		vec2 uv = d.xz / (up + 0.12) * 0.22;
		float n1 = texture(clouds, uv + vec2(TIME * 0.004, TIME * 0.0015)).r;
		float n2 = texture(clouds, uv * 2.3 - vec2(TIME * 0.006, 0.0)).r;
		float n = n1 * 0.7 + n2 * 0.3;
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, n);
		c *= smoothstep(0.0, 0.18, up);   // у горизонта облака тают в дымке
		vec3 cloud_lit = mix(vec3(0.16, 0.18, 0.26), vec3(1.0), daylight);
		cloud_lit = mix(cloud_lit, cloud_lit * sun_color, 0.35);
		// Низ облака темнее — объём
		vec3 cloud_col = mix(cloud_lit * 0.72, cloud_lit, smoothstep(0.0, 0.5, n - (1.0 - cloud_cover)));
		col = mix(col, cloud_col, c * 0.92);
	}
	// Лёгкий шум против полос в плавных переходах неба
	if (!AT_CUBEMAP_PASS) {
		col += (hash(SCREEN_UV * 1733.0) - 0.5) * 0.012;
	}
	COLOR = col;
}
