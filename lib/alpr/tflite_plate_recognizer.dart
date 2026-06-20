import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'plate_recognizer.dart';

/// TFLite-backed character recognizer.
///
/// Reads the characters of a cropped plate. For 2-line bike plates the decoder
/// clusters characters into rows (top then bottom) before joining — see Phase 4.
/// Inert (isReady == false) until the model asset and decoding both land, so the
/// app keeps working with manual entry in the meantime.
class TflitePlateRecognizer implements PlateRecognizer {
  TflitePlateRecognizer({this.assetPath = 'assets/models/plate_recognizer.tflite'});

  final String assetPath;
  Interpreter? _interpreter;

  // Flipped to true in Phase 4, together with the recognize() decoding below.
  static const bool _decodeImplemented = false;

  @override
  bool get isReady => _interpreter != null && _decodeImplemented;

  Future<void> load() async {
    try {
      _interpreter = await Interpreter.fromAsset(assetPath);
    } catch (_) {
      _interpreter = null;
    }
  }

  @override
  Future<String?> recognize(img.Image plateCrop) async {
    if (!isReady) return null;
    // TODO(Phase 4): resize crop to model input, run _interpreter!.run(...),
    // decode characters, sort by row (bikes) then left-to-right, join.
    return null;
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
