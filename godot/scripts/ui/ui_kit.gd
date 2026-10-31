## Общие элементы окон: рамки, подписи, кнопки и ячейки предметов в одном стиле.
class_name UiKit
extends RefCounted

const GOLD := Color("#ffd479")
const CREAM := Color("#ffe7b0")
const TEXT := Color("#f4ecd8")

static func box(bg: Color, border: Color, radius := 10, margin := 8, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

static func window_box() -> StyleBoxFlat:
	return box(Color(0.11, 0.086, 0.063, 0.97), Color(1, 0.86, 0.63, 0.4), 12, 10)

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
		var s := box(GOLD if primary else Color("#3a2d1c"), Color(1, 0.86, 0.63, 0.5), 8, 0, 1)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		if state == "pressed":
			s.bg_color = s.bg_color.darkened(0.2)
		if state == "disabled":
			s.bg_color = s.bg_color.darkened(0.55)
		b.add_theme_stylebox_override(state, s)
	var fc := Color("#2a1d08") if primary else CREAM
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
		var s := box(Color(1, 0.83, 0.47, 0.18) if selected else Color(1, 1, 1, 0.06), GOLD if selected else border, 8, 0, 2)
		b.add_theme_stylebox_override(state, s)
	if count != "":
		var n := label(count, 11, Color.WHITE)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 4)
		n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		n.offset_left = -18
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
	dim.color = Color(0, 0, 0, 0.55)
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
