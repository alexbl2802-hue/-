## Экран загрузки (картинка meshy/ui/loading_src.jpg): полоска заполняется по мере загрузки и по ней
## всё время бежит блик. Первый запуск — сначала скачивание данных игры (модели и текстуры, файл
## user://data-<id>.pck из релиза на GitHub), затем загрузка мира. Следующие запуски — только мир.
extends Control

const REPO := "https://github.com/alexbl2802-hue/-/releases/download/"
const MAIN := "res://scenes/main.tscn"
const BAR := Rect2(358, 628, 560, 20)        # полоска на картинке (пиксели 1280×720)
const TEXT := Rect2(440, 578, 400, 40)       # где надпись «Загрузка…»

var _http: HTTPRequest
var _fill: TextureRect
var _shine: TextureRect
var _label: Label
var _note: Label
var _retry: Button
var _part := ""
var _final := ""
var _url := ""
var _shown := 0.0        # что показывает полоска (плавно догоняет _target)
var _target := 0.0
var _t := 0.0
var _phase := ""         # "download" | "load" | "start"

func _ready() -> void:
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
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_child(_note)
	_retry = Button.new()
	_retry.text = "Повторить"
	_retry.visible = false
	_retry.pressed.connect(_download)
	add_child(_retry)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_chunk_size = 1 << 20
	_http.request_completed.connect(_done)
	add_child(_http)
	_layout()
	get_viewport().size_changed.connect(_layout)
	await get_tree().process_frame
	# В редакторе и в сборке, где данные уже внутри, качать нечего
	if ResourceLoader.exists("res://models/hero.glb"):
		_load_world()
		return
	var id := str(ProjectSettings.get_setting("application/config/data_id", ""))
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	_final = "user://data-%s.pck" % id
	_part = _final + ".part"
	if id != "" and FileAccess.file_exists(_final) and ProjectSettings.load_resource_pack(_final, false):
		_load_world()
		return
	var base := OS.get_environment("ZEMLI_DATA_URL")   # для проверки: свой адрес вместо релиза
	_url = (base if base != "" else REPO + "v%s/" % ver) + "data-%s.pck" % id
	_download()

func _layout() -> void:
	var s := get_viewport_rect().size
	ArtScreen.place(_fill, s, BAR)
	_fill.size.x = ArtScreen.map(s, BAR).size.x   # ширину задаёт прогресс (_process)
	ArtScreen.place(_label, s, TEXT)
	var k := ArtScreen.map(s, BAR).size.y
	_label.add_theme_font_size_override("font_size", int(k * 1.35))
	var nb := ArtScreen.map(s, Rect2(BAR.position + Vector2(0, 26), Vector2(BAR.size.x, 24)))
	_note.position = nb.position
	_note.size = nb.size
	_note.add_theme_font_size_override("font_size", int(k * 0.8))
	var rb := ArtScreen.map(s, Rect2(560, 530, 160, 40))
	_retry.position = rb.position
	_retry.size = rb.size

func _process(dt: float) -> void:
	_t += dt
	if _phase == "download" and _http.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := _http.get_body_size()
		var got := _http.get_downloaded_bytes()
		if total > 0:
			_target = 0.85 * got / total
			_note.text = "Данные игры: %d из %d МБ (один раз, лучше по Wi-Fi)" % [got >> 20, total >> 20]
	elif _phase == "load":
		var pr := []
		var st := ResourceLoader.load_threaded_get_status(MAIN, pr)
		if not pr.is_empty():
			_target = maxf(_target, lerpf(_load_from, 0.97, float(pr[0])))
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_phase = "start"
			_target = 1.0
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_phase = ""
			get_tree().change_scene_to_file.call_deferred(MAIN)
	elif _phase == "start" and _shown > 0.995:
		_phase = ""
		_label.text = "Загрузка мира…"
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(MAIN))
		return
	# Полоска плавно догоняет прогресс; пока ждём — сама понемногу ползёт, чтобы не стоять
	if _phase != "" and _shown >= _target - 0.002:
		_target = minf(_target + dt * 0.01, 0.98)
	_shown = move_toward(_shown, _target, dt * 0.9)
	var full := ArtScreen.map(get_viewport_rect().size, BAR).size.x
	_fill.size.x = maxf(2.0, full * _shown)
	# Блик бежит по заполненной части
	var w := _fill.size.y * 5.0
	_shine.size = Vector2(w, _fill.size.y)
	_shine.position = Vector2(fmod(_t * full * 0.6, _fill.size.x + w) - w, 0)
	if not _retry.visible:
		_label.text = "Загрузка" + ".".repeat(1 + int(_t * 2.5) % 3)

var _load_from := 0.0

func _download() -> void:
	_retry.visible = false
	_phase = "download"
	_http.download_file = _part
	var err := _http.request(_url)
	if err != OK:
		_fail("Не удалось начать загрузку (%d)" % err)

func _done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Ошибка загрузки (%d, код %d). Проверь интернет." % [result, code])
		return
	var d := DirAccess.open("user://")
	if d:
		for f in d.get_files():
			if f.begins_with("data-") and "user://" + f != _part:
				d.remove(f)
		d.rename(_part.get_file(), _final.get_file())
	if not ProjectSettings.load_resource_pack(_final, false):
		DirAccess.remove_absolute(_final)
		_fail("Файл данных повреждён — нажми «Повторить».")
		return
	_load_world()

func _load_world() -> void:
	_note.text = ""
	_load_from = _target
	_phase = "load"
	ResourceLoader.load_threaded_request(MAIN)

func _fail(msg: String) -> void:
	_phase = ""
	_note.text = msg
	_label.text = "Ошибка"
	_retry.visible = true
