## Экран загрузки по картинке (meshy/ui/loading_src.jpg): картинка вписана целиком, по полоске
## плавно растёт заливка и всё время бежит блик, надпись «Загрузка…» мигает точками.
## Используется и при запуске (scripts/boot.gd), и пока строится мир (scripts/main.gd).
class_name LoadingScreen
extends Control

const BAR := Rect2(358, 628, 560, 20)        # полоска на картинке (пиксели 1280×720)
const TEXT := Rect2(440, 578, 400, 40)       # где надпись «Загрузка…»

var target := 0.0        # к чему стремится полоска (0…1)
var shown := 0.0
var creep := true        # пока ждём — полоска понемногу ползёт сама, чтобы не стоять
var text := ""           # своя надпись вместо «Загрузка…»
var note: Label
var retry: Button
var _fill: TextureRect
var _shine: TextureRect
var _label: Label
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	ArtScreen.background(self, "res://ui/loading_bg.jpg")
	var grad := Gradient.new()
	grad.set_color(0, Color("#0a52d8"))
	grad.set_color(1, Color("#3ff0ff"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 4
	_fill = TextureRect.new()
	_fill.texture = gt
	_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_fill.clip_contents = true
	add_child(_fill)
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	sg.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.width = 64
	st.height = 4
	_shine = TextureRect.new()
	_shine.texture = st
	_shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shine.stretch_mode = TextureRect.STRETCH_SCALE
	_fill.add_child(_shine)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color("#f4f0ff"))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)
	note = Label.new()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_child(note)
	retry = Button.new()
	retry.text = "Повторить"
	retry.visible = false
	add_child(retry)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var s := size if size.x > 0 else get_viewport_rect().size
	var bar := ArtScreen.map(s, BAR)
	_fill.position = bar.position
	_fill.size = Vector2(maxf(2.0, bar.size.x * shown), bar.size.y)
	ArtScreen.place(_label, s, TEXT)
	_label.add_theme_font_size_override("font_size", maxi(12, int(bar.size.y * 1.35)))
	var nb := ArtScreen.map(s, Rect2(BAR.position + Vector2(0, 30), Vector2(BAR.size.x, 26)))
	note.position = nb.position
	note.size = nb.size
	note.add_theme_font_size_override("font_size", maxi(10, int(bar.size.y * 0.8)))
	var rb := ArtScreen.map(s, Rect2(560, 520, 160, 44))
	retry.position = rb.position
	retry.size = rb.size

## Сразу показать полоску на p (без плавности) — когда кадры идут редко (строится мир)
func jump(p: float) -> void:
	target = p
	shown = p
	_tick(0.0)

func _process(dt: float) -> void:
	_tick(dt)

func _tick(dt: float) -> void:
	_t += dt
	if creep and shown >= target - 0.002:
		target = minf(target + dt * 0.01, 0.98)
	shown = move_toward(shown, target, dt * 0.9)
	var s := size if size.x > 0 else get_viewport_rect().size
	var full := ArtScreen.map(s, BAR).size.x
	_fill.size.x = maxf(2.0, full * shown)
	var w := _fill.size.y * 5.0
	_shine.size = Vector2(w, _fill.size.y)
	_shine.position = Vector2(fmod(_t * full * 0.6, _fill.size.x + w) - w, 0)
	_label.text = text if text != "" else "Загрузка" + ".".repeat(1 + int(_t * 2.5) % 3)
