// Smoke test: the app builds and a signed-out user lands on the sign-in screen.

import 'package:daaymn/auth_screen.dart';
import 'package:daaymn/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // No session is stored, so nothing is sent to this URL.
    await Supabase.initialize(url: 'http://localhost:54321', anonKey: 'test-anon-key');
  });

  testWidgets('signed-out user sees the sign-in screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
