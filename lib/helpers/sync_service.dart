import 'package:kota_pf1_app/helpers/local_db.dart';
import 'package:kota_pf1_app/helpers/api_helper.dart';
import 'package:kota_pf1_app/helpers/pref_helper.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:kota_pf1_app/helpers/sync_settings.dart';
import 'package:kota_pf1_app/helpers/connectivity_helper.dart';

class SyncService {
  static const String taskName = 'periodic_sync_lookup';

  final ApiClient _apiClient = ApiClient.create();

  Future<void> syncLookupData({void Function(double, String)? onProgress}) async {
    final adminId = await PrefHelper.getUserData('admin_id');

    onProgress?.call(0.05, 'Preparing...');

    // Push pending ops first
    try {
      onProgress?.call(0.08, 'Pushing offline records...');
      await _pushPendingOps();
    } catch (_) {}

    // Fetch rates
    try {
      onProgress?.call(0.10, 'Fetching parking rates...');
      final res = await _apiClient.post(path: 'parking_cost_list', data: {"admin_id": adminId});
      if (res.statusCode == 200 && res.data['status'] == '200') {
        final List data = res.data['data'] ?? [];
        final rates = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        await LocalDb.saveRates(rates);

        // derive maps
        final Map<String, String> typeMap = {};
        final Set<String> availableTypes = {};
        for (final r in rates) {
          final id = (r['parking_type'] ?? '').toString();
          availableTypes.add(id);
          typeMap.putIfAbsent(id, () => (r['parking_type_text'] ?? '').toString());
        }
        await LocalDb.saveParkingTypeMap(typeMap);
        await LocalDb.saveAvailableParkingTypeIds(availableTypes.toList());
      }
      onProgress?.call(0.33, 'Rates synced');
    } catch (_) {
      onProgress?.call(0.33, 'Rates failed, continuing...');
    }

    // Fetch vehicle types
    try {
      onProgress?.call(0.38, 'Fetching vehicle types...');
      final res = await _apiClient.post(path: 'get_vehicle_type', data: {"admin_id": adminId});
      if (res.statusCode == 200 && (res.data['status']?.toString() == '200')) {
        final List data = res.data['data'] ?? [];
        final types = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        await LocalDb.saveVehicleTypes(types);
      }
      onProgress?.call(0.66, 'Vehicle types synced');
    } catch (_) {
      onProgress?.call(0.66, 'Vehicle types failed, continuing...');
    }

    // Fetch recent history (limit 100 on backend side preferred)
    try {
      onProgress?.call(0.71, 'Fetching recent history...');
      final res = await _apiClient.post(path: 'get_history', data: {"admin_id": adminId});
      final List data = (res.data['data'] ?? []) as List;
      final items = data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
      await LocalDb.saveHistory(items);
      onProgress?.call(0.95, 'History synced');
    } catch (_) {
      onProgress?.call(0.95, 'History failed, continuing...');
    }

    await LocalDb.setMeta('last_sync_at', DateTime.now().toIso8601String());
    onProgress?.call(1.0, 'Sync complete');
  }

  Future<void> _pushPendingOps() async {
    if (!await ConnectivityHelper.isOnline()) return;
    final ops = LocalDb.getPendingOps();
    if (ops.isEmpty) return;
    for (final op in List<Map<String, dynamic>>.from(ops)) {
      final id = (op['id'] ?? '').toString();
      final type = (op['type'] ?? '').toString();
      final payload = Map<String, dynamic>.from(op['payload'] ?? {});
      try {
        if (type == 'checkin') {
          await _apiClient.post(path: 'save', data: payload);
        } else if (type == 'checkout') {
          await _apiClient.post(path: 'chekout', data: payload);
        }
        await LocalDb.removePendingOpById(id);
      } catch (_) {
        // stop further attempts if first fails (will retry next sync)
        break;
      }
    }
  }

  static Future<void> configureBackgroundFetch() async {
    final minutes = await SyncSettings.loadMinutes();
    final interval = minutes < 15 ? 15 : minutes; // platform minimums

    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: interval,
        stopOnTerminate: false,
        enableHeadless: true,
        startOnBoot: true,
        requiredNetworkType: NetworkType.ANY,
      ),
      (String taskId) async {
        try {
          await LocalDb.init();
          await SyncService().syncLookupData();
        } finally {
          BackgroundFetch.finish(taskId);
        }
      },
      (String taskId) async {
        // timeout callback
        BackgroundFetch.finish(taskId);
      },
    );

    // Start now
    await BackgroundFetch.start();
  }
}

// Headless task (Android)
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  final String taskId = task.taskId;
  final bool timeout = task.timeout;
  if (timeout) {
    BackgroundFetch.finish(taskId);
    return;
  }
  try {
    await LocalDb.init();
    await SyncService().syncLookupData();
  } finally {
    BackgroundFetch.finish(taskId);
  }
} 