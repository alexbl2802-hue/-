## Этап 5: предметы (шесть рангов, случайный ранг добычи, границы характеристик) и подземелья
## (10 этажей, страж на каждом, финальный — на 10-м, у каждого стража — таблица добычи).
## Запуск: godot --headless --path godot res://tests/items_dungeons.tscn
extends Node

var ok := true
func _check(n: String, c: bool, info := "") -> void:
	print("%s %s  %s" % ["PASS" if c else "FAIL", n, info])
	ok = ok and c

const NAMES := ["Обычный", "Необычный", "Редкий", "Эпический", "Легендарный", "Мифический"]
const GEAR := ["weapon", "armor", "helm", "boots", "ring", "amulet", "cloak", "shield"]

func _ready() -> void:
	# 1. Шесть рангов
	var names: Array = Items.RANKS.map(func(r): return r["name"])
	_check("six rarity levels with expected names", names == NAMES, str(names))
	var mult_ok := true
	for i in range(1, Items.RANKS.size()):
		mult_ok = mult_ok and Items.RANKS[i]["mult"] > Items.RANKS[i - 1]["mult"]
	_check("rarity multipliers increase", mult_ok, str(Items.RANKS.map(func(r): return r["mult"])))
	# 2. Случайный ранг добычи: всегда в 0…5, не ниже базового, все шесть встречаются
	var lm := CardinalLootManager.new()
	lm.rng.seed = 12345
	var seen := {}
	var below_base := 0
	var out_range := 0
	var amount_bad := 0
	var drops := 0
	for k in 40000:
		var enemy: String = Items.LOOT.keys()[k % Items.LOOT.size()]
		for d in lm.roll_enemy(enemy, 1.0 + (k % 5) * 0.5):
			drops += 1
			var it: Dictionary = Items.ALL[d["id"]]
			if int(d["amount"]) < 1:
				amount_bad += 1
			if not it["kind"] in GEAR:
				continue
			var r := int(d["rank"])
			seen[r] = seen.get(r, 0) + 1
			if r < 0 or r > Items.MAX_RANK:
				out_range += 1
			if r < int(it["rank"]):
				below_base += 1
	var ranks := seen.keys()
	ranks.sort()
	_check("loot ranks stay in 0..5 and not below item base", out_range == 0 and below_base == 0, "вне 0…5: %d, ниже базового: %d" % [out_range, below_base])
	_check("all six ranks can drop", ranks == [0, 1, 2, 3, 4, 5], "встречены %s из %d вещей (%d выпадений)" % [str(seen), seen.values().reduce(func(a, b): return a + b, 0), drops])
	_check("drop amounts >= 1", amount_bad == 0, str(amount_bad))
	# 3. Характеристики: на каждом ранге и улучшении — конечные, не отрицательные, в пределах
	var bad: Array = []
	for id in Items.ALL:
		var it: Dictionary = Items.ALL[id]
		if not it["kind"] in GEAR:
			continue
		for r in Items.MAX_RANK + 1:
			for u in [0, Items.MAX_UPGRADE]:
				var inst := Items.make(id, 1, r)
				inst["u"] = u
				for key in ["dmg", "armor", "hp", "speed", "crit", "block"]:
					var base := int(it.get(key, 0))
					var v := Items.stat(inst, key)
					var hi := roundi(base * Items.RANKS[Items.MAX_RANK]["mult"]) + (Items.UPGRADE_DMG * Items.MAX_UPGRADE if key == "dmg" else 0)
					if v < 0 or v > hi or (base > 0 and v < base and not Items.broken(inst)):
						bad.append("%s r%d u%d %s=%d (база %d, предел %d)" % [id, r, u, key, v, base, hi])
	_check("item stats bounded for every rank and upgrade", bad.is_empty(), "; ".join(bad.slice(0, 5)))
	var n0 := Items.normalize({"id": "sword_iron", "r": 99, "u": 999, "d": -5})
	_check("normalize clamps bad saved values", n0["r"] == Items.MAX_RANK and n0["u"] == Items.MAX_UPGRADE and n0["d"] == 0, str(n0))
	# 4. Подземелья: 10 этажей, страж на каждом, финал — 10-й, у стражей есть добыча
	var tower: Array = DungeonDefs.TOWER
	_check("tower has 10 floors", tower.size() == 10, str(tower.size()))
	var no_boss: Array = []
	var no_loot: Array = []
	var finals: Array = []
	for i in tower.size():
		var f: Dictionary = tower[i]
		if not f.has("boss") or not Enemy_TYPES().has(f["boss"]):
			no_boss.append(i + 1)
		elif not Items.LOOT.has(f["boss"]):
			no_loot.append("%d:%s" % [i + 1, f["boss"]])
		if f.get("final", false):
			finals.append(i + 1)
	_check("every floor has a guardian (mini-boss on 1–9)", no_boss.is_empty(), "без стража: %s" % str(no_boss))
	_check("final boss on floor 10 only", finals == [10], str(finals))
	_check("every guardian has a reward table", no_loot.is_empty(), str(no_loot))
	var lv_ok := true
	for i in range(1, tower.size()):
		lv_ok = lv_ok and int(tower[i]["level"]) > int(tower[i - 1]["level"])
	_check("floor levels increase", lv_ok, str(tower.map(func(f): return f["level"])))
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)

func Enemy_TYPES() -> Dictionary:
	return (load("res://scripts/enemy.gd") as Script).get_script_constant_map()["TYPES"]
