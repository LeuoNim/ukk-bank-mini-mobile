import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bank_mini_mobile/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login uses USB and sends password without truncation', () async {
    final api = ApiService.withClient(
      MockClient((request) async {
        expect(
          request.url.toString(),
          'http://127.0.0.1:8000/api/nasabah/login',
        );
        expect(jsonDecode(request.body)['password'], 'Long Password 123!');
        return http.Response(
          '{"success":false,"message":"Kredensial salah"}',
          401,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    expect(
      (await api.login('2024001', 'Long Password 123!')).message,
      'Kredensial salah',
    );
  });

  test('server errors are not described as USB errors', () async {
    final api = ApiService.withClient(
      MockClient((_) async => http.Response('<html>Laravel error</html>', 500)),
    );
    expect(
      (await api.login('2024001', 'password')).message,
      contains('HTTP 500'),
    );
  });

  test('malformed response distinguishes an accessible server', () async {
    final api = ApiService.withClient(
      MockClient((_) async => http.Response('<html>Other server</html>', 200)),
    );
    expect(
      (await api.login('2024001', 'password')).message,
      contains('bukan JSON'),
    );
  });

  test('failed connection gives USB instructions', () async {
    final api = ApiService.withClient(
      MockClient((_) async => throw http.ClientException('Connection refused')),
    );
    expect(
      (await api.login('2024001', 'password')).message,
      contains('adb reverse'),
    );
  });
}
