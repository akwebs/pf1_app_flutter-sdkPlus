# ALPR models

Drop the trained TFLite models here (Phase 4):

- `plate_detector.tflite` — YOLO-style license-plate detector
- `plate_recognizer.tflite` — character recognizer (0-9, A-Z)

Loaded by `lib/alpr/tflite_plate_detector.dart` and `tflite_plate_recognizer.dart`.
Until both files are present (and their `detect`/`recognize` decoding is enabled),
the scanner shows the live preview only and vehicle numbers are entered manually.
