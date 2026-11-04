extends Node
class_name CardinalPerformanceManager
@export var core: CardinalCore
@export var low_fps_threshold := 25.0
var elapsed := 0.0
func _process(delta: float) -> void:
 elapsed += delta
 if elapsed < 5.0: return
 elapsed = 0.0
 if core == null: return
 if Engine.get_frames_per_second() < low_fps_threshold:
  core.max_monsters = maxi(10, core.max_monsters - 5)
  core.log_event("Low FPS: spawn cap reduced")
