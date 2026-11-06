## Cardinal 2.1, Error Guardian для героя: если герой провалился под мир (ниже minimum_y)
## или его позиция стала неверной (NaN), он возвращается на последнее место, где стоял на земле.
## Отличие от исходного модуля: «безопасное место» запоминается только когда герой стоит на опоре,
## иначе при падении в пустоту его возвращало бы в точку того же падения.
class_name CardinalHeroGuard
extends CardinalErrorGuardian

var _last := Vector3.INF

func _process(_delta: float) -> void:
	if not is_instance_valid(monitored_player):
		return
	var p := monitored_player.global_position
	var body := monitored_player as CharacterBody3D
	# Граница провала — у каждого места своя (подземелья и этажи башни глубоко внизу)
	var main: Node = CardinalDirector._main
	if is_instance_valid(main) and main.get("mode") != null:
		minimum_y = CardinalDirector.fall_y_at(p, int(main.mode))
	# Переход в другое место (вход на этаж, портал, возрождение) — прежнее безопасное место не годится
	if p.is_finite() and (_last == Vector3.INF or _last.distance_to(p) > 30.0):
		safe_position = p
	_last = p
	if p.is_finite() and p.y >= minimum_y:
		if safe_position == Vector3.ZERO or (body and body.is_on_floor()):
			safe_position = p
		return
	if core:
		core.report_error("Герой вне мира (%s) — возвращён на %s" % [p, safe_position])
	monitored_player.global_position = safe_position + Vector3.UP * 0.5
	_last = monitored_player.global_position
	if body:
		body.velocity = Vector3.ZERO
