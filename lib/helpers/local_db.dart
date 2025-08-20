import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalDb {
  static const String boxMeta = 'meta_box';
  static const String boxRates = 'rates_box';
  static const String boxTypes = 'types_box';
  static const String boxHistory = 'history_box';
  static const String boxPending = 'pending_ops_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxMeta);
    await Hive.openBox(boxRates);
    await Hive.openBox(boxTypes);
    await Hive.openBox(boxHistory);
    await Hive.openBox(boxPending);
  }

  // Meta helpers (lastSync etc.)
  static Future<void> setMeta(String key, dynamic value) async {
    final box = Hive.box(boxMeta);
    await box.put(key, value);
  }

  static dynamic getMeta(String key) {
    final box = Hive.box(boxMeta);
    return box.get(key);
  }

  // Rates
  static Future<void> saveRates(List<Map<String, dynamic>> rates) async {
    final box = Hive.box(boxRates);
    await box.put('items', rates);
  }

  static List<Map<String, dynamic>> getRates() {
    final box = Hive.box(boxRates);
    final data = (box.get('items') ?? []) as List;
    return data.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Types
  static Future<void> saveParkingTypeMap(Map<String, String> map) async {
    final box = Hive.box(boxTypes);
    await box.put('parking_type_map', map);
  }

  static Map<String, String> getParkingTypeMap() {
    final box = Hive.box(boxTypes);
    final map = Map<String, dynamic>.from(box.get('parking_type_map') ?? {});
    return map.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Future<void> saveAvailableParkingTypeIds(List<String> ids) async {
    final box = Hive.box(boxTypes);
    await box.put('available_parking_types', ids);
  }

  static List<String> getAvailableParkingTypeIds() {
    final box = Hive.box(boxTypes);
    return List<String>.from(box.get('available_parking_types') ?? []);
  }

  static Future<void> saveVehicleTypes(List<Map<String, dynamic>> types) async {
    final box = Hive.box(boxTypes);
    await box.put('vehicle_types', types);
  }

  static List<Map<String, dynamic>> getVehicleTypes() {
    final box = Hive.box(boxTypes);
    final data = (box.get('vehicle_types') ?? []) as List;
    return data.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // History records
  // record: {vehicle_no, checked_in, checked_out, status: 1=in,2=out}
  static Future<void> addHistory(Map<String, dynamic> record) async {
    final box = Hive.box(boxHistory);
    final list = List<Map<String, dynamic>>.from(box.get('items') ?? []);
    list.insert(0, record);
    await box.put('items', list);
  }

  static Future<void> updateHistoryOnCheckout(String vehicleNo, Map<String, dynamic> update) async {
    final box = Hive.box(boxHistory);
    final list = List<Map<String, dynamic>>.from(box.get('items') ?? []);
    for (int i = 0; i < list.length; i++) {
      final r = Map<String, dynamic>.from(list[i]);
      if ((r['vehicle_no'] ?? '').toString().toUpperCase() == vehicleNo.toUpperCase() && (r['status'] ?? 1) == 1) {
        final merged = {...r, ...update};
        list[i] = merged;
        break;
      }
    }
    await box.put('items', list);
  }

  static Future<void> saveHistory(List<Map<String, dynamic>> items) async {
    final box = Hive.box(boxHistory);
    await box.put('items', items);
  }

  static List<Map<String, dynamic>> getHistory() {
    final box = Hive.box(boxHistory);
    final data = (box.get('items') ?? []) as List;
    return data.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // Pending operations queue: each item => {id, type: 'checkin'|'checkout', payload: {...}}
  static Future<void> enqueuePendingOp(Map<String, dynamic> op) async {
    final box = Hive.box(boxPending);
    final list = List<Map<String, dynamic>>.from(box.get('items') ?? []);
    list.insert(0, op);
    await box.put('items', list);
  }

  static List<Map<String, dynamic>> getPendingOps() {
    final box = Hive.box(boxPending);
    final data = (box.get('items') ?? []) as List;
    return data.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> removePendingOpById(String id) async {
    final box = Hive.box(boxPending);
    final list = List<Map<String, dynamic>>.from(box.get('items') ?? []);
    list.removeWhere((e) => (e['id'] ?? '') == id);
    await box.put('items', list);
  }

  static Future<void> clearAll() async {
    await Hive.box(boxRates).clear();
    await Hive.box(boxTypes).clear();
    await Hive.box(boxHistory).clear();
    await Hive.box(boxMeta).clear();
    await Hive.box(boxPending).clear();
  }
} 