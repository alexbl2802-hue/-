## Цветокоррекция в аниме-стиле (shaders/post.gdshader): наборы под время суток и место.
## Днём — сочно и тепло, на закате — золотистые света, ночью — синие тени и приглушённые цвета,
## в пещере — холодная бирюза, в склепе — тёплый свет факелов, в башне и на плато — светло и ярко.
class_name Grade
extends RefCounted

const DAY := {"contrast": 1.10, "saturation": 1.0, "vibrance": 0.2, "shadow_tint": Color(0.93, 0.98, 1.07), "highlight_tint": Color(1.05, 1.02, 0.94), "lift": 0.012, "glow": 0.10, "vignette": 0.28}
const DUSK := {"contrast": 1.10, "saturation": 1.02, "vibrance": 0.24, "shadow_tint": Color(0.90, 0.92, 1.08), "highlight_tint": Color(1.13, 1.0, 0.86), "lift": 0.015, "glow": 0.14, "vignette": 0.32}
const NIGHT := {"contrast": 1.06, "saturation": 0.90, "vibrance": 0.25, "shadow_tint": Color(0.84, 0.92, 1.16), "highlight_tint": Color(0.96, 0.99, 1.08), "lift": 0.022, "glow": 0.16, "vignette": 0.38}
const CAVE := {"contrast": 1.08, "saturation": 1.04, "vibrance": 0.30, "shadow_tint": Color(0.86, 0.98, 1.10), "highlight_tint": Color(1.0, 1.03, 1.04), "lift": 0.02, "glow": 0.16, "vignette": 0.36}
const CRYPT := {"contrast": 1.08, "saturation": 1.02, "vibrance": 0.30, "shadow_tint": Color(0.92, 0.90, 1.06), "highlight_tint": Color(1.10, 1.0, 0.88), "lift": 0.02, "glow": 0.18, "vignette": 0.40}
const BRIGHT := {"contrast": 1.08, "saturation": 1.0, "vibrance": 0.22, "shadow_tint": Color(0.95, 0.99, 1.05), "highlight_tint": Color(1.04, 1.02, 0.97), "lift": 0.01, "glow": 0.12, "vignette": 0.24}

static var mat: ShaderMaterial

static func apply(p: Dictionary) -> void:
	if mat == null:
		return
	for k in p:
		mat.set_shader_parameter(k, p[k])

## Смешать два набора
static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in a:
		out[k] = lerp(a[k], b[k], t)
	return out

## Под открытым небом: d — освещённость (0 ночь … 1 день), dusk — закат/рассвет (0…1)
static func sky(d: float, dusk: float) -> void:
	apply(mix(mix(NIGHT, DAY, d), DUSK, clampf(dusk, 0.0, 1.0)))
