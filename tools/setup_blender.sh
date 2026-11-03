#!/bin/sh
# Blender (без окна, скриптами на Python) — для своих анимаций и моделей персонажей и мобов.
# Ставится в рабочую среду: apt-get blender + numpy (нужен модулю glTF).
set -e
apt-get install -y -q blender python3-numpy
blender --version | head -1
