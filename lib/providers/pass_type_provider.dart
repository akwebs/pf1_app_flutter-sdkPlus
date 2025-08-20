import 'package:flutter/material.dart';

class PassTypeProvider extends ChangeNotifier {
  String _selectedPassType = ""; //can be 1:vip 2:employee 3:customer:
  String get selectedPassType => _selectedPassType;

  void setPassType(String newVal) {
    _selectedPassType = newVal;
    notifyListeners();
  }

  resetSelectedPassType() {
    _selectedPassType = "";
    notifyListeners();
  }
}
