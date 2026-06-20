import 'package:image/image.dart' as img;

import 'plate_detector.dart';
import 'plate_recognizer.dart';
import 'plate_result.dart';
import 'plate_voter.dart';

/// Orchestrates the on-device ALPR pipeline for one camera session.
///
/// For each frame: detect plate boxes -> crop the highest-scoring one ->
/// recognize characters -> feed the raw read to a [PlateVoter]. When the voter
/// confirms a plate across enough frames, [onPlate] fires with a clean result.
///
/// Frames are dropped while a previous frame is still being processed
/// (backpressure) and rate-limited by [minInterval], so a fast camera stream
/// never queues up work on a slow device.
class AlprController {
  AlprController({
    required this.detector,
    required this.recognizer,
    required this.onPlate,
    PlateVoter? voter,
    this.minInterval = const Duration(milliseconds: 250),
  }) : voter = voter ?? PlateVoter(windowSize: 5, threshold: 3);

  final PlateDetector detector;
  final PlateRecognizer recognizer;
  final void Function(PlateResult) onPlate;
  final PlateVoter voter;
  final Duration minInterval;

  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  /// Runs the pipeline on an already-decoded RGB [image].
  Future<void> processImage(img.Image image) async {
    if (_busy) return;
    if (DateTime.now().difference(_lastRun) < minInterval) return;
    if (!detector.isReady || !recognizer.isReady) return;

    _busy = true;
    try {
      final boxes = await detector.detect(image);
      _lastRun = DateTime.now();
      if (boxes.isEmpty) return;

      boxes.sort((a, b) => b.score.compareTo(a.score));
      final best = boxes.first;
      final crop = _crop(image, best);
      final raw = await recognizer.recognize(crop);
      if (raw == null) return;

      final confirmed = voter.add(raw);
      if (confirmed != null) {
        onPlate(PlateResult(confirmed, score: best.score));
      }
    } finally {
      _busy = false;
    }
  }

  img.Image _crop(img.Image image, PlateBox b) {
    final x = (b.left * image.width).clamp(0, image.width - 1).round();
    final y = (b.top * image.height).clamp(0, image.height - 1).round();
    final w = (b.width * image.width).clamp(1, image.width - x).round();
    final h = (b.height * image.height).clamp(1, image.height - y).round();
    return img.copyCrop(image, x: x, y: y, width: w, height: h);
  }

  /// Re-arms voting after a confirmed plate has been consumed.
  void reset() => voter.reset();

  void dispose() {
    detector.dispose();
    recognizer.dispose();
  }
}
