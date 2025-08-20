import 'package:flutter/material.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';

class VehicleTypeProvider extends ChangeNotifier {
  bool _isLoading = true;
  List<dynamic> _vehicleTypes = [];
  Map _selectedVehicleType = {};

  bool get isLoading => _isLoading;
  List<dynamic> get vehicleTypes => _vehicleTypes;
  Map get selectedVehicleType => _selectedVehicleType;

  void setVehicleType(Map newVal) {
    _selectedVehicleType = newVal;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Load vehicle types from local DB (Hive)
  Future<void> loadVehicleTypes(BuildContext context) async {
    if (_vehicleTypes.isEmpty) {
      _setLoading(true);
    }

    try {
      var local = LocalDb.getVehicleTypes();
      if (local.isEmpty) {
        // fallback: fetch and cache
        final api = ApiClient.create();
        final res = await api.post(path: 'get_vehicle_type', data: {"admin_id": await PrefHelper.getUserData('admin_id')});
        final List data = res.data['data'] ?? [];
        local = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        await LocalDb.saveVehicleTypes(local);
      }
      _vehicleTypes = local;

      // Ensure a valid selection when only one type is available
      if (_vehicleTypes.length == 1) {
        _selectedVehicleType = _vehicleTypes.first;
      } else if (_vehicleTypes.isNotEmpty) {
        // Keep previous selection if still valid; otherwise clear
        if (_selectedVehicleType.isEmpty ||
            !_vehicleTypes.any((t) => t['id'] == _selectedVehicleType['id'])) {
          _selectedVehicleType = {};
        }
      } else {
        _selectedVehicleType = {};
      }
    } finally {
      _setLoading(false);
    }
  }

  resetSelectedVehicleType() {
    _selectedVehicleType.clear();
    notifyListeners();
  }
}
