## Профиль героя: ник, уровень и очки навыков; слева — прокручиваемый список навыков,
## справа — описание выбранного навыка, под ним кнопки «Улучшить» и «Эволюция».
## Игра на паузе, пока окно открыто.
extends Control

signal closed

var _title: Label
var _points: Label
var _list: VBoxContainer
var _reset: Button
var _reset_armed := false
var _sel := "strength"
var _tab := "skills"          # skills — навыки, stats — характеристики
var _sel_stat := "str"
var _tabs := {}
const STATS := [
	{"id": "str", "icon": "💪", "name": "Сила"},
	{"id": "agi", "icon": "🪶", "name": "Ловкость"},
	{"id": "vit", "icon": "❤️", "name": "Выносливость"},
]
# Правая половина: описание выбранного навыка
var _d_name: Label
var _d_kind: Label
var _d_rank: Label
var _d_now: Label
var _d_next: Label
var _d_need: Label
var _up: Button
var _evo: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.window_box())
	panel.custom_minimum_size = Vector2(700, 320)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	# Шапка: ник и уровень, очки навыков, сброс, закрыть
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	_title = _lbl("", 18, UiKit.GOLD)
	head.add_child(_title)
	_points = _lbl("", 13, UiKit.CREAM)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in [["skills", "Навыки"], ["stats", "Характеристики"]]:
		var tb := _btn(t[1], false)
		var key: String = t[0]
		tb.pressed.connect(func():
			_tab = key
			_reset_armed = false
			_reset.text = "Сбросить"
			_render())
		head.add_child(tb)
		_tabs[key] = tb
	head.add_child(_points)
	_reset = _btn("Сбросить", false)
	_reset.pressed.connect(_on_reset)
	head.add_child(_reset)
	var x := _btn("✕", false)
	x.pressed.connect(close)
	head.add_child(x)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	# Левая половина: список навыков с прокруткой
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	scroll.custom_minimum_size = Vector2(0, 250)
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	# Правая половина: описание навыка, ниже — «Улучшить» и рядом «Эволюция»
	var info := PanelContainer.new()
	var ib := StyleBoxFlat.new()
	ib.bg_color = Color(1, 1, 1, 0.05)
	ib.border_color = Color(0.45, 0.85, 1.0, 0.3)
	ib.set_border_width_all(1)
	ib.set_corner_radius_all(UiKit.RADIUS)
	ib.set_content_margin_all(10)
	info.add_theme_stylebox_override("panel", ib)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_stretch_ratio = 1.0
	body.add_child(info)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 5)
	info.add_child(dv)
	_d_name = _lbl("", 18, UiKit.CREAM)
	dv.add_child(_d_name)
	_d_kind = _lbl("", 11, Color("#8fd8ff"))
	dv.add_child(_d_kind)
	_d_rank = _lbl("", 14, UiKit.GOLD)
	dv.add_child(_d_rank)
	_d_now = _wrap(_lbl("", 13, Color(1, 1, 1, 0.9)))
	dv.add_child(_d_now)
	_d_next = _wrap(_lbl("", 12, Color(1, 1, 1, 0.6)))
	dv.add_child(_d_next)
	_d_need = _lbl("", 12, Color("#ff9a7a"))
	dv.add_child(_d_need)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	dv.add_child(buttons)
	_up = _btn("Улучшить", true)
	_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up.custom_minimum_size = Vector2(0, 40)
	_up.pressed.connect(func():
		var ok := Game.add_stat(_sel_stat) if _tab == "stats" else Game.learn(_sel)
		if ok:
			_render())
	buttons.add_child(_up)
	_evo = _btn("✨ Эволюция", false)
	_evo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_evo.custom_minimum_size = Vector2(0, 40)
	_evo.pressed.connect(func():
		if Game.evolve(_sel):
			_render())
	buttons.add_child(_evo)

func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	return l

func _lbl(t: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

func _btn(t: String, primary: bool) -> Button:
	return UiKit.button(t, primary)

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
	if (_tab == "skills" and Game.skills.is_empty()) or (_tab == "stats" and Game.stat_points_free() == (Game.level - 1) * Game.STAT_PER_LEVEL):
		return
	if not _reset_armed:
		_reset_armed = true
		_reset.text = "Точно сбросить?"
		return
	if _tab == "stats":
		Game.reset_stats()
	else:
		Game.reset_skills()
	_reset_armed = false
	_reset.text = "Сбросить"
	_render()

func _render() -> void:
	var free := Game.points_free()
	_title.text = "👤 %s · Ур. %d" % [Game.player_name if Game.player_name != "" else "Странник", Game.level]
	for k in _tabs:
		(_tabs[k] as Button).text = ("● " if k == _tab else "") + ("Навыки" if k == "skills" else "Характеристики")
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if _tab == "stats":
		_render_stats()
		return
	_points.text = "Очки навыков: %d" % free
	for s in SkillDefs.LIST:
		var id: String = s["id"]
		var r := Game.rank(id)
		var locked: bool = Game.level < s["lvl"]
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s  %s      %d / %d" % [s["icon"], s["name"], r, s["max"]]
		if id == "dash":   # у рывка — текущая форма эволюции
			match SkillDefs.dash_form(Game.skills):
				"slide": row.text = "🌬️  Скользящий шаг      %d / %d" % [Game.rank("dash_slide"), SkillDefs.SLIDE_MAX]
				"blink": row.text = "✨  Мерцание      прорыв"
		row.add_theme_font_size_override("font_size", 14)
		row.custom_minimum_size = Vector2(0, 40)
		for state in ["normal", "hover", "pressed", "focus"]:
			var st := StyleBoxFlat.new()
			st.bg_color = Color(1, 0.72, 0.29, 0.2) if id == _sel else Color(0.45, 0.85, 1.0, 0.06)
			st.border_color = UiKit.GOLD if id == _sel else Color(0.45, 0.85, 1.0, 0.3)
			st.set_border_width_all(2 if id == _sel else 1)
			st.set_corner_radius_all(UiKit.RADIUS)
			st.content_margin_left = 10
			row.add_theme_stylebox_override(state, st)
		var fc := Color(1, 0.91, 0.69, 0.45 if locked else 1.0)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			row.add_theme_color_override(k, fc)
		row.pressed.connect(func():
			_sel = id
			_render())
		_list.add_child(row)
	_render_info(free)

## Вкладка «Характеристики»: Сила, Ловкость, Выносливость — по 2 очка за уровень
func _render_stats() -> void:
	var free := Game.stat_points_free()
	_points.text = "Очки характеристик: %d" % free
	for st in STATS:
		var id: String = st["id"]
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s  %s      %d" % [st["icon"], st["name"], Game.stats[id]]
		row.add_theme_font_size_override("font_size", 14)
		row.custom_minimum_size = Vector2(0, 40)
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 0.72, 0.29, 0.2) if id == _sel_stat else Color(0.45, 0.85, 1.0, 0.06)
			sb.border_color = UiKit.GOLD if id == _sel_stat else Color(0.45, 0.85, 1.0, 0.3)
			sb.set_border_width_all(2 if id == _sel_stat else 1)
			sb.set_corner_radius_all(UiKit.RADIUS)
			sb.content_margin_left = 10
			row.add_theme_stylebox_override(state, sb)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			row.add_theme_color_override(k, Color(1, 0.91, 0.69))
		row.pressed.connect(func():
			_sel_stat = id
			_render())
		_list.add_child(row)
	var cur: Dictionary = STATS.filter(func(x): return x["id"] == _sel_stat)[0]
	var n: int = Game.stats[_sel_stat]
	_d_name.text = "%s %s" % [cur["icon"], cur["name"]]
	_d_kind.text = "Характеристика · по %d очка за каждый уровень" % Game.STAT_PER_LEVEL
	_d_rank.text = "Вложено очков: %d" % n
	match _sel_stat:
		"str":
			_d_now.text = "Сейчас: урон +%d" % (n * Game.STAT_STR)
			_d_next.text = "Каждое очко: урон +%d" % Game.STAT_STR
		"agi":
			_d_now.text = "Сейчас: удары быстрее на %d%%, крит +%d%%" % [roundi(n * Game.STAT_AGI_SPEED * 100), roundi(n * Game.STAT_AGI_CRIT * 100)]
			_d_next.text = "Каждое очко: удары быстрее на %d%%, крит +%d%%" % [roundi(Game.STAT_AGI_SPEED * 100), roundi(Game.STAT_AGI_CRIT * 100)]
		"vit":
			_d_now.text = "Сейчас: здоровье +%d" % (n * Game.STAT_VIT)
			_d_next.text = "Каждое очко: здоровье +%d" % Game.STAT_VIT
	_d_need.text = ""
	_up.text = "+1 очко"
	_up.disabled = free <= 0
	_evo.visible = false

## Правая половина: что даёт навык сейчас и на следующем ранге, кнопки
func _render_info(free: int) -> void:
	_evo.visible = true
	if _sel == "dash" and SkillDefs.dash_form(Game.skills) != "dash":
		_render_dash_evo(free)
		return
	var s: Dictionary = SkillDefs.find(_sel)
	var r := Game.rank(_sel)
	var mx: int = s["max"]
	var locked: bool = Game.level < s["lvl"]
	_d_name.text = "%s %s" % [s["icon"], s["name"]]
	_d_kind.text = "Умение — своя кнопка на экране" if s.get("active", false) else "Пассивный навык"
	_d_rank.text = "Ранг %d / %d" % [r, mx]
	_d_now.text = ("Сейчас: " + SkillDefs.desc(_sel, r)) if r > 0 else "Ещё не изучен"
	if r < mx:
		_d_next.text = "Следующий ранг: " + SkillDefs.desc(_sel, r + 1)
	else:
		_d_next.text = "Максимальный ранг — открыта эволюция"
	_d_need.text = "Нужен уровень %d" % s["lvl"] if locked else ""
	_up.text = "Изучить" if r == 0 else "Улучшить"
	_up.disabled = locked or r >= mx or free <= 0
	# Эволюция — на максимальном ранге (у рывка — в Скользящий шаг, у остальных пока закрыта)
	if _sel == "dash":
		_d_next.text += "\nНа %d уровне — эволюция в Скользящий шаг" % mx if r < mx else ""
		_evo.text = "✨ Эволюция: Скользящий шаг" if Game.can_evolve("dash") else "✨ Эволюция  🔒"
		_evo.disabled = not Game.can_evolve("dash")
		return
	var evo_ready: bool = r >= mx and SkillDefs.EVOLUTION_ENABLED
	_evo.text = "✨ Эволюция" if evo_ready else "✨ Эволюция  🔒"
	_evo.disabled = not evo_ready

## Рывок после эволюции: Скользящий шаг (5 уровней) и прорыв в Мерцание
func _render_dash_evo(free: int) -> void:
	var form := SkillDefs.dash_form(Game.skills)
	var st := SkillDefs.dash_stats(Game.skills)
	_d_kind.text = "Умение — своя кнопка на экране · эволюция Рывка"
	_d_need.text = ""
	_d_now.text = "Сейчас: " + SkillDefs.dash_desc(st["speed"], st["cd"])
	if form == "blink":
		_d_name.text = "✨ Мерцание"
		_d_rank.text = "Прорыв · высшая форма"
		_d_next.text = "Герой исчезает и появляется впереди"
		_up.text = "Максимум"
		_up.disabled = true
		_evo.text = "⚡ Прорыв пройден"
		_evo.disabled = true
		return
	var sl := Game.rank("dash_slide")
	_d_name.text = "🌬️ Скользящий шаг"
	_d_rank.text = "Уровень %d / %d" % [sl, SkillDefs.SLIDE_MAX]
	if sl < SkillDefs.SLIDE_MAX:
		var nx := Game.skills.duplicate()
		nx["dash_slide"] = sl + 1
		var ns := SkillDefs.dash_stats(nx)
		_d_next.text = "Следующий уровень: " + SkillDefs.dash_desc(ns["speed"], ns["cd"]) + "\nНа %d уровне — прорыв в Мерцание" % SkillDefs.SLIDE_MAX
	else:
		_d_next.text = "Прорыв в Мерцание: скорость +200%, откат 3 с"
	_up.text = "Улучшить"
	_up.disabled = sl >= SkillDefs.SLIDE_MAX or free <= 0
	_evo.text = "⚡ Прорыв: Мерцание" if Game.can_evolve("dash") else "⚡ Прорыв  🔒"
	_evo.disabled = not Game.can_evolve("dash")
