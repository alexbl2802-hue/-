// Обработка кадра в аниме-стиле: живые, но не кислотные цвета (сочность сильнее у блёклых цветов),
// мягкая S-кривая контраста, раздельный оттенок теней (холодный) и светов (тёплый), лёгкое
// «сияние» светлых мест и мягкая виньетка. Параметры меняются по времени суток и месту
// (scripts/grade.gd).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float contrast = 1.08;
uniform float saturation = 1.06;
uniform float vibrance = 0.35;          // добавка сочности блёклым цветам
uniform vec3 shadow_tint : source_color = vec3(0.93, 0.98, 1.06);
uniform vec3 highlight_tint : source_color = vec3(1.05, 1.02, 0.95);
uniform float tone_split = 0.5;          // граница теней и светов по яркости
uniform float lift = 0.012;              // приподнять самые тёмные места (не в чёрную дыру)
uniform float glow = 0.10;               // мягкое сияние светлых мест
uniform float vignette = 0.30;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	// Сияние: светлые места чуть разливаются (дешёвая выборка соседей, без размытия всего кадра)
	if (glow > 0.0) {
		vec2 px = SCREEN_PIXEL_SIZE * 3.0;
		vec3 n = texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb + texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb
			+ texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb + texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb;
		n *= 0.25;
		c += max(n - 0.72, vec3(0.0)) * glow * 2.2;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// Сочность: блёклые цвета насыщаются сильнее, яркие — почти не меняются
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx - mn;
	c = mix(vec3(l), c, saturation * (1.0 + vibrance * (1.0 - sat)));
	// Мягкая S-кривая вокруг середины
	c = clamp(c, 0.0, 1.5);
	vec3 s = c * c * (3.0 - 2.0 * min(c, vec3(1.0)));
	c = mix(c, s, clamp(contrast - 1.0, 0.0, 1.0) * 1.6);
	c = c * (1.0 - lift) + lift;
	// Тени холоднее, света теплее
	float k = smoothstep(tone_split - 0.35, tone_split + 0.35, l);
	c *= mix(shadow_tint, highlight_tint, k);
	vec2 v = SCREEN_UV - 0.5;
	v.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.6;
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, length(v) * 1.2);
	c += (fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 160.0;   // против полос
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
