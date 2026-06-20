#!/usr/bin/env python3
"""Train and export the ALPR YOLOv8 models to TFLite for the Flutter app.

Two models share this script:
  * detector   - finds the plate box in a frame   -> assets/models/plate_detector.tflite
  * recognizer - reads characters on a plate crop -> assets/models/plate_recognizer.tflite

Examples
--------
  python tools/train.py --task detector   --data tools/data/detector.yaml   --epochs 100
  python tools/train.py --task recognizer --data tools/data/recognizer.yaml --epochs 120

The exported .tflite is copied straight into assets/models/ where the Flutter
app expects it (see lib/alpr/tflite_plate_detector.dart / tflite_plate_recognizer.dart).
"""

import argparse
import shutil
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = Path(__file__).resolve().parent
ASSETS_DIR = REPO_ROOT / "assets" / "models"

TASKS = {
    "detector": {
        "data": TOOLS_DIR / "data" / "detector.yaml",
        "out": "plate_detector.tflite",
        "imgsz": 320,
    },
    "recognizer": {
        "data": TOOLS_DIR / "data" / "recognizer.yaml",
        "out": "plate_recognizer.tflite",
        "imgsz": 192,
    },
}


def _resolve_dataset_path(yaml_path: Path) -> Path:
    """Rewrite a relative dataset `path:` to absolute.

    Ultralytics resolves a relative `path:` against its configured
    `datasets_dir`, not the YAML location or the cwd — a frequent source of
    "dataset not found". Making it absolute (relative to the YAML file) sidesteps
    that and works identically on a laptop or Colab. Returns the YAML to train
    with (a patched copy when rewriting was needed).
    """
    import yaml

    cfg = yaml.safe_load(yaml_path.read_text())
    raw = Path(str(cfg.get("path", ".")))
    if raw.is_absolute():
        return yaml_path
    cfg["path"] = str((yaml_path.parent / raw).resolve())
    patched = yaml_path.parent / f".{yaml_path.stem}_resolved.yaml"
    patched.write_text(yaml.safe_dump(cfg, sort_keys=False))
    return patched


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--task", required=True, choices=sorted(TASKS))
    parser.add_argument("--data", default=None,
                        help="path to the dataset YAML (defaults to tools/data/<task>.yaml)")
    parser.add_argument("--model", default="yolov8n.pt",
                        help="base weights to fine-tune (yolov8n = smallest/fastest)")
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--imgsz", type=int, default=None,
                        help="training/export image size (defaults per task)")
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--int8", action="store_true",
                        help="export int8 (smallest/fastest, needs the dataset for calibration). "
                             "Default export is float32, which is simplest to decode in Dart.")
    parser.add_argument("--no-export", action="store_true",
                        help="train only, skip the TFLite export step")
    args = parser.parse_args()

    cfg = TASKS[args.task]
    data = Path(args.data) if args.data else cfg["data"]
    imgsz = args.imgsz or cfg["imgsz"]

    # Fail fast on a bad dataset path before the (heavy) ultralytics import.
    if not data.exists():
        raise SystemExit(f"Dataset config not found: {data}\n"
                         f"Fill in tools/data/{args.task}.yaml and point `path:` at your dataset.")

    # Imported lazily so `--help` and the check above work without heavy deps.
    from ultralytics import YOLO

    data = _resolve_dataset_path(data)
    print(f"[train] task={args.task} model={args.model} data={data} imgsz={imgsz} "
          f"epochs={args.epochs} batch={args.batch}")

    model = YOLO(args.model)
    model.train(
        data=str(data),
        epochs=args.epochs,
        imgsz=imgsz,
        batch=args.batch,
        name=f"alpr_{args.task}",
    )

    best = Path(model.trainer.save_dir) / "weights" / "best.pt"
    print(f"[train] best weights: {best}")

    if args.no_export:
        print("[done] training complete (export skipped).")
        return

    print(f"[export] exporting TFLite (int8={args.int8}) ...")
    best_model = YOLO(str(best))
    export_path = best_model.export(
        format="tflite",
        imgsz=imgsz,
        int8=args.int8,
        data=str(data) if args.int8 else None,
    )

    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    target = ASSETS_DIR / cfg["out"]
    shutil.copyfile(export_path, target)
    print(f"[export] {export_path}")
    print(f"[export] -> {target}  ({target.stat().st_size // 1024} KB)")
    print("[done] Model copied into assets/models/.")
    print("       Next: enable decoding in the matching lib/alpr/tflite_*.dart file")
    print("       (set _decodeImplemented = true), then `flutter pub get` and rebuild.")


if __name__ == "__main__":
    main()
