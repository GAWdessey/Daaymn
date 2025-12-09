
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class ReportCardData {
  final int likesReceived;
  final int dislikesReceived;
  final int likesSent;
  final int matches;
  final int otmsSent;
  final int matchesWithNoMessages;
  final int reportsAgainst;
  final int timesBlocked;
  final int bioLength;
  final int photoCount;

  final double popularityScore;
  final double engagementScore;
  final double safetyScore;
  final double daaymnScore;

  final String attractivenessRatio;
  final String matchRate;
  final String ghostingRate;
  final String safetyGrade;

  final String daaymnIdiologyHeadline;
  final String daaymnIdiologyBody;

  ReportCardData({
    required this.likesReceived,
    required this.dislikesReceived,
    required this.likesSent,
    required this.matches,
    required this.otmsSent,
    required this.matchesWithNoMessages,
    required this.reportsAgainst,
    required this.timesBlocked,
    required this.bioLength,
    required this.photoCount,
    required this.popularityScore,
    required this.engagementScore,
    required this.safetyScore,
    required this.daaymnScore,
    required this.attractivenessRatio,
    required this.matchRate,
    required this.ghostingRate,
    required this.safetyGrade,
    required this.daaymnIdiologyHeadline,
    required this.daaymnIdiologyBody,
  });
}

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _getDaaymnIdiologyHeadline(double score) {
    if (score >= 9.0) return "Certified Daaymn.";
    if (score >= 8.0) return "You're Hot Property.";
    if (score >= 7.0) return "Turning Heads.";
    if (score >= 6.0) return "Warming Up.";
    if (score >= 5.0) return "Flying Under the Radar.";
    if (score >= 4.0) return "In the Shadows.";
    if (score >= 3.0) return "Work to Do.";
    if (score >= 2.0) return "On Thin Ice.";
    return "Seriously?";
  }

  String _getDaaymnIdiologyBody(double score) {
    if (score >= 9.0) return "You've cracked the code. You're what everyone's looking for. Keep being you.";
    if (score >= 8.0) return "Your profile is on fire and your game is strong. You're getting noticed for all the right reasons.";
    if (score >= 7.0) return "You're definitely catching eyes. To take it from a passing glance to a real connection, try sharpening your bio or leading with a more confident first message.";
    if (score >= 6.0) return "You're in the game, but you're not making waves yet. Time to step it up and show them what you've got.";
    if (score >= 5.0) return "You're getting lost in the crowd. To go from just another face to someone they can't forget, you need to show them what makes you 'Daaymn' good.";
    if (score >= 4.0) return "You're barely making a dent. It's time for a major rethink of your profile and approach.";
    if (score >= 3.0) return "Your score is a red flag to others. You need to make some serious changes, starting now.";
    if (score >= 2.0) return "This is a warning. Your activity is being perceived negatively. Read our guidelines, fast.";
    return "Your profile is a dead zone. You need a complete overhaul to even get in the game.";
  }

  Future<ReportCardData> getReportCardData(String userId, {required Function(String status) onProgress}) async {
    // --- Data Fetching with Progress Updates ---
    Map<String, dynamic> profileData;
    List<dynamic> likesReceivedData;
    List<dynamic> likesSentData;
    int otmsSent;
    List<dynamic> sentMessagesData;
    int timesBlocked;
    int dislikesReceived;
    int reportsAgainst;

    onProgress("Analyzing your Daaymn profile...");
    try { profileData = await _supabase.from('profiles').select('bio, image_urls').eq('id', userId).single(); } catch (_) { profileData = {'bio': '', 'image_urls': []}; }
    
    onProgress("Counting your likes and dislikes...");
    try { likesReceivedData = await _supabase.from('likes').select('user_id').eq('liked_user_id', userId); } catch (_) { likesReceivedData = []; }
    try { dislikesReceived = await _supabase.from('dislikes').count(CountOption.exact).eq('disliked_user_id', userId); } catch (_) { dislikesReceived = 0; }

    onProgress("Reviewing your sent likes...");
    try { likesSentData = await _supabase.from('likes').select('liked_user_id').eq('user_id', userId); } catch (_) { likesSentData = []; }

    onProgress("Checking your OTMs...");
    try { otmsSent = await _supabase.from('messages').count(CountOption.exact).eq('sender_id', userId).eq('is_otm', true); } catch (_) { otmsSent = 0; }

    onProgress("Scanning your message history...");
    try { sentMessagesData = await _supabase.from('messages').select('receiver_id').eq('sender_id', userId); } catch (_) { sentMessagesData = []; }
    
    onProgress("Checking community safety records...");
    try { timesBlocked = await _supabase.from('blocks').count(CountOption.exact).eq('blocked_id', userId); } catch (_) { timesBlocked = 0; }
    try { reportsAgainst = await _supabase.from('reports').count(CountOption.exact).eq('reported_id', userId); } catch (_) { reportsAgainst = 0; }

    onProgress("Calculating your Daaymn scores...");
    final likesReceivedIds = likesReceivedData.map((e) => e['user_id'].toString()).toSet();
    final likesSentIds = likesSentData.map((e) => e['liked_user_id'].toString()).toSet();

    final matchesIds = likesReceivedIds.intersection(likesSentIds);
    final receiversOfMyMessages = sentMessagesData.map((e) => e['receiver_id'].toString()).toSet();

    int matchesWithNoMessages = 0;
    for (final matchId in matchesIds) {
      if (!receiversOfMyMessages.contains(matchId)) {
        matchesWithNoMessages++;
      }
    }

    final bio = profileData['bio'] as String? ?? '';
    final imageUrls = profileData['image_urls'] as List? ?? [];
    final likesReceived = likesReceivedIds.length;
    final likesSent = likesSentIds.length;
    final matches = matchesIds.length;

    // --- Calculation Logic ---

    // 1. Popularity Score
    final rawAttractivenessRatio = (likesReceived + dislikesReceived) == 0 ? 0.0 : likesReceived / (likesReceived + dislikesReceived);
    final popularityScore = min(10.0, rawAttractivenessRatio * 20);

    // 2. Engagement Score
    final rawMatchRate = likesSent == 0 ? 0.0 : matches / likesSent;
    final rawGhostingRate = matches == 0 ? 0.0 : matchesWithNoMessages / matches;
    double engagementScore = (rawMatchRate * 8) + (min(otmsSent / 10, 1) * 2) - (rawGhostingRate * 5);
    engagementScore = engagementScore.clamp(0, 10).toDouble();

    // 3. Community Standing
    final negativeIncidents = reportsAgainst + timesBlocked;
    String safetyGrade;
    double safetyScore;
    if (negativeIncidents == 0) {
      safetyGrade = 'A+';
      safetyScore = 10.0;
    } else if (negativeIncidents <= 2) {
      safetyGrade = 'A';
      safetyScore = 9.0;
    } else if (negativeIncidents <= 4) {
      safetyGrade = 'B';
      safetyScore = 7.0;
    } else if (negativeIncidents <= 7) {
      safetyGrade = 'C';
      safetyScore = 5.0;
    } else if (negativeIncidents <= 10) {
      safetyGrade = 'D';
      safetyScore = 3.0;
    } else {
      safetyGrade = 'F';
      safetyScore = 1.0;
    }

    // 4. Daaymn Score
    double daaymnScore = (0.4 * popularityScore) + (0.35 * engagementScore) + (0.25 * safetyScore);
    if (safetyScore <= 3) {
      daaymnScore = min(daaymnScore, 4.0);
    }
    daaymnScore = double.parse(daaymnScore.toStringAsFixed(1));

    onProgress("Finalizing your report card...");
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate final step

    return ReportCardData(
      likesReceived: likesReceived,
      dislikesReceived: dislikesReceived,
      likesSent: likesSent,
      matches: matches,
      otmsSent: otmsSent,
      matchesWithNoMessages: matchesWithNoMessages,
      reportsAgainst: reportsAgainst,
      timesBlocked: timesBlocked,
      bioLength: bio.length,
      photoCount: imageUrls.length,
      popularityScore: popularityScore,
      engagementScore: engagementScore,
      safetyScore: safetyScore,
      daaymnScore: daaymnScore,
      attractivenessRatio: '${(rawAttractivenessRatio * 100).toStringAsFixed(1)}%',
      matchRate: '${(rawMatchRate * 100).toStringAsFixed(1)}%',
      ghostingRate: '${(rawGhostingRate * 100).toStringAsFixed(1)}%',
      safetyGrade: safetyGrade,
      daaymnIdiologyHeadline: _getDaaymnIdiologyHeadline(daaymnScore),
      daaymnIdiologyBody: _getDaaymnIdiologyBody(daaymnScore),
    );
  }
}
