## CARDINAL 4.0: сторож общего предела автотеста — реальное время (Time.get_ticks_msec), не зависит
## от ускорения игры и паузы. Мета "at" — момент (мс), "cb" — что вызвать; срабатывает один раз.
extends Node

func _process(_dt: float) -> void:
	if not has_meta("at") or not has_meta("cb"):
		return
	if Time.get_ticks_msec() >= int(get_meta("at")):
		var cb: Callable = get_meta("cb")
		remove_meta("at")
		remove_meta("cb")
		cb.call()
