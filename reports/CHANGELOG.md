# CHANGELOG (ветка audit-4.0)

## Этап 0
- `godot/tests/baseline.gd`, `godot/tests/baseline.tscn` — новый тест базовых метрик (время загрузки, FPS, узлы, draw calls, примитивы, память). В APK не входит (`tests/*` исключены).
- `reports/` — отчёты аудита.

## Этап 1 — версии и загрузка ресурсов
- `godot/scripts/boot.gd`: `DATA_FORMAT = 1`; `_read_list()` — новый вид `packs.json` `{format, app, packs}` и старый (массив); формат новее — понятное сообщение без попытки загрузки; `_check_pack()` — sha256 части сверяется один раз после скачивания (`user://packs_verified.json`); перед монтированием проверяются наличие, размер и сумма всех частей, повреждённые удаляются и ставятся на перекачку; журнал `[boot] …`; повтор при непрочитанном списке не запускает мир; для тестов — переменные `ZEMLI_PACKS_LIST`, `ZEMLI_FORCE_PACKS`.
- `tools/data_pack.py`: `packs.json` с `format`, `app` (версия из `project.godot`) и `sha256` каждой части.
- `godot/scripts/game.gd`: `SAVE_VERSION = 2`; сохранение через `.tmp` + проверка + замена, прежнее → `save.json.bak`; загрузка из копии, если основной файл испорчен; сохранение новее — копия `save.json.v<N>.bak`; в сохранение пишется версия приложения `app`; «Новая игра» откладывает файлы `*.wiped*.bak` вместо удаления.
- Тесты: `godot/tests/save_safety.*`, `godot/tests/boot_packs.*`.

## Этап 2 — CARDINAL 4.0
- Новое: `addons/cardinal/v4/cardinal_config.gd` (все лимиты и пороги), `cardinal_balance.gd` (сложность, урон монстров, множитель добычи), `cardinal_registry.gd` (реестр систем), `cardinal_deadline.gd` (сторож предела 900 с), `README_4_0.md` (компоненты и обязанности).
- `addons/cardinal/scripts/cardinal.gd`: `max_active_mobs` — лимит бодрствующих (35), `max_registered_mobs` — созданных (2000); пороги из `CardinalConfig`.
- `addons/cardinal/v2/cardinal_core.gd`: `max_monsters` и `loot_multiplier` — ссылки на единые значения (API 2.1 сохранён).
- `addons/cardinal/v2/performance_manager.gd`: снижает и возвращает настоящий лимит бодрствующих монстров.
- `godot/scripts/enemies.gd`: бодрствуют ближайшие N (N = `Cardinal.max_active_mobs`); боссы в радиусе — без лимита.
- `godot/scripts/cardinal_director.gd`: баланс — через `CardinalBalance`; проверка анимаций — вызов ANIMATE (`AnimateAudit.check_actors`).
- `godot/scripts/animate_audit.gd`: `check_actors()` (перенесено из CARDINAL).
- `godot/scripts/cardinal_autotest.gd`: реестр систем; SKIPPED с причиной для отсутствующих; предел 900 с реального времени (сторож, работает на паузе); после остановки результаты не перезаписываются; сохранение возвращается через временный файл; удалена неиспользуемая копия проверки моделей; итог не считает «нет системы» неполнотой; `limit_seconds` для проверки предела.
- `godot/scripts/cardinal_scenarios.gd`: сценарии прерываются при остановке; новый сценарий NPC.
- `godot/scripts/house_model.gd`: жители в группе `npc`.
- `godot/scripts/settings.gd`, `touch_ui.gd`, `ui/main_menu.gd`: скрытый режим администратора (7 нажатий на номер версии); кнопка CARDINAL только в нём.
- Тесты: `godot/tests/cardinal_timeout.*`, `godot/tests/cardinal_limits.*`.

## Этап 3 — ANIMATE 4.0
- Новое: `godot/animate_4/animate_spec.gd` (разбор описания, словарь), `animate_templates.gd` (позы всего тела, фазы, контакты; стойка с одним мечом), `animate_ik.gd` (прямая кинематика по трекам, двухзвенный IK ног, удержание стоп), `animate_validator4.gd` (скелет и анимация, безопасный сокет), `animate_pipeline.gd` (конвейер, тайминг, опора на землю, пределы суставов, экспорт/сохранение), `README_4_0.md`.
- `godot/scripts/ui/animate_panel.gd`: генерация через ANIMATE 4.0 с выводом проверок; прочие движения — прежний генератор.
- Тесты и предпросмотр: `godot/tests/animate4_demo.*`, `godot/tests/animate4_window.*`; `tests/load_all.gd` проверяет и `animate_4`, `addons/animate`.
- Кадры предпросмотра: `reports/previews/animate4/`.

## Этап 4 — герой, передвижение, бой
- Новое: `godot/scripts/hero_states.gd` (`HeroStates`: 15 состояний, таблица `CAN`), `godot/scripts/fx/dash_streak.gd` (`DashStreak` — след рывка вынесен из `hero.gd`), `godot/data/anim/hero_stance_sword.res`, `hero_block_shield.res` (запечённые ANIMATE 4.0, входят в APK через `include_filter=data/*`).
- `godot/scripts/hero.gd`: сигнал `state_changed(from, to)`; `states.update()` каждый кадр физики; `attack/dodge/use_skill/use_horizontal/use_art` проверяют `HeroStates.can()`; `_load_animate4()` и `_stance_and_block()` — стойка с одним мечом и блок по снаряжению; след рывка через `DashStreak`. Прежние сигналы (`hurt`, `died`) и публичные методы сохранены.
- `godot/scripts/hero_anim.gd`: `set_act_anim(kind, clip)` — замена клипа действия.
- `godot/animate_4/`: шаблон «стойка» (петля с дыханием), поддержка петель; клинок стойки — вправо-вниз.
- Тесты: `godot/tests/hero_states_test.*`, `godot/tests/animate4_bake.*` (запекание клипов героя).

## Этап 5 — монстры, предметы, данжи, UI
- `godot/scripts/enemy.gd`: обход препятствий в погоне и по дороге домой (`_steer`, `_path_free`); 3 с упора в воду — отказ от погони.
- `godot/scripts/touch_ui.gd`: верхние кнопки через `_top_rect()` — на экранах выше телефонных до +25 %.
- Тесты: `godot/tests/monsters_ai.*`, `items_dungeons.*`, `ui_layout.*`.

## Этап 6 — оптимизация
- `godot/scripts/settings.gd`: профили качества `QUALITY` (Низкое/Среднее/Высокое: порог LOD, полные модели деревьев, тени, дальность), сохраняются; по умолчанию «Высокое» (прежний вид).
- `godot/scripts/main.gd` `apply_settings`: порог LOD вида, дальность полных моделей деревьев.
- `godot/scripts/world.gd`: `set_tree_full(d)`; списки ступеней деревьев.
- `godot/scripts/ui/settings_panel.gd`: выбор «Качество графики».
- Тест-замер: `godot/tests/perf_probe.*`.
