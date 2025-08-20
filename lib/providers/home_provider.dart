import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';

class HomeProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient.create();
  final CancelToken _cancelToken = CancelToken();

  bool _isLoading = true;
  Map<String, dynamic> _data = {};

  bool get isLoading => _isLoading;
  Map<String, dynamic> get data => _data;

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Load dashboard data
  Future<void> loadData(BuildContext context) async {
    if (data.isEmpty) {
      _setLoading(true);
    }

    try {
      final response = await _apiClient.post(
        path: 'dashboard',
        data: {
          "admin_id": await PrefHelper.getUserData('admin_id'),
        },
        cancelToken: _cancelToken,
      );

      _data = response.data;
    } on DioException catch (err) {
      ToastHelper.openErrorToast(context, err.response?.data['message']);
    } on Exception {
      ToastHelper.openErrorToast(context, StrConstants.connectionError);
    }

    _setLoading(false);
  }
}
