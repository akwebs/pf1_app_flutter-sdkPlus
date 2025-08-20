import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';

class SlotProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient.create();
  final CancelToken _cancelToken = CancelToken();

  bool _isLoading = true;
  Map<String, dynamic> _slot = {};

  bool get isLoading => _isLoading;
  Map<String, dynamic> get slot => _slot;

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Load parking slots
  Future<void> loadSlots(BuildContext context, String vehicleTypeId) async {
    // Frontend no longer fetches a slot. Backend will auto-assign on save.
    // We set an AUTO placeholder so existing UI/validations continue to work.
    _setLoading(true);
    try {
      _slot = {"slot": "AUTO", "slot_id": "AUTO"};
    } finally {
      _setLoading(false);
    }
  }

  resetSlot() {
    _slot.clear();
    notifyListeners();
  }
}
