## CARDINAL 4.0 — реестр систем: что реально есть в запущенной игре. Автотест проверяет только
## имеющиеся системы; отсутствующие получают SKIPPED с причиной из реестра (а не «не проверено»).
class_name CardinalRegistry
extends RefCounted

## Система → проверки автотеста (CardinalAutotest.CHECK_NAMES), которые к ней относятся
const CHECKS := {
	"combat": ["enemy_combat"], "monsters": ["enemy_spawn", "enemy_death"], "bosses": ["boss"],
	"inventory": ["inventory", "equipment"], "skills": ["skills"], "npc": ["npc"], "trade": ["trade", "alchemist"],
	"forge": ["forge"], "quests": ["quests"], "dungeons": ["dungeon"], "loot": ["loot", "weapon_drop"], "saves": ["save_load"],
}

## {система: {"available": bool, "evidence": String}}
static func detect(main: Node) -> Dictionary:
	var r := {}
	var hero = main.get("hero")
	var hud = main.get("hud")
	var en = main.get("enemies")
	var mobs: Array = en.list if en and en.get("list") is Array else []
	r["combat"] = _e(hero != null and hero.has_method("attack") and hero.has_method("use_skill"), "герой: attack(), use_skill()")
	r["monsters"] = _e(mobs.size() > 0, "монстров в мире: %d" % mobs.size())
	var bosses := mobs.filter(func(e): return is_instance_valid(e) and e.T.get("boss", false)).size()
	var ds: Array = main.get("dungeons") if main.get("dungeons") is Array else []
	var boss_floors := ds.filter(func(d): return d.def.has("boss")).size()
	r["bosses"] = _e(bosses > 0 or boss_floors > 0, "боссов создано: %d, этажей/подземелий с боссом: %d" % [bosses, boss_floors])
	r["inventory"] = _e(hud != null and hud.get("inventory") != null, "окно инвентаря")
	var active := SkillDefs.LIST.filter(func(s): return s.get("active", false)).size()
	r["skills"] = _e(hud != null and hud.get("skills") != null and active > 0, "активных навыков: %d" % active)
	var npcs: Array = main.get_tree().get_nodes_in_group("npc")
	r["npc"] = _e(npcs.size() > 0, "NPC в мире: %d" % npcs.size())
	r["trade"] = _e(hud != null and hud.get("alchemist") != null, "лавка алхимика (покупка за золото)")
	r["forge"] = _e(hud != null and hud.get("forge") != null, "кузница")
	var quest_classes := ProjectSettings.get_global_class_list().filter(func(c): return str(c["class"]).to_lower().contains("quest"))
	r["quests"] = _e(not quest_classes.is_empty(), "классов заданий: %d" % quest_classes.size())
	r["dungeons"] = _e(ds.size() > 0, "подземелий и этажей: %d" % ds.size())
	r["loot"] = _e(main.get("loot") != null, "система добычи")
	r["saves"] = _e(Game.has_method("save_game") and Game.has_method("load_game"), "Game.save_game/load_game")
	return r

static func _e(ok: bool, evidence: String) -> Dictionary:
	return {"available": ok, "evidence": evidence}
