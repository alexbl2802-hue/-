## Экранный интерфейс: название места, баннеры, миникарта и сенсорное управление.
extends CanvasLayer

var touch: Control
var minimap: Control
var _status: Label
var _banner: Label
var _banner_sub: Label
var _banner_box: VBoxContainer
var _tween: Tween

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Название места вверху по центру
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.55)
	sb.border_color = Color(1, 0.86, 0.63, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 12
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color("#f4ecd8"))
	panel.add_child(_status)
	root.add_child(panel)
	# Миникарта справа сверху
	minimap = preload("res://scripts/minimap.gd").new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -124
	minimap.offset_right = -12
	minimap.offset_top = 12
	minimap.offset_bottom = 124
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	# Баннер с названием места
	_banner_box = VBoxContainer.new()
	_banner_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner_box.position.y = 90
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.modulate.a = 0.0
	_banner = _label(32, Color("#f4ecd8"))
	_banner_sub = _label(15, Color(0.96, 0.93, 0.85, 0.85))
	_banner_box.add_child(_banner)
	_banner_box.add_child(_banner_sub)
	root.add_child(_banner_box)
	# Сенсорное управление
	touch = preload("res://scripts/touch_ui.gd").new()
	root.add_child(touch)

func _label(fs: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func set_status(text: String) -> void:
	_status.text = text

func banner(title: String, sub := "") -> void:
	_banner.text = title
	_banner_sub.text = sub
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.5)
	_tween.tween_interval(2.4)
	_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.8)
