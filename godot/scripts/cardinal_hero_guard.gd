## Cardinal 2.1, Error Guardian для героя: если герой провалился под мир (ниже minimum_y)
## или его позиция стала неверной (NaN), он возвращается на последнее место, где стоял на земле.
## Отличие от исходного модуля: «безопасное место» запоминается только когда герой стоит на опоре,
## иначе при падении в пустоту его возвращало бы в точку того же падения.
class_name CardinalHeroGuard
extends CardinalErrorGuardian

func _process(_delta: float) -> void:
	if not is_instance_valid(monitored_player):
		return
	var p := monitored_player.global_position
	var body := monitored_player as CharacterBody3D
	if p.is_finite() and p.y >= minimum_y:
		if safe_position == Vector3.ZERO or (body and body.is_on_floor()):
			safe_position = p
		return
	if core:
		core.report_error("Герой вне мира (%s) — возвращён на %s" % [p, safe_position])
	monitored_player.global_position = safe_position + Vector3.UP * 0.5
	if body:
		body.velocity = Vector3.ZERO
