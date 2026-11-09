# CHANGELOG (ветка audit-4.0)

## Этап 0
- `godot/tests/baseline.gd`, `godot/tests/baseline.tscn` — новый тест базовых метрик (время загрузки, FPS, узлы, draw calls, примитивы, память). В APK не входит (`tests/*` исключены).
- `reports/` — отчёты аудита.

## Этап 1 — версии и загрузка ресурсов
- `godot/scripts/boot.gd`: `DATA_FORMAT = 1`; `_read_list()` — новый вид `packs.json` `{format, app, packs}` и старый (массив); формат новее — понятное сообщение без попытки загрузки; `_check_pack()` — sha256 части сверяется один раз после скачивания (`user://packs_verified.json`); перед монтированием проверяются наличие, размер и сумма всех частей, повреждённые удаляются и ставятся на перекачку; журнал `[boot] …`; повтор при непрочитанном списке не запускает мир; для тестов — переменные `ZEMLI_PACKS_LIST`, `ZEMLI_FORCE_PACKS`.
- `tools/data_pack.py`: `packs.json` с `format`, `app` (версия из `project.godot`) и `sha256` каждой части.
- `godot/scripts/game.gd`: `SAVE_VERSION = 2`; сохранение через `.tmp` + проверка + замена, прежнее → `save.json.bak`; загрузка из копии, если основной файл испорчен; сохранение новее — копия `save.json.v<N>.bak`; в сохранение пишется версия приложения `app`; «Новая игра» откладывает файлы `*.wiped*.bak` вместо удаления.
- Тесты: `godot/tests/save_safety.*`, `godot/tests/boot_packs.*`.
