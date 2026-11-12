## Этап 5: интерфейс на разных разрешениях — кнопки (джойстик, удар, спринт, прыжок, защита, перекат,
## навыки, верхняя панель) внутри экрана и не перекрываются, зона джойстика свободна, окна
## (инвентарь, навыки, кузница, алхимик, настройки) целиком на экране.
## Запуск: xvfb-run godot --path godot --resolution 2400x1080 res://tests/ui_layout.tscn
extends Node

var ok := true
func _check(n: String, c: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if c else "FAIL", n, info])
	ok = ok and c

func _circle_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var q := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return q.distance_to(c) < r - 1.0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.hero == null or main.hud == null:
		await get_tree().process_frame
	main.hud.menu._on_main()
	Game.skills = {"dash": 1, "horizontal": 1, "art_sword": 1, "art_great": 1, "art_rapier": 1, "art_dagger": 1}
	for i in 20:
		await get_tree().process_frame
	var t: Control = main.hud.touch
	var vp: Vector2 = t.get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	print("SCREEN %dx%d → интерфейс %dx%d" % [win.x, win.y, vp.x, vp.y])
	var bs: Array = t._buttons()
	var outside: Array = []
	var overlap: Array = []
	var in_joy: Array = []
	var small: Array = []
	var k := float(win.y) / vp.y   # пикселей экрана на единицу интерфейса
	for i in bs.size():
		var a: Dictionary = bs[i]
		if a.has("rect"):
			var r: Rect2 = a["rect"]
			if r.position.x < 0 or r.position.y < 0 or r.end.x > vp.x or r.end.y > vp.y:
				outside.append(a["id"])
			if minf(r.size.x, r.size.y) * k < 40.0:
				small.append(a["id"])
		else:
			var c: Vector2 = a["c"]
			var rr: float = a["r"]
			if c.x - rr < 0 or c.y - rr < 0 or c.x + rr > vp.x or c.y + rr > vp.y:
				outside.append(a["id"])
			if c.x < vp.x * 0.42:
				in_joy.append(a["id"])
			if rr * 2.0 * k < 40.0:
				small.append(a["id"])
		for j in range(i + 1, bs.size()):
			var b: Dictionary = bs[j]
			var hit := false
			if a.has("rect") and b.has("rect"):
				hit = (a["rect"] as Rect2).grow(-1).intersects(b["rect"])
			elif a.has("rect"):
				hit = _circle_rect(b["c"], b["r"], a["rect"])
			elif b.has("rect"):
				hit = _circle_rect(a["c"], a["r"], b["rect"])
			else:
				hit = (a["c"] as Vector2).distance_to(b["c"]) < float(a["r"]) + float(b["r"]) - 1.0
			if hit:
				overlap.append("%s×%s" % [a["id"], b["id"]])
	_check("buttons inside the screen", outside.is_empty(), str(outside))
	_check("buttons do not overlap", overlap.is_empty(), str(overlap))
	_check("joystick zone (left 42%) free of round buttons", in_joy.is_empty(), str(in_joy))
	if win == Vector2i(844, 390):
		print("SKIPPED touch targets >= 40 px  эталонный холст проекта 844×390 (1 пиксель = 1 единица), не экран устройства")
	else:
		_check("touch targets >= 40 px", small.is_empty(), "%s (масштаб %.2f пикс/ед.)" % [str(small), k])
	var mm: Control = main.hud.minimap
	var mm_hit: Array = bs.filter(func(b): return b.has("rect") and (b["rect"] as Rect2).intersects(mm.get_global_rect()))
	_check("top buttons clear of the minimap", mm_hit.is_empty(), str(mm_hit.map(func(b): return b["id"])))
	var plate: Control = main.hud._status.get_parent()
	var pl_hit: Array = bs.filter(func(b): return b.has("rect") and (b["rect"] as Rect2).intersects(plate.get_global_rect()))
	_check("top buttons clear of the name/level plate", pl_hit.is_empty(), str(pl_hit.map(func(b): return b["id"])))
	for pn in ["inventory", "skills", "forge", "alchemist"]:
		var p: Control = main.hud.get(pn)
		p.open()
		for i in 6:
			await get_tree().process_frame
		var panel: Control = p.find_children("*", "PanelContainer", true, false)[0]
		var r := panel.get_global_rect()
		_check("window %s fits on screen" % pn, r.position.x >= -1 and r.position.y >= -1 and r.end.x <= vp.x + 1 and r.end.y <= vp.y + 1,
			"%s в %s" % [r, vp])
		p.close()
		await get_tree().process_frame
	var st: Control = main.hud.menu.settings
	st.open()
	for i in 6:
		await get_tree().process_frame
	var sp: Control = st.find_children("*", "PanelContainer", true, false)[0]
	var sr := sp.get_global_rect()
	_check("window settings fits on screen", sr.position.x >= -1 and sr.position.y >= -1 and sr.end.x <= vp.x + 1 and sr.end.y <= vp.y + 1, "%s в %s" % [sr, vp])
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
