import 'dart:collection';

import 'plate_format.dart';

/// Stabilises noisy per-frame OCR results with K-of-N voting.
///
/// Live recognition produces a plate guess every frame, some of them wrong.
/// [PlateVoter] only confirms a plate once the same normalized value has been
/// read [threshold] times within the last [windowSize] *valid* reads, which
/// removes most single-frame misreads before the number is auto-filled.
class PlateVoter {
  PlateVoter({required this.windowSize, required this.threshold})
      : assert(threshold > 0),
        assert(windowSize >= threshold);

  final int windowSize;
  final int threshold;
  final Queue<String> _window = Queue<String>();

  /// Feeds one raw OCR [candidate]. Returns the confirmed plate when the
  /// threshold is met (and resets), otherwise null. Invalid candidates are
  /// ignored and do not affect the window.
  String? add(String? candidate) {
    if (candidate == null) return null;
    if (!PlateFormat.isValid(candidate)) return null;

    final plate = PlateFormat.normalize(candidate);
    _window.addLast(plate);
    while (_window.length > windowSize) {
      _window.removeFirst();
    }

    final count = _window.where((p) => p == plate).length;
    if (count >= threshold) {
      reset();
      return plate;
    }
    return null;
  }

  /// Clears accumulated votes (e.g. after a confirmation or when restarting).
  void reset() => _window.clear();
}
