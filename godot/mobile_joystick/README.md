# Плавающий джойстик — Земли приключений

Godot 4.x, Android, мультитач. Не требует изображений или плагинов.

## Установка
1. Скопируйте папку `mobile_joystick` в корень проекта Godot.
2. Добавьте сцену `JoystickDemo.tscn` как дочернюю к `CanvasLayer` в игровой сцене (не запускайте её вместо игрового мира).
3. Подключите сигнал `movement_changed` от `VirtualJoystick` к скрипту персонажа.
4. Передавайте `direction` в движение относительно камеры, например:

```gdscript
var joystick_input := Vector2.ZERO

func _on_virtual_joystick_movement_changed(value: Vector2) -> void:
    joystick_input = value

func _physics_process(delta: float) -> void:
    var cam := get_viewport().get_camera_3d()
    if cam == null:
        return
    var forward := -cam.global_basis.z
    var right := cam.global_basis.x
    forward.y = 0.0
    right.y = 0.0
    var desired := (right.normalized() * joystick_input.x + forward.normalized() * -joystick_input.y)
    # CharacterBody3D: use existing gravity/jump logic and call move_and_slide() once.
    velocity.x = desired.x * 5.0
    velocity.z = desired.z * 5.0
    move_and_slide()
```

## Настройки
- `joystick_radius`: радиус стика (пиксели UI).
- `deadzone`: мёртвая зона.
- `floating`: плавающий или закреплённый.
- `activation_area_width`: доля ширины экрана для активации.
- `activation_area_height_start`: верхняя граница области активации.
- `walk_threshold`: порог, который можно использовать для переключения анимации ходьбы/бега.
- `sprint_changed`: сигнал двойного касания с удержанием.

## Важно
- Используется `_unhandled_input`: элементы UI, обрабатывающие касания, имеют приоритет.
- Касание справа не активирует джойстик: оно остаётся доступным для кнопок атаки.
- При необходимости увеличьте `activation_area_width`.
- Для тестирования на ПК включите Project Settings → Input Devices → Pointing → Emulate Touch From Mouse.
- Для камеры, перемещающейся другим пальцем, используйте отдельный контроллер, обрабатывающий только не занятые джойстиком касания.
