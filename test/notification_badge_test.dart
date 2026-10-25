import 'package:daaymn/notification_provider.dart' show countLikedYou;
import 'package:daaymn/main.dart' show NotificationBadge;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _likedYouTests();
  testWidgets('badge sits beside the icon and never covers it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: NotificationBadge(icon: Icons.whatshot, count: 3)),
      ),
    ));
    final icon = tester.getRect(find.byIcon(Icons.whatshot));
    final badge = tester.getRect(find.text('3'));
    expect(find.byIcon(Icons.whatshot), findsOneWidget);
    expect(badge.center.dx, greaterThan(icon.center.dx));
    expect(badge.left, greaterThanOrEqualTo(icon.center.dx));
  });

  testWidgets('no badge when count is zero', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NotificationBadge(icon: Icons.whatshot, count: 0)),
    ));
    expect(find.text('0'), findsNothing);
  });
}

void _likedYouTests() {
  test('liked-you count ignores people I liked back long ago (old matches)', () {
    expect(
      countLikedYou(
        whoLikedMe: {'a', 'b', 'c'},
        allMyLikes: {'a', 'b', 'c'},
        myDislikes: {},
        blocked: {},
      ),
      0,
    );
    expect(
      countLikedYou(
        whoLikedMe: {'a', 'b', 'c', 'd'},
        allMyLikes: {'a'},
        myDislikes: {'b'},
        blocked: {'c'},
      ),
      1,
    );
  });
}
