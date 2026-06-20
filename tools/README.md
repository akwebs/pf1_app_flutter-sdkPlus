# Training the ALPR models (Phase 4)

This folder produces the two on-device models the app needs:

| Model | Job | Output file |
|-------|-----|-------------|
| **Detector** | Find the plate box in a camera frame | `assets/models/plate_detector.tflite` |
| **Recognizer** | Read the characters on a cropped plate | `assets/models/plate_recognizer.tflite` |

Both are **YOLOv8n** (smallest/fastest) trained with [Ultralytics](https://docs.ultralytics.com/)
and exported to TFLite. Everything is **free** — train on Google Colab's free GPU.

The Flutter pipeline that consumes them is already built and tested
(`lib/alpr/`): camera → detector → crop → recognizer → K-of-N voting → auto-fill.
The only thing missing is the two model files **and** turning the decode on
(Steps 5–6 below).

---

## Step 0 — What you need

- A Google account (for Colab free GPU) **or** a local machine with Python 3.10/3.11.
- Two datasets in **YOLOv8 format** (see Step 2).
- ~1–2 hours per model on a free Colab T4.

---

## Step 1 — Environment

**Colab (recommended):** new notebook → Runtime → Change runtime type → **GPU**. Then:

```python
!git clone https://github.com/akwebs/pf1_app_flutter-sdkPlus.git app
%cd /content/app
!pip install -r tools/requirements.txt
```

> Use the `%cd` **magic** (not `!cd`) — a `!cd` inside a `!` cell does **not** persist to the
> next cell, so later `!pip`/`!python tools/...` commands would run from the wrong directory
> and fail with "No such file or directory". `%cd` changes the notebook's working dir for good.

**Local:**

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r tools/requirements.txt
```

---

## Step 2 — Get the datasets

You need two YOLO-format datasets (each = `images/{train,val}` + `labels/{train,val}`
with a `data.yaml`). Templates are in [`tools/data/`](data/).

### 2a. Detector dataset (1 class: `plate`)
Each label line: `0 cx cy w h` (normalized 0–1).

Free sources (export as **YOLOv8**):
- **Roboflow Universe** — search *"license plate"* / *"ANPR"* (Indian-specific sets exist).
- **Kaggle** — *"Car License Plate Detection"*, *"Indian Vehicle Number Plate"*.

If you have one or more Roboflow YOLOv8 **zips**, merge them into the dataset the
config already expects (every class remapped to `0` = plate):

```bash
python tools/prepare_data.py --zips "tools/data/*.zip"
```

This writes `tools/datasets/plate_detector/{train,valid,test}/{images,labels}`, which
[`tools/data/detector.yaml`](data/detector.yaml) already points at — no edits needed.
(The current repo's two Indian-plate sets merge to ~1943/538/271.)

### 2b. Recognizer dataset (36 classes: 0-9, A-Z)
Each training image is a **cropped plate**; each label is a **character box** with its
class. Label line: `<class> cx cy w h`.

Free sources:
- **Roboflow Universe** — *"license plate characters"*, *"ANPR OCR"*.
- **Kaggle** — *"Indian Number Plate Characters"*.
- **Synthetic** — render random valid Indian plates (e.g. `MH12AB1234`, 2-line bike layout)
  onto plate templates; you get perfect labels for free and full control over fonts/spacing.

⚠️ **Class order must match** [`tools/data/recognizer.yaml`](data/recognizer.yaml) exactly
(0…9 then A…Z = indices 0–35), or characters will come out wrong.

Set `path:` in `recognizer.yaml` to your dataset root.

---

## Step 3 — Train the detector

```bash
python tools/train.py --task detector --data tools/data/detector.yaml --epochs 100
```

Exports and copies → `assets/models/plate_detector.tflite`. Default input size **320**.

## Step 4 — Train the recognizer

```bash
python tools/train.py --task recognizer --data tools/data/recognizer.yaml --epochs 120
```

Exports and copies → `assets/models/plate_recognizer.tflite`. Default input size **192**.

> Add `--int8` for smaller/faster models (needs the dataset for calibration). The default
> **float32** export is simplest to decode in Dart — start there, optimize later.
>
> On Colab, after training, download the two files from `assets/models/` and commit them,
> or push the repo from Colab.

---

## Step 5 — The models are in place

After Steps 3–4 you have:

```
assets/models/plate_detector.tflite
assets/models/plate_recognizer.tflite
```

`assets/models/` is already declared in `pubspec.yaml`, and
`TflitePlateDetector` / `TflitePlateRecognizer` already load these paths.

---

## Step 6 — Turn the decode on (Dart)

The Dart classes load the models but keep `_decodeImplemented = false` so the app
stays shippable until a real model exists. Now implement the decode and flip the flag.

### YOLOv8 TFLite I/O (what the Dart code must produce/consume)

**Input** — `[1, imgsz, imgsz, 3]`, `float32`, **RGB**, pixels scaled to **0..1**
(`imgsz` = 320 detector / 192 recognizer). Resize the crop/frame with letterboxing.

**Output** — `[1, 4 + numClasses, numBoxes]` (transposed YOLOv8 head):
- rows `0..3` = `cx, cy, w, h` in **pixels relative to imgsz** (divide by `imgsz` to normalize),
- rows `4..` = per-class scores (already activated).
- `numBoxes` depends on `imgsz` (e.g. 320 → 2100). Read it from the output tensor shape.

Decode = transpose to `[numBoxes, 4+numClasses]`, keep boxes whose best class score
> `confThreshold` (~0.25), convert `xywh→corners`, run **NMS** (IoU ~0.45).

### `lib/alpr/tflite_plate_detector.dart` → `detect()`
1. Letterbox-resize `image` to 320×320, fill `Float32List` (RGB, /255).
2. `_interpreter!.run(input, output)` with `output` shaped `[1, 5, numBoxes]` (1 class).
3. Decode + NMS → list of `PlateBox` (normalized `left/top/width/height`, `score`).
4. Set `static const bool _decodeImplemented = true;`

### `lib/alpr/tflite_plate_recognizer.dart` → `recognize()`
1. Letterbox-resize `plateCrop` to 192×192, fill input.
2. Run → `[1, 40, numBoxes]` (36 classes + 4 box).
3. Decode + NMS → character boxes; for each, `argmax` over the 36 class scores → char
   (index 0–9 = digits, 10–35 = A–Z).
4. **Sort into reading order:** cluster boxes into rows by `cy` (1 row = car, 2 rows = bike),
   top row first, then **left-to-right by `cx`** within each row; join the chars.
5. Return the string (raw — the controller normalizes/validates/votes it).
6. Set `_decodeImplemented = true;`

> Tip: Ultralytics can also run the raw model in Python (`YOLO('best.pt')(img)`) so you can
> sanity-check class indices and box outputs against the Dart decode before shipping.

---

## Step 7 — Build & test on a device

```bash
flutter pub get
flutter build apk --debug      # or: flutter run  (on a connected Android phone)
```

With both models present and `_decodeImplemented = true`, `AlprScannerView` starts the
camera image stream and auto-fills the vehicle number on a confirmed plate. Test with real
**bikes (2-line)** and **cars (1-line)** in varied light/angles.

---

## Step 8 — Tuning

- **Misreads** → raise the voter threshold in `AlprController` (`PlateVoter(windowSize, threshold)`).
- **Slow on cheap phones** → re-export with `--int8`, lower `imgsz`, and/or raise
  `minInterval` in `AlprController`; move inference to an isolate (TODO already marked in
  `alpr_scanner_view.dart`).
- **Confused characters (0/O, 1/I, 8/B)** → add more training samples of those; the
  `PlateFormat` regex already rejects structurally-invalid reads.
- **Accuracy** → more/representative Indian data in Step 2 is the biggest lever.

---

## Appendix — Colab run sheet (copy-paste)

The datasets are gitignored, so they are **not** in the clone — you upload the zips to Colab.
Keep detector zips and the character zip in **separate folders** so each merge only sees its own.

**Cell 1 — setup** (first: Runtime → Change runtime type → **GPU**)
```python
!git clone https://github.com/akwebs/pf1_app_flutter-sdkPlus.git app
%cd /content/app
!pip install -q -r tools/requirements.txt
!mkdir -p tools/data/det tools/data/rec
```

**Cell 2 — upload the DETECTOR zips** (the two Indian-plate detection zips)
```python
import shutil
from google.colab import files
for name in files.upload():        # select both detector .zip files
    shutil.move(name, f'tools/data/det/{name}')
!ls tools/data/det
```

**Cell 3 — upload the CHARACTER zip** (your recognizer dataset)
```python
import shutil
from google.colab import files
for name in files.upload():        # select your character .zip
    shutil.move(name, f'tools/data/rec/{name}')
!ls tools/data/rec
```

**Cell 4 — build both datasets**
```python
!python tools/prepare_data.py --task detector   --zips "tools/data/det/*.zip"
!python tools/prepare_data.py --task recognizer --zips "tools/data/rec/*.zip"
```

**Cell 5 — train (GPU)**
```python
!python tools/train.py --task detector   --epochs 100
!python tools/train.py --task recognizer --epochs 120
```

**Cell 6 — download the two models**
```python
from google.colab import files
files.download('assets/models/plate_detector.tflite')
files.download('assets/models/plate_recognizer.tflite')
```

Then drop both files into `assets/models/` in your local repo and do **Step 6** (enable the
Dart decode) + **Step 7** (build & test on a device).

