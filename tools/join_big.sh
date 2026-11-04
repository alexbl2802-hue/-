#!/bin/sh
# Большие модели (> 100 МБ — лимит GitHub на файл) хранятся частями в meshy/big/<имя>.partNN
# и склеиваются обратно в godot/models/<имя> без изменений. Запускается перед импортом и сборкой.
set -e
cd "$(dirname "$0")/.."
for first in meshy/big/*.part00; do
	[ -e "$first" ] || continue
	name=$(basename "$first" .part00)
	cat meshy/big/"$name".part* > godot/models/"$name"
	echo "собрано: godot/models/$name ($(du -h godot/models/"$name" | cut -f1))"
done
