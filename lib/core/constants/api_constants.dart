import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  // Default URL jika via kabel USB (adb reverse tcp:8000 tcp:8000)
  static const String defaultBaseUrl = 'http://127.0.0.1:8000/api';
  static const String prefKeyCustomBaseUrl = 'custom_api_base_url';
  static const String prefKeyToken = 'bank_mini_sanctum_token';
  static const String prefKeyCustomerData = 'bank_mini_customer_cache';

  /// Mengambil URL server aktif dari penyimpanan lokal (SharedPreferences)
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(prefKeyCustomBaseUrl);
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
    return defaultBaseUrl;
  }

  /// Menyimpan URL server kustom (misal: IP WiFi lokal atau Domain deploy online)
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(prefKeyCustomBaseUrl, cleaned);
  }

  /// Mereset kembali ke URL default USB
  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefKeyCustomBaseUrl);
  }
}
