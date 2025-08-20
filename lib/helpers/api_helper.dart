import 'package:dio/dio.dart';
import 'package:kota_pf1_app/constants/api_constants.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  factory ApiClient.create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.apiBaseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    )..interceptors.add(LogInterceptor(
        responseBody: true,
        requestBody: true,
        requestHeader: true,
        responseHeader: true,
        error: true));

    return ApiClient(dio);
  }

  Future<void> _setToken() async {
    // Refresh baseUrl on every call to honor environment switches
    _dio.options.baseUrl = ApiConstants.apiBaseUrl;
    final token = await PrefHelper.getString('token');
    _dio.options.headers['Authorization'] = 'Bearer $token';
    _dio.options.headers['X-API-KEY'] = ApiConstants.apiKey;
    _dio.options.headers['apikey'] = ApiConstants.apiKey;
  }

  Future<Response> get(
      {required String path, dynamic data, CancelToken? cancelToken}) async {
    await _setToken();
    return _dio.get(path, data: data, cancelToken: cancelToken);
  }

  Future<Response> post(
      {required String path, dynamic data, CancelToken? cancelToken}) async {
    await _setToken();
    return _dio.post(path, data: data, cancelToken: cancelToken);
  }

  Future<Response> put(
      {required String path, dynamic data, CancelToken? cancelToken}) async {
    await _setToken();
    return _dio.put(path, data: data, cancelToken: cancelToken);
  }

  Future<Response> delete(
      {required String path, CancelToken? cancelToken}) async {
    await _setToken();
    return _dio.delete(path, cancelToken: cancelToken);
  }
}
