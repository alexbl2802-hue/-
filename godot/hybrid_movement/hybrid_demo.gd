## Hybrid Movement 3.0 в сборе (по docs/INSTALL_RU.md модуля): CharacterBody3D со скриптом
## hybrid_character.gd, VisualRoot с моделью героя и её AnimationPlayer, мобильный джойстик,
## пять кнопок действий (Прыжок, Рывок, Удар, Бой, Бег) и мост CARDINAL/ANIMATE.
## Сцена: res://hybrid_movement/hybrid_demo.tscn
extends Node3D

const HERO := "res://models/hero.glb"
# Имена клипов модуля → клипы модели героя
const CLIPS := {"idle_anim": "Idle", "walk_anim": "Walking", "run_anim": "RunFast", "combat_idle_anim": "Combat_Stance",
	"combat_move_anim": "Walk_Fight_Forward", "jump_anim": "Basic_Jump", "fall_anim": "Basic_Jump", "dash_anim": "DashJump"}
const ATTACKS := ["Sword_Diagonal_Slash", "Sword_Horizontal_Slash", "Thrust_Slash"]   # Attack1..3
const LOOPED := ["Idle", "Walking", "RunFast", "Combat_Stance", "Walk_Fight_Forward"]

var character: HybridCharacter
var camera: Camera3D
var bridge: HybridCardinalAnimateBridge
var _log: Label
var _lines: Array = []

func _ready() -> void:
	_input_map()
	_world()
	_character()
	_ui()

## Действия для клавиатуры на ПК (шаг 4 инструкции): WASD, Shift, Space, Ctrl, ЛКМ, Tab
func _input_map() -> void:
	var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
		"run": KEY_SHIFT, "jump": KEY_SPACE, "dash": KEY_CTRL, "toggle_combat": KEY_TAB}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var e := InputEventKey.new()
			e.physical_keycode = keys[a]
			InputMap.action_add_event(a, e)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", m)

func _world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	add_child(sun)
	# Площадка из каменных плит и несколько столбов — видно движение
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	mi.mesh = pm
	mi.material_override = Mats.tiled(Mats.stone_path(), 0x74777c, 0.22, 1.0)
	floor_body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	var stone := Mats.tiled(Mats.stone_wall(), 0x7e838b, 0.18)
	for p in [Vector3(-5, 0, -6), Vector3(5, 0, -6), Vector3(-5, 0, 6), Vector3(5, 0, 6), Vector3(0, 0, -12)]:
		var col := StaticBody3D.new()
		col.position = p + Vector3(0, 1.5, 0)
		add_child(col)
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 3, 1.2)
		var m2 := MeshInstance3D.new()
		m2.mesh = bm
		m2.material_override = stone
		col.add_child(m2)
		var c2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = bm.size
		c2.shape = b2
		col.add_child(c2)

func _character() -> void:
	character = HybridCharacter.new()
	character.name = "Hero"
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	character.add_child(shape)
	var visual := Node3D.new()
	visual.name = "VisualRoot"
	character.add_child(visual)
	var model: Node3D = (load(HERO) as PackedScene).instantiate()
	model.rotation.y = PI   # модель Meshy смотрит по +Z, модулю нужно лицом к -Z
	visual.add_child(model)
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	for n in LOOPED:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var lib := ap.get_animation_library("")
	for i in ATTACKS.size():
		if ap.has_animation(ATTACKS[i]) and not ap.has_animation("Attack%d" % (i + 1)):
			lib.add_animation("Attack%d" % (i + 1), ap.get_animation(ATTACKS[i]))
	character.visual_root = visual
	character.animation_player = ap
	for k in CLIPS:
		character.set(k, CLIPS[k])
	character.attack_prefix = "Attack"
	add_child(character)
	camera = Camera3D.new()
	camera.fov = 60
	add_child(camera)
	camera.current = true
	character.camera_pivot = camera
	# Мост: события движения → CARDINAL, проблемы анимаций → ANIMATE (сигнал CARDINAL issue_detected)
	bridge = HybridCardinalAnimateBridge.new()
	bridge.character = character
	bridge.cardinal_event.connect(_on_cardinal_event)
	bridge.animate_issue.connect(func(issue: String, d: Dictionary): Cardinal.issue_detected.emit("ANIMATE_" + issue.to_upper(), str(d)))
	add_child(bridge)

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var joy := HybridMobileJoystick.new()
	joy.character = character
	joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy.offset_left = 24
	joy.offset_top = -204
	joy.offset_right = 204
	joy.offset_bottom = -24
	layer.add_child(joy)
	var names := ["Прыжок", "Рывок", "Удар", "Бой", "Бег"]
	var spots := [Vector2(-120, -230), Vector2(-250, -150), Vector2(-130, -120), Vector2(-250, -270), Vector2(-370, -170)]
	for i in names.size():
		var b := HybridMobileActionButton.new()
		b.character = character
		b.action = i
		b.text = names[i]
		b.add_theme_font_size_override("font_size", 15)
		var r := 46.0 if i == 2 else 36.0
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := UiKit.box(Color(0.07, 0.12, 0.22, 0.7) if st != "pressed" else Color(0.2, 0.4, 0.8, 0.8), Color(0.6, 0.8, 1.0, 0.8), int(r), 0, 2)
			b.add_theme_stylebox_override(st, sb)
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		b.offset_left = spots[i].x - r
		b.offset_top = spots[i].y + 90 - r
		b.offset_right = spots[i].x + r
		b.offset_bottom = spots[i].y + 90 + r
		layer.add_child(b)
	_log = UiKit.label("", 13, Color(0.85, 0.92, 1.0))
	_log.position = Vector2(16, 12)
	layer.add_child(_log)

func _on_cardinal_event(name: String, data: Dictionary) -> void:
	_lines.append("CARDINAL ← %s %s" % [name, str(data) if name != "movement_diagnostics" else ""])
	_lines = _lines.slice(-5)

func _process(_dt: float) -> void:
	# Камера сзади-сверху за героем
	var p := character.global_position
	camera.global_position = camera.global_position.lerp(p + Vector3(0, 3.2, 6.0), 0.15)
	camera.look_at(p + Vector3(0, 1.2, 0))
	var d := character.get_diagnostics()
	_log.text = "Hybrid Movement 3.0 · режим: %s · скорость %.1f м/с · клип: %s\n%s" % [
		"бой" if d["combat_mode"] else "обычный", d["speed"], d["animation"], "\n".join(_lines)]
