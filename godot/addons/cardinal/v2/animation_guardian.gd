extends Node
class_name CardinalAnimationGuardian
## CARDINAL 2.1: diagnostics for AnimationPlayer resources and imported GLB rigs.
## Safe fixes are opt-in; original imported animations should be fixed in source files.
signal issue_found(report: Dictionary)
signal scan_finished(reports: Array[Dictionary])

@export var scan_on_ready := false
@export var allow_safe_fixes := false
@export_range(0.0, 1.0, 0.01) var recommended_blend_seconds := 0.15
@export var required_animation_names: PackedStringArray = []
@export var player_paths: Array[NodePath] = []
var reports: Array[Dictionary] = []

func _ready() -> void:
 if scan_on_ready:
  scan_configured_players()

func scan_configured_players() -> Array[Dictionary]:
 reports.clear()
 for path in player_paths:
  var player := get_node_or_null(path) as AnimationPlayer
  if player == null:
   _issue("ERROR", str(path), "AnimationPlayer не найден", "Исправьте путь в инспекторе")
  else:
   scan_player(player)
 scan_finished.emit(reports)
 return reports

func scan_player(player: AnimationPlayer) -> void:
 if player == null:
  return
 var names := player.get_animation_list()
 for expected in required_animation_names:
  if not names.has(expected):
   _issue("WARNING", str(player.get_path()), "Нет анимации: " + expected, "Добавьте клип или настройте соответствие имён")
 for name in names:
  var animation := player.get_animation(name)
  if animation == null:
   _issue("ERROR", name, "Ресурс анимации не найден", "Проверьте AnimationLibrary")
   continue
  if animation.length <= 0.0:
   _issue("ERROR", name, "Нулевая длительность", "Укажите корректную длительность в исходной анимации")
  if animation.get_track_count() == 0:
   _issue("WARNING", name, "Нет дорожек", "Проверьте импорт GLB")
  for track_index in range(animation.get_track_count()):
   _scan_track(player, animation, name, track_index)
  if name.to_lower().contains("idle") or name.to_lower().contains("walk") or name.to_lower().contains("run"):
   if animation.loop_mode == Animation.LOOP_NONE:
    _issue("INFO", name, "Циклическая анимация без повтора", "Проверьте loop_mode; не меняется автоматически")
 if player.get_animation_list().size() > 0 and player.playback_default_blend_time <= 0.0:
  _issue("INFO", str(player.get_path()), "Нет стандартного смешивания переходов", "Рекомендуется около 0.15 с; настройте под тип движений")
  if allow_safe_fixes:
   player.playback_default_blend_time = recommended_blend_seconds
   _issue("FIXED", str(player.get_path()), "Установлено время смешивания", str(recommended_blend_seconds) + " с")

func _scan_track(player: AnimationPlayer, animation: Animation, animation_name: StringName, index: int) -> void:
 var track_path := animation.track_get_path(index)
 var base := player.get_node_or_null(player.root_node)
 if base == null:
  _issue("ERROR", str(player.get_path()), "Корневой узел анимаций не найден", "Проверьте root_node")
  return
 var target := base.get_node_or_null(NodePath(str(track_path).split(":")[0]))
 if target == null:
  _issue("WARNING", str(animation_name), "Не найден узел дорожки: " + str(track_path), "Проверьте имена узлов и импорт скелета")
 var count := animation.track_get_key_count(index)
 if count == 0:
  _issue("WARNING", str(animation_name), "Пустая дорожка: " + str(track_path), "Удалите или заполните дорожку в исходнике")
 var previous := -1.0
 for key_index in range(count):
  var time := animation.track_get_key_time(index, key_index)
  if time < 0.0 or time > animation.length + 0.001:
   _issue("WARNING", str(animation_name), "Ключ вне длительности: " + str(track_path), "Проверьте тайминг в редакторе")
  if time < previous:
   _issue("ERROR", str(animation_name), "Нарушен порядок ключей", "Переэкспортируйте анимацию")
  previous = time

func _issue(severity: String, subject: String, message: String, advice: String) -> void:
 var report := {"severity": severity, "subject": subject, "message": message, "advice": advice}
 reports.append(report)
 issue_found.emit(report)

func export_report_json(path: String = "user://cardinal_animation_report.json") -> Error:
 var file := FileAccess.open(path, FileAccess.WRITE)
 if file == null:
  return FileAccess.get_open_error()
 file.store_string(JSON.stringify(reports, "  "))
 return OK
