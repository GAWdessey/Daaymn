import 'package:daaymn/services/invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('play link carries the app id and an encoded campaign tag', () {
    final uri = InviteService.playLink(source: 'whatsapp');
    expect(uri.host, 'play.google.com');
    expect(uri.queryParameters['id'], 'com.daaymn.daaymn');
    expect(
      uri.queryParameters['referrer'],
      'utm_source=whatsapp&utm_medium=referral&utm_campaign=invite',
    );
  });

  test('score share text includes the score and a score_card tagged link', () {
    final text = InviteService.scoreShareText(7.4);
    expect(text, contains('7.4/10'));
    expect(text, contains('utm_source%3Dscore_card'));
  });
}
