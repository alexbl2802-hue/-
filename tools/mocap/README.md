# Видео → анимация героя (Open MoCap Blender)

Дополнение Blender [Open MoCap Blender](https://github.com/Larenju-Rai/open-mocap-blender) (MIT, копия в
`tools/open_mocap_blender/`) снимает движение человека с видео нейросетью MediaPipe. В саму игру (APK)
его не встроить — это инструмент сборки: видео превращается в клип `MC_<Имя>` внутри `godot/models/hero.glb`.

1. `tools/mocap/track_video.py` — 33 точки тела на каждом кадре (MediaPipe Pose, мировые координаты).
2. `tools/blender/mocap_bake.py` — Blender без окон: кости героя смотрят на точки, таз/грудь/голова
   поворачиваются по линиям тела, ноги стоят на земле, ключи на каждый кадр.
3. `tools/mocap/mocap_merge.py` — клип переносится в модель героя.

Всё сразу: `tools/mocap/video_to_clip.sh видео.mp4 Имя`
(Python 3.12: `python3.12 -m venv mpenv && mpenv/bin/pip install mediapipe==0.10.14 opencv-python-headless==4.11.0.86`).

Лучше всего: человек целиком в кадре, лицом к камере, камера неподвижна, однотонный фон.
