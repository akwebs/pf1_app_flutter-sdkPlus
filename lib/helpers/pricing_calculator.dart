import 'package:kota_pf1_app/constants/print_data.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';

class PricingResult {
  final int extraAmount; // numeric final amount
  final String extraAmountString; // e.g. "120 (1 d 3 h 5 m)"
  final String durationString; // e.g. "1 d 3 h 5 m"

  PricingResult({required this.extraAmount, required this.extraAmountString, required this.durationString});
}

class PricingCalculator {
  // Helper to compute time delta components
  static (_TimeParts, int) _computeParts(DateTime checkin, DateTime now) {
    final diff = now.difference(checkin);
    final totalMinutes = diff.inMinutes;
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutesOnly = diff.inMinutes % 60;
    final durationString = '${days} d ${hours} h ${minutesOnly} m';
    return (_TimeParts(days: days, hours: hours, minutesOnly: minutesOnly, totalMinutes: totalMinutes), totalMinutes);
  }

  static PricingResult calculate({
    required DateTime checkinTime,
    required String vehicleTypeText, // 'Two Wheeler' or 'Four Wheeler'
    required int parkingType, // 1 or 2 where applicable
  }) {
    final env = PrintData.currentEnv; // 'ggc','sogariya','pf1','pf4'
    final now = DateTime.now();
    final (parts, totalMinutes) = _computeParts(checkinTime, now);
    final totalHours = _ceilHours(parts.days, parts.hours, parts.minutesOnly);

    // Try dynamic DB-driven pricing first
    final dbResult = _computeFromDbRates(
      vehicleTypeText: vehicleTypeText,
      parkingType: parkingType,
      totalHours: totalHours,
      totalMinutes: totalMinutes,
    );
    if (dbResult != null) {
      final durationStr = '${parts.days} d ${parts.hours} h ${parts.minutesOnly} m';
      final formatted = '${dbResult.round()} ($durationStr)';
      return PricingResult(extraAmount: dbResult.round(), extraAmountString: formatted, durationString: durationStr);
    }

    // Fallback to hardcoded rules mirroring PHP
    int extra = 0;

    if (env == 'ggc') {
      if (vehicleTypeText.toLowerCase() == 'two wheeler') {
        extra = _ggcTwoWheeler(totalHours);
      } else {
        extra = _ggcFourWheeler(totalHours);
      }
    } else if (env == 'sogariya') {
      if (parkingType == 1) {
        // Drop & Go rough defaults
        extra = _dropAndGo(totalMinutes, vehicleTypeText.toLowerCase() == 'two wheeler' ? 10 : 20, vehicleTypeText.toLowerCase() == 'two wheeler' ? 20 : 40, vehicleTypeText.toLowerCase() == 'two wheeler' ? 30 : 100, vehicleTypeText.toLowerCase() == 'two wheeler' ? 80 : 300, vehicleTypeText.toLowerCase() == 'two wheeler' ? 130 : 500, vehicleTypeText.toLowerCase() == 'two wheeler' ? 210 : 800, vehicleTypeText.toLowerCase() == 'two wheeler' ? 290 : 1100, vehicleTypeText.toLowerCase() == 'two wheeler' ? 100 : 500);
      } else {
        if (totalHours <= 6) {
          extra = vehicleTypeText.toLowerCase() == 'two wheeler' ? 20 : 40;
        } else {
          final perDay = vehicleTypeText.toLowerCase() == 'two wheeler' ? 30 : 100;
          final blocks = (totalHours / 24).ceil();
          extra = blocks * perDay;
        }
      }
    } else {
      if (vehicleTypeText.toLowerCase() == 'two wheeler') {
        extra = _kotaPfTwoWheeler(totalHours);
      } else {
        extra = _kotaPfFourWheeler(totalHours);
      }
    }

    final durationStr = '${parts.days} d ${parts.hours} h ${parts.minutesOnly} m';
    final formatted = '${extra.round()} ($durationStr)';
    return PricingResult(extraAmount: extra.round(), extraAmountString: formatted, durationString: durationStr);
  }

  static int? _computeFromDbRates({
    required String vehicleTypeText,
    required int parkingType,
    required int totalHours,
    required int totalMinutes,
  }) {
    final rates = LocalDb.getRates();
    if (rates.isEmpty) return null;

    final filtered = rates.where((r) =>
      (r['vehicle_type_text'] ?? '').toString().toLowerCase() == vehicleTypeText.toLowerCase() &&
      (r['parking_type'] ?? '').toString() == parkingType.toString()
    ).toList();

    if (filtered.isEmpty) return null;

    // Build a duration map
    final Map<String, int> priceByKey = {};
    for (final r in filtered) {
      final dt = (r['duration_text'] ?? '').toString().toLowerCase();
      final price = int.tryParse((r['price'] ?? '0').toString()) ?? 0;
      if (dt.contains('up to 04 hours') || dt.contains('up to 4 hours')) priceByKey['0_4'] = price;
      else if (dt.contains('up to 12 hours')) priceByKey['4_12'] = price;
      else if (dt.contains('up to 24 hours')) priceByKey['12_24'] = price;
      else if (dt.contains('after 24 hours up to 48 hours')) priceByKey['24_48'] = price;
      else if (dt.contains('after 48 hours up to 72 hours')) priceByKey['48_72'] = price;
      else if (dt.contains('after 72 hours up to 96 hours')) priceByKey['72_96'] = price;
      else if (dt.contains('after 96 hours up to 120 hours')) priceByKey['96_120'] = price;
      else if (dt.contains('after 120 hours')) priceByKey['120_plus'] = price;
      else if (dt.contains('up to 06 hours') || dt.contains('up to 6 hours')) priceByKey['0_6'] = price;
      else if (dt.contains('more than 6')) priceByKey['gt_6'] = price;
    }

    // Sogariya long parking special case
    if (parkingType == 2 && (priceByKey.containsKey('0_6') || priceByKey.containsKey('gt_6'))) {
      if (totalHours <= 6) {
        return priceByKey['0_6'] ?? 0;
      } else {
        final perDay = priceByKey['gt_6'] ?? 0;
        final blocks = (totalHours / 24).ceil();
        return blocks * perDay;
      }
    }

    // General additive model using ranges if present
    if (totalHours <= 4 && priceByKey.containsKey('0_4')) return priceByKey['0_4'];
    if (totalHours <= 12 && priceByKey.containsKey('4_12')) return priceByKey['4_12'];
    if (totalHours < 24 && priceByKey.containsKey('12_24')) return priceByKey['12_24'];

    if (!priceByKey.containsKey('12_24')) return null;
    int extra = priceByKey['12_24']!;
    int remaining = totalHours - 24;
    // 24-48
    if (remaining > 0 && priceByKey.containsKey('24_48')) {
      final blocks = (remaining / 24).ceil().clamp(0, 1);
      extra += blocks * priceByKey['24_48']!;
      remaining -= blocks * 24;
    }
    // 48-72
    if (remaining > 0 && priceByKey.containsKey('48_72')) {
      final blocks = (remaining / 24).ceil().clamp(0, 1);
      extra += blocks * priceByKey['48_72']!;
      remaining -= blocks * 24;
    }
    // 72-96
    if (remaining > 0 && priceByKey.containsKey('72_96')) {
      final blocks = (remaining / 24).ceil().clamp(0, 1);
      extra += blocks * priceByKey['72_96']!;
      remaining -= blocks * 24;
    }
    // 96-120
    if (remaining > 0 && priceByKey.containsKey('96_120')) {
      final blocks = (remaining / 24).ceil().clamp(0, 1);
      extra += blocks * priceByKey['96_120']!;
      remaining -= blocks * 24;
    }
    // >120
    if (remaining > 0 && priceByKey.containsKey('120_plus')) {
      final blocks = (remaining / 24).ceil();
      extra += blocks * priceByKey['120_plus']!;
    }

    return extra;
  }

  static int _ceilHours(int days, int hours, int minutes) {
    int totalHours = days * 24 + hours;
    if (minutes > 0) totalHours += 1;
    return totalHours;
  }

  // Hardcoded fallbacks mirroring PHP blocks
  static int _ggcTwoWheeler(int totalHours) {
    if (totalHours <= 4) return 10;
    if (totalHours <= 12) return 20;
    if (totalHours < 24) return 30;
    int extra = 30; // 12-24 base
    final after24 = totalHours - 24;
    final blocks24_72 = (after24 / 24).ceil().clamp(0, 2);
    extra += blocks24_72 * 80;
    final remAfter72 = after24 - blocks24_72 * 24;
    final blocks72_120 = (remAfter72 / 24).ceil().clamp(0, 2);
    extra += blocks72_120 * 130;
    final remAfter120 = remAfter72 - blocks72_120 * 24;
    final blocks120Plus = (remAfter120 / 24).ceil().clamp(0, 1000000);
    extra += blocks120Plus * 100;
    return extra;
  }

  static int _ggcFourWheeler(int totalHours) {
    if (totalHours <= 4) return 20;
    if (totalHours <= 12) return 40;
    if (totalHours < 24) return 100;
    int extra = 100;
    final after24 = totalHours - 24;
    final blocks24_72 = (after24 / 24).ceil().clamp(0, 2);
    extra += blocks24_72 * 300;
    final remAfter72 = after24 - blocks24_72 * 24;
    final blocks72_120 = (remAfter72 / 24).ceil().clamp(0, 2);
    extra += blocks72_120 * 500;
    final remAfter120 = remAfter72 - blocks72_120 * 24;
    final blocks120Plus = (remAfter120 / 24).ceil().clamp(0, 1000000);
    extra += blocks120Plus * 500;
    return extra;
  }

  static int _kotaPfTwoWheeler(int totalHours) {
    if (totalHours <= 4) return 10;
    if (totalHours <= 12) return 20;
    if (totalHours < 24) return 30;
    int extra = 30;
    final after24 = totalHours - 24;
    final blocks24_72 = (after24 / 24).ceil().clamp(0, 2);
    extra += blocks24_72 * 80;
    final remAfter72 = after24 - blocks24_72 * 24;
    final blocks72_120 = (remAfter72 / 24).ceil().clamp(0, 2);
    extra += blocks72_120 * 210; // Kota rates differ here (example from php)
    final remAfter120 = remAfter72 - blocks72_120 * 24;
    final blocks120Plus = (remAfter120 / 24).ceil().clamp(0, 1000000);
    extra += blocks120Plus * 100;
    return extra;
  }

  static int _kotaPfFourWheeler(int totalHours) {
    if (totalHours <= 4) return 20;
    if (totalHours <= 12) return 60;
    if (totalHours < 24) return 120;
    int extra = 120;
    final after24 = totalHours - 24;
    final blocks24_72 = (after24 / 24).ceil().clamp(0, 2);
    extra += blocks24_72 * 320;
    final remAfter72 = after24 - blocks24_72 * 24;
    final blocks72_120 = (remAfter72 / 24).ceil().clamp(0, 2);
    extra += blocks72_120 * 820;
    final remAfter120 = remAfter72 - blocks72_120 * 24;
    final blocks120Plus = (remAfter120 / 24).ceil().clamp(0, 1000000);
    extra += blocks120Plus * 500;
    return extra;
  }

  static int _dropAndGo(int totalMinutes, int r0_4, int r4_12, int r12_24, int r24_48, int r48_72, int r72_96, int r96_120, int r120PlusPerDay) {
    if (totalMinutes <= 240) return r0_4;
    if (totalMinutes <= 720) return r4_12;
    if (totalMinutes <= 1440) return r12_24;
    if (totalMinutes <= 2880) return r24_48;
    if (totalMinutes <= 4320) return r48_72;
    if (totalMinutes <= 5760) return r72_96;
    if (totalMinutes <= 7200) return r96_120;
    final over = totalMinutes - 7200;
    final blocks = (over / 1440).ceil();
    return r96_120 + blocks * r120PlusPerDay;
  }
}

class _TimeParts {
  final int days;
  final int hours;
  final int minutesOnly;
  final int totalMinutes;
  _TimeParts({required this.days, required this.hours, required this.minutesOnly, required this.totalMinutes});
} 