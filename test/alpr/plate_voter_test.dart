import 'package:flutter_test/flutter_test.dart';
import 'package:kota_pf1_app/alpr/plate_voter.dart';

void main() {
  group('PlateVoter', () {
    test('does not confirm before threshold reached', () {
      final voter = PlateVoter(windowSize: 5, threshold: 3);
      expect(voter.add('MH12AB1234'), isNull);
      expect(voter.add('MH12AB1234'), isNull);
    });

    test('confirms once the same plate hits the threshold', () {
      final voter = PlateVoter(windowSize: 5, threshold: 3);
      voter.add('MH12AB1234');
      voter.add('MH12AB1234');
      expect(voter.add('MH12AB1234'), 'MH12AB1234');
    });

    test('ignores invalid candidates without consuming the window', () {
      final voter = PlateVoter(windowSize: 3, threshold: 3);
      voter.add('MH12AB1234');
      expect(voter.add('GARBAGE'), isNull); // not a valid plate
      voter.add('MH12AB1234');
      expect(voter.add('MH12AB1234'), 'MH12AB1234');
    });

    test('normalizes candidates before counting', () {
      final voter = PlateVoter(windowSize: 5, threshold: 2);
      voter.add('mh 12 ab 1234');
      expect(voter.add('MH12AB1234'), 'MH12AB1234');
    });

    test('old reads fall out of the window', () {
      final voter = PlateVoter(windowSize: 3, threshold: 3);
      voter.add('MH12AB1234');
      voter.add('KA01A1234');
      voter.add('KA01A1234');
      // window now [MH.., KA.., KA..]; MH has dropped to 1, no 3-of-3 yet
      expect(voter.add('KA01A1234'), 'KA01A1234');
    });

    test('reset clears accumulated votes', () {
      final voter = PlateVoter(windowSize: 5, threshold: 2);
      voter.add('MH12AB1234');
      voter.reset();
      expect(voter.add('MH12AB1234'), isNull);
    });
  });
}
