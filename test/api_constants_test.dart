import 'package:bank_mini_mobile/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh installation connects through USB loopback', () async {
    expect(await ApiConstants.getBaseUrl(), 'http://127.0.0.1:8000/api');
  });

  test('old Wi-Fi preference cannot override USB', () async {
    SharedPreferences.setMockInitialValues({
      'bank_mini_api_base_url': 'http://192.168.1.5:8000/api',
    });
    expect(await ApiConstants.getBaseUrl(), 'http://127.0.0.1:8000/api');
  });

  test('old emulator preference cannot override USB', () async {
    SharedPreferences.setMockInitialValues({
      'bank_mini_api_base_url': 'http://10.0.2.2:8000/api',
    });
    expect(await ApiConstants.getBaseUrl(), 'http://127.0.0.1:8000/api');
  });
}
