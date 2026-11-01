## Главное меню: имя героя, «Начать игру» при первом запуске и «Продолжить» потом,
## «Новая игра» стирает прогресс. Кнопка ☰ в игре открывает его снова.
extends Control

signal started(first: bool)

var _name: LineEdit
var settings: Control   # окно настроек (открывается из меню)
var _main: Button
var _new: Button
var _info: Label
var _new_armed := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.02, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(430, 0)
	vb.add_theme_constant_override("separation", 7)
	center.add_child(vb)
	var title := UiKit.label("Земли Приключений", 40, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 3)
	vb.add_child(title)
	var sub := UiKit.label("Город за крепостной стеной, долина, полная чудовищ, и два подземелья с сокровищами", 13, Color(1, 1, 1, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	vb.add_child(UiKit.label("Имя героя", 12, Color(1, 1, 1, 0.75)))
	_name = LineEdit.new()
	_name.placeholder_text = "Введи имя или ник"
	_name.max_length = 16
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 18)
	_name.add_theme_stylebox_override("normal", UiKit.box(Color(0, 0.04, 0.08, 0.6), Color(0.45, 0.85, 1.0, 0.6), 2, 9))
	_name.add_theme_stylebox_override("focus", UiKit.box(Color(0, 0, 0, 0.5), UiKit.GOLD, 10, 9))
	_name.add_theme_color_override("font_color", Color("#fff3d8"))
	_name.text_submitted.connect(func(_t): _name.release_focus())
	vb.add_child(_name)
	_main = UiKit.button("Начать игру", true, 21)
	_main.custom_minimum_size = Vector2(0, 50)
	_main.pressed.connect(_on_main)
	vb.add_child(_main)
	_new = UiKit.button("Новая игра", false, 15)
	_new.pressed.connect(_on_new)
	vb.add_child(_new)
	var st := UiKit.button("⚙ Настройки", false, 15)
	st.pressed.connect(func(): settings.open())
	vb.add_child(st)
	_info = UiKit.label("", 12, Color(1, 1, 1, 0.7))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_info)
	settings = preload("res://scripts/ui/settings_panel.gd").new()
	settings.visible = false
	add_child(settings)
	# Номер версии в углу — чтобы видеть, какая сборка установлена (его прописывает сборка APK)
	var ver := UiKit.label("Версия " + str(ProjectSettings.get_setting("application/config/version", "dev")), 12, Color(1, 1, 1, 0.55))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.position -= Vector2(14, 10)
	add_child(ver)

func open() -> void:
	_new_armed = false
	_new.text = "Новая игра"
	_name.text = Game.player_name
	_main.text = "Продолжить" if Game.has_save else "Начать игру"
	_new.visible = Game.has_save
	_info.text = ("%s · уровень %d · 🪙 %d" % [Game.player_name if Game.player_name != "" else "Странник", Game.level, Game.gold]) if Game.has_save else "Твоё приключение начнётся в городе Камнеград"
	visible = true
	get_tree().paused = true

func _on_main() -> void:
	var first := not Game.has_save
	Game.player_name = _name.text.strip_edges().left(16)
	if Game.player_name == "":
		Game.player_name = "Странник"
	_name.release_focus()
	DisplayServer.virtual_keyboard_hide()
	Game.has_save = true
	Game.save_game()
	visible = false
	get_tree().paused = false
	started.emit(first)

## «Новая игра»: второе нажатие подтверждает, прогресс стирается, мир перезапускается
func _on_new() -> void:
	if not _new_armed:
		_new_armed = true
		_new.text = "Точно? Прогресс будет удалён"
		return
	var keep := _name.text
	Game.wipe()
	Game.player_name = keep
	get_tree().paused = false
	get_tree().reload_current_scene()
