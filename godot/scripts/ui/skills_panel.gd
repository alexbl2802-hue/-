## Окно навыков: очки за уровни до 10-го, 8 навыков с рангами. Игра на паузе, пока окно открыто.
extends Control

signal closed

var _points: Label
var _grid: GridContainer
var _reset: Button
var _reset_armed := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.086, 0.063, 0.97)
	sb.border_color = Color(1, 0.86, 0.63, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(_lbl("Навыки", 18, Color("#ffd479")))
	_points = _lbl("", 14, Color("#ffe7b0"))
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_points)
	_reset = _btn("Сбросить", false)
	_reset.pressed.connect(_on_reset)
	head.add_child(_reset)
	var x := _btn("✕", false)
	x.pressed.connect(close)
	head.add_child(x)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(_grid)

func _lbl(t: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

func _btn(t: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("#ffd479") if primary else Color("#3a2d1c")
		if state == "pressed":
			s.bg_color = s.bg_color.darkened(0.2)
		if state == "disabled":
			s.bg_color = s.bg_color.darkened(0.55)
		s.border_color = Color(1, 0.86, 0.63, 0.5)
		s.set_border_width_all(1)
		s.set_corner_radius_all(8)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, s)
	var fc := Color("#2a1d08") if primary else Color("#ffe7b0")
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", fc.darkened(0.3))
	return b

func open() -> void:
	_reset_armed = false
	_reset.text = "Сбросить"
	_render()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _on_reset() -> void:
	if Game.skills.is_empty():
		return
	if not _reset_armed:
		_reset_armed = true
		_reset.text = "Точно сбросить?"
		return
	Game.reset_skills()
	_reset_armed = false
	_reset.text = "Сбросить"
	_render()

func _render() -> void:
	var free := Game.points_free()
	_points.text = "Очки навыков: %d   · по 1 за каждый уровень до %d-го" % [free, SkillDefs.MAX_SKILL_LEVEL]
	for c in _grid.get_children():
		c.queue_free()
	for s in SkillDefs.LIST:
		var id: String = s["id"]
		var r := Game.rank(id)
		var locked: bool = Game.level < s["lvl"]
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.border_color = Color(0.5, 0.85, 1, 0.45) if s.get("active", false) else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(7)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(186, 0)
		if locked:
			card.modulate.a = 0.5
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		card.add_child(vb)
		vb.add_child(_lbl("%s %s" % [s["icon"], s["name"]], 14, Color("#ffe7b0")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_lbl("%d / %d" % [r, s["max"]], 13, Color("#ffd479")))
		row.add_child(_lbl("умение (кнопка)" if s.get("active", false) else "пассивный", 10, Color("#8fd8ff")))
		vb.add_child(row)
		var d := _lbl(SkillDefs.desc(id, maxi(1, r)), 11, Color(1, 1, 1, 0.88))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(170, 0)
		vb.add_child(d)
		if r > 0 and r < s["max"]:
			var nx := _lbl("Далее: " + SkillDefs.desc(id, r + 1), 10, Color(1, 1, 1, 0.55))
			nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nx.custom_minimum_size = Vector2(170, 0)
			vb.add_child(nx)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(spacer)
		if locked:
			vb.add_child(_lbl("Нужен уровень %d" % s["lvl"], 11, Color("#ff9a7a")))
		elif r >= s["max"]:
			# Максимальный ранг открывает эволюцию навыка (пока недоступна)
			var evo := _btn("✨ Эволюция  🔒" if not SkillDefs.EVOLUTION_ENABLED else "✨ Эволюция", true)
			evo.disabled = not SkillDefs.EVOLUTION_ENABLED
			vb.add_child(evo)
			vb.add_child(_lbl("Максимум · эволюция скоро", 10, Color("#7dff8a")))
		else:
			var b := _btn("Улучшить" if r > 0 else "Изучить", true)
			b.disabled = free <= 0
			b.pressed.connect(func():
				if Game.learn(id):
					_render())
			vb.add_child(b)
		_grid.add_child(card)
