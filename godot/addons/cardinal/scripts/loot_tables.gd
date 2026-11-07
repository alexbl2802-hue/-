extends RefCounted
class_name CardinalLootTables
## Таблицы добычи Cardinal под предметы «Земель Приключений» (Items.ALL): эссенция, осколки, золото.
## Это добавка к обычной добыче монстров (scripts/loot.gd); зелья не выпадают — только у алхимика.
const MONSTERS := {
	'wolf': [{'id':'essence','weight':65.0,'min':1,'max':1,'chance':0.5}, {'id':'shard','weight':35.0,'min':1,'max':1,'chance':0.3}],
	'skeleton': [{'id':'gold','weight':70.0,'min':3,'max':8,'chance':0.6}, {'id':'shard','weight':30.0,'min':1,'max':1,'chance':0.35}],
	'spider': [{'id':'essence','weight':80.0,'min':1,'max':2,'chance':0.6}, {'id':'shard','weight':20.0,'min':1,'max':1,'chance':0.3}],
	'default': [{'id':'essence','weight':60.0,'min':1,'max':1,'chance':0.35}, {'id':'gold','weight':40.0,'min':2,'max':6,'chance':0.5}],
}
const BOSSES := {
	'tower_guardian': [{'id':'shard','weight':60.0,'min':2,'max':4,'chance':1.0}, {'id':'essence','weight':40.0,'min':2,'max':3,'chance':1.0}],
}
const CHESTS := {
	'common': [{'id':'gold','weight':80.0,'min':5,'max':20,'chance':1.0}, {'id':'essence','weight':20.0,'min':1,'max':2,'chance':0.8}],
	'rare': [{'id':'gold','weight':60.0,'min':20,'max':60,'chance':1.0}, {'id':'shard','weight':40.0,'min':1,'max':3,'chance':0.85}],
}
static func get_table(kind: String, key: String) -> Array:
	match kind:
		'monster': return _enemy_table(key)
		'boss': return _enemy_table(key)
		'chest': return CHESTS.get(key, []).duplicate(true)
	return []

static func _enemy_table(key: String) -> Array:
	if not Items.LOOT.has(key):
		return []
	var pool: Array = Items.LOOT[key].get("pool", [])
	var output: Array = []
	for id in pool:
		if Items.ALL.has(str(id)):
			output.append({"id": str(id), "weight": Items.RANK_WEIGHTS[clampi(int(Items.ALL[str(id)]["rank"]), 0, Items.MAX_RANK)], "chance": 1.0, "min": 1, "max": 1})
	return output
