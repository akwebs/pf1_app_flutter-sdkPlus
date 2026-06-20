import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'alpr_controller.dart';
import 'frame_converter.dart';
import 'tflite_plate_detector.dart';
import 'tflite_plate_recognizer.dart';

/// Live camera view for license-plate scanning.
///
/// Single integration point used by the check-in / check-out pages in place of
/// the old native `facedetectionview`. It owns the camera lifecycle and the
/// [AlprController] pipeline; when a plate is confirmed it calls
/// [onPlateDetected] with a normalized string (e.g. `MH12AB1234`).
///
/// The recognition models are loaded on start. Until they ship (Phase 4) the
/// detector/recognizer report not-ready, the image stream is not started, and
/// the widget simply shows the live preview while users type the number.
class AlprScannerView extends StatefulWidget {
  const AlprScannerView({
    super.key,
    required this.onPlateDetected,
  });

  /// Called with a confirmed, normalized plate (e.g. `MH12AB1234`).
  final ValueChanged<String> onPlateDetected;

  @override
  State<AlprScannerView> createState() => _AlprScannerViewState();
}

class _AlprScannerViewState extends State<AlprScannerView> {
  CameraController? _controller;
  AlprController? _alpr;
  bool _ready = false;
  bool _streaming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera available');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final detector = TflitePlateDetector();
      final recognizer = TflitePlateRecognizer();
      await detector.load();
      await recognizer.load();
      final alpr = AlprController(
        detector: detector,
        recognizer: recognizer,
        onPlate: (result) => widget.onPlateDetected(result.number),
      );

      setState(() {
        _controller = controller;
        _alpr = alpr;
        _ready = true;
      });

      // Only spin up the (expensive) frame stream once a model is actually
      // loaded; otherwise the preview alone is shown and entry stays manual.
      if (detector.isReady && recognizer.isReady) {
        await controller.startImageStream(_onFrame);
        _streaming = true;
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  bool _convertingFrame = false;
  void _onFrame(CameraImage image) {
    // Drop frames while one is still being converted (backpressure at source).
    if (_convertingFrame || _alpr == null) return;
    _convertingFrame = true;
    // TODO(Phase 4): move YUV->RGB + inference onto an isolate to keep the UI
    // thread free on lower-end devices.
    final rgb = FrameConverter.yuv420ToRgb(image);
    _alpr!.processImage(rgb).whenComplete(() => _convertingFrame = false);
  }

  @override
  void dispose() {
    if (_streaming) {
      _controller?.stopImageStream();
    }
    _alpr?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _Centered(
        child: Text(
          '$_error\nEnter the number manually below.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }
    if (!_ready || _controller == null) {
      return const _Centered(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final preview = _controller!.value.previewSize;
    // Fill the whole box (cover): scale the preview up so the shorter side
    // matches the box, cropping the overflow. previewSize is reported in
    // sensor orientation, so width/height are swapped for portrait display.
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: preview?.height ?? _controller!.value.aspectRatio,
          height: preview?.width ?? 1,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
