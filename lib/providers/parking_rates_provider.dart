import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart'; // Your ApiClient
import 'package:kota_pf1_app/constants/api_constants.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart'; // For the endpoint
import 'package:provider/provider.dart';
import 'package:kota_pf1_app/providers/parking_type_provider.dart';
import 'package:kota_pf1_app/helpers/local_db.dart';

// Model for a single parking rate item
class ParkingRate {
  final String id;
  final String parkingType;
  final String parkingTypeText;
  final String vehicleTypeText;
  final String durationText;
  final String price;

  ParkingRate({
    required this.id,
    required this.parkingType,
    required this.parkingTypeText,
    required this.vehicleTypeText,
    required this.durationText,
    required this.price,
  });

  factory ParkingRate.fromJson(Map<String, dynamic> json) {
    return ParkingRate(
      id: json['id'].toString(),
      parkingType: json['parking_type'].toString(),
      parkingTypeText: json['parking_type_text'],
      vehicleTypeText: json['vehicle_type_text'],
      durationText: json['duration_text'],
      price: json['price'].toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parking_type': parkingType,
        'parking_type_text': parkingTypeText,
        'vehicle_type_text': vehicleTypeText,
        'duration_text': durationText,
        'price': price,
      };
}

class ParkingRatesProvider with ChangeNotifier {
  final ApiClient _apiClient =
      ApiClient.create(); // Create an instance of your ApiClient

  static const String _prefRates = 'cached_parking_rates';
  static const String _prefParkingTypeMap = 'cached_parking_type_map';
  static const String _prefAvailableParkingTypes = 'cached_available_parking_types';
  static const String _prefVehicleTypesFromRates = 'cached_vehicle_types_from_rates';

  List<ParkingRate> _parkingRates = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ParkingRate> get parkingRates => _parkingRates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // -------- Cache helpers --------
  Future<void> _loadFromCache() async {
    // Prefer LocalDb over old shared_pref cache
    final local = LocalDb.getRates();
    if (local.isNotEmpty) {
      _parkingRates = local.map((e) => ParkingRate.fromJson(e)).toList();
      return;
    }
    final jsonStr = await PrefHelper.getString(_prefRates);
    if (jsonStr.isEmpty) return;
    try {
      final List<dynamic> raw = jsonDecode(jsonStr);
      _parkingRates = raw.map((e) => ParkingRate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // ignore corrupt cache
    }
  }

  Future<void> _saveToCache() async {
    try {
      final raw = _parkingRates.map((e) => e.toJson()).toList();
      await PrefHelper.setString(_prefRates, jsonEncode(raw));
      await LocalDb.saveRates(raw.map((e) => Map<String, dynamic>.from(e)).toList());
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveDerivedDataToCache() async {
    final Map<String, String> typeMap = {};
    final Set<String> availableTypes = {};
    final Set<String> vehicleTypes = {};

    for (final r in _parkingRates) {
      availableTypes.add(r.parkingType);
      typeMap.putIfAbsent(r.parkingType, () => r.parkingTypeText);
      vehicleTypes.add(r.vehicleTypeText);
    }

    await PrefHelper.setString(_prefParkingTypeMap, jsonEncode(typeMap));
    await PrefHelper.setString(_prefAvailableParkingTypes, jsonEncode(availableTypes.toList()));
    await PrefHelper.setString(_prefVehicleTypesFromRates, jsonEncode(vehicleTypes.toList()));
    await LocalDb.saveParkingTypeMap(typeMap);
    await LocalDb.saveAvailableParkingTypeIds(availableTypes.toList());
  }

  Future<List<String>> getCachedAvailableParkingTypeIds() async {
    final ids = LocalDb.getAvailableParkingTypeIds();
    if (ids.isNotEmpty) return ids;
    final s = await PrefHelper.getString(_prefAvailableParkingTypes);
    if (s.isEmpty) return [];
    try {
      final List<dynamic> raw = jsonDecode(s);
      return raw.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, String>> getCachedParkingTypeTextMap() async {
    final map = LocalDb.getParkingTypeMap();
    if (map.isNotEmpty) return map;
    final s = await PrefHelper.getString(_prefParkingTypeMap);
    if (s.isEmpty) return {};
    try {
      final Map<String, dynamic> raw = jsonDecode(s);
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<List<String>> getCachedVehicleTypesFromRates() async {
    final s = await PrefHelper.getString(_prefVehicleTypesFromRates);
    if (s.isEmpty) return [];
    try {
      final List<dynamic> raw = jsonDecode(s);
      return raw.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // -------- Public API --------
  Future<void> fetchParkingRates() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        path: ApiConstants.parkingCostListEndpoint,
        data: {
          "admin_id": await PrefHelper.getUserData('admin_id'),
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['status'] == '200') {
          final List<dynamic> data = responseData['data'];
          _parkingRates =
              data.map((item) => ParkingRate.fromJson(item)).toList();
          await _saveToCache();
          await _saveDerivedDataToCache();
        } else {
          _errorMessage = responseData['msg'] ?? 'Failed to load rates';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (error) {
      _errorMessage = 'An error occurred: ${error.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Ensures rates are available locally: tries local DB first, fetches from API if absent.
  /// Also updates `ParkingTypeProvider` with available parking type ids from cache/response.
  Future<void> ensureCachedRates(BuildContext context) async {
    // Try local DB
    await _loadFromCache();
    if (_parkingRates.isEmpty) {
      await fetchParkingRates();
    }

    // Update ParkingTypeProvider from cached derived data
    final available = await getCachedAvailableParkingTypeIds();
    final map = await getCachedParkingTypeTextMap();
    if (available.isNotEmpty) {
      context.read<ParkingTypeProvider>().setAvailableParkingTypes(available);
    }
    if (map.isNotEmpty) {
      context.read<ParkingTypeProvider>().setParkingTypeTextMap(map);
    }
  }
}
