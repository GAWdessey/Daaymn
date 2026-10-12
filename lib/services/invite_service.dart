import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds tagged Play Store links and sends invites, WhatsApp first.
class InviteService {
  static const String _packageId = 'com.daaymn.daaymn';

  /// Play link carrying a campaign tag, so installs can be split by source in
  /// Play Console (Acquisition reports).
  static Uri playLink({required String source, String medium = 'referral', String campaign = 'invite'}) {
    final referrer = Uri(queryParameters: {
      'utm_source': source,
      'utm_medium': medium,
      'utm_campaign': campaign,
    }).query;
    return Uri.https('play.google.com', '/store/apps/details', {
      'id': _packageId,
      'referrer': referrer,
    });
  }

  static String inviteMessage() =>
      'I\'m on Daaymn: real singles, and every like means something. Join me: ${playLink(source: 'whatsapp')}';

  /// Opens WhatsApp with the invite ready to send. Falls back to the system
  /// share sheet when WhatsApp isn't installed.
  static Future<void> inviteViaWhatsApp() async {
    final message = inviteMessage();
    final uri = Uri.https('wa.me', '/', {'text': message});
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      await Share.share(message);
    }
  }

  /// Text that goes with the Daaymn Score share card.
  static String scoreShareText(num score) =>
      'This is my verified DaaymnScore: $score/10. What\'s yours? #DaaymnScore ${playLink(source: 'score_card', medium: 'share', campaign: 'score')}';
}
