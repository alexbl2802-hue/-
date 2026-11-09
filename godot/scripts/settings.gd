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

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "cam_sens", cam_sens)
	cf.set_value("game", "shadows", shadows)
	cf.set_value("game", "view", view)
	cf.set_value("game", "show_fps", show_fps)
	cf.set_value("game", "admin", admin)
	cf.save(PATH)
