## Запечь клипы ANIMATE 4.0 для героя в res://data/anim/ (входят в APK; игра их только загружает):
## стойка с одним мечом, блок щитом и уборка меча в ножны за спину. Запуск (в проекте, не на телефоне):
## godot --headless --path godot res://tests/animate4_bake.tscn
extends Node

const CLIPS := [["hero_stance_sword", "стойка с мечом"], ["hero_block_shield", "блок щитом"], ["hero_sheathe", "убрать меч в ножны"]]

func _ready() -> void:
	for k in Game.equip:
		Game.equip[k] = null
	Game.equip["weapon"] = Items.make("sword_iron")
	var h: CharacterBody3D = preload("res://scripts/hero.gd").new()
	add_child(h)
	await get_tree().process_frame
	h.set_physics_process(false)
	var ap: AnimationPlayer = h._anim
	var sk: Skeleton3D = h._sk
	var prefix := String(ap.get_node(ap.root_node).get_path_to(sk))
	var blade: Vector3 = h._sword.transform.basis.y.normalized()
	var ref: Animation = ap.get_animation("Combat_Stance")
	var ok := true
	DirAccess.make_dir_recursive_absolute("res://data/anim")
	for c in CLIPS:
		var r := AnimatePipeline.generate(c[1], sk, prefix, {"blade": blade, "ref": ref, "ref_t": 0.0})
		var line := "%s %s «%s»" % ["PASS" if r["ok"] else "FAIL", c[0], c[1]]
		for ch in r.get("report", {}).get("checks", []):
			if not ch["ok"]:
				line += " | " + ch["name"] + ": " + ch["detail"]
		print(line)
		ok = ok and r["ok"]
		if r.has("animation"):
			var err := ResourceSaver.save(r["animation"], "res://data/anim/%s.res" % c[0])
			print("  сохранено res://data/anim/%s.res (%d)" % [c[0], err])
	print("RESULT: %s" % ("ALL OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
