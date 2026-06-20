import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Converts camera frames into RGB images the ALPR models can consume.
///
/// Only exercised on a real device (the camera plugin produces YUV420 frames),
/// so it is kept dependency-light and free of platform channels.
class FrameConverter {
  /// Converts a YUV420 [CameraImage] to an RGB [img.Image].
  static img.Image yuv420ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final out = img.Image(width: width, height: height);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

        final yy = yPlane.bytes[yIndex];
        final uu = uPlane.bytes[uvIndex];
        final vv = vPlane.bytes[uvIndex];

        final r = (yy + 1.402 * (vv - 128)).clamp(0, 255).toInt();
        final g = (yy - 0.344136 * (uu - 128) - 0.714136 * (vv - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yy + 1.772 * (uu - 128)).clamp(0, 255).toInt();

        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }
}
