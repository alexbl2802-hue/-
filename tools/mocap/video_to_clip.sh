#!/bin/bash
# Видео движения → клип героя MC_<Имя> в godot/models/hero.glb (Open MoCap Blender + MediaPipe).
# tools/mocap/video_to_clip.sh видео.mp4 Имя [mpenv]
set -e
V="$1"; NAME="$2"; ENV="${3:-mpenv}"
T=$(mktemp -d)
"$ENV/bin/python" -I tools/mocap/track_video.py "$V" "$T/points.json"
blender -b -P tools/blender/mocap_bake.py -- "$T/points.json" godot/models/hero.glb "$T/clip.glb" "$NAME" | grep "MC "
python3 tools/mocap/mocap_merge.py "$T/clip.glb" hero.glb
