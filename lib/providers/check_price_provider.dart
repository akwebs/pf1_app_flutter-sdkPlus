import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:kota_pf1_app/constants/str_constants.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:kota_pf1_app/helpers/toast_helper.dart';

class CheckPriceProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient.create();
  final CancelToken _cancelToken = CancelToken();

  bool _isLoading = false;

  Map _vehicleDetail = {};

  bool get isLoading => _isLoading;

  Map get vehicleDetail => _vehicleDetail;

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> loadVehicleDetails(
      BuildContext context, String vehicleNumber) async {
    if (vehicleDetail.isEmpty) {
      _setLoading(true);
    }

    try {
      resetVehicleDetail();
      final response = await _apiClient.post(
        path: 'get_pass_details',
        data: {
          "admin_id": await PrefHelper.getUserData('admin_id'),
          "vehicle_no": vehicleNumber,
        },
        cancelToken: _cancelToken,
      );

      _vehicleDetail = response.data ?? {};
      if (_vehicleDetail['status'] != '200') {
        ToastHelper.nativeToastErr(
            msg:
                _vehicleDetail['msg'] ?? 'No data found / Already checked out');
      }
    } on DioException catch (err) {
      ToastHelper.openErrorToast(context, err.response?.data['message']);
    } on Exception {
      ToastHelper.openErrorToast(context, StrConstants.connectionError);
    }

    _setLoading(false);
  }

  resetVehicleDetail() {
    _vehicleDetail.clear();
    notifyListeners();
  }
}
