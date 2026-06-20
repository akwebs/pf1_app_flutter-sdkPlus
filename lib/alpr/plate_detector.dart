import 'package:image/image.dart' as img;

/// A detected plate region, in normalized image coordinates (0..1).
class PlateBox {
  const PlateBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.score,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  /// Detector confidence in [0, 1].
  final double score;
}

/// Finds license-plate regions in an RGB frame.
///
/// Implementations are injected into [AlprController] so the pipeline can be
/// tested with fakes and the model backend swapped without touching callers.
abstract class PlateDetector {
  /// False until a model is loaded; the controller skips inference while false.
  bool get isReady;

  Future<List<PlateBox>> detect(img.Image image);

  void dispose();
}
