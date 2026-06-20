import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'plate_detector.dart';

/// TFLite-backed plate detector (YOLO-style).
///
/// Phase 4 trains the model and bundles it as a Flutter asset, then implements
/// [detect]'s output decoding to match that model. Until BOTH the asset and the
/// decoding exist, [isReady] stays false: [AlprController] then skips inference
/// and the UI falls back to manual entry. This keeps the app shippable while the
/// model is still being produced.
class TflitePlateDetector implements PlateDetector {
  TflitePlateDetector({this.assetPath = 'assets/models/plate_detector.tflite'});

  final String assetPath;
  Interpreter? _interpreter;

  // Flipped to true in Phase 4, together with the detect() decoding below.
  static const bool _decodeImplemented = false;

  @override
  bool get isReady => _interpreter != null && _decodeImplemented;

  /// Attempts to load the bundled model. Safe to call when no model is shipped
  /// yet — it simply leaves the detector not-ready.
  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(assetPath);
    } catch (_) {
      _interpreter = null;
    }
  }

  @override
  Future<List<PlateBox>> detect(img.Image image) async {
    if (!isReady) return const [];
    // TODO(Phase 4): resize to model input, run _interpreter!.run(...), then
    // decode boxes (objectness + class) and apply NMS into normalized PlateBox.
    return const [];
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
