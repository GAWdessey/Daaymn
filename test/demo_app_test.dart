import 'package:daaymn/demo/demo_main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo app shows the Demo profiles label and every key screen', (tester) async {
    await tester.pumpWidget(const DemoApp());
    expect(find.text('Demo profiles'), findsOneWidget);

    await tester.tap(find.text('Daaymn Score'));
    await tester.pump();
    expect(find.text('SCORE BREAKDOWN'), findsOneWidget);

    await tester.tap(find.text('Vibe'));
    await tester.pump();
    expect(find.text("What's your vibe?"), findsOneWidget);
  });
}
