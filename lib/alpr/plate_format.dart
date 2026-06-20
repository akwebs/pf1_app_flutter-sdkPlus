/// Pure helpers for normalizing and validating Indian vehicle number plates.
///
/// Used by the on-device ALPR pipeline to turn raw OCR output into a clean,
/// validated plate string. Covers both standard plates (cars and bikes) and
/// the newer BH (Bharat) series.
class PlateFormat {
  PlateFormat._();

  /// Standard format: 2-letter state + 1-2 digit RTO code + 1-3 letter series
  /// + 4-digit number. e.g. MH12AB1234, DL8CAF5031, KA01A1234.
  static final RegExp _standard = RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,3}\d{4}$');

  /// BH (Bharat) series: 2-digit year + BH + 4-digit number + 1-2 letters.
  /// e.g. 22BH1234A, 21BH5678AB.
  static final RegExp _bh = RegExp(r'^\d{2}BH\d{4}[A-Z]{1,2}$');

  static final RegExp _nonAlphaNumeric = RegExp(r'[^A-Z0-9]');

  /// Uppercases and removes everything that is not a letter or digit.
  static String normalize(String raw) {
    return raw.toUpperCase().replaceAll(_nonAlphaNumeric, '');
  }

  /// True when [raw], once normalized, is a valid Indian plate.
  static bool isValid(String raw) {
    final plate = normalize(raw);
    return _standard.hasMatch(plate) || _bh.hasMatch(plate);
  }

  /// Merges OCR text [lines] (top-to-bottom) into a single normalized plate.
  ///
  /// Bike plates are typically two rows; cars are usually one. Blank lines are
  /// ignored so a stray empty row from the recognizer does not corrupt output.
  static String mergeLines(Iterable<String> lines) {
    return lines.map(normalize).where((s) => s.isNotEmpty).join();
  }
}
