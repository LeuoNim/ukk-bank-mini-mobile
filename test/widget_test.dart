import 'package:flutter_test/flutter_test.dart';
import 'package:bank_mini_mobile/main.dart';
import 'package:bank_mini_mobile/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App basic initialization test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BankMiniApp());
    expect(find.byType(BankMiniApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byTooltip('Konfigurasi IP Server'), findsNothing);
  });
}
