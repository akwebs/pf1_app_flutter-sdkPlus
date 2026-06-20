/// A confirmed plate read emitted by the ALPR pipeline.
class PlateResult {
  const PlateResult(this.number, {this.score = 1.0});

  /// Normalized, validated Indian plate string, e.g. `MH12AB1234`.
  final String number;

  /// Detector/recognizer confidence in [0, 1]. 1.0 for sources without a score.
  final double score;

  @override
  String toString() => 'PlateResult($number, score: $score)';
}
