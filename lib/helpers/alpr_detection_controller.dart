import 'package:flutter/services.dart';
import 'package:alprsdk_plugin/alprdetection_interface.dart';

class LocalAlprDetectionViewController {
  final int id;
  final AlprDetectionInterface _interface;
  late final MethodChannel _channel;

  LocalAlprDetectionViewController(this.id, this._interface) {
    _channel = MethodChannel('facedetectionview_$id');
  }

  Future<void> initHandler() async {
    _channel.setMethodCallHandler((call) {
      switch (call.method) {
        case 'onAlprDetected':
          _interface.onAlprDetected(call.arguments);
          break;
        default:
          throw PlatformException(
            code: 'notImplemented',
            message: 'Method ${call.method} not implemented',
          );
      }
      return Future<void>.value();
    });
  }

  Future<void> startCamera(int cameraId) async {
    try {
      await _channel.invokeMethod('startCamera', {'cameraLens': cameraId});
    } catch (e) {
      print('Error starting camera: $e');
    }
  }

  Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod('stopCamera');
    } catch (e) {
      print('Error stopping camera: $e');
    }
  }
} 