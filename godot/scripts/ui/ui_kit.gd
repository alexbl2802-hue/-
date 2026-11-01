## Общие элементы окон в стиле игровых меню из аниме: полупрозрачные тёмные окна,
## острые углы, светящиеся голубые рамки; главное действие — оранжевое.
class_name UiKit
extends RefCounted

const GOLD := Color("#ffb84a")      # акцент: заголовки, выбранное, главная кнопка
const CREAM := Color("#d6f1ff")     # текст на кнопках
const TEXT := Color("#eef7ff")
const GLOW := Color(0.45, 0.85, 1.0)        # светящаяся рамка
const WIN_BG := Color(0.03, 0.07, 0.12, 0.9)
const BTN_BG := Color(0.07, 0.16, 0.24, 0.88)
const RADIUS := 2                    # острые углы

static func box(bg: Color, border: Color, radius := RADIUS, margin := 8, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(mini(radius, RADIUS))
	s.set_content_margin_all(margin)
	return s

## Светящаяся рамка: мягкое голубое свечение вокруг окна
static func glow(s: StyleBoxFlat, size := 10, a := 0.35) -> StyleBoxFlat:
	s.shadow_color = Color(GLOW.r, GLOW.g, GLOW.b, a)
	s.shadow_size = size
	return s

static func window_box() -> StyleBoxFlat:
	var s := glow(box(WIN_BG, Color(GLOW.r, GLOW.g, GLOW.b, 0.85), RADIUS, 10, 1))
	s.border_width_top = 3     # яркая полоса сверху, как у окон-голограмм
	s.border_blend = false
	return s

static func label(t: String, fs := 13, c := TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

static func button(t: String, primary := false, fs := 13) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", fs)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := box(GOLD if primary else BTN_BG, Color(1, 0.9, 0.7, 0.9) if primary else Color(GLOW.r, GLOW.g, GLOW.b, 0.7), RADIUS, 0, 1)
		if state == "hover" or state == "pressed":
			glow(s, 6, 0.5)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		if state == "pressed":
			s.bg_color = s.bg_color.darkened(0.2)
		if state == "disabled":
			s.bg_color = s.bg_color.darkened(0.55)
		b.add_theme_stylebox_override(state, s)
	var fc := Color("#1a1006") if primary else CREAM
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", fc.darkened(0.3))
	return b

## Ячейка предмета: значок, рамка цвета редкости, число в углу, подпись снизу
static func slot(icon: String, border: Color, count := "", caption := "", size := 42.0, selected := false) -> Button:
	var b := Button.new()
	b.text = icon
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", int(size * 0.5))
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := box(Color(1, 0.72, 0.29, 0.2) if selected else Color(0.45, 0.85, 1.0, 0.07), GOLD if selected else border, RADIUS, 0, 2)
		if selected:
			s.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
			s.shadow_size = 6
		b.add_theme_stylebox_override(state, s)
	if count != "":
		var n := label(count, 11, Color.WHITE)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 4)
		# С подписью внизу число переезжает в правый верхний угол
		if caption != "":
			n.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			n.offset_left = -26
			n.offset_top = 1
			n.offset_right = -4
		else:
			n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			n.offset_left = -26
			n.offset_top = -16
			n.offset_right = -3
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(n)
	if caption != "":
		var c := label(caption, 9, Color(1, 1, 1, 0.7))
		c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		c.offset_top = -13
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(c)
	return b

## Затемнение фона + окно по центру; возвращает контейнер содержимого
static func modal(owner: Control, on_backdrop: Callable) -> VBoxContainer:
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.visible = false
	owner.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: on_backdrop.call())
	owner.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", window_box())
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	return vb
