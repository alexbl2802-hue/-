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
		'monster': return MONSTERS.get(key, MONSTERS['default']).duplicate(true)
		'boss': return BOSSES.get(key, BOSSES['tower_guardian']).duplicate(true)
		'chest': return CHESTS.get(key, []).duplicate(true)
	return []
