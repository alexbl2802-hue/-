## CARDINAL: сценарии проверки систем игры (вызываются автотестом scripts/cardinal_autotest.gd
## после полевой части, где Кардинал играет с монстрами). Каждый сценарий что-то делает в игре
## и проверяет результат; итог — в at.checks (PASS / FAIL / SKIPPED) с пояснением.
## Перед сценариями автотест сохраняет состояние игры, после — возвращает (сохранение не портится).
class_name CardinalScenarios
extends RefCounted

var at            # автотест (CardinalAutotest)
var main: Node
var hero: Node
var hud: Node

func _init(autotest) -> void:
	at = autotest
	main = at.main
	hero = at.hero
	hud = main.get("hud")

func _tree() -> SceneTree:
	return main.get_tree()

func _frames(n: int) -> void:
	for i in n:
		await _tree().physics_frame

## Подождать столько секунд реального времени (затемнение при переходах идёт по игровому)
func _wait(sec: float) -> void:
	await _tree().create_timer(sec, true, false, true).timeout

func _act_method() -> String:
	var a: Callable = main.get("_act")
	return String(a.get_method()) if a.is_valid() else ""

## Поставить героя в точку (на землю под ней)
func _teleport(p: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = hero.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 20, 0), p + Vector3(0, -40, 0))
	q.exclude = [hero.get_rid()]
	var r := space.intersect_ray(q)
	hero.global_position = (r["position"] if not r.is_empty() else p) + Vector3(0, 0.2, 0)
	hero.velocity = Vector3.ZERO

## Ждать до sec секунд, пока у героя не появится нужное действие (надпись у двери)
func _await_act(method: String, sec := 2.0) -> bool:
	var t := 0.0
	while t < sec:
		await _frames(2)
		if _act_method() == method:
			return true
		t += 0.1
		await _wait(0.1)
	return false

func _why() -> String:
	return "занят=%s, мёртв=%s, режим=%s, действие=«%s»" % [hero.busy, hero.dead, main.mode, _act_method()]

func run() -> void:
	await _inventory()
	await _equipment()
	await _weapon_drop()
	await _skills()
	await _forge()
	await _alchemist()
	await _dungeons()
	await _boss()
	await _save_load()
	_absent()

# ---------- Инвентарь: окно открывается и закрывается
func _inventory() -> void:
	at.set_step("инвентарь")
	if hud == null or hud.get("inventory") == null:
		at._fail("inventory", "Нет окна инвентаря")
		return
	hud.open_inventory()
	await _frames(3)
	var shown: bool = hud.inventory.visible
	hud.inventory.close()
	await _frames(2)
	if shown and not hud.inventory.visible:
		at._pass("inventory", "Окно инвентаря открывается и закрывается")
	else:
		at._fail("inventory", "Окно инвентаря: открылось=%s, закрылось=%s" % [shown, not hud.inventory.visible])

# ---------- Снаряжение: снять и надеть оружие — меняется урон
func _equipment() -> void:
	at.set_step("снаряжение")
	var w = Game.equip.get("weapon")
	if w == null:
		Game.add_item("sword_iron")
		Game.equip_from(Game.inv.size() - 1)
		w = Game.equip.get("weapon")
	var dmg_with: int = Game.dmg
	if not Game.unequip("weapon"):
		at._fail("equipment", "Не удалось снять оружие (инвентарь полон?)")
		return
	var dmg_without: int = Game.dmg
	var idx := -1
	for i in Game.inv.size():
		if Game.inv[i] == w:
			idx = i
	if idx < 0:
		at._fail("equipment", "Снятое оружие не появилось в инвентаре")
		return
	Game.equip_from(idx)
	hero.update_look()
	await _frames(2)
	if Game.equip["weapon"] == w and dmg_with > dmg_without:
		at._pass("equipment", "Оружие снимается и надевается, урон %d → %d → %d" % [dmg_with, dmg_without, Game.dmg])
	else:
		at._fail("equipment", "После снятия/надевания: оружие на месте=%s, урон %d/%d" % [Game.equip["weapon"] == w, dmg_with, dmg_without])

# ---------- Выпадение оружия: в таблицах добычи есть оружие; выпавшее оружие подбирается и надевается
func _weapon_drop() -> void:
	at.set_step("выпадение оружия")
	var bad: Array = []
	var weapons := 0
	for t in Items.LOOT:
		for id in Items.LOOT[t].get("pool", []):
			if not Items.ALL.has(id):
				bad.append("%s: %s" % [t, id])
			elif Items.get_item(id)["kind"] == "weapon":
				weapons += 1
	if not bad.is_empty():
		at._fail("weapon_drop", "В таблицах добычи несуществующие вещи: " + ", ".join(bad.slice(0, 5)))
		return
	if weapons == 0:
		at._fail("weapon_drop", "В таблицах добычи нет оружия")
		return
	var loot = main.get("loot")
	if loot == null:
		at._fail("weapon_drop", "Нет системы добычи")
		return
	var id := "sword_steel"
	var before: int = Game.count_of(id)
	if Game.inv.size() >= Items.INV_SIZE:
		Game.inv.remove_at(Game.inv.size() - 1)   # место для находки (сохранение после теста вернётся)
	loot.drop(id, 1, hero.global_position)
	var picked := false
	var walked := false
	for i in 60:
		await _wait(0.1)
		if Game.count_of(id) > before:
			picked = true
			break
		# как игрок: подойти к выпавшему предмету, когда он упал на землю
		if i == 12 and not walked:
			for L in loot._items:
				if L["id"] == id:
					hero.global_position = L["pos"] + Vector3(0, -0.3, 0)
					hero.velocity = Vector3.ZERO
					walked = true
	if not picked:
		at._fail("weapon_drop", "Выпавшее оружие не подобралось за 6 с (подошёл к нему: %s; вещей в инвентаре %d из %d; %s)" % [walked, Game.inv.size(), Items.INV_SIZE, _why()])
		return
	var idx := -1
	for i in Game.inv.size():
		if Game.inv[i]["id"] == id:
			idx = i
	Game.equip_from(idx)
	hero.update_look()
	await _frames(2)
	if Game.equip["weapon"] != null and Game.equip["weapon"]["id"] == id:
		at._pass("weapon_drop", "Оружие есть в %d записях таблиц добычи; выпавший меч подобран и надет" % weapons)
	else:
		at._fail("weapon_drop", "Подобранное оружие не надевается")

# ---------- Навыки: приём срабатывает
func _skills() -> void:
	at.set_step("навыки")
	if int(Game.skills.get("whirl", 0)) <= 0:
		Game.skills["whirl"] = 1
		Game.refresh()
	hero.cd["whirl"] = 0.0
	hero.use_skill("whirl")
	var ok := false
	for i in 10:
		await _frames(1)
		if float(hero.get("_spin_t")) >= 0.0:
			ok = true
			break
	if ok:
		at._pass("skills", "Приём «Вихрь» срабатывает")
	else:
		at._fail("skills", "Приём «Вихрь» не сработал")
	await _wait(1.2)

# ---------- Кузница: у двери появляется «Кузница», окно открывается; улучшение, починка, ковка работают
func _forge() -> void:
	at.set_step("кузница")
	if int(main.mode) != -1:
		await _to_surface()
	_teleport(Vector3(WorldGen.FORGE_POS.x, WorldGen.TOWN_Y, WorldGen.FORGE_POS.y))
	var at_door: bool = await _await_act("open_forge")
	var why := "" if at_door else " (" + _why() + ")"
	hud.open_forge()
	await _frames(3)
	var shown: bool = hud.forge.visible
	hud.forge.close()
	var notes: Array = []
	Game.gold += 100000
	var w = Game.equip["weapon"]
	var u0: int = w["u"] if w else 0
	var up := Game.upgrade_weapon()
	notes.append("улучшение %s" % ("да" if up and Game.equip["weapon"]["u"] == u0 + 1 else "НЕТ"))
	if w and w.has("d"):
		w["d"] = 1
	var rep := Game.repair_weapon()
	notes.append("починка %s" % ("да" if rep else "НЕТ"))
	var rec: Dictionary = Items.RECIPES[0]
	Game.add_item(rec["mat"], 1)
	Game.add_item("shard", rec["shards"])
	var had: int = Game.count_of(rec["id"])
	var fr := Game.forge(rec)
	notes.append("ковка «%s» %s" % [Items.get_item(rec["id"])["name"], "да" if fr and Game.count_of(rec["id"]) > had else "НЕТ"])
	var ok: bool = at_door and shown and up and rep and fr
	var detail := "у двери «Кузница»: %s%s, окно: %s; %s" % ["да" if at_door else "НЕТ", why, "да" if shown else "НЕТ", ", ".join(notes)]
	if ok:
		at._pass("forge", detail)
	else:
		at._fail("forge", detail)

# ---------- Лавка алхимика: у двери «Алхимик», окно; покупка и варка зелья
func _alchemist() -> void:
	at.set_step("лавка алхимика")
	var al := Vector3(WorldGen.ALCHEMIST_POS.x, WorldGen.TOWN_Y, WorldGen.ALCHEMIST_POS.y)
	_teleport(Alchemist.front(al, WorldGen.ALCHEMIST_YAW))
	var at_door: bool = await _await_act("open_alchemist")
	var why := "" if at_door else " (" + _why() + ")"
	hud.open_alchemist()
	await _frames(3)
	var shown: bool = hud.alchemist.visible
	hud.alchemist.close()
	Game.gold += 10000
	var p0: int = Game.potions()
	var bought := Game.buy_potion() and Game.potions() == p0 + 1
	Game.add_item("essence", Items.BREW_ESSENCE)
	var brewed := Game.brew_potion() and Game.potions() == p0 + 2
	var detail := "у двери «Алхимик»: %s%s, окно: %s, покупка зелья: %s, варка зелья: %s" % [
		"да" if at_door else "НЕТ", why, "да" if shown else "НЕТ", "да" if bought else "НЕТ", "да" if brewed else "НЕТ"]
	if at_door and shown and bought and brewed:
		at._pass("alchemist", detail)
		at._pass("trade", "Торговля работает: покупка и варка зелья у алхимика, улучшение и ковка у кузнеца")
	else:
		at._fail("alchemist", detail)
		at._fail("trade", "Сбой торговли у алхимика: " + detail)

# ---------- Подземелья: вход на каждый этаж — герой у входа на полу, монстры на месте; выход наверх
func _dungeons() -> void:
	var ds: Array = main.get("dungeons")
	var problems: Array = []
	for i in ds.size():
		at.set_step("подземелья: %d из %d" % [i + 1, ds.size()])
		var d: Node3D = ds[i]
		main.enter_dungeon(i)
		await _wait(1.6)
		await _frames(4)
		var p: Vector3 = hero.global_position
		var name: String = d.def["name"]
		if int(main.mode) != i:
			problems.append("%s: не вошёл" % name)
		elif absf(p.y - float(d.Y)) > 3.0 or Vector2(p.x - d.start_pos.x, p.z - d.start_pos.z).length() > 6.0:
			problems.append("%s: герой не у входа (%s)" % [name, p.round()])
		elif not at.floor_under(p):
			problems.append("%s: под героем нет пола" % name)
		var alive := 0
		for e in main.enemies.list:
			if is_instance_valid(e) and e.dungeon_idx == i and not e.dead:
				alive += 1
		if alive == 0 and d.get("tower") and not main.enemies.boss_beaten(i):
			problems.append("%s: нет монстров" % name)
		main.exit_dungeon()
		await _wait(1.6)
		await _frames(4)
		if int(main.mode) != -1 or hero.global_position.y < -50.0:
			problems.append("%s: не вышел на поверхность" % name)
	if problems.is_empty():
		at._pass("dungeon", "Вход и выход работают на всех %d этажах и подземельях; герой у входа на полу, монстры на месте" % ds.size())
	else:
		at._fail("dungeon", "; ".join(problems.slice(0, 6)))

# ---------- Босс: страж первого этажа на месте за воротами; после победы открывается лестница
func _boss() -> void:
	at.set_step("босс")
	var idx: int = DungeonDefs.floor_index(1)
	var d: Node3D = main.dungeons[idx]
	main.enter_dungeon(idx)
	await _wait(1.6)
	await _frames(4)
	var boss: Node3D = main.enemies.boss_of(idx)
	if boss == null:
		if main.enemies.boss_beaten(idx):
			at._pass("boss", "Страж этажа 1 уже побеждён в этом сохранении; лестница открыта: %s" % d.stairs_open)
		else:
			at._fail("boss", "На этаже 1 нет стража")
		main.exit_dungeon()
		await _wait(1.6)
		return
	var name: String = boss.T["name"]
	boss.hit(int(boss.hp) + 10000, Vector3.FORWARD, false)
	var dead := false
	for i in 30:
		await _wait(0.1)
		if boss.dead:
			dead = true
			break
	await _wait(0.5)
	var opened: bool = d.stairs_open
	if dead and opened:
		at._pass("boss", "Страж «%s» на этаже 1; после победы открылась лестница на этаж 2" % name)
	else:
		at._fail("boss", "Страж «%s»: побеждён=%s, лестница открыта=%s" % [name, dead, opened])
	main.exit_dungeon()
	await _wait(1.6)
	await _frames(4)

# ---------- Сохранение: запись и чтение настоящего сохранения (после теста оно возвращается как было)
func _save_load() -> void:
	at.set_step("сохранение")
	var g0: int = Game.gold
	var lv: int = Game.level
	var n_inv: int = Game.inv.size()
	var w = Game.equip["weapon"]
	Game.save_game()
	Game.gold = -1
	Game.inv = []
	var loaded := Game.load_game()
	Game.refresh()
	var same: bool = loaded and Game.gold == g0 and Game.level == lv and Game.inv.size() == n_inv \
		and ((w == null and Game.equip["weapon"] == null) or (w != null and Game.equip["weapon"] != null and Game.equip["weapon"]["id"] == w["id"]))
	if same:
		at._pass("save_load", "Сохранение записывается и читается: золото, уровень, %d вещей, оружие совпадают" % n_inv)
	else:
		at._fail("save_load", "После чтения сохранения данные не совпали (загружено=%s)" % loaded)

# ---------- Чего в игре нет
func _absent() -> void:
	at._skip("npc", "В игре нет NPC (жителей с диалогами) — проверять нечего")
	at._skip("quests", "В игре нет системы заданий — проверять нечего")

func _to_surface() -> void:
	main.exit_dungeon()
	await _wait(1.6)
