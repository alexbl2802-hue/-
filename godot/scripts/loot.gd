## Добыча на земле: золото, зелья и вещи. Подбирается, когда герой подходит близко.
extends Node3D

var hero: Node3D
var _items: Array = []   # [{id, n, r, node, pos, vy, base, t}]
var _full_warn := 0.0
var _mesh := {}
var _mat := {}

func _ready() -> void:
	var coin := CylinderMesh.new()
	coin.top_radius = 0.16; coin.bottom_radius = 0.16; coin.height = 0.05; coin.radial_segments = 10
	var gem := SphereMesh.new()  # 4×2 сегмента — получается октаэдр
	gem.radius = 0.24; gem.height = 0.48; gem.radial_segments = 4; gem.rings = 2
	var bottle := CylinderMesh.new()
	bottle.top_radius = 0.12; bottle.bottom_radius = 0.14; bottle.height = 0.26; bottle.radial_segments = 8
	var neck := CylinderMesh.new()
	neck.top_radius = 0.05; neck.bottom_radius = 0.05; neck.height = 0.12; neck.radial_segments = 6
	var beam := CylinderMesh.new()
	beam.top_radius = 0.06; beam.bottom_radius = 0.06; beam.height = 2.6; beam.radial_segments = 6
	beam.cap_top = false; beam.cap_bottom = false
	_mesh = {"coin": coin, "gem": gem, "bottle": bottle, "neck": neck, "beam": beam}
	_mat = {
		"gold": Mats.lp(0xffd34d, 0.3, 0.8, 0x6a4a00, 1.0),
		"potion": Mats.lp(0xff4040, 0.2, 0.0, 0x801010, 1.0),
		"cork": Mats.lp(0x8a6a40),
	}
	_mat["shard"] = Mats.lp(0x9a5cff, 0.2, 0.0, 0x6a2aff, 1.4)
	for r in Items.RANKS.size():
		var c: Color = Items.RANKS[r]["color"]
		_mat["gem%d" % r] = Mats.lp(c.to_rgba32() >> 8, 0.2, 0.0, c.to_rgba32() >> 8, 0.45)
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.albedo_color = Color(c, 0.35)
		_mat["beam%d" % r] = bm

func _part(parent: Node3D, mesh_key: String, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh[mesh_key]
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func drop(id: String, n: int, at: Vector3, r := -1) -> void:
	if r < 0:
		r = Items.get_item(id)["rank"]
	var node := Node3D.new()
	if id == "gold":
		for k in 3:
			_part(node, "coin", _mat["gold"], Vector3((k - 1) * 0.12, k * 0.06, (k % 2) * 0.1))
	elif id == "potion":
		_part(node, "bottle", _mat["potion"], Vector3.ZERO)
		_part(node, "neck", _mat["cork"], Vector3(0, 0.19, 0))
	elif id == "shard":
		for k in 2:
			_part(node, "gem", _mat["shard"], Vector3((k - 0.5) * 0.2, k * 0.08, 0))
	else:
		_part(node, "gem", _mat["gem%d" % r], Vector3.ZERO)
		_part(node, "beam", _mat["beam%d" % r], Vector3(0, 1.2, 0))
	var a := randf() * TAU
	var rr := 0.5 + randf()
	var pos := at + Vector3(cos(a) * rr, 0.9, sin(a) * rr)
	# Подземелья лежат глубоко под миром: там пол — высота, на которой выпала вещь
	var base := at.y if at.y < -50.0 else WorldGen.ground_at(pos.x, pos.z)
	add_child(node)
	node.global_position = pos
	_items.append({"id": id, "n": n, "r": r, "node": node, "pos": pos, "vy": 5.0, "base": base, "t": 0.0})

## Бросаем кости: что выпало из монстра
func roll(type: String, at: Vector3) -> void:
	var t: Dictionary = Items.LOOT[type]
	var g: Array = t["gold"]
	if randf() < g[0]:
		drop("gold", randi_range(g[1], g[2]), at)
	if randf() < t["potion"]:
		drop("potion", 1, at)
	if randf() < t["item"]:
		# Эпические вещи выпадают реже
		var pool: Array = t["pool"]
		var w := []
		var total := 0.0
		for id in pool:
			var wt: float = [1.0, 0.6, 0.25, 0.15, 0.1][Items.get_item(id)["rank"]]
			w.append(wt)
			total += wt
		var r := randf() * total
		var k := 0
		while k < pool.size() - 1:
			r -= w[k]
			if r <= 0.0:
				break
			k += 1
		drop(pool[k], 1, at)
	# Тёмные осколки — только с монстров подземелий
	if t.has("shard") and randf() < t["shard"][0]:
		drop("shard", randi_range(t["shard"][1], t["shard"][2]), at)

func _process(dt: float) -> void:
	_full_warn -= dt
	for i in range(_items.size() - 1, -1, -1):
		var L: Dictionary = _items[i]
		L["t"] += dt
		if L["t"] > 180.0:
			L["node"].queue_free()
			_items.remove_at(i)
			continue
		var pos: Vector3 = L["pos"]
		if L["vy"] != null:
			L["vy"] -= 20.0 * dt
			pos.y += L["vy"] * dt
			if pos.y <= L["base"] + 0.35:
				pos.y = L["base"] + 0.35
				L["vy"] = null
		else:
			pos.y = L["base"] + 0.35 + sin(L["t"] * 3.0) * 0.08
		L["pos"] = pos
		var node: Node3D = L["node"]
		node.global_position = pos
		node.rotation.y += dt * 2.0
		if hero and L["t"] > 0.6 and not hero.dead:
			var hp: Vector3 = hero.global_position
			if Vector2(pos.x - hp.x, pos.z - hp.z).length() < 1.5 and absf(pos.y - hp.y) < 2.5:
				if _pickup(L):
					node.queue_free()
					_items.remove_at(i)

func _pickup(L: Dictionary) -> bool:
	var id: String = L["id"]
	var n: int = L["n"]
	if not Game.add_item(id, n, L["r"]):
		if _full_warn <= 0.0:
			Fx.text("Инвентарь полон", hero.global_position, Color("#ff8a6a"))
			_full_warn = 3.0
		return false
	var it := Items.get_item(id)
	if id == "gold":
		Fx.text("+%d 🪙" % n, L["pos"], Color("#ffd34d"))
	else:
		Fx.text("%s %s%s" % [it["icon"], it["name"], " ×%d" % n if n > 1 else ""], L["pos"], Items.RANKS[L["r"]]["color"])
	Game.save_game()
	Game.changed.emit()
	return true
