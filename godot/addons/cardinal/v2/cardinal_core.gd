extends Node
class_name CardinalCore
signal event_logged(message: String)
var spawn_multiplier := 1.0
## Множитель добычи — хранится в CardinalBalance (единый источник, CARDINAL 4.0)
var loot_multiplier: float:
 get: return CardinalBalance.loot_multiplier
 set(v): CardinalBalance.loot_multiplier = clampf(v, CardinalConfig.LOOT_MULT_MIN, CardinalConfig.LOOT_MULT_MAX)
var active_monsters := 0
## Лимит бодрствующих монстров — тот же, что у autoload Cardinal (единый источник, CARDINAL 4.0)
var max_monsters: int:
 get: return Cardinal.max_active_mobs
 set(v): Cardinal.max_active_mobs = clampi(v, CardinalConfig.ACTIVE_MOBS_MIN, CardinalConfig.REGISTERED_MOBS_MAX)
var error_count := 0
var event_log: Array[String] = []
func log_event(message: String) -> void:
 event_log.append(message)
 if event_log.size() > 200: event_log.pop_front()
 event_logged.emit(message)
func can_spawn() -> bool:
 return active_monsters < max_monsters
func register_spawn() -> bool:
 if not can_spawn(): return false
 active_monsters += 1
 return true
func register_despawn() -> void:
 active_monsters = maxi(0, active_monsters - 1)
func report_error(message: String) -> void:
 error_count += 1
 log_event("ERROR: " + message)
func set_spawn_multiplier(value: float) -> void:
 spawn_multiplier = clampf(value, 0.1, 3.0)
func set_loot_multiplier(value: float) -> void:
 loot_multiplier = clampf(value, CardinalConfig.LOOT_MULT_MIN, CardinalConfig.LOOT_MULT_MAX)
