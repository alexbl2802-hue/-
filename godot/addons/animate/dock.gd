@tool
extends VBoxContainer

const Generator = preload("res://addons/animate/generator.gd")
var editor: EditorPlugin
var skeleton: Skeleton3D
var player: AnimationPlayer
var status: Label
var prompt: TextEdit
var duration: SpinBox
var intensity: SpinBox
var bone_picker: OptionButton
var angle_x: HSlider
var angle_y: HSlider
var angle_z: HSlider
var pose_keys: Dictionary = {}
var current_animation: Animation

func setup(plugin: EditorPlugin) -> void:
    editor = plugin

func _ready() -> void:
    custom_minimum_size = Vector2(290, 350)
    _label("ANIMATE 0.1 — генератор анимаций", true)
    _button("Использовать выделенный Skeleton3D / GLB", _select_skeleton)
    status = _label("Выбери Skeleton3D в дереве сцены")
    _label("Описание движения", true)
    prompt = TextEdit.new()
    prompt.custom_minimum_size.y = 80
    prompt.placeholder_text = "Например: быстрый бег, удар мечом, прыжок"
    prompt.text = "быстрый бег"
    add_child(prompt)
    duration = _spin("Длительность, сек", 1.0, 0.2, 20.0, 0.1)
    intensity = _spin("Амплитуда", 1.0, 0.1, 2.0, 0.1)
    _button("Сгенерировать по описанию", _generate)
    _button("Сохранить анимацию .tres", _save)
    add_child(HSeparator.new())
    _label("Ручной редактор поз", true)
    bone_picker = OptionButton.new()
    add_child(bone_picker)
    angle_x = _slider("X", 0)
    angle_y = _slider("Y", 1)
    angle_z = _slider("Z", 2)
    _button("Применить поворот к кости", _apply_pose)
    _button("Добавить позу в начало (0 сек)", func(): _store_pose(0.0))
    _button("Добавить позу в середину", func(): _store_pose(duration.value * 0.5))
    _button("Добавить позу в конец", func(): _store_pose(duration.value))
    _button("Создать анимацию из поз", _build_manual)
    _button("Сбросить позу", _reset_pose)

func _label(value: String, heading: bool = false) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if heading:
        label.add_theme_font_size_override("font_size", 16)
    add_child(label)
    return label

func _button(value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = value
    button.pressed.connect(callback)
    add_child(button)

func _spin(value: String, initial: float, minimum: float, maximum: float, step: float) -> SpinBox:
    _label(value)
    var spin := SpinBox.new()
    spin.min_value = minimum
    spin.max_value = maximum
    spin.step = step
    spin.value = initial
    add_child(spin)
    return spin

func _slider(axis: String, unused_axis: int) -> HSlider:
    _label("Поворот %s (градусы)" % axis)
    var slider := HSlider.new()
    slider.min_value = -180
    slider.max_value = 180
    slider.step = 1
    slider.value = 0
    add_child(slider)
    return slider

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _select_skeleton() -> void:
    var selected := editor.get_editor_interface().get_selection().get_selected_nodes()
    if selected.is_empty():
        status.text = "Сначала выдели модель или Skeleton3D"
        return
    skeleton = _find_skeleton(selected[0])
    if skeleton == null:
        status.text = "Skeleton3D не найден: нужен риг с костями"
        return
    player = _find_player(selected[0].get_tree().edited_scene_root)
    bone_picker.clear()
    for i in range(skeleton.get_bone_count()):
        bone_picker.add_item(skeleton.get_bone_name(i), i)
    pose_keys.clear()
    status.text = "Скелет: %s (%d костей)" % [skeleton.name, skeleton.get_bone_count()]

func _find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var result := _find_player(child)
        if result != null:
            return result
    return null

func _generate() -> void:
    if skeleton == null or not is_instance_valid(skeleton):
        status.text = "Сначала выбери Skeleton3D"
        return
    var spec: Dictionary = Generator.parse_prompt(prompt.text)
    current_animation = Generator.generate(skeleton, spec["motion"], duration.value, intensity.value)
    status.text = "Создано: %s, %d дорожек. Сохрани .tres" % [spec["motion"], current_animation.get_track_count()]

func _apply_pose() -> void:
    if skeleton == null or bone_picker.item_count == 0:
        return
    var index := bone_picker.get_selected_id()
    var euler := Vector3(deg_to_rad(angle_x.value), deg_to_rad(angle_y.value), deg_to_rad(angle_z.value))
    skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(euler))
    status.text = "Поза применена: %s" % skeleton.get_bone_name(index)

func _store_pose(time: float) -> void:
    if skeleton == null:
        return
    var poses := {}
    for i in range(skeleton.get_bone_count()):
        poses[skeleton.get_bone_name(i)] = skeleton.get_bone_pose_rotation(i)
    pose_keys[time] = poses
    status.text = "Ключ: %.2f сек, костей: %d" % [time, poses.size()]

func _build_manual() -> void:
    if skeleton == null or pose_keys.is_empty():
        status.text = "Сначала добавь ключевые позы"
        return
    current_animation = Animation.new()
    current_animation.length = duration.value
    var times := pose_keys.keys()
    times.sort()
    for i in range(skeleton.get_bone_count()):
        var bone_name := skeleton.get_bone_name(i)
        var track := current_animation.add_track(Animation.TYPE_ROTATION_3D)
        current_animation.track_set_path(track, NodePath(":%s" % bone_name))
        for t in times:
            current_animation.rotation_track_insert_key(track, float(t), pose_keys[t][bone_name])
    status.text = "Ручная анимация готова: %d ключевых поз" % times.size()

func _reset_pose() -> void:
    if skeleton == null:
        return
    for i in range(skeleton.get_bone_count()):
        skeleton.set_bone_pose_rotation(i, Quaternion.IDENTITY)
    angle_x.value = 0
    angle_y.value = 0
    angle_z.value = 0
    status.text = "Поза сброшена"

func _save() -> void:
    if current_animation == null:
        status.text = "Сначала создай анимацию"
        return
    var base := "res://animate_motion_%d.tres" % Time.get_ticks_msec()
    var error := ResourceSaver.save(current_animation, base)
    if error == OK:
        status.text = "Сохранено: %s" % base
        EditorInterface.get_resource_filesystem().scan()
    else:
        status.text = "Ошибка сохранения: %d" % error
