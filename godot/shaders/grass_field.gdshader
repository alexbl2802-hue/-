// Густая трава вокруг героя: сетка пучков всегда вокруг камеры (шаг сетки привязан к миру, поэтому
// трава не «плывёт»), высота земли и где растёт трава — из карт мира. Каждый пучок повёрнут и сдвинут
// по-своему, травинки разной высоты и оттенка, у земли тёмные, к кончику светлее, качаются на ветру.
// Вдали трава плавно уменьшается до нуля — дальше видна текстура луга.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx;

uniform sampler2D height_tex : filter_linear, repeat_disable;   // высоты рельефа (R, метры)
uniform sampler2D mask_tex : filter_linear, repeat_disable;     // где растёт трава (R: 0..1)
uniform vec4 height_rect;                                      // x0, z0, ширина, глубина мира
uniform float spacing = 0.45;
uniform float radius = 17.0;
uniform float wind_strength = 0.22;
uniform float wind_speed = 1.4;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform vec3 base_col : source_color = vec3(0.24, 0.42, 0.11);
uniform vec3 tip_col : source_color = vec3(0.42, 0.62, 0.22);
uniform vec3 dry_col : source_color = vec3(0.62, 0.60, 0.30);

varying float tip;
varying float shade;
varying vec3 col_var;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 cell_off = MODEL_MATRIX[3].xyz;            // смещение пучка в сетке вокруг камеры
	vec3 local = VERTEX - cell_off;                 // точка травинки относительно пучка
	vec2 cam = floor(CAMERA_POSITION_WORLD.xz / spacing) * spacing;
	vec2 cell = cam + cell_off.xz;
	float h1 = hash(cell);
	float h2 = hash(cell + 17.3);
	vec2 pos = cell + (vec2(h1, h2) - 0.5) * spacing * 0.9;
	vec2 uv = (pos - height_rect.xy) / height_rect.zw;
	float ground = texture(height_tex, uv).r;
	float m = texture(mask_tex, uv).r;
	float dist = length(pos - CAMERA_POSITION_WORLD.xz);
	float grow = smoothstep(radius, radius * 0.65, dist) * smoothstep(0.35, 0.7, m);
	float hs = (0.4 + h2 * 0.3) * grow;   // травинки 0,15–0,5 м: по щиколотку, монстров и ноги не прячут
	float ang = h1 * 6.2832;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	local.xz = rot * local.xz;
	local *= vec3(1.0, hs, 1.0) * mix(0.0, 1.0, step(0.001, grow));
	tip = clamp(local.y / 0.42, 0.0, 1.0);
	// Ветер: волны по лугу и мелкая дрожь
	float w = sin(TIME * wind_speed + dot(pos, wind_dir) * 0.18) * 0.7 + sin(TIME * wind_speed * 2.7 + pos.x * 1.3 + pos.y * 0.9) * 0.3;
	float bend = (w * 0.6 + 0.45) * wind_strength * tip * tip;
	local.xz += wind_dir * bend;
	local.y -= bend * bend * 0.4;
	VERTEX = vec3(pos.x, ground - 0.02, pos.y) + local;
	// Оттенок пучка: зелень разной густоты, изредка сухие травинки
	float dry = step(0.86, hash(cell + 5.1));
	col_var = mix(vec3(0.85 + h1 * 0.3, 0.9 + h2 * 0.2, 0.8 + h1 * 0.2), dry_col / tip_col, dry * 0.8);
	shade = 0.85 + 0.2 * h2;
	NORMAL = normalize(vec3(local.x * 0.6, 1.0, local.z * 0.6));
}

void fragment() {
	vec3 c = mix(base_col, tip_col * col_var, smoothstep(0.0, 1.0, tip)) * shade;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	// Просвет на солнце: тонкие кончики пропускают свет
	BACKLIGHT = vec3(0.25, 0.32, 0.1) * tip;
}
