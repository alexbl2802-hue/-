#!/usr/bin/env python3
"""Шаг 1 «видео → анимация героя» (Open MoCap Blender, https://github.com/Larenju-Rai/open-mocap-blender, MIT).
Как в дополнении: MediaPipe Pose находит 33 точки тела на каждом кадре видео. Здесь берутся «мировые»
точки MediaPipe (метры, центр — таз), чтобы движение переносилось на героя без перекосов.

Нужен Python 3.12 с mediapipe 0.10.14 и opencv (версии из PackageInstaller.py дополнения):
  python3.12 -m venv mpenv && mpenv/bin/pip install mediapipe==0.10.14 opencv-python-headless==4.11.0.86
  mpenv/bin/python tools/mocap/track_video.py видео.mp4 точки.json
"""
import json
import sys

import cv2
import mediapipe as mp


def main():
    src, out = sys.argv[1], sys.argv[2]
    cap = cv2.VideoCapture(src)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frames, seen = [], 0
    with mp.solutions.pose.Pose(static_image_mode=False, model_complexity=2, smooth_landmarks=True,
                                min_detection_confidence=0.5, min_tracking_confidence=0.5) as pose:
        while True:
            ok, img = cap.read()
            if not ok:
                break
            res = pose.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
            if res.pose_world_landmarks:
                w = [[p.x, p.y, p.z, p.visibility] for p in res.pose_world_landmarks.landmark]
                i = [[p.x, p.y] for p in res.pose_landmarks.landmark]
                frames.append({"w": w, "i": i})
                seen += 1
            else:
                frames.append(None)   # человек не найден — кадр заполнится соседним
    # Пропуски — копией ближайшего найденного кадра
    last = next((f for f in frames if f), None)
    if last is None:
        sys.exit("На видео не найден человек")
    for k, f in enumerate(frames):
        if f:
            last = f
        else:
            frames[k] = last
    json.dump({"fps": fps, "frames": frames}, open(out, "w"))
    print("кадров %d, человек найден на %d, %.1f кадр/с → %s" % (len(frames), seen, fps, out))


if __name__ == "__main__":
    main()
