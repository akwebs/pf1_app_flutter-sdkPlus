import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kota_pf1_app/alpr/alpr_controller.dart';
import 'package:kota_pf1_app/alpr/plate_detector.dart';
import 'package:kota_pf1_app/alpr/plate_recognizer.dart';
import 'package:kota_pf1_app/alpr/plate_result.dart';
import 'package:kota_pf1_app/alpr/plate_voter.dart';

class _FakeDetector implements PlateDetector {
  _FakeDetector(this.boxes, {this.onDetect});
  final List<PlateBox> boxes;
  final void Function()? onDetect;
  @override
  bool get isReady => true;
  @override
  Future<List<PlateBox>> detect(img.Image image) async {
    onDetect?.call();
    return boxes;
  }

  @override
  void dispose() {}
}

class _FakeRecognizer implements PlateRecognizer {
  _FakeRecognizer(this.text);
  final String? text;
  @override
  bool get isReady => true;
  @override
  Future<String?> recognize(img.Image crop) async => text;
  @override
  void dispose() {}
}

void main() {
  final image = img.Image(width: 100, height: 60);
  const box = PlateBox(left: 0.1, top: 0.1, width: 0.5, height: 0.3, score: 0.9);

  test('emits a confirmed plate after enough consistent frames', () async {
    final results = <PlateResult>[];
    final controller = AlprController(
      detector: _FakeDetector([box]),
      recognizer: _FakeRecognizer('MH 12 AB 1234'),
      voter: PlateVoter(windowSize: 3, threshold: 2),
      onPlate: results.add,
      minInterval: Duration.zero,
    );

    await controller.processImage(image);
    expect(results, isEmpty, reason: 'one frame is below threshold');

    await controller.processImage(image);
    expect(results.single.number, 'MH12AB1234');
  });

  test('does not emit when the detector finds no plate', () async {
    final results = <PlateResult>[];
    final controller = AlprController(
      detector: _FakeDetector([]),
      recognizer: _FakeRecognizer('MH12AB1234'),
      voter: PlateVoter(windowSize: 3, threshold: 1),
      onPlate: results.add,
      minInterval: Duration.zero,
    );

    await controller.processImage(image);
    expect(results, isEmpty);
  });

  test('throttles detection by minInterval', () async {
    var detectCalls = 0;
    final controller = AlprController(
      detector: _FakeDetector([box], onDetect: () => detectCalls++),
      recognizer: _FakeRecognizer('MH12AB1234'),
      voter: PlateVoter(windowSize: 3, threshold: 2),
      onPlate: (_) {},
      minInterval: const Duration(seconds: 10),
    );

    await controller.processImage(image);
    await controller.processImage(image);
    expect(detectCalls, 1, reason: 'second frame within the interval is skipped');
  });
}
