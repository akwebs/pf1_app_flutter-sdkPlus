import 'package:image/image.dart' as img;

/// Reads the characters of a cropped plate image into a raw string.
///
/// The raw string is not assumed to be clean — [AlprController] feeds it
/// through [PlateFormat]/[PlateVoter] for normalization, validation and voting.
abstract class PlateRecognizer {
  /// False until a model is loaded; the controller skips inference while false.
  bool get isReady;

  Future<String?> recognize(img.Image plateCrop);

  void dispose();
}
