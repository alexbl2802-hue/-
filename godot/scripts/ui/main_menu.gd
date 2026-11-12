## Главное меню (картинка meshy/ui/menu_src.jpg): поверх нарисованных кнопок — настоящие.
## «Продолжить» — в игру (первый раз — новая игра), «Новая игра» — окно с именем героя
## (если есть сохранение — прогресс стирается), «Настройки», «Выход». Кнопка ☰ в игре открывает меню снова.
extends Control

signal started(first: bool)

var settings: Control   # окно настроек (открывается из меню)
var _name: LineEdit
var _btns := {}          # имя → [кнопка, прямоугольник на картинке]
var _info: Label
var _ver: Label
var _dlg: Control        # окно «Новая игра»
var _warn: Label
var _dlg_box: PanelContainer

## Где нарисованы кнопки на картинке 1280×720
const RECTS := {
	"continue": Rect2(790, 265, 370, 58),
	"new": Rect2(803, 347, 348, 58),
	"settings": Rect2(806, 421, 345, 58),
	"exit": Rect2(806, 497, 345, 58),
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	ArtScreen.background(self, "res://ui/menu_bg.jpg")
	var acts := {"continue": _on_main, "new": _open_new, "settings": func(): settings.open(), "exit": func(): get_tree().quit()}
	for k in RECTS:
		var b := Button.new()
		b.flat = false
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _glow(0.10))
		b.add_theme_stylebox_override("pressed", _glow(0.28))
		b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		b.pressed.connect(acts[k])
		b.button_down.connect(func(): b.modulate = Color(1.15, 1.15, 1.3))
		b.button_up.connect(func(): b.modulate = Color.WHITE)
		add_child(b)
		_btns[k] = b
	_info = UiKit.label("", 13, Color(1, 1, 1, 0.85))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_child(_info)
	# Номер версии в углу — чтобы видеть, какая сборка установлена (его прописывает сборка APK)
	_ver = UiKit.label("Версия " + str(ProjectSettings.get_setting("application/config/version", "dev")), 12, Color(1, 1, 1, 0.55))
	add_child(_ver)
	_build_dialog()
	settings = preload("res://scripts/ui/settings_panel.gd").new()
	settings.visible = false
	add_child(settings)
	resized.connect(_layout)
	_layout()

func _glow(a: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.45, 0.8, 1.0, a)
	s.border_color = Color(0.55, 0.9, 1.0, 0.7)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.shadow_color = Color(0.3, 0.7, 1.0, 0.5)
	s.shadow_size = 8
	return s

func _layout() -> void:
	var s := size if size.x > 0 else get_viewport_rect().size
	for k in RECTS:
		ArtScreen.place(_btns[k], s, RECTS[k])
	var r := ArtScreen.map(s, Rect2(806, 566, 345, 26))
	_info.position = r.position
	_info.size = r.size
	_ver.position = Vector2(s.x - 130, s.y - 26)

## Окно «Новая игра»: имя героя, «Начать», «Отмена»
func _build_dialog() -> void:
	_dlg = Control.new()
	_dlg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dlg.visible = false
	add_child(_dlg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dlg.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dlg.add_child(cc)
	_dlg_box = PanelContainer.new()
	_dlg_box.add_theme_stylebox_override("panel", UiKit.window_box())
	cc.add_child(_dlg_box)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(380, 0)
	vb.add_theme_constant_override("separation", 10)
	_dlg_box.add_child(vb)
	UiKit.decorate(_dlg_box)
	var t := UiKit.title_plate("Новая игра")
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vb.add_child(t)
	vb.add_child(UiKit.label("Имя героя", 13, UiKit.DIM))
	_name = LineEdit.new()
	_name.placeholder_text = "Введи имя или ник"
	_name.max_length = 16
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 18)
	_name.add_theme_stylebox_override("normal", UiKit.box(Color("#0b1322"), UiKit.LINE, 8, 9, 1))
	_name.add_theme_stylebox_override("focus", UiKit.glow(UiKit.box(Color("#0b1322"), Color("#7cc0ff"), 8, 9, 1), 5, 0.45))
	_name.add_theme_color_override("font_color", UiKit.CREAM)
	_name.text_submitted.connect(func(_t): _name.release_focus())
	vb.add_child(_name)
	_warn = UiKit.label("Сохранённый прогресс будет удалён", 12, Color("#ff9a8a"))
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_warn)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	var ok := UiKit.button("Начать", true, 18)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_start_new)
	hb.add_child(ok)
	var no := UiKit.button("Отмена", false, 16)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func(): _dlg.visible = false; DisplayServer.virtual_keyboard_hide())
	hb.add_child(no)

func open() -> void:
	_name.text = Game.player_name
	_dlg.visible = false
	_info.text = ("%s · уровень %d · 🪙 %d" % [Game.player_name if Game.player_name != "" else "Странник", Game.level, Game.gold]) if Game.has_save else ""
	visible = true
	get_tree().paused = true
	_layout()
	# После «Новой игры» с сохранением мир перезапущен — сразу в игру
	if Game.has_meta("autostart"):
		Game.remove_meta("autostart")
		_on_main.call_deferred()

## «Продолжить»: в игру (первый запуск — как новая игра с введённым или обычным именем)
func _on_main() -> void:
	var first := not Game.has_save
	Game.player_name = _name.text.strip_edges().left(16)
	if Game.player_name == "":
		Game.player_name = "Странник"
	_name.release_focus()
	DisplayServer.virtual_keyboard_hide()
	_dlg.visible = false
	Game.has_save = true
	Game.save_game()
	visible = false
	get_tree().paused = false
	started.emit(first)

func _open_new() -> void:
	_name.text = Game.player_name
	_warn.visible = Game.has_save
	_dlg.visible = true

## «Начать» в окне новой игры: есть сохранение — прогресс стирается, мир перезапускается
func _start_new() -> void:
	var keep := _name.text.strip_edges().left(16)
	DisplayServer.virtual_keyboard_hide()
	if not Game.has_save:
		_on_main()
		return
	Game.wipe()
	Game.player_name = keep
	Game.set_meta("autostart", true)
	get_tree().paused = false
	get_tree().reload_current_scene()

