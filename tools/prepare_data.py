#!/usr/bin/env python3
"""Merge Roboflow YOLOv8 zip(s) into a training dataset for the ALPR models.

Two tasks:

  detector    single-class plate boxes -> every class remapped to 0 (= plate),
              merged into tools/datasets/plate_detector/.

  recognizer  character boxes -> classes remapped by NAME to the canonical order
              0-9 then A-Z (indices 0..35), merged into tools/datasets/plate_recognizer/.
              This means the source dataset can list its classes in ANY order:
              we align them to recognizer.yaml + the Dart decode, which are fixed.

Examples
--------
  python tools/prepare_data.py --task detector   --zips "tools/data/*.zip"
  python tools/prepare_data.py --task recognizer --zips "tools/data/chars.zip"
"""

import argparse
import glob
import shutil
import tempfile
import zipfile
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
SPLIT_ALIASES = {"train": "train", "valid": "valid", "val": "valid", "test": "test"}

# Canonical recognizer classes: digits then uppercase letters (36 total).
CANON = [str(d) for d in range(10)] + [chr(c) for c in range(ord("A"), ord("Z") + 1)]
CANON_INDEX = {name: i for i, name in enumerate(CANON)}

DEFAULT_OUT = {"detector": "plate_detector", "recognizer": "plate_recognizer"}


def _load_source_names(extract_root: Path) -> list[str]:
    """Read `names` from a Roboflow data.yaml (supports list or dict form)."""
    import yaml

    cfg = yaml.safe_load((extract_root / "data.yaml").read_text())
    names = cfg.get("names")
    if isinstance(names, dict):
        return [names[k] for k in sorted(names)]
    if isinstance(names, list):
        return names
    raise SystemExit("Could not read class names from the dataset's data.yaml")


def _build_class_map(task: str, extract_root: Path) -> dict[int, int]:
    """src class index -> output class index."""
    if task == "detector":
        # Everything is a plate; collapse to class 0 regardless of source ids.
        return {}  # sentinel: handled as "force 0" below
    names = _load_source_names(extract_root)
    mapping: dict[int, int] = {}
    for src_idx, raw in enumerate(names):
        key = str(raw).strip().upper()
        if key not in CANON_INDEX:
            raise SystemExit(
                f"Recognizer class '{raw}' is not one of 0-9/A-Z. "
                f"This dataset has non-character classes and can't be used as-is."
            )
        mapping[src_idx] = CANON_INDEX[key]
    return mapping


def _write_label(src: Path, dst: Path, task: str, class_map: dict[int, int]) -> None:
    out_lines = []
    for line in src.read_text().splitlines():
        parts = line.split()
        if len(parts) < 5:
            continue
        if task == "detector":
            parts[0] = "0"
        else:
            parts[0] = str(class_map[int(parts[0])])
        out_lines.append(" ".join(parts))
    dst.write_text("\n".join(out_lines) + ("\n" if out_lines else ""))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--task", choices=("detector", "recognizer"), default="detector")
    parser.add_argument("--zips", nargs="+", required=True,
                        help="zip paths or globs (e.g. 'tools/data/*.zip')")
    parser.add_argument("--out", default=None,
                        help="dataset folder name under tools/datasets/ (defaults per task)")
    args = parser.parse_args()

    out_name = args.out or DEFAULT_OUT[args.task]
    zips = sorted({p for pattern in args.zips for p in glob.glob(pattern)})
    if not zips:
        raise SystemExit(f"No zips matched: {args.zips}")

    out_root = TOOLS_DIR / "datasets" / out_name
    for split in ("train", "valid", "test"):
        for kind in ("images", "labels"):
            d = out_root / split / kind
            if d.exists():
                shutil.rmtree(d)
            d.mkdir(parents=True, exist_ok=True)

    totals = {"train": 0, "valid": 0, "test": 0}
    for i, zp in enumerate(zips):
        print(f"[prepare] {zp}")
        with tempfile.TemporaryDirectory() as tmp:
            with zipfile.ZipFile(zp) as zf:
                zf.extractall(tmp)
            root = Path(tmp)
            class_map = _build_class_map(args.task, root)
            for raw_split, split in SPLIT_ALIASES.items():
                img_dir = root / raw_split / "images"
                lbl_dir = root / raw_split / "labels"
                if not img_dir.is_dir():
                    continue
                for img in img_dir.iterdir():
                    if not img.is_file():
                        continue
                    shutil.copyfile(img, out_root / split / "images" / f"d{i}_{img.name}")
                    lbl = lbl_dir / f"{img.stem}.txt"
                    dst_lbl = out_root / split / "labels" / f"d{i}_{img.stem}.txt"
                    if lbl.exists():
                        _write_label(lbl, dst_lbl, args.task, class_map)
                    else:
                        dst_lbl.write_text("")  # negative sample
                    totals[split] += 1

    print("[prepare] merged:", ", ".join(f"{k}={v}" for k, v in totals.items()))
    print(f"[prepare] -> {out_root}")


if __name__ == "__main__":
    main()
