import 'package:flutter/material.dart';

class ParkingTypeProvider extends ChangeNotifier {
  String _selectedParkingType = '';
  List<String> _availableParkingTypes = ['1'];
  Map<String, String> _parkingTypeTextMap = {};

  String get selectedParkingType => _selectedParkingType;
  List<String> get availableParkingTypes => List.unmodifiable(_availableParkingTypes);
  Map<String, String> get parkingTypeTextMap => Map.unmodifiable(_parkingTypeTextMap);

  void setParkingType(String type) {
    _selectedParkingType = type;
    notifyListeners();
  }

  void resetSelectedParkingType() {
    _selectedParkingType = '';
    notifyListeners();
  }

  void setAvailableParkingTypes(List<String> types) {
    _availableParkingTypes = List.from(types);
    // Ensure selected is valid when available types change
    if (_availableParkingTypes.isNotEmpty) {
      if (!_availableParkingTypes.contains(_selectedParkingType)) {
        _selectedParkingType = _availableParkingTypes.first;
      }
    } else {
      _selectedParkingType = '';
    }
    notifyListeners();
  }

  void setParkingTypeTextMap(Map<String, String> map) {
    _parkingTypeTextMap = Map.from(map);
    notifyListeners();
  }
}
