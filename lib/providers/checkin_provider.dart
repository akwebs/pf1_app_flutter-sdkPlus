import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class CheckInProvider extends ChangeNotifier {
  String _licenseImage = "";
  String _vehicleImage = "";

  FormData _licenseImageData = FormData();
  FormData _vehicleImageData = FormData();

  String get licenseImage => _licenseImage;
  String get vehicleImage => _vehicleImage;

  FormData get licenseImageData => _licenseImageData;
  FormData get vehicleImageData => _vehicleImageData;

  setLicenseImage(String newVal, FormData formData) {
    _licenseImage = newVal;
    _licenseImageData = formData;
    notifyListeners();
  }

  setVehicleImage(String newVal, FormData formData) {
    _vehicleImage = newVal;
    _vehicleImageData = formData;
    notifyListeners();
  }

  resetImages() {
    _licenseImage = "";
    _vehicleImage = "";
    _licenseImageData = FormData();
    _vehicleImageData = FormData();
    notifyListeners();
  }
}
