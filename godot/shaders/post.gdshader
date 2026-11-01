// Обработка кадра: чуть больше контраста и насыщенности, тёплый оттенок и мягкая виньетка
// (края экрана темнее — взгляд тянется к центру).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float contrast = 1.06;
uniform float saturation = 1.14;
uniform vec3 tint : source_color = vec3(1.02, 1.0, 0.96);
uniform float vignette = 0.32;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.3) * contrast + 0.3;   // опора низко — тёмные подземелья не проваливаются в черноту
	c *= tint;
	vec2 v = SCREEN_UV - 0.5;
	v.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.6;
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, length(v) * 1.2);
	c += (fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 160.0;   // против полос
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
