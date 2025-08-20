import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PrefHelper {
  static Future<SharedPreferences> get prefInstance =>
      SharedPreferences.getInstance();

  static Future<void> setString(String key, String value) async {
    final pref = await prefInstance;
    pref.setString(key, value);
  }

  static Future<String> getString(String key) async {
    final pref = await prefInstance;
    return pref.getString(key) ?? '';
  }

  static Future<void> setInt(String key, int value) async {
    final pref = await prefInstance;
    pref.setInt(key, value);
  }

  static Future<int> getInt(String key) async {
    final pref = await prefInstance;
    return pref.getInt(key) ?? 0;
  }

  static Future<void> setBool(String key, bool value) async {
    final pref = await prefInstance;
    pref.setBool(key, value);
  }

  static Future<bool> getBool(String key) async {
    final pref = await prefInstance;
    return pref.getBool(key) ?? false;
  }

  static Future<void> remove(String key) async {
    final pref = await prefInstance;
    pref.remove(key);
  }

  static Future<void> setToken(String value) async {
    final pref = await prefInstance;
    pref.setString('token', value);
  }

  static Future<String> getToken() async {
    final pref = await prefInstance;
    return pref.getString('token') ?? '';
  }

  static Future<void> setUserId(String value) async {
    final pref = await prefInstance;
    pref.setString('userId', value);
  }

  static Future<String> getUserId() async {
    final pref = await prefInstance;
    return pref.getString('userId') ?? '';
  }

  static Future<void> setRole(String value) async {
    final pref = await prefInstance;
    pref.setString('role', value);
  }

  static Future<String> getRole() async {
    final pref = await prefInstance;
    return pref.getString('role') ?? '';
  }

  static Future clearAll() async {
    final pref = await prefInstance;
    pref.clear();
  }

  static Future<void> setUserData(Map<String, dynamic> userData) async {
    final prefs = await prefInstance;
    String jsonString = jsonEncode(userData);
    await prefs.setString('user_data', jsonString);
  }

  /// Get user data for a specific key
  static Future<dynamic> getUserData(String key) async {
    final prefs = await prefInstance;
    String? jsonString = prefs.getString('user_data');

    if (jsonString != null) {
      Map<String, dynamic> userData = jsonDecode(jsonString);
      return userData[key]; // Return the value for the given key
    }
    return null; // Return null if no data found
  }
}
