class DateTimeHelper {
  /// Converts the first time component found in the string to 12-hour AM/PM format.
  /// Examples:
  /// - 2024-08-01 17:45:00 -> 2024-08-01 05:45:00 PM
  /// - 09:05 -> 09:05 AM
  /// If no time is found or already in AM/PM format, returns the original string.
  static String toAmPm(String? input) {
    if (input == null) return '';
    final value = input.trim();
    if (value.isEmpty) return value;

    // If already contains AM/PM, return as is
    final upper = value.toUpperCase();
    if (upper.contains(' AM') || upper.contains(' PM')) {
      return value;
    }

    final timeRegex = RegExp(r"(\d{1,2}):(\d{2})(?::(\d{2}))?");
    final match = timeRegex.firstMatch(value);
    if (match == null) return value;

    try {
      final hour = int.parse(match.group(1)!);
      final minute = match.group(2)!;
      final second = match.group(3); // optional

      final isPm = hour >= 12;
      final hour12 = (hour % 12 == 0) ? 12 : hour % 12;
      final hourStr = hour12.toString().padLeft(2, '0');
      final replaced = second == null
          ? '$hourStr:$minute ${isPm ? 'PM' : 'AM'}'
          : '$hourStr:$minute:$second ${isPm ? 'PM' : 'AM'}';

      return value.replaceRange(match.start, match.end, replaced);
    } catch (_) {
      return value;
    }
  }
} 