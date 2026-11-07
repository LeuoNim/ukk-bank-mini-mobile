class ApiConstants {
  /// URL Server API Backend Bank Mini Sekolah
  /// Seperti aplikasi online pada umumnya (BCA Mobile, Livin', Gojek, dll),
  /// aplikasi terhubung otomatis langsung ke server utama tanpa perlu konfigurasi manual.
  ///
  /// - Mode Online / Deployment: Ganti dengan domain website hosting Anda
  ///   (Contoh: 'https://bankmini.smkn1bantul.sch.id/api' atau 'https://bank-mini.test/api')
  /// - Mode Pengujian Lokal USB: 'http://127.0.0.1:8000/api'
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  static const String prefKeyToken = 'bank_mini_sanctum_token';
  static const String prefKeyCustomerData = 'bank_mini_customer_cache';

  /// Mengambil URL server aktif secara otomatis
  static Future<String> getBaseUrl() async {
    return baseUrl;
  }
}
