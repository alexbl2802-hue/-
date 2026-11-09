extends Node
class_name CardinalPerformanceManager
## Монитор частоты кадров: при низкой — уменьшает лимит бодрствующих монстров (Cardinal.max_active_mobs,
## его читает enemies.gd), когда кадров снова хватает — возвращает. Пороги — CardinalConfig.
@export var core: CardinalCore
@export var low_fps_threshold := CardinalConfig.LOW_FPS
var elapsed := 0.0
var _good := 0
func _process(delta: float) -> void:
 elapsed += delta
 if elapsed < CardinalConfig.PERF_CHECK_SECONDS: return
 elapsed = 0.0
 if core == null: return
 var fps := float(Engine.get_frames_per_second())
 if fps < low_fps_threshold:
  _good = 0
  if core.max_monsters > CardinalConfig.ACTIVE_MOBS_MIN:
   core.max_monsters = maxi(CardinalConfig.ACTIVE_MOBS_MIN, core.max_monsters - CardinalConfig.ACTIVE_MOBS_STEP)
   core.log_event("Мало кадров (%.0f/с): бодрствующих монстров не больше %d" % [fps, core.max_monsters])
 elif fps > CardinalConfig.RECOVER_FPS and core.max_monsters < CardinalConfig.ACTIVE_MOBS_DEFAULT:
  _good += 1
  if _good >= 3:
   _good = 0
   core.max_monsters = mini(CardinalConfig.ACTIVE_MOBS_DEFAULT, core.max_monsters + CardinalConfig.ACTIVE_MOBS_STEP)
   core.log_event("Кадров достаточно (%.0f/с): бодрствующих монстров снова до %d" % [fps, core.max_monsters])
 else:
  _good = 0
