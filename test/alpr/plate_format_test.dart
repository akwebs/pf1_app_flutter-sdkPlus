import 'package:flutter_test/flutter_test.dart';
import 'package:kota_pf1_app/alpr/plate_format.dart';

void main() {
  group('PlateFormat.normalize', () {
    test('uppercases and strips spaces and hyphens', () {
      expect(PlateFormat.normalize('mh 12 ab 1234'), 'MH12AB1234');
      expect(PlateFormat.normalize('dl-8c-af-5031'), 'DL8CAF5031');
    });

    test('drops other punctuation and whitespace', () {
      expect(PlateFormat.normalize('  KA.01\tAB#1234 '), 'KA01AB1234');
    });
  });

  group('PlateFormat.isValid', () {
    test('accepts standard car plates', () {
      expect(PlateFormat.isValid('MH12AB1234'), isTrue); // 2-digit RTO, 2-letter series
      expect(PlateFormat.isValid('DL8CAF5031'), isTrue); // 1-digit RTO, 3-letter series
      expect(PlateFormat.isValid('KA01A1234'), isTrue); // 1-letter series
    });

    test('accepts BH-series plates', () {
      expect(PlateFormat.isValid('22BH1234A'), isTrue);
      expect(PlateFormat.isValid('21BH5678AB'), isTrue);
    });

    test('rejects malformed plates', () {
      expect(PlateFormat.isValid(''), isFalse);
      expect(PlateFormat.isValid('ABCD'), isFalse);
      expect(PlateFormat.isValid('MH12AB123'), isFalse); // only 3 trailing digits
      expect(PlateFormat.isValid('1234'), isFalse);
      expect(PlateFormat.isValid('MH12ABCD1234'), isFalse); // 4-letter series
    });

    test('normalizes before validating', () {
      expect(PlateFormat.isValid('mh 12 ab 1234'), isTrue);
    });
  });

  group('PlateFormat.mergeLines', () {
    test('joins two-line bike plate into one normalized string', () {
      expect(PlateFormat.mergeLines(['MH 12', 'AB 1234']), 'MH12AB1234');
    });

    test('single-line car plate is just normalized', () {
      expect(PlateFormat.mergeLines(['KA 01 A 1234']), 'KA01A1234');
    });

    test('ignores empty/blank lines', () {
      expect(PlateFormat.mergeLines(['', 'MH12', '  ', 'AB1234']), 'MH12AB1234');
    });
  });
}
