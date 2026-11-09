# ISSUES

Серьёзность: CRITICAL / HIGH / MEDIUM / LOW. Статус: OPEN / FIXED (с проверкой) / WONTFIX (с причиной) / BLOCKED.

| ID | Серьёзность | Где | Проблема | Воспроизведение | Статус |
|---|---|---|---|---|---|
| I-01 | MEDIUM | `scripts/cardinal_director.gd:29`, `addons/cardinal/scripts/cardinal.gd:6`, `addons/cardinal/v2/cardinal_core.gd:7` | Три несогласованных лимита монстров: 35 по умолчанию, 2000 в игре, 40 в ядре (ядро нигде не используется для спавна) | чтение кода; в мире 445 монстров при «лимите» 35/40 | OPEN |
| I-02 | HIGH | `scripts/boot.gd:73` | Пакет считается целым, если совпал размер; повреждённое содержимое того же размера не обнаруживается | подменить байты в `.pck`, размер тот же — игра монтирует его | FIXED: sha256 в `packs.json` (`tools/data_pack.py`), сверка один раз после скачивания (`boot.gd` `_check_pack`), повреждённая часть удаляется и перекачивается. Тест `tests/boot_packs.tscn` |
| I-03 | HIGH | `scripts/game.gd:449` | Сохранение пишется прямо поверх `save.json`; обрыв записи (закрытие игры, нехватка памяти) оставляет пустой/битый файл, а `load_game` молча начинает новую игру | убить процесс во время `store_string` | FIXED: запись через `.tmp` с проверкой и заменой, прежнее — `save.json.bak`, загрузка из копии при порче. Тест `tests/save_safety.tscn` |
| I-04 | MEDIUM | `data/packs.json` (создаёт `tools/data_pack.py`), `scripts/boot.gd` | Нет версии формата пакетов: несовместимый список пакетов от другой версии не распознаётся | — | FIXED: `{"format": 1, "app", "packs"}`; формат новее — сообщение «обнови игру»; старый вид списка читается. Тест `tests/boot_packs.tscn` |
| I-06 | MEDIUM | `scripts/game.gd` `wipe()` | После добавления копии `.bak` «Новая игра» подняла бы прежний прогресс из копии | — | FIXED: «Новая игра» откладывает `save.json` и `.bak` как `*.wiped*.bak` (без удаления данных). Тест `tests/save_safety.tscn` |
| I-07 | LOW | `scripts/game.gd` `load_game()` | Сохранение более новой версии читалось и затиралось без копии | — | FIXED: копия `save.json.v<N>.bak` перед первой перезаписью. Тест `tests/save_safety.tscn` |
| I-05 | HIGH (Android) | мир | 7 053 807 примитивов и 878 draw calls в кадре в городе | `tests/baseline.tscn` | OPEN |
