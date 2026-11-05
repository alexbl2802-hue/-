// Живая ткань (мантия героя): чем ниже точка плаща, тем сильнее она отстаёт от движения героя,
// колышется на ветру и бьётся на бегу. Смещение считает hero.gd (пружина от скорости героя),
// здесь оно раскладывается по высоте ткани плюс волны вдоль полы.
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float roughness = 0.85;
uniform vec3 lag = vec3(0.0);        // отставание низа ткани, метры, в мировых осях
uniform float flutter = 0.0;         // сила трепета (растёт с бегом)
uniform float hero_y = 0.0;          // высота ног героя (мир)
uniform float top_h = 1.45;          // высота, выше которой ткань не двигается (плечи)
uniform float rim = 0.25;

varying float sway_w;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp((top_h - (wp.y - hero_y)) / max(top_h - 0.05, 0.1), 0.0, 1.0);
	float w = h * h * (3.0 - 2.0 * h);
	sway_w = w;
	vec3 off = lag * w;
	// Волны по поле: бегут сверху вниз, сильнее у края
	float wave = sin(TIME * 9.0 - (wp.y - hero_y) * 6.0 + wp.x * 3.0) + 0.5 * sin(TIME * 14.0 + wp.z * 5.0);
	off += vec3(0.0, 0.0, 0.0) + normalize(lag + vec3(0.0001)) * wave * flutter * w * 0.035;
	off.y += abs(wave) * flutter * w * 0.012;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	RIM = rim;
	RIM_TINT = 0.6;
}
