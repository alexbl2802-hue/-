## Окно настроек: чувствительность камеры, тени, дальность прорисовки, счётчик кадров.
## Работает и поверх главного меню (игра на паузе).
extends Control

signal changed
signal closed

var _sens_lbl: Label
var _sens: HSlider
var _shadows: Button
var _fps: Button
var _view_btns: Array = []
var _q_btns: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vb := UiKit.modal(self, close)
	UiKit.header(vb, "Настройки", close)
	# Чувствительность камеры
	_sens_lbl = UiKit.label("", 14)
	vb.add_child(_sens_lbl)
	_sens = HSlider.new()
	_sens.min_value = 0.5
	_sens.max_value = 2.0
	_sens.step = 0.1
	_sens.custom_minimum_size = Vector2(420, 32)
	_sens.value_changed.connect(func(v):
		Settings.cam_sens = v
		_apply())
	vb.add_child(_sens)
	# Профиль качества: сразу ставит тени и дальность (их можно поменять отдельно)
	vb.add_child(UiKit.label("Качество графики", 14))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	vb.add_child(qrow)
	for i in Settings.QUALITY.size():
		var qb := UiKit.button(Settings.QUALITY[i]["name"], false, 14)
		qb.custom_minimum_size = Vector2(130, 40)
		var qi := i
		qb.pressed.connect(func():
			Settings.quality = qi
			Settings.shadows = Settings.QUALITY[qi]["shadows"]
			Settings.view = Settings.QUALITY[qi]["view"]
			_apply())
		qrow.add_child(qb)
		_q_btns.append(qb)
	# Дальность прорисовки
	vb.add_child(UiKit.label("Дальность прорисовки", 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	for i in Settings.VIEW.size():
		var b := UiKit.button(Settings.VIEW[i]["name"], false, 14)
		b.custom_minimum_size = Vector2(130, 40)
		var k := i
		b.pressed.connect(func():
			Settings.view = k
			_apply())
		row.add_child(b)
		_view_btns.append(b)
	# Тени и счётчик кадров
	_shadows = UiKit.button("", false, 14)
	_shadows.custom_minimum_size = Vector2(0, 40)
	_shadows.pressed.connect(func():
		Settings.shadows = not Settings.shadows
		_apply())
	vb.add_child(_shadows)
	_fps = UiKit.button("", false, 14)
	_fps.custom_minimum_size = Vector2(0, 40)
	_fps.pressed.connect(func():
		Settings.show_fps = not Settings.show_fps
		_apply())
	vb.add_child(_fps)
	vb.add_child(UiKit.label("Слабый телефон: качество «Низкое»", 11, Color(1, 1, 1, 0.6)))

func open() -> void:
	_sens.set_value_no_signal(Settings.cam_sens)
	_render()
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func _apply() -> void:
	Settings.save_settings()
	_render()
	changed.emit()

func _render() -> void:
	_sens_lbl.text = "Чувствительность камеры: ×%s" % String.num(Settings.cam_sens, 1)
	for i in _q_btns.size():
		(_q_btns[i] as Button).text = ("● " if i == Settings.quality else "") + Settings.QUALITY[i]["name"]
	for i in _view_btns.size():
		var b: Button = _view_btns[i]
		b.text = ("● " if i == Settings.view else "") + Settings.VIEW[i]["name"]
	_shadows.text = "Тени: " + ("вкл" if Settings.shadows else "выкл")
	_fps.text = "Счётчик кадров: " + ("вкл" if Settings.show_fps else "выкл")
