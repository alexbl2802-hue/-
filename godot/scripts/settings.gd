## Настройки игры: чувствительность камеры, тени, дальность прорисовки, счётчик кадров.
## Хранятся отдельно от прогресса — в user://settings.cfg.
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"
## Дальность прорисовки: [камера, конец тумана, камни]
const VIEW := [
	{"name": "Ближе", "far": 450.0, "fog": 260.0, "rocks": 120.0},
	{"name": "Обычно", "far": 1000.0, "fog": 420.0, "rocks": 200.0},
	{"name": "Дальше", "far": 1500.0, "fog": 620.0, "rocks": 300.0},
]

## Профили качества для слабых / средних / мощных устройств (замеры — reports/BASELINE.md, этап 6):
## lod — порог упрощения моделей (пикселей экрана; больше — проще модели вдали), tree_full — до какого
## расстояния деревья полной модели (дальше — упрощённая копия), shadows/view — тени и дальность.
## «Высокое» — прежний вид игры (по умолчанию).
const QUALITY := [
	{"name": "Низкое", "lod": 8.0, "tree_full": 0.0, "shadows": false, "view": 0},
	{"name": "Среднее", "lod": 4.0, "tree_full": 10.0, "shadows": true, "view": 1},
	{"name": "Высокое", "lod": 1.0, "tree_full": 25.0, "shadows": true, "view": 1},
]
static var quality := 2
static var cam_sens := 1.0
static var shadows := true
static var view := 1
static var show_fps := false
## Скрытый режим администратора (окна CARDINAL и ANIMATE). Обычный игрок кнопку не видит;
## включается 7 нажатиями на номер версии в главном меню.
static var admin := false
static var _loaded := false

static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	cam_sens = clampf(float(cf.get_value("game", "cam_sens", 1.0)), 0.5, 2.0)
	shadows = bool(cf.get_value("game", "shadows", true))
	view = clampi(int(cf.get_value("game", "view", 1)), 0, VIEW.size() - 1)
	show_fps = bool(cf.get_value("game", "show_fps", false))
	admin = bool(cf.get_value("game", "admin", false))
	quality = clampi(int(cf.get_value("game", "quality", 2)), 0, QUALITY.size() - 1)

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "cam_sens", cam_sens)
	cf.set_value("game", "shadows", shadows)
	cf.set_value("game", "view", view)
	cf.set_value("game", "show_fps", show_fps)
	cf.set_value("game", "admin", admin)
	cf.set_value("game", "quality", quality)
	cf.save(PATH)
