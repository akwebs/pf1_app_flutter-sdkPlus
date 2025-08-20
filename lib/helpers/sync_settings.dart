import 'package:kota_pf1_app/helpers/pref_helper.dart';

class SyncSettings {
  static const String _kKeyMinutes = 'bg_sync_minutes';
  static const int defaultMinutes = 30; // default schedule

  static Future<int> loadMinutes() async {
    final v = await PrefHelper.getInt(_kKeyMinutes);
    if (v == 0) return defaultMinutes; // treat 0 as unset
    return v;
  }

  static Future<void> saveMinutes(int minutes) async {
    await PrefHelper.setInt(_kKeyMinutes, minutes);
  }
} 