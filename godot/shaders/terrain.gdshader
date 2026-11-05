// Рельеф: цвет местности из вершин (луга, песок, камень), поверх — настоящие текстуры:
// газон из травинок (textures/grass_*), утоптанная земля с камешками (textures/dirt_*),
// камень со мхом на склонах гор. Текстуры берутся в двух масштабах — повторы не видны.
// Нормали гладкие (из сетки) + карты нормалей травы и земли — рельеф выглядит объёмным.
shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform sampler2D detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_tile = 3.2;    // метров на один повтор газона
uniform float dirt_tile = 4.0;
uniform float grass_lum = 0.312;   // средняя яркость текстур (см. tools/make_ground_textures.py)
uniform float dirt_lum = 0.081;
// Камень со мхом с модели горы (Mossy Stone Peak) — на склонах гор, наложение с трёх сторон
uniform sampler2D mountain : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float mountain_tile = 14.0;   // метров на один повтор текстуры
uniform sampler2D mountain_nrm : hint_normal, filter_linear_mipmap, repeat_enable;   // рельеф камня
uniform float mountain_bump = 1.0;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Текстура в двух масштабах, второй повёрнут — швы и повторы не складываются в узор
vec3 two_scale(sampler2D t, vec2 p, float tile, float far) {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	vec3 a = texture(t, p / tile).rgb;
	vec3 b = texture(t, q / (tile * 4.7) + 0.37).rgb;
	return mix(mix(a, b, 0.35), b, far);
}

vec3 two_scale_n(sampler2D t, vec2 p, float tile, float far) {
	vec2 q = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p;
	vec3 a = texture(t, p / tile).rgb * 2.0 - 1.0;
	vec3 b = texture(t, q / (tile * 4.7) + 0.37).rgb * 2.0 - 1.0;
	b.xy = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * b.xy;
	vec3 n = mix(mix(a, b, 0.35), b, far);
	return normalize(n);
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 wn = normalize(world_n);
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float dist = length(VERTEX);
	float far = smoothstep(25.0, 90.0, dist);
	float m = texture(macro, world_pos.xz * 0.018).r;
	float m2 = texture(macro, world_pos.xz * 0.061 + 0.5).r;
	// Что за земля: зелёная — луг, серая/бурая — земля, светлая жёлтая — песок у воды
	float green = COLOR.g - max(COLOR.r, COLOR.b);
	float grassw = smoothstep(0.03, 0.14, green);
	// Проплешины утоптанной земли среди травы
	float patch = smoothstep(0.7, 0.84, m2) * 0.7 * grassw;
	grassw -= patch;
	float sand = smoothstep(0.62, 0.78, COLOR.r) * (1.0 - grassw);
	vec3 gt = two_scale(grass_tex, world_pos.xz, grass_tile, far);
	vec3 dt = two_scale(dirt_tex, world_pos.xz, dirt_tile, far);
	// Цвет местности сохраняем, текстура даёт рисунок и чуть-чуть своего оттенка
	float gl = lum(gt) / grass_lum;
	vec3 gcol = mix(base * gl, gt * (lum(base) / grass_lum), 0.65);   // рисованная трава — больше своего цвета
	gcol = mix(vec3(lum(gcol)), gcol, 0.95);
	// Земля: на серых/бурых местах — оттенок местности с рисунком земли, на песке — светлый песок,
	// в проплешинах среди травы — сама текстура земли
	float dl = lum(dt) / dirt_lum;
	vec3 dbase = mix(base, vec3(0.16, 0.11, 0.06), 0.3 * (1.0 - sand));
	vec3 dcol = mix(dbase * dl, dt * (lum(dbase) / dirt_lum), 0.35 * (1.0 - sand));
	dcol = mix(dcol, dt * 1.05, patch / max(1.0 - grassw, 0.001));
	vec3 col = mix(dcol, gcol, grassw);
	col *= mix(0.86, 1.12, m);
	// Карта нормалей травы/земли → нормаль в мире (касательные — оси X и Z мира)
	vec3 tn = normalize(mix(two_scale_n(dirt_nrm, world_pos.xz, dirt_tile, far),
		two_scale_n(grass_nrm, world_pos.xz, grass_tile, far), grassw));
	tn.xy *= mix(1.0, 0.25, far);
	vec3 t = normalize(vec3(1.0, 0.0, 0.0) - wn * wn.x);
	vec3 b = normalize(cross(t, wn));
	vec3 pn = normalize(t * tn.x + b * tn.y + wn * tn.z);
	// Скалы на крутых склонах — трещины камня
	float rocky = smoothstep(0.22, 0.45, slope);
	if (rocky > 0.001) {
		float cr = mix(texture(rock, world_pos.xy * 0.22).r, texture(rock, world_pos.zy * 0.22).r, abs(wn.x));
		cr = mix(cr, 0.5, far * 0.7);
		col = mix(col, base * mix(0.68, 1.22, cr) * mix(0.86, 1.12, m), rocky);
	}
	// Горы как у модели: выше ~18 м и на крутых склонах — камень со мхом, вершины без снега
	float mw = max(smoothstep(16.0, 30.0, world_pos.y), rocky * smoothstep(6.0, 16.0, world_pos.y));
	if (mw > 0.001) {
		vec3 bw = pow(abs(wn), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 tx = texture(mountain, world_pos.zy / mountain_tile).rgb;
		vec3 ty = texture(mountain, world_pos.xz / mountain_tile).rgb;
		vec3 tz = texture(mountain, world_pos.xy / mountain_tile).rgb;
		vec3 stone = tx * bw.x + ty * bw.y + tz * bw.z;
		// крупный узор того же камня — чтобы вдали склоны не были однотонными
		vec3 big = texture(mountain, world_pos.xz / (mountain_tile * 9.0)).rgb;
		stone = stone * mix(0.8, 1.25, dot(big, vec3(0.333)) * 2.0 - 0.1);
		col = mix(col, stone * 0.72, mw);
		// Рельеф камня: карта нормалей с трёх сторон (трещины и выступы видны при свете)
		vec2 nx = (texture(mountain_nrm, world_pos.zy / mountain_tile).rg * 2.0 - 1.0) * sign(wn.x);
		vec2 ny = (texture(mountain_nrm, world_pos.xz / mountain_tile).rg * 2.0 - 1.0) * sign(wn.y);
		vec2 nz = (texture(mountain_nrm, world_pos.xy / mountain_tile).rg * 2.0 - 1.0) * sign(wn.z);
		vec3 rn = normalize(wn + (vec3(0.0, nx.y, nx.x) * bw.x + vec3(ny.x, 0.0, ny.y) * bw.y + vec3(nz.x, nz.y, 0.0) * bw.z) * mountain_bump * (1.0 - far * 0.6));
		pn = normalize(mix(pn, rn, mw));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.85, grassw);
	SPECULAR = 0.25;
}
