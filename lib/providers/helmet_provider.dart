import 'package:flutter/material.dart';

class HelmetProvider extends ChangeNotifier {
  bool _hasHelmet = false;

  bool get hasHelmet => _hasHelmet;

  void setHelmetStatus(bool status) {
    _hasHelmet = status;
    notifyListeners();
  }

  void resetHelmetStatus() {
    _hasHelmet = false;
    notifyListeners();
  }
} 