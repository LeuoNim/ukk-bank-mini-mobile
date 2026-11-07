import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../models/customer_model.dart';
import '../models/transaction_model.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  final http.Client _client;
  ApiService._internal() : _client = http.Client();
  ApiService.withClient(this._client);

  Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConstants.prefKeyToken);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.prefKeyToken, token);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.prefKeyToken);
    await prefs.remove(ApiConstants.prefKeyCustomerData);
  }

  Future<CustomerModel?> getCachedCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(ApiConstants.prefKeyCustomerData);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        return CustomerModel.fromJson(data);
      } catch (_) {}
    }
    return null;
  }

  Future<void> saveCachedCustomer(CustomerModel customer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiConstants.prefKeyCustomerData,
      jsonEncode(customer.toJson()),
    );
  }

  /// Login with the web password, or initial PIN before a password is set.
  Future<ApiResponse<CustomerModel>> login(
    String loginId,
    String password,
  ) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final url = Uri.parse('$baseUrl/nasabah/login');

      final response = await _client
          .post(
            url,
            headers: await _getHeaders(withAuth: false),
            body: jsonEncode({
              'account_number': loginId.trim(),
              'login_id': loginId.trim(),
              'student_id': loginId.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 500) {
        return ApiResponse(
          success: false,
          message:
              'Server terhubung tetapi mengalami kesalahan (HTTP ${response.statusCode}). Periksa Laravel dan database di laptop.',
        );
      }
      if (response.statusCode == 404) {
        // A JSON 404 can also mean an unknown customer; preserve that message.
        if (!response.headers['content-type'].toString().contains(
          'application/json',
        )) {
          return ApiResponse(
            success: false,
            message:
                'Server terhubung, tetapi API login tidak ditemukan. Pastikan Laravel proyek Bank Mini berjalan pada port 8000.',
          );
        }
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final body = decoded;

      if (response.statusCode == 200 && body['success'] == true) {
        final token = body['token']?.toString() ?? '';
        await saveToken(token);

        final customer = CustomerModel.fromJson(body['data']);
        await saveCachedCustomer(customer);

        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Login berhasil',
          data: customer,
        );
      } else {
        return ApiResponse(
          success: false,
          message:
              body['message'] ??
              'Gagal login. Periksa NIS/No Rekening dan password atau PIN awal.',
        );
      }
    } on TimeoutException {
      return ApiResponse(
        success: false,
        message:
            'Server tidak merespons dalam 15 detik. Pastikan Laravel berjalan, USB tersambung, dan adb reverse tcp:8000 tcp:8000 sudah dijalankan di laptop.',
      );
    } on SocketException {
      return ApiResponse(
        success: false,
        message:
            'Koneksi USB ke server belum tersedia. Pastikan USB debugging diizinkan, Laravel port 8000 berjalan, dan adb reverse tcp:8000 tcp:8000 dijalankan di laptop.',
      );
    } on http.ClientException {
      return ApiResponse(
        success: false,
        message:
            'Koneksi USB terputus atau ditolak. Sambungkan USB dan jalankan ulang adb reverse tcp:8000 tcp:8000 di laptop.',
      );
    } on FormatException {
      return ApiResponse(
        success: false,
        message:
            'Server terhubung tetapi respons API bukan JSON yang valid. Periksa error Laravel di laptop.',
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message:
            'Respons login tidak dapat diproses. Periksa backend Bank Mini di laptop.',
      );
    }
  }

  Future<ApiResponse<void>> changeSecurity(Map<String, String> fields) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/nasabah/security'),
            headers: await _getHeaders(),
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 500) {
        return ApiResponse(
          success: false,
          message:
              'Server mengalami kesalahan. Perubahan belum dapat dikonfirmasi.',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        await clearSession();
        return ApiResponse(
          success: true,
          message: 'Kredensial berhasil diubah. Silakan login kembali.',
        );
      }
      final errors = body['errors'];
      final message = errors is Map && errors.isNotEmpty
          ? (errors.values.first as List).first.toString()
          : body['message']?.toString();
      return ApiResponse(
        success: false,
        message: message ?? 'Perubahan ditolak. Periksa isian Anda.',
      );
    } catch (_) {
      return ApiResponse(
        success: false,
        message:
            'Hasil perubahan belum dapat dikonfirmasi. Periksa USB dan server. Jika koneksi terputus setelah menyimpan, coba login dengan password baru sebelum mengulang.',
      );
    }
  }

  /// Mengambil informasi saldo terkini secara realtime
  Future<ApiResponse<CustomerModel>> getSaldo() async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final url = Uri.parse('$baseUrl/nasabah/saldo');

      final response = await http
          .get(url, headers: await _getHeaders())
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final cached = await getCachedCustomer();
        final rawData = body['data'];

        final updatedCustomer =
            (cached ??
                    CustomerModel(
                      id: 0,
                      accountNumber: rawData['account_number'] ?? '',
                      studentId: '',
                      studentName: rawData['student_name'] ?? '',
                      className: rawData['class'] ?? '',
                      balance: 0,
                      status: 'Aktif',
                    ))
                .copyWith(
                  balance: rawData['balance'] is num
                      ? (rawData['balance'] as num).toInt()
                      : int.tryParse(rawData['balance']?.toString() ?? '0') ??
                            0,
                  studentName: rawData['student_name'] ?? cached?.studentName,
                  className: rawData['class'] ?? cached?.className,
                  accountNumber:
                      rawData['account_number'] ?? cached?.accountNumber,
                );

        await saveCachedCustomer(updatedCustomer);

        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Saldo berhasil diambil',
          data: updatedCustomer,
        );
      } else if (response.statusCode == 401) {
        await clearSession();
        return ApiResponse(
          success: false,
          message: 'Sesi login telah berakhir. Silakan login kembali.',
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Gagal mengambil informasi saldo',
        );
      }
    } catch (e) {
      // Jika offline, gunakan cached data
      final cached = await getCachedCustomer();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Menampilkan data offline tersimpan',
          data: cached,
        );
      }
      return ApiResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Mengambil riwayat mutasi transaksi
  Future<ApiResponse<List<TransactionModel>>> getMutasi({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      var uriString = '$baseUrl/nasabah/mutasi';
      final params = <String>[];
      if (startDate != null && startDate.isNotEmpty) {
        params.add('start_date=$startDate');
      }
      if (endDate != null && endDate.isNotEmpty) {
        params.add('end_date=$endDate');
      }
      if (params.isNotEmpty) {
        uriString += '?${params.join('&')}';
      }

      final url = Uri.parse(uriString);
      final response = await http
          .get(url, headers: await _getHeaders())
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final List listData = body['data'] ?? [];
        final transactions = listData
            .map((item) => TransactionModel.fromJson(item))
            .toList();

        return ApiResponse(
          success: true,
          message: body['message'] ?? 'Mutasi berhasil diambil',
          data: transactions,
        );
      } else if (response.statusCode == 401) {
        await clearSession();
        return ApiResponse(
          success: false,
          message: 'Sesi login berakhir. Silakan login kembali.',
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Gagal mengambil mutasi',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Reset password atau PIN nasabah secara mandiri
  Future<ApiResponse<void>> forgotPassword({
    required String studentId,
    required String accountNumber,
    required String resetType,
    String? newPassword,
    String? newPin,
  }) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final url = Uri.parse('$baseUrl/nasabah/forgot-password');

      final body = {
        'student_id': studentId,
        'account_number': accountNumber,
        'reset_type': resetType,
        if (newPassword != null) 'new_password': newPassword,
        if (newPassword != null) 'new_password_confirmation': newPassword,
        if (newPin != null) 'new_pin': newPin,
        if (newPin != null) 'new_pin_confirmation': newPin,
      };

      final response = await http
          .post(
            url,
            headers: await _getHeaders(withAuth: false),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return ApiResponse(
          success: true,
          message: data['message'] ?? 'Kredensial berhasil diperbarui',
        );
      } else {
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Gagal memperbarui kredensial',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Cek apakah ada permintaan penarikan pending di loket teller
  Future<ApiResponse<Map<String, dynamic>?>> getPendingWithdrawal() async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final url = Uri.parse('$baseUrl/nasabah/withdrawal/pending');

      final response = await http
          .get(url, headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return ApiResponse(
          success: true,
          message: 'Data penarikan berhasil dimuat',
          data: data['data'],
        );
      }
      return ApiResponse(
        success: false,
        message: data['message'] ?? 'Gagal memeriksa permintaan penarikan',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Otorisasi penarikan menggunakan PIN transaksi nasabah
  Future<ApiResponse<void>> confirmWithdrawal(
    int transactionId,
    String pin,
  ) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final url = Uri.parse('$baseUrl/nasabah/withdrawal/confirm');

      final response = await http
          .post(
            url,
            headers: await _getHeaders(),
            body: jsonEncode({'transaction_id': transactionId, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return ApiResponse(
          success: true,
          message: data['message'] ?? 'Penarikan berhasil diotorisasi.',
        );
      }
      return ApiResponse(
        success: false,
        message: data['message'] ?? 'Otorisasi gagal. Periksa kembali PIN Anda.',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Tolak permintaan penarikan di loket teller
  Future<ApiResponse<void>> rejectWithdrawal(int transactionId) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final url = Uri.parse('$baseUrl/nasabah/withdrawal/reject');

      final response = await http
          .post(
            url,
            headers: await _getHeaders(),
            body: jsonEncode({'transaction_id': transactionId}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return ApiResponse(
          success: true,
          message: data['message'] ?? 'Permintaan penarikan ditolak.',
        );
      }
      return ApiResponse(
        success: false,
        message: data['message'] ?? 'Gagal menolak penarikan',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  /// Logout nasabah
  Future<ApiResponse<void>> logout() async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl();
      final url = Uri.parse('$baseUrl/nasabah/logout');

      await http
          .post(url, headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
    } catch (_) {}

    await clearSession();
    return ApiResponse(success: true, message: 'Berhasil keluar');
  }
}
