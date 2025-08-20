import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:kota_pf1_app/constants/api_constants.dart';

class ImageHelper {
  static Future<Map<String, dynamic>?> capturePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      File imageFile = File(photo.path);
      String fileName = photo.path.split('/').last;

      return {
        "path": photo.path, // Image file path
        "filename": fileName, // Image file name
        "formData": FormData.fromMap({
          "image": await MultipartFile.fromFile(photo.path, filename: fileName),
        }), // FormData for Dio upload
      };
    }
    return null;
  }

  static Future<String> uploadImage(formData) async {
    if (formData != null) {
      Dio dio = Dio();
      Response response = await dio.post(
        '${ApiConstants.apiBaseUrl}upload_image',
        data: formData,
        options: Options(headers: {
          "apikey": ApiConstants.apiKey,
          "Content-Type": "multipart/form-data"
        }),
      );

      if (response.data['filename'] != null) {
        return response.data['filename'];
      } else {
        return "";
      }
    } else {
      return "";
    }
  }

  static Future<String?> saveCameraImageToFile(CameraImage cameraImage) async {
    try {
      // Convert YUV420 to RGB with optimized processing
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      
      // Create a new image with the correct dimensions
      final img.Image rgbImage = img.Image(width: width, height: height);
      
      // Get the Y, U, and V planes
      final planeY = cameraImage.planes[0];
      final planeU = cameraImage.planes[1];
      final planeV = cameraImage.planes[2];
      
      // Get the stride and pixel stride for U and V planes
      final int uvRowStride = planeU.bytesPerRow;
      final int uvPixelStride = planeU.bytesPerPixel!;
      
      // Process the image in chunks for better performance
      const int chunkSize = 16;
      for (int y = 0; y < height; y += chunkSize) {
        for (int x = 0; x < width; x += chunkSize) {
          // Process each chunk
          for (int cy = y; cy < y + chunkSize && cy < height; cy++) {
            for (int cx = x; cx < x + chunkSize && cx < width; cx++) {
              final int uvIndex = uvPixelStride * (cx ~/ 2) + uvRowStride * (cy ~/ 2);
              final int index = cy * width + cx;
              
              // Get Y, U, V values
              final int yp = planeY.bytes[index];
              final int up = planeU.bytes[uvIndex];
              final int vp = planeV.bytes[uvIndex];
              
              // Convert YUV to RGB using optimized coefficients
              int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
              int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
              int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
              
              // Set the pixel in the output image
              rgbImage.setPixelRgba(cx, cy, r, g, b, 255);
            }
          }
        }
      }
      
      // Encode as JPEG with high quality
      final jpeg = img.encodeJpg(rgbImage, quality: 100);
      
      // Save to temporary file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(jpeg);
      
      return file.path;
    } catch (e) {
      print('Error saving CameraImage to file: $e');
      return null;
    }
  }
}
