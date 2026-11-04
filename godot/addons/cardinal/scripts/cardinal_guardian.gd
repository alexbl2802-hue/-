extends Node
class_name CardinalGuardian
## Безопасная диагностика и восстановление только известных состояний.
signal diagnostic(level: String, code: String, message: String)
@export var scan_interval := 5.0
@export var auto_repair := true
var _elapsed := 0.0
func _ready() -> void:
    Cardinal.issue_detected.connect(_on_issue)
    Cardinal.issue_recovered.connect(_on_recovered)
func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < maxf(scan_interval, 1.0): return
    _elapsed = 0.0
    scan()
func scan() -> void:
    var counts := Cardinal.active_counts()
    if counts['mobs'] > Cardinal.max_active_mobs:
        diagnostic.emit('warning','MOB_OVERFLOW','Активных монстров больше лимита; новые появления заблокированы')
    if Cardinal.max_active_mobs < 1 or not is_finite(Cardinal.difficulty):
        diagnostic.emit('error','CONFIG','Обнаружена некорректная конфигурация')
        if auto_repair: Cardinal._monitor_health()
func _on_issue(code: String, message: String) -> void:
    diagnostic.emit('error', code, message)
func _on_recovered(code: String) -> void:
    diagnostic.emit('info', code, 'Восстановлено безопасное значение')
