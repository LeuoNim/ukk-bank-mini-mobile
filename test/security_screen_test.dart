import 'package:bank_mini_mobile/screens/security_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('security form supports both secrets and rejects missing input', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SecurityScreen()));
    expect(find.byType(TextFormField), findsNWidgets(6));
    await tester.ensureVisible(find.text('Simpan Perubahan'));
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();
    expect(find.text('Wajib diisi'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('password-only mode does not require a new PIN', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SecurityScreen()));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Password saja').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
