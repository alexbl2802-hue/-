## Окно ANIMATE 2.0: анимация по описанию движения — генерируется на скелете героя
## (addons/animate/generator.gd) и сразу показывается на нём; можно сохранить в память телефона
## (user://animate/) и показать сохранённую снова. Диагностика — зона ANIMATE (не CARDINAL):
## проверка моделей и анимаций героя и монстров (scripts/animate_audit.gd), проверка скелета героя
## и созданной анимации (addons/animate/inspector.gd), безопасное исправление копии анимации
## (addons/animate/autofix.gd). Открывается из окна CARDINAL.
extends Control

signal closed

const DIR := "user://animate/"
const Inspector = preload("res://addons/animate/inspector.gd")
const AutoFix = preload("res://addons/animate/autofix.gd")
const QUICK := ["быстрый бег", "шаг", "удар мечом", "рывок", "присед", "прыжок", "взмах рукой", "стойка"]

var hero: Node
var _prompt: LineEdit
var _dur: HSlider
var _amp: HSlider
var _dur_l: Label
var _amp_l: Label
var _status: Label
var _list: VBoxContainer
var _anim: Animation
var _motion := ""
var _overlay: CanvasLayer
var _audit: AnimateAudit

func _ready() -> void:
	var vb := UiKit.modal(self, close)
	vb.custom_minimum_size = Vector2(560, 0)
	vb.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := UiKit.label("✦ ANIMATE 2.0 — анимации и модели", 18, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiKit.button("✕")
	x.pressed.connect(close)
	head.add_child(x)
	_prompt = LineEdit.new()
	_prompt.placeholder_text = "Например: быстрый бег, удар мечом, прыжок"
	_prompt.text = "быстрый бег"
	_prompt.custom_minimum_size = Vector2(0, 40)
	vb.add_child(_prompt)
	# быстрые варианты — одной строкой с прокруткой (окно должно помещаться на экран)
	var csc := ScrollContainer.new()
	csc.custom_minimum_size = Vector2(540, 40)
	csc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(csc)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	csc.add_child(chips)
	for q in QUICK:
		var b := UiKit.button(q, false, 12)
		b.custom_minimum_size = Vector2(0, 32)
		b.pressed.connect(func(): _prompt.text = q)
		chips.add_child(b)
	# Длительность и амплитуда — рядом
	var sl := HBoxContainer.new()
	sl.add_theme_constant_override("separation", 16)
	vb.add_child(sl)
	var c1 := VBoxContainer.new()
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.add_child(c1)
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.add_child(c2)
	_dur_l = UiKit.label("", 13)
	c1.add_child(_dur_l)
	_dur = _slider(0.4, 4.0, 0.1, 1.0, c1)
	_amp_l = UiKit.label("", 13)
	c2.add_child(_amp_l)
	_amp = _slider(0.3, 2.0, 0.1, 1.0, c2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var gen := UiKit.button("▶ Сгенерировать и показать", true, 14)
	gen.custom_minimum_size = Vector2(0, 42)
	gen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gen.pressed.connect(_generate)
	row.add_child(gen)
	var save := UiKit.button("💾 Сохранить", false, 14)
	save.custom_minimum_size = Vector2(140, 42)
	save.pressed.connect(_save)
	row.add_child(save)
	# Диагностика (зона ANIMATE)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	vb.add_child(drow)
	for d in [["🔍 Модели и анимации", _check_models], ["🦴 Скелет героя", _check_skeleton], ["🛠 Исправить копию", _autofix]]:
		var b := UiKit.button(d[0], false, 13)
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(d[1])
		drow.add_child(b)
	var ssc := ScrollContainer.new()
	ssc.custom_minimum_size = Vector2(540, 40)
	vb.add_child(ssc)
	_status = UiKit.label("", 12, Color(1, 1, 1, 0.75))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(530, 0)
	ssc.add_child(_status)
	vb.add_child(UiKit.label("Сохранённые", 13, Color(1, 1, 1, 0.7)))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(540, 50)
	vb.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	_dur.value_changed.connect(func(_v): _labels())
	_amp.value_changed.connect(func(_v): _labels())
	_labels()

func _slider(lo: float, hi: float, step: float, v: float, parent: Control) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.custom_minimum_size = Vector2(250, 20)
	parent.add_child(s)
	return s

func _labels() -> void:
	_dur_l.text = "Длительность: %.1f с" % _dur.value
	_amp_l.text = "Амплитуда: ×%.1f" % _amp.value

func open() -> void:
	_refresh_list()
	_status.text = "Понимает: бег, шаг, удар/меч, рывок, присед, прыжок, взмах, стойка; «быстро», «плавно»."
	visible = true

func close() -> void:
	visible = false
	closed.emit()

## Проверка моделей и анимаций героя и всех монстров (может занять несколько секунд)
func _check_models() -> void:
	if hero == null:
		return
	if _audit == null:
		_audit = AnimateAudit.new()
		add_child(_audit)
	if _audit.running:
		return
	_status.text = "Проверяю модели и анимации…"
	await _audit.run(hero)
	var c := _audit.counts()
	var lines: Array = ["Модели и анимации: ошибок %d, предупреждений %d, заметок %d (отчёт: animate_audit.json)" % [c["ERROR"], c["WARNING"], c["INFO"]]]
	for k in _audit.issues:
		var i: Dictionary = _audit.issues[k]
		if i["sev"] != "INFO" and lines.size() < 12:
			lines.append("%s %s: %s" % ["✖" if i["sev"] == "ERROR" else "⚠", i["subject"], i["msg"]])
	_status.text = "\n".join(lines)

## Проверка скелета героя и созданной анимации
func _check_skeleton() -> void:
	var r := _rig()
	if r.is_empty():
		_status.text = "У героя нет скелета"
		return
	var issues: Array[String] = Inspector.inspect(r[0], _anim)
	_status.text = "Скелет героя%s (%d):\n%s" % [" и анимация" if _anim else "", issues.size(), "\n".join(issues)]

## Безопасное исправление: только копия созданной анимации
func _autofix() -> void:
	var r := _rig()
	if r.is_empty() or _anim == null:
		_status.text = "Сначала сгенерируй движение"
		return
	var rep: Dictionary = AutoFix.fix_animation(_anim, r[0])
	if rep["animation"] != null:
		_anim = rep["animation"]
	_status.text = "Исправление (копия):\n" + "\n".join(rep["changes"])

## Скелет и проигрыватель анимаций героя
func _rig() -> Array:
	if hero == null:
		return []
	var sk: Skeleton3D = hero.get("_sk")
	var ap: AnimationPlayer = hero.get("_anim")
	if sk == null or ap == null:
		return []
	return [sk, ap]

func _generate() -> void:
	var r := _rig()
	if r.is_empty():
		_status.text = "У героя нет скелета с анимациями"
		return
	var sk: Skeleton3D = r[0]
	var ap: AnimationPlayer = r[1]
	var spec: Dictionary = AnimateGenerator.parse_prompt(_prompt.text)
	_motion = spec["motion"]
	var prefix := String(ap.get_node(ap.root_node).get_path_to(sk))
	_anim = AnimateGenerator.generate(sk, _motion, _dur.value, _amp.value * float(spec["intensity"]), 30, prefix)
	_status.text = "Создано: %s, дорожек %d" % [_motion, _anim.get_track_count()]
	_show(_anim, _motion)

func _save() -> void:
	if _anim == null:
		_status.text = "Сначала сгенерируй движение"
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var n := 1
	while FileAccess.file_exists(DIR + "%s_%d.tres" % [_motion, n]):
		n += 1
	var path := DIR + "%s_%d.tres" % [_motion, n]
	var err := ResourceSaver.save(_anim, path)
	_status.text = ("Сохранено: %s" % path.get_file()) if err == OK else ("Ошибка сохранения (%d)" % err)
	_refresh_list()

func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var d := DirAccess.open(DIR)
	if d == null:
		_list.add_child(UiKit.label("Пока ничего", 12, Color(1, 1, 1, 0.5)))
		return
	var files := Array(d.get_files()).filter(func(f): return f.ends_with(".tres"))
	files.sort()
	if files.is_empty():
		_list.add_child(UiKit.label("Пока ничего", 12, Color(1, 1, 1, 0.5)))
	for f in files:
		var row := HBoxContainer.new()
		var l := UiKit.label(f.get_basename(), 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var play := UiKit.button("▶", false, 12)
		play.pressed.connect(func():
			var a = load(DIR + f)
			if a is Animation:
				_show(a, f.get_basename()))
		row.add_child(play)
		var del := UiKit.button("✕", false, 12)
		del.pressed.connect(func():
			DirAccess.remove_absolute(DIR + f)
			_refresh_list())
		row.add_child(del)
		_list.add_child(row)

## Показ на герое: дерево анимаций героя на время выключается, движение крутится по кругу
func _show(anim: Animation, title: String) -> void:
	var r := _rig()
	if r.is_empty():
		return
	var ap: AnimationPlayer = r[1]
	var lib: AnimationLibrary
	if ap.has_animation_library("animate"):
		lib = ap.get_animation_library("animate")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("animate", lib)
	if lib.has_animation("preview"):
		lib.remove_animation("preview")
	var a: Animation = anim.duplicate()
	a.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("preview", a)
	var ha = hero.get("_ha")
	if ha and ha.tree:
		ha.tree.active = false
	ap.active = true
	ap.play("animate/preview")
	close()
	_show_overlay(title)

func _show_overlay(title: String) -> void:
	if _overlay:
		_overlay.queue_free()
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	add_child(_overlay)
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-170, 74)
	box.add_theme_constant_override("separation", 8)
	_overlay.add_child(box)
	var l := UiKit.label(" ✦ ANIMATE: %s " % title, 13, Color(0.75, 0.92, 1))
	box.add_child(l)
	var back := UiKit.button("✦ Окно", false, 12)
	back.pressed.connect(func():
		_stop_show()
		open())
	box.add_child(back)
	var stop := UiKit.button("■ Стоп", false, 12)
	stop.pressed.connect(_stop_show)
	box.add_child(stop)

func _stop_show() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	var r := _rig()
	if r.is_empty():
		return
	var ap: AnimationPlayer = r[1]
	ap.stop()
	var ha = hero.get("_ha")
	if ha and ha.tree:
		ap.active = false
		ha.tree.active = true
