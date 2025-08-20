import 'package:flutter/material.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';

class ReprintProvider extends ChangeNotifier {
  bool _isLoading = true;
  List<dynamic> _history = [];
  List<dynamic> _historyCheckIn = [];

  bool get isLoading => _isLoading;
  List<dynamic> get history => _history;
  List<dynamic> get historyCheckIn => _historyCheckIn;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> loadHistory(BuildContext context, String vehicleNumber) async {
    _setLoading(true);
    try {
      final all = LocalDb.getHistory();
      if (vehicleNumber.trim().isEmpty) {
        _history = all;
      } else {
        final q = vehicleNumber.trim().toUpperCase();
        final filtered = all.where((e) => (e['vehicle_no'] ?? '').toString().toUpperCase().contains(q)).toList();
        if (filtered.isNotEmpty) {
          _history = filtered;
        } else {
          // Fallback to server search when not found locally
          final api = ApiClient.create();
          final res = await api.post(
            path: 'get_history',
            data: {
              'admin_id': await PrefHelper.getUserData('admin_id'),
              'vehicle_number': vehicleNumber.trim(),
            },
          );
          final List data = (res.data['data'] ?? []) as List;
          _history = data;
        }
      }
    } catch (_) {
      // keep current history on errors
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCheckInHistory(BuildContext context, String vehicleNumber) async {
    _setLoading(true);
    try {
      final all = LocalDb.getHistory();
      final onlyCheckIn = all.where((e) => (e['status']?.toString() ?? '1') == '1').toList();
      if (vehicleNumber.trim().isEmpty) {
        _historyCheckIn = onlyCheckIn;
      } else {
        final q = vehicleNumber.trim().toUpperCase();
        final filtered = onlyCheckIn.where((e) => (e['vehicle_no'] ?? '').toString().toUpperCase().contains(q)).toList();
        if (filtered.isNotEmpty) {
          _historyCheckIn = filtered;
        } else {
          // Fallback to server search
          final api = ApiClient.create();
          final res = await api.post(
            path: 'get_check_in_history',
            data: {
              'admin_id': await PrefHelper.getUserData('admin_id'),
              'vehicle_number': vehicleNumber.trim(),
            },
          );
          final List data = (res.data['data'] ?? []) as List;
          _historyCheckIn = data;
        }
      }
    } catch (_) {
      // keep current history on errors
    } finally {
      _setLoading(false);
    }
  }
}
