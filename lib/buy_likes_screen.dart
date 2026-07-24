
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:daaymn/globals.dart';
import 'package:daaymn/in_app_purchase_service.dart';
import 'package:daaymn/services/report_service.dart';
import 'package:daaymn/widgets/daaymn_loading_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:daaymn/services/ad_service.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:daaymn/services/promo_code_service.dart';



enum ReportTier { free, basic, pro, deluxe }



class BuyLikesScreen extends StatelessWidget {
  const BuyLikesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InAppPurchaseService()),
        ChangeNotifierProvider.value(value: serviceLocator.promoCodeService),
      ],
      child: const _BuyLikesScreenContent(),
    );
  }
}

class _BuyLikesScreenContent extends StatefulWidget {
  const _BuyLikesScreenContent();


  @override
  State<_BuyLikesScreenContent> createState() => _BuyLikesScreenContentState();
}

class _BuyLikesScreenContentState extends State<_BuyLikesScreenContent> with TickerProviderStateMixin {
  final GlobalKey _shareKey = GlobalKey();
  String? _verificationId;
  final GlobalKey _badgeKey = GlobalKey();
  final GlobalKey _cvKey = GlobalKey();
  final AdService _likeAdService = serviceLocator.likeAdService;
  final AdService _scrollAdService = serviceLocator.scrollAdService;
  final AdService _ghostAdService = serviceLocator.ghostAdService;
  MapEntry<String, String>? _randomAboutMeFactEntry;
  final TextEditingController _customAmountController = TextEditingController();
  late TabController _tabController;
  TabController? _reportTabController;
  ReportTier? _pendingReportTier;
  ReportTier? _unlockedTier;
  ReportCardData? _reportData;Color _selectedCardColor = const Color(0xFF2E2E2E); // Default to a dark charcoal
  // --- State for the New Report Card Design ---Color _selectedCardColor = const Color(0xFF2E2E2E); // Default to a dark charcoal
  final List<Color> _cardColorOptions = [
    const Color(0xFF2E2E2E), // Dark Charcoal
    const Color(0xFF1A237E), // Deep Indigo
    const Color(0xFF4A148C), // Deep Purple
    const Color(0xFF004D40), // Dark Teal
  ];


  final ReportService _reportService = ReportService();

  final bool _isDevelopment = kDebugMode;
  late InAppPurchaseService _iapService;
  Profile? _userProfile;
  bool _isLoadingProfile = true;
  Timer? _countdownTimer;
  Duration? _timeUntilNextClaim;



  Widget _buildBrandedScoreBadge() {
    return RepaintBoundary(
      key: _badgeKey,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            _ScoreBadge(score: _reportData!.daaymnScore, isFinal: true),
            _CurvedText(
              text: '#DaaymnScore',
              radius: 61,
              startAngle: -math.pi * 0.25,
              textStyle: const TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 5.5,
                  fontWeight: FontWeight.w900),
            ),
            if (_verificationId != null)
              Positioned(
                bottom: 6, // Adjusted for new size
                left: 6,   // Adjusted for new size
                // This Container WRAPS the QR code to provide the circular background.
                child: Container(
                  width: 40.0, // *** SMALLER SIZE ***
                  height: 40.0, // *** SMALLER SIZE ***
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  child: QrImageView(
                    data: _verificationId!,
                    version: QrVersions.auto,
                    size: 40.0, // *** SMALLER SIZE ***
                    backgroundColor: Colors.transparent,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Colors.white,
                    ),
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onAdStateChanged() {
    // This forces the UI to rebuild when an ad's ready status changes
    if (mounted) {
      setState(() {});
    }
  }

  // This method shows the dialog asking the user to share.
  void _showShareForLikesDialog() {    // A small delay to let any current UI process finish.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Share your Daaymn report and tag us!'),
          content: const Text('we will give you 6 Daaymn Likes! Sharing the love.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Thanks!'),
            ),
          ],
        ),
      );
    });
  }

  // This method calls your new Supabase function.
  Future<void> _grantShareBonus() async {
    try {
      await Supabase.instance.client.functions.invoke('grant-share-bonus');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daaymn! 6 Likes have been added to your account.'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the user's profile to show the new like balance
        _loadUserProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred while granting likes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  // This is the new widget that displays the three pillar scores.
  Widget _buildCategoryScores() {
    if (_reportData == null) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          'SCORE BREAKDOWN',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 1,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          alignment: WrapAlignment.center,
          children: [
            _StatChip(
                label: 'Popularity',
                value: _reportData!.popularityScore.toStringAsFixed(1)),
            _StatChip(
                label: 'Engagement',
                value: _reportData!.engagementScore.toStringAsFixed(1)),
            _StatChip(
                label: 'Safety (${_reportData!.safetyGrade})',
                value: _reportData!.safetyScore.toStringAsFixed(1)),
          ],
        ),
      ],
    );
  }  // This is a helper widget to display a single score category neatly.
  // This is a helper widget to display a single score category neatly.
  Widget _categoryScore({required String title, required double score, String? grade}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              score.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Text('/10', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        // Put the grade on a new line for symmetry and clarity
        if (grade != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Grade: $grade',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
  void _startCountdownTimer(DateTime nextClaimDate) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      if (now.isAfter(nextClaimDate)) {
        setState(() {
          _timeUntilNextClaim = null;
        });
        timer.cancel();
      } else {
        setState(() {
          _timeUntilNextClaim = nextClaimDate.difference(now);
        });
      }
    });
  }


  void _resetReportView() {
    setState(() {
      _reportTabController = null;
      _unlockedTier = null;
      _reportData = null;});
  }

  Future<void> _claimMonthlyReport() async {
    final statusController = StreamController<String>();
    statusController.add('Claiming your report...');

    final future = Supabase.instance.client.functions.invoke('claim-monthly-report');

    showDaaymnLoadingDialog(
      context: context,
      statusStream: statusController.stream,
      future: future,
    );

    try {
      final response = await future;
      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'Server error.');
      }

      final claimedTierString = response.data['claimedTier'] as String;
      final ReportTier claimedTier;
      switch (claimedTierString.toLowerCase()) {
        case 'basic':
          claimedTier = ReportTier.basic;
          break;
        case 'pro':
          claimedTier = ReportTier.pro;
          break;
        case 'deluxe':
          claimedTier = ReportTier.deluxe;
          break;
        default:
          throw Exception('Unknown report tier claimed.');
      }

      // Unlock the view and fetch data
      setState(() {
        _unlockedTier = claimedTier;
      });
      _fetchReportData(claimedTier);

      // Refresh profile data to update the UI
      await _loadUserProfile();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Claim failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      statusController.close();
    }
  }

  Future<bool> _showExitReportWarningDialog() async {
    // If this is triggered from a back press while NOT on the reports tab,
    // the user wants to leave the store, not the report.
    // Silently reset the report state and allow the screen to close.
    if (_tabController.index != 1) { // Assuming Reports tab is index 1
      _resetReportView();
      return true; // Allow pop to proceed.
    }

    // If we ARE on the report tab, show the user the warning dialog with more options.
    return await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.black.withAlpha(190),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text(
            'Report In Progress',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Bungee',
              color: Colors.white,
            ),
          ),
          content: const Text(
            'This is a one-time view. If you leave, this report will be gone forever. What would you like to do?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          actions: <Widget>[
            Column( // Arrange buttons vertically for clarity
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_download, size: 20),
                  label: const Text('SAVE & LEAVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);

                    // The user wants to save, so we must go to the report's 'Export' tab first.
                    if (_reportTabController?.index != 1) {
                      _reportTabController?.animateTo(1);
                      // Wait for the UI to build the export tab.
                      await Future.delayed(const Duration(milliseconds: 400));
                    }

                    final bool success = await _exportReport();

                    if (success) {
                      if (navigator.mounted) navigator.pop(true); // Pop with true to indicate leaving
                    }
                    // If save fails, the dialog remains open for the user to try again or choose another option.
                  },
                ),
                const SizedBox(height: 8),
                // New "LEAVE ANYWAY" button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true), // Pop with true to leave
                  child: const Text('LEAVE ANYWAY', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
                // "STAY" button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // Pop with false to stay
                  child: const Text('STAY', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    ) ?? false; // Return false if dialog is dismissed by tapping outside
  }
  void _handlePop() async {
    // Check if a paid report is open
    if (_unlockedTier != null && _unlockedTier != ReportTier.free) {
      final shouldExit = await _showExitReportWarningDialog();
      if (shouldExit && mounted) {
        Navigator.of(context).pop();
      }
      // If shouldExit is false, we do nothing and stay on the screen.
    } else {
      // If no paid report is open, just pop the screen normally.
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildUnlockedReportView() {
    if (_reportTabController == null || _reportData == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_unlockedTier == ReportTier.free) {
      return _buildShareableCard();
    }

    // This widget is a simple column, designed to be placed in a SingleChildScrollView.
    // It uses manual indexing into a list of widgets instead of a TabBarView to avoid layout errors.
    final reportTabsContent = [
      // --- Tab 1: Scorecard ---
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            _buildShareableCard(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share Card'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: _shareDaaymnScore,
            ),
          ],
        ),
      ),
      // --- Tab 2: Export ---
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            _buildColorPicker(),
            const SizedBox(height: 8),
            _buildReportCvCard(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_download),
              label: const Text('Export Report'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: _exportReport,
            ),
          ],
        ),
      ),
      // --- Tab 3: Breakdown ---
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            _buildCategoryScores(), // This will be the new bubble layout
            const SizedBox(height: 32),
            // Conditionally show the locked deluxe stats for non-deluxe users
            if (_unlockedTier != ReportTier.deluxe) _buildLockedDeluxeStatsSection(),
            const SizedBox(height: 24),
            // Improvement section only for Pro and Deluxe
            if (_unlockedTier == ReportTier.pro || _unlockedTier == ReportTier.deluxe)
              _buildImprovementSection(),
          ],
        ),
      ),
      // --- Tab 4: Deep Dive (only if deluxe) ---
      if (_unlockedTier == ReportTier.deluxe)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: _buildDeluxeStatsSection(),
        ),
    ];


    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _reportTabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withAlpha(178),
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: Colors.black.withAlpha(102),
                border: Border.all(color: Colors.white.withAlpha(38)),
              ),
              tabs: [
                const Tab(text: 'SCORECARD'),
                const Tab(text: 'EXPORT'),
                const Tab(text: 'BREAKDOWN'),
                if (_unlockedTier == ReportTier.deluxe) const Tab(text: 'DEEP DIVE'),
              ],
            ),
            // Manually show the content for the selected tab.
            // This avoids layout errors when inside a SingleChildScrollView.
            // The listener on _reportTabController handles updating the view.
            reportTabsContent[_reportTabController!.index],
          ],
        ),
        Positioned(
          top: -12,
          right: -12,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () async {
              final shouldExit = await _showExitReportWarningDialog();
              if (shouldExit) {
                _resetReportView();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShareableCard() {
    if (_reportData == null) {
      return const SizedBox.shrink();
    }

    final title = _reportData!.daaymnIdiologyHeadline;
    final subtitle = _reportData!.daaymnIdiologyBody;

    return Card(
      elevation: 8,
      color: Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // This now calls the corrected badge widget with NO parameters.
            // The badge itself is now smart enough to show the ID when needed.
            _buildBrandedScoreBadge(),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Bungee'),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claimFreeMonthlyReport() async {
    final statusController = StreamController<String>();
    showDaaymnLoadingDialog(
      context: context,
      statusStream: statusController.stream,
      future: _performClaimAndCalculateScore(statusController),
    );
  }

  // This new helper function contains the full, correct logic for the claim process.
  Future<void> _performClaimAndCalculateScore(StreamController<String> statusController) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Step 1: Call the Supabase function to verify eligibility and timestamp the claim.
      statusController.add('Verifying eligibility...');
      final claimResponse = await Supabase.instance.client.functions.invoke('claim-free-report');
      if (claimResponse.status != 200) {
        final errorData = claimResponse.data as Map<String, dynamic>?;
        throw Exception(errorData?['message'] ?? 'Eligibility check failed.');
      }

      // Step 2: Use the app's OWN ReportService to calculate the real score.
      // The 'onProgress' callback will pipe the ReportService's status messages
      // directly into our loading dialog for a great user experience.
      final reportData = await _reportService.getReportCardData(
        userId,
        onProgress: (status) {
          if (!statusController.isClosed) {
            statusController.add(status);
          }
        },
      );
      final newScore = reportData.daaymnScore;

      // Step 3: Save the calculated static score back to the database.
      statusController.add('Saving your static score...');
      await Supabase.instance.client
          .from('profiles')
          .update({'last_claimed_score': newScore}) // SAVE THE TRUE DECIMAL SCORE
          .eq('id', userId);

      // Step 4: Update the local UI state instantly so the user sees the result.
      if (mounted) {
        setState(() {
          _userProfile = _userProfile?.copyWith(
            lastClaimedScore: newScore, // SAVE THE TRUE DECIMAL SCORE LOCALLY
            lastFreeReportClaimedAt: DateTime.now(),
          );
          // Immediately start the countdown timer with the new claim date.
          if (_userProfile?.lastFreeReportClaimedAt != null) {
            final nextClaimDate = _userProfile!.lastFreeReportClaimedAt!.add(const Duration(days: 30));
            _startCountdownTimer(nextClaimDate);
          }
        });
      }
    } catch (e) {
      // If anything fails, show a clear error message.
      if (mounted) {
        // *** THIS IS THE FIX ***
        // Capture the ScaffoldMessenger before the async call.
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        // A small delay ensures the loading dialog has time to close before the error appears.
        await Future.delayed(const Duration(milliseconds: 100));
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Claim failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always close the stream controller to prevent memory leaks.
      if (!statusController.isClosed) {
        statusController.close();
      }
    }
  }
  Widget _buildLockedDeluxeStatsSection() {
    return Column(
      children: [
        Text(
          'DEEP DIVE STATISTICS',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          alignment: WrapAlignment.center,
          children: const [
            _StatChip(label: 'Likes Received', value: 'Unlock', isLocked: true),
            _StatChip(label: 'Dislikes Received', value: 'Unlock', isLocked: true),
            _StatChip(label: 'Total Matches', value: 'Unlock', isLocked: true),
            _StatChip(label: 'Match Rate', value: 'Unlock', isLocked: true),
            _StatChip(label: 'Ghosting Rate', value: 'Unlock', isLocked: true),
            _StatChip(label: 'Attractiveness Ratio', value: 'Unlock', isLocked: true),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Upgrade to a Deluxe Report to view!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
        )
      ],
    );
  }

  // --- START: PASTE THIS BLOCK TO REPLACE THE OLD _watchAdForReward ---

// This helper function loads ads in the background when they are available.
  // --- START: REPLACE the old _watchAdForReward function with this block ---

  // --- REPLACE the old _watchAdForReward function ---
  // --- REPLACE the old _watchAdForReward function ---
  Future<void> _watchAdForReward({
    required String rewardType,
    required AdService adService,
  }) async {
    if (!mounted) return;

    adService.showRewardedAd(
      onUserEarnedReward: (reward) async {
        try {
          await Supabase.instance.client.functions.invoke(
            'claim-ad-reward',
            body: {'rewardType': rewardType},
          );
        } catch (e) {
          debugPrint('claim reward failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Daaymn, we couldn't apply your reward. Please try again."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onAdDismissed: () {
        // The ad service handles loading the next ad automatically.
      },
    );
  }


// --- END: REPLACE the old function with this block ---
// --- END: PASTE THIS BLOCK TO REPLACE THE OLD _watchAdForReward ---

  Widget _buildFreeReportSection() {
    if (_isLoadingProfile) {
      return const Card(child: Padding(padding: EdgeInsets.all(40.0), child: Center(child: CircularProgressIndicator())));
    }

    final lastClaim = _userProfile?.lastFreeReportClaimedAt;
    bool canClaim = true;
    if (lastClaim != null) {
      if (DateTime.now().isBefore(lastClaim.add(const Duration(days: 30)))) {
        canClaim = false;
      }
    }

    if (canClaim) {
      // This part for claiming remains the same.
      return Card(
        elevation: 8, margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blueAccent[100]!, width: 2)),
        clipBehavior: Clip.antiAlias, color: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          onTap: _claimFreeMonthlyReport,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Text('MONTHLY FREEBIE', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Text('Your Score', style: TextStyle(fontFamily: 'Bungee', fontSize: 24, color: Colors.blueAccent[100], fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24, height: 32),
                Icon(Icons.card_giftcard, color: Colors.blueAccent[100], size: 40),
                const SizedBox(height: 16),
                const Text('Claim Your Free Score', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.white70, blurRadius: 10.0)])),
              ],
            ),
          ),
        ),
      );
    } else {
      // --- NEW UI LOGIC ---
      // This now reads the static score directly from the user's profile.
      return Card(
        elevation: 8, margin: const EdgeInsets.symmetric(vertical: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[700]!, width: 2)),
        clipBehavior: Clip.antiAlias, color: Colors.black.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text('Daaymn Score', style: TextStyle(fontFamily: 'Bungee', fontSize: 24, color: Colors.blueAccent[100], fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // If the score is missing for some reason, show a placeholder.
              // Otherwise, show the static score from the user's profile.
              _userProfile?.lastClaimedScore == null
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Score not found', style: TextStyle(color: Colors.white70)),
              )
                  : _ScoreBadge(score: _userProfile!.lastClaimedScore!, isFinal: true),

              const SizedBox(height: 16),
              Text('Next Free #DaaymnScore:', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              const SizedBox(height: 8),

              Text(
                _getCountdownText(),
                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      );
    }
  }

  // Helper function to format the countdown text to avoid duplicating code.
  String _getCountdownText() {
    if (_timeUntilNextClaim == null) {
      return 'Calculating...';
    }
    final d = _timeUntilNextClaim!.inDays;
    final h = _timeUntilNextClaim!.inHours.remainder(24);
    final m = _timeUntilNextClaim!.inMinutes.remainder(60);
    final s = _timeUntilNextClaim!.inSeconds.remainder(60);
    return '${d.toString().padLeft(2, '0')}d ${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length:5, vsync: this);
    _iapService = Provider.of<InAppPurchaseService>(context, listen: false);
    _iapService.addListener(_onPurchaseUpdate);
    _loadUserProfile();

    _likeAdService.addListener(_onAdStateChanged);
    _scrollAdService.addListener(_onAdStateChanged);
    _ghostAdService.addListener(_onAdStateChanged);
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userProfile = Profile.fromJson(data);
          if (_userProfile?.lastFreeReportClaimedAt != null) {
            final nextClaimDate = _userProfile!.lastFreeReportClaimedAt!.add(const Duration(days: 30));
            if (DateTime.now().isBefore(nextClaimDate)) {
              _startCountdownTimer(nextClaimDate);
            }
          }
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load your profile data.'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  void dispose() {
    _tabController.dispose();
    _reportTabController?.dispose();
    _customAmountController.dispose();
    _countdownTimer?.cancel();
    _iapService.removeListener(_onPurchaseUpdate);
    _likeAdService.removeListener(_onAdStateChanged);
    _scrollAdService.removeListener(_onAdStateChanged);
    _ghostAdService.removeListener(_onAdStateChanged);
    super.dispose();
  }



  void _onPurchaseUpdate() {
    if (!mounted) return;

    if (_iapService.purchaseCompleted) {      // A purchase was successful. Check if it was the report we were waiting for.
      if (_pendingReportTier != null) {
        // It was a report. The loading dialog will close on its own.
        // Unlock the view and fetch the report data.
        final tierToUnlock = _pendingReportTier!;
        setState(() {
          _unlockedTier = tierToUnlock;
          _pendingReportTier = null; // Clear the pending state
        });
        _fetchReportData(tierToUnlock);
      } else {
        // It was a different purchase (e.g., likes, subscription, unlock).
        // Show a success message and reload the user's profile
        // data to reflect the purchase on the UI.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase successful!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserProfile();
      }
      // IMPORTANT: Reset the flag in the service so this doesn't fire multiple times.
      _iapService.clearPurchaseCompletedFlag();
    } else if (_iapService.purchaseError != null) {
      // An error occurred or the user cancelled. The dialog will also close itself.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_iapService.purchaseError!),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Crucially, we must also clear the pending report state on failure/cancellation.
      if (_pendingReportTier != null) {
        setState(() {
          _pendingReportTier = null;
        });
      }
    }
  }

  ProductDetails? _findProduct(List<ProductDetails> products, String productId) {
    if (_isDevelopment) {
      String title;
      String price;
      switch (productId) {
        case kProductIdLike1:
          title = '1 Like';
          price = 'R4.99';
          break;
        case kProductIdLike10:
          title = '10 Likes';
          price = 'R44.99';
          break;
        case kProductIdLike20:
          title = '20 Likes';
          price = 'R79.99';
          break;
        case kProductIdReportBasic:
          title = 'Basic Report';
          price = 'R19.99';
          break;
        case kProductIdReportPro:
          title = 'Pro Report';
          price = 'R39.99';
          break;
        case kProductIdReportDeluxe:
          title = 'Deluxe Report';
          price = 'R59.99';
          break;
        case kProductIdUnlockScrolling:
          title = 'Unlock Infinite Scrolling';
          price = 'R19.99/month';
          break;
        case kProductIdUnlockVisibility:
          title = 'Unlock Online Status Toggle';
          price = 'R19.99/month';
          break;
        case kProductIdSubStandard:
          title = 'Standard';
          price = 'R159.99/month';
          break;
        case kProductIdSubPro:
          title = 'Pro';
          price = 'R269.99/month';
          break;
        case kProductIdSubDeluxe:
          title = 'Deluxe';
          price = 'R459.99/month';
          break;
        default:
          title = 'Test Product';
          price = 'R0.00';
      }
      return ProductDetails(
        id: productId,
        title: title,
        description: 'This is a test product for $title.',
        price: price,
        rawPrice: double.tryParse(price.replaceAll(RegExp(r'[R/a-zA-Z]'), '')) ?? 0.0,
        currencyCode: 'ZAR',
      );
    }
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null; // Not found
    }
  }

  Future<void> _unlockReport(InAppPurchaseService iapService, ReportTier tier) async {
    // This function now ONLY initiates the purchase.
    // The _onPurchaseUpdate listener will handle the result.

    if (_isDevelopment) {
      // In dev mode, we can simulate the full flow instantly.
      setState(() {
        _unlockedTier = tier;
      });
      _fetchReportData(tier);
      return;
    }

    String? productId;
    switch (tier) {
      case ReportTier.free:
        return; // This should not be called for the free tier.
      case ReportTier.basic:
        productId = kProductIdReportBasic;
        break;
      case ReportTier.pro:
        productId = kProductIdReportPro;
        break;
      case ReportTier.deluxe:
        productId = kProductIdReportDeluxe;
        break;
    }

    final product = _findProduct(iapService.products, productId);
    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This item isn't available for purchase right now.")),
        );
      }
      return;
    }

    // --- THIS IS THE FIX ---
    // 1. Set the pending state so we know what we're trying to buy.
    setState(() {
      _pendingReportTier = tier;
    });

    // 2. Show a loading dialog and initiate the purchase.
    final statusController = StreamController<String>();
    statusController.add('Connecting to the store...');

    final purchaseFuture = iapService.buyProduct(product).whenComplete(() {
      // The listener will handle the result, so we just close the stream.
      if (!statusController.isClosed) {
        statusController.close();
      }
    });

    showDaaymnLoadingDialog(
      context: context,
      statusStream: statusController.stream,
      future: purchaseFuture,
    );
  }


  Future<void> _fetchReportData(ReportTier tier) async {
    final statusController = StreamController<String>();

    final reportFuture = _reportService.getReportCardData(
      Supabase.instance.client.auth.currentUser!.id,
      onProgress: (status) {
        statusController.add(status);
      },
    );

    showDaaymnLoadingDialog(
      context: context,
      statusStream: statusController.stream,
      future: reportFuture,
    );

    try {
      final data = await reportFuture;
      if (mounted) {
        // Pro/Basic reports have 3 tabs. Deluxe has 4.
        final tabCount = tier == ReportTier.deluxe ? 4 : 3;
        _reportTabController = TabController(length: tabCount, vsync: this);
        // Add a listener to rebuild the UI when the tab changes,
        // which allows the Share/Export button to update.
        _reportTabController?.addListener(() => setState(() {}));
        setState(() {
          _reportData = data;
        });

        // *** THIS IS THE NEW LINE ***
        // After successfully fetching a new report, show the share dialog.
        _showShareForLikesDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      statusController.close();
    }
  }



  Future<void> _shareDaaymnScore() async {
    if (_reportData == null || _userProfile == null) return;

    final uniqueId = const Uuid().v4().substring(0, 8);

    setState(() {
      _verificationId = uniqueId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        // Adding .select() forces the app to wait until the database
        // confirms the data is written AND readable, fixing the race condition.
        await Supabase.instance.client.from('verified_reports').insert({
          'id': uniqueId,
          'user_id': _userProfile!.id,
          'user_name': _userProfile!.name,
          'score': _reportData!.daaymnScore,
        }).select();

        // Now we can safely capture the image.
        RenderRepaintBoundary boundary = _badgeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/DaaymnScore_Badge.png').create();
        await file.writeAsBytes(pngBytes);

        await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], text: 'This is my verified DaaymnScore: ${_reportData!.daaymnScore}/10. What\'s yours? #DaaymnScore');

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate score badge: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _verificationId = null;
          });
        }
      }
    });
  }

  Future<bool> _exportReport() async {
    if (_reportData == null || _userProfile == null) {
      return false;
    }

    if (_cvKey.currentContext == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not find the report card to save.'))
        );
      }
      return false;
    }

    final uniqueId = const Uuid().v4().substring(0, 8);
    bool exportSucceeded = false;

    final completer = Completer<void>();
    setState(() {
      _verificationId = uniqueId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!completer.isCompleted) completer.complete();
      });
    });

    await completer.future;
    if (!mounted) return false;

    try {
      await Supabase.instance.client.from('verified_reports').insert({
        'id': uniqueId,
        'user_id': _userProfile!.id,
        'user_name': _userProfile!.name,
        'score': _reportData!.daaymnScore,
      }).select();

      RenderRepaintBoundary boundary = _cvKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/Daaymn_Report.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Here is my official #DaaymnScore Report. See where you stand!',
      );

      exportSucceeded = true;

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate report card: ${e.toString()}')));
      }
      exportSucceeded = false;
    } finally {
      if (mounted) {
        setState(() {
          _verificationId = null;
        });
      }
    }
    return exportSucceeded;
  }



  // This helper creates the gradient effect for the score.
  // NOTE: You may need to adjust the colors to match your app's exact theme.
  Gradient _getGradientForScore(double score) {if (score < 4.0) {
    return const LinearGradient(colors: [Color(0xFFE57373), Color(0xFFF06292)]); // Red to Pink
  } else if (score < 7.0) {
    return const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFFF176)]); // Orange to Yellow
  } else if (score < 9.0) {
    return const LinearGradient(colors: [Color(0xFF81C784), Color(0xFF4CAF50)]); // Light Green to Green
  } else {
    // Your signature "Daaymn" gradient for top scores
    return const LinearGradient(colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)]);
  }
  }

  // =======================================================================
  // === NEW, REDESIGNED REPORT CARD METHODS (REPLACE THE OLD ONES) ======
  // =======================================================================

  Widget _buildColorPicker() {
  return Padding(
  padding: const EdgeInsets.symmetric(vertical: 8.0),
  child: Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: _cardColorOptions.map((color) {
  return GestureDetector(
  onTap: () => setState(() => _selectedCardColor = color),
  child: Container(
  margin: const EdgeInsets.symmetric(horizontal: 8),
  width: 30,
  height: 30,
  decoration: BoxDecoration(
  color: color,
  shape: BoxShape.circle,
  border: Border.all(
  color: _selectedCardColor == color ? Colors.white : Colors.transparent,
  width: 2,
  ),
  ),
  ),
  );
  }).toList(),
  ),
  );
  }

  Widget _buildNewHighlight(IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor.withValues(alpha: 0.8), size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: textColor),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCvCategoryScore({required String title, required double score, String? grade, required Color textColor}) {
  return Column(
  children: [
  Text(title, style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 12)),
  const SizedBox(height: 8),
  Wrap(
  crossAxisAlignment: WrapCrossAlignment.center,
  alignment: WrapAlignment.center,
  spacing: 4.0,
  children: [
  Text(
  score.toStringAsFixed(1),
  style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
  ),
  Text('/10', style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 10)),
  if (grade != null) Text('($grade)', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
  ],
  ),
  ],
  );
  }

  Widget _buildCvScore(Color textColor) {
  final score = _reportData!.daaymnScore;
  return Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
  Text(
  'DAAYMN SCORE',
  style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold),
  ),
  const SizedBox(height: 8),
  Text(
  score.toStringAsFixed(1),
  style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: textColor, height: 1),
  ),
  ],
  );
  }

  Widget _buildVerifiedBadge() {
  return Transform.scale(
  scale: 0.8,
  alignment: Alignment.bottomRight,
  child: Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(12),
  gradient: const LinearGradient(
  colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  ),
  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 2))],
  ),
  child: const Row(
  mainAxisSize: MainAxisSize.min,
  children: [
  Icon(Icons.star, color: Colors.white, size: 16),
  SizedBox(width: 8),
  Text(
  'Daaymn Verified Scorecard',
  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
  ),
  ],
  ),
  ),
  );
  }

  Widget _buildReportCvCard() {
    if (_userProfile == null || _reportData == null) {
      return const SizedBox.shrink();
    }
    final bool isDark = _selectedCardColor.computeLuminance() < 0.5;
    final Color textColor = isDark ? Colors.white : Colors.black;
    if (_randomAboutMeFactEntry == null && _userProfile!.bioTopics.isNotEmpty) {
      _randomAboutMeFactEntry =
          (_userProfile!.bioTopics.entries.toList()..shuffle()).first;
    }
    final aboutMeFact = _randomAboutMeFactEntry != null
        ? _randomAboutMeFactEntry!.value
        : 'Not available';
    final corePreference = _userProfile!.interestedIn?.isNotEmpty == true
        ? _userProfile!.interestedIn!.join(', ')
        : 'Not specified';
    String height;
    final heightValue = _userProfile!.heightCm?.value;
    if (heightValue != null) {
      final metricSystem = _userProfile!.metricSystem ?? 'Metric';
      height = _formatHeight(heightValue, metricSystem);
    } else {
      height = 'Not specified';
    }

    return RepaintBoundary(
      key: _cvKey,
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: _selectedCardColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              _userProfile!.imageUrl ?? '',
                              cacheWidth: 1080,
                              fit: BoxFit.cover,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    child: Icon(Icons.person,
                                        size: 60,
                                        color: textColor.withValues(alpha: 0.5)),
                                  ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: VerticalDivider(
                            width: 1, color: textColor.withValues(alpha: 0.2)),
                      ),
                      Expanded(child: _buildCvScore(textColor)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 80,
                              height: 1,
                              color: textColor.withValues(alpha: 0.2),
                              margin:
                              const EdgeInsets.symmetric(vertical: 12))),
                      Text(_userProfile!.name,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      const SizedBox(height: 8),
                      _buildNewHighlight(
                          Icons.height, 'Height', height, textColor),
                      _buildNewHighlight(Icons.short_text, _randomAboutMeFactEntry?.key ?? 'About', aboutMeFact, textColor),
                      _buildNewHighlight(Icons.volunteer_activism,
                          'Preference', corePreference, textColor),
                      Center(
                          child: Container(
                              width: 80,
                              height: 1,
                              color: textColor.withValues(alpha: 0.2),
                              margin:
                              const EdgeInsets.symmetric(vertical: 16))),
                      Row(
                        children: [
                          Expanded(
                              child: _buildCvCategoryScore(
                                  title: 'Popularity',
                                  score: _reportData!.popularityScore,
                                  textColor: textColor)),
                          Expanded(
                              child: _buildCvCategoryScore(
                                  title: 'Engagement',
                                  score: _reportData!.engagementScore,
                                  textColor: textColor)),
                          Expanded(
                              child: _buildCvCategoryScore(
                                  title: 'Safety',
                                  score: _reportData!.safetyScore,
                                  grade: _reportData!.safetyGrade,
                                  textColor: textColor)),
                        ],
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: _buildVerifiedBadge(),
            ),
            if (_verificationId != null)
              Positioned(
                bottom: 10, // Adjusted for new size
                left: 10,  // Adjusted for new size
                // This Container WRAPS the QR code to provide the circular background.
                child: Container(
                  width: 40.0,  // *** SMALLER SIZE ***
                  height: 40.0, // *** SMALLER SIZE ***
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  child: QrImageView(
                    data: _verificationId!,
                    version: QrVersions.auto,
                    size: 40.0, // *** SMALLER SIZE ***
                    backgroundColor: Colors.transparent,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Colors.white,
                    ),
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // This new helper builds the DAAYMN score with the gradient effect.
  String _formatHeight(double cm, String system) {
    if (system == 'Imperial') {
      final inches = cm / 2.54;
      final feet = inches ~/ 12;
      final remainingInches = (inches % 12).round();
      return "$feet' $remainingInches";
    } else {
      return '${cm.toStringAsFixed(0)} cm';
    }
  }




  // UPDATED: The "Verified" badge is now straight (no rotation).
  @override
  Widget build(BuildContext context) {
    final iapService = Provider.of<InAppPurchaseService>(context);
    final appBar = AppBar(
      title: const Text("Store",
          style: TextStyle(
              fontFamily: 'Pacifico',
              color: Colors.white,
              shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))])),
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      bottom: TabBar(
        isScrollable: false,
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withAlpha(178),
        indicatorColor: Colors.white,
        labelStyle: const TextStyle(fontSize: 11),
        tabs: const [
          Tab(icon: Icon(Icons.favorite), text: 'Likes'),
          Tab(icon: Icon(Icons.assessment), text: 'Reports'),
          Tab(icon: Icon(Icons.slow_motion_video), text: 'Freebies'),
          Tab(icon: Icon(Icons.lock_open), text: 'Unlock'),
          Tab(icon: Icon(Icons.star), text: 'Subs'),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        _handlePop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: appBar,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // ----------------------------------------------------
              Padding(
                padding: EdgeInsets.only(top: appBar.preferredSize.height + MediaQuery.of(context).padding.top),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLikesTab(iapService),
                    _buildReportsTab(iapService),
                    _buildAdsTab(),
                    _buildUnlockTab(iapService),
                    _buildSubscriptionsTab(iapService),
                  ],
                ),
              ),
              if (iapService.isPurchasePending)
                const Opacity(
                  opacity: 0.8,
                  child: ModalBarrier(dismissible: false, color: Colors.black),
                ),
              if (iapService.isPurchasePending)
                const Center(
                  child: CircularProgressIndicator(),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikesTab(InAppPurchaseService iapService) {
    if (!iapService.isStoreAvailable && !_isDevelopment) {
      return const Center(child: Text("Store not available.", style: TextStyle(color: Colors.white)));
    }

    final product1 = _findProduct(iapService.products, kProductIdLike1);
    final product10 = _findProduct(iapService.products, kProductIdLike10);
    final product20 = _findProduct(iapService.products, kProductIdLike20);

    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Daaymn',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 50,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))]),
            ),
            const SizedBox(height: 8),
            Text(
              'Buy some Daaymn likes!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            if (product1 != null) _buildPurchaseOption(product: product1, baseLikes: 1, bonusLikes: 0, iapService: iapService),
            if (product10 != null) _buildPurchaseOption(product: product10, baseLikes: 10, bonusLikes: 1, iapService: iapService),
            if (product20 != null) _buildPurchaseOption(product: product20, baseLikes: 20, bonusLikes: 2, iapService: iapService),
          ],
        ),
      );
  }

  Widget _buildReportsTab(InAppPurchaseService iapService) {
    if (!iapService.isStoreAvailable && !_isDevelopment) {
      return const Center(child: Text("Store not available.", style: TextStyle(color: Colors.white)));
    }

    // The entire tab is now one scrollable view. This prevents the "scroll to bottom" issue
    // and makes the whole page feel like one unit.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The header is always at the top of the scroll view.
          const Text(
            'Daaymn Reports',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Pacifico',
                fontSize: 50,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))]),
          ),
          const SizedBox(height: 8),
          Text(
            _unlockedTier != null ? 'Your Report Card' : 'Find out where you really stand.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          // Conditionally display the correct view below the header.
          if (_unlockedTier != null && _reportData != null)
            _buildUnlockedReportView()
          else
            _buildLockedReportView(iapService),
        ],
      ),
    );
  }
  Widget _buildAdsTab() {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('id', userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final userProfile = Profile.fromJson(snapshot.data!.first);
        final now = DateTime.now();
        const twentyFourHours = Duration(hours: 24);

        final bool isLikeClaimed = userProfile.lastAdLikeAt != null && now.difference(userProfile.lastAdLikeAt!) < twentyFourHours;
        final bool isScrollClaimed = userProfile.lastAdScrollAt != null && now.difference(userProfile.lastAdScrollAt!) < twentyFourHours;
        final bool isGhostClaimed = userProfile.lastAdGhostAt != null && now.difference(userProfile.lastAdGhostAt!) < twentyFourHours;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Freebies', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Pacifico', fontSize: 50, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))])),
              const SizedBox(height: 8),
              Text('Watch an ad, get a Daaymn reward! (Once per day)', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              _buildAdOptionCard(
                icon: Icons.favorite,
                title: 'Daaymn Like!',
                description: 'Your daily freebie. One like, on the house. Shoot your shot!',
                onPressed: !isLikeClaimed && _likeAdService.isAdReady ? () => _watchAdForReward(rewardType: 'like', adService: _likeAdService) : null,
                isClaimed: isLikeClaimed,
                isAdReady: _likeAdService.isAdReady,
              ),
              _buildAdOptionCard(
                icon: Icons.all_inclusive,
                title: 'Infinity Scroll (1 Hour)',
                description: 'Scroll forever, see everyone. Your 1-hour all-access pass to the Discover feed.',
                onPressed: !isScrollClaimed && _scrollAdService.isAdReady ? () => _watchAdForReward(rewardType: 'scroll', adService: _scrollAdService) : null,
                isClaimed: isScrollClaimed,
                isAdReady: _scrollAdService.isAdReady,
              ),
              _buildAdOptionCard(
                icon: Icons.visibility_off,
                title: 'Ghost Mode (1 Hour)',
                description: 'Vanish. Browse profiles without a trace for one hour.',
                onPressed: !isGhostClaimed && _ghostAdService.isAdReady ? () => _watchAdForReward(rewardType: 'ghost', adService: _ghostAdService) : null,
                isClaimed: isGhostClaimed,
                isAdReady: _ghostAdService.isAdReady,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onPressed,
    required bool isClaimed,
    required bool isAdReady,
  }) {
    final bool isButtonEnabled = onPressed != null;

    String buttonText;
    if (isClaimed) {
      buttonText = 'Claimed';
    } else if (isAdReady) {
      buttonText = 'Watch';
    } else {
      buttonText = 'Loading...';
    }

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      color: Colors.black.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: !isClaimed ? Colors.white70 : Colors.white30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: !isClaimed ? Colors.white : Colors.grey)),
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: !isClaimed ? Colors.white70 : Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isButtonEnabled ? Colors.greenAccent : Colors.grey,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockTab(InAppPurchaseService iapService) {
    if (!iapService.isStoreAvailable && !_isDevelopment) {
      return const Center(child: Text("Store not available.", style: TextStyle(color: Colors.white)));
    }

    final scrolling = _findProduct(iapService.products, kProductIdUnlockScrolling);
    final visibility = _findProduct(iapService.products, kProductIdUnlockVisibility);

    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Unlock Features',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 50,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))]),
            ),
            const SizedBox(height: 8),
            Text(
              'Get the features you want, monthly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            if (scrolling != null) _buildUnlockFeatureCard(product: scrolling, icon: Icons.all_inclusive, description: "See everyone in the Discover feed without limits.", iapService: iapService),
            if (visibility != null) _buildUnlockFeatureCard(product: visibility, icon: Icons.visibility_off, description: "Toggle your online status at any time.", iapService: iapService),
          ],
        ),
      );
  }

  Widget _buildUnlockFeatureCard({
    required ProductDetails product,
    required IconData icon,
    required String description,
    required InAppPurchaseService iapService,
  }) {
    bool isUnlocked = false;
    // *** CORRECTED LOGIC ***
    // Check the 'until' timestamps to see if the feature is active,
    // regardless of whether it was from an ad or a purchase.
    if (_userProfile != null) {
      if (product.id == kProductIdUnlockScrolling) {
        isUnlocked = _userProfile!.infiniteScrollUntil != null &&
            _userProfile!.infiniteScrollUntil!.isAfter(DateTime.now());
      } else if (product.id == kProductIdUnlockVisibility) {
        isUnlocked = _userProfile!.ghostModeUntil != null &&
            _userProfile!.ghostModeUntil!.isAfter(DateTime.now());
      }
    }

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      color: Colors.black.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, size: 50, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              product.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Bungee',
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Divider(color: Colors.white24, height: 32),
            if (isUnlocked)
              const Text('Unlocked',
                  style: TextStyle(
                      fontSize: 20,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold))
            else
              Text(product.price,
                  style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              // Disable the button if unlocked. Pressing it will trigger the purchase flow.
              onPressed: isUnlocked ? null : () => iapService.buyProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnlocked ? Colors.grey : Colors.white,
                foregroundColor: Colors.black,
                padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isUnlocked ? 'Unlocked' : 'Unlock',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsTab(InAppPurchaseService iapService) {
    if (!iapService.isStoreAvailable && !_isDevelopment) {
      return const Center(child: Text("Store not available.", style: TextStyle(color: Colors.white)));
    }

    final standard = _findProduct(iapService.products, kProductIdSubStandard);
    final pro = _findProduct(iapService.products, kProductIdSubPro);
    final deluxe = _findProduct(iapService.products, kProductIdSubDeluxe);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Go Premium',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Pacifico',
                fontSize: 50,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(1, 1))]),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock the ultimate Daaymn experience.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          if (standard != null) _buildSubscriptionTierCard(product: standard, features: ['60 Likes/Month', '1 Basic Report/Month', 'Infinite Scrolling', 'Online Status Toggle'], iapService: iapService, savings: 33.56),
          if (pro != null) _buildSubscriptionTierCard(product: pro, features: ['120 Likes/Month', '1 Pro Report/Month', 'Infinite Scrolling', 'Online Status Toggle'], iapService: iapService, isPopular: true, savings: 47.59),
          if (deluxe != null) _buildSubscriptionTierCard(product: deluxe, features: ['240 Likes/Month', '1 Deluxe Report/Month', 'Infinite Scrolling', 'Online Status Toggle'], iapService: iapService, savings: 58.51),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTierCard({
    required ProductDetails product,required List<String> features,
    required InAppPurchaseService iapService,
    bool isPopular = false,
    double savings = 0, // Changed to double
  }) {
    // --- START: New Simplified Logic ---
    const tierOrder = ['Standard', 'Pro', 'Deluxe'];

    String getTierFromProductId(String id) {
      if (id == kProductIdSubStandard) return 'Standard';
      if (id == kProductIdSubPro) return 'Pro';
      if (id == kProductIdSubDeluxe) return 'Deluxe';
      return '';
    }

    final cardTier = getTierFromProductId(product.id);

    final bool hasActiveSub = _userProfile?.subscriptionExpiresAt != null &&
        _userProfile!.subscriptionExpiresAt!.isAfter(DateTime.now());

    final String currentActiveTier = hasActiveSub ? (_userProfile?.subscriptionTier ?? '') : '';

    final int cardTierIndex = tierOrder.indexOf(cardTier);
    final int currentActiveTierIndex = tierOrder.indexOf(currentActiveTier);

    final bool isSubscribedToThisTier = hasActiveSub && currentActiveTier == cardTier;
    final bool isHigherTier = hasActiveSub && cardTierIndex > currentActiveTierIndex;
    final bool canPurchase = !hasActiveSub || isHigherTier;
    // --- END: New Simplified Logic ---

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        InkWell(
          onTap: canPurchase
              ? () {
            if (_isDevelopment) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Simulating subscription to ${product.title}...'
                  )
              ));
              setState(() {
                _userProfile = _userProfile?.copyWith(
                  subscriptionExpiresAt: DateTime.now().add(const Duration(days: 30)),
                  subscriptionTier: cardTier,
                  hasClaimedMonthlyReport: false,
                );
              });
            } else {
              iapService.buyProduct(product);
            }
          }
              : null,
          child: Card(
            elevation: isPopular ? 12 : 8,
            margin:
            const EdgeInsets.only(top: 20, left: 8, right: 8, bottom: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)
            ),
            clipBehavior: Clip.antiAlias,
            color: Colors.black.withValues(alpha: isSubscribedToThisTier
                ? 0.4 // Highlight for the active subscription
                : isPopular && canPurchase
                ? 0.4
                : 0.2),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (isPopular && canPurchase && !isSubscribedToThisTier)
                    const Text(
                      'MOST POPULAR',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  if (isPopular && canPurchase && !isSubscribedToThisTier) const SizedBox(height: 8),
                  Text(
                    product.title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Bungee',
                      fontSize: 24,
                      color: isSubscribedToThisTier
                          ? Colors.greenAccent // Highlight color for active sub
                          : canPurchase
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isSubscribedToThisTier)
                    const Text('CURRENT PLAN',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold))
                  else if (canPurchase)
                    Text(product.price,
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold))
                  else // For tiers lower than the current one
                    const Text('INCLUDED IN HIGHER TIER',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold)),

                  const Divider(color: Colors.white24, height: 32),
                  ...features.map((feature) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.check,
                                color: (isSubscribedToThisTier || canPurchase)
                                    ? Colors.greenAccent
                                    : Colors.grey,
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(feature,
                                    style: TextStyle(
                                        color: (isSubscribedToThisTier || canPurchase)
                                            ? Colors.white
                                            : Colors.grey))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 24),
                  Text(
                    isSubscribedToThisTier ? 'Active' : (canPurchase ? 'Take me now' : 'Subscribed'),
                    style: TextStyle(
                        fontSize: 18,
                        color: (isSubscribedToThisTier || !canPurchase) ? Colors.grey : Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (savings > 0 && canPurchase && !isSubscribedToThisTier)
          Positioned(
            top: 0,
            left: 0,
            child: _buildSavingsBanner(savings: savings),
          ),
      ],
    );
  }

  Widget _buildSavingsBanner({required double savings}) { // Changed to double
    return Transform.rotate(
      angle: -math.pi / 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(2, 2))],
        ),
        child: Text(
          // Format to 2 decimal places
          'SAVE ${savings.toStringAsFixed(2)}%',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLockedReportView(InAppPurchaseService iapService) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    final basicProduct = _findProduct(iapService.products, kProductIdReportBasic);
    final proProduct = _findProduct(iapService.products, kProductIdReportPro);
    final deluxeProduct = _findProduct(iapService.products, kProductIdReportDeluxe);

    // Determine if user has a valid, unclaimed report credit
    final bool hasActiveSub = _userProfile?.subscriptionExpiresAt != null && _userProfile!.subscriptionExpiresAt!.isAfter(DateTime.now());
    final bool hasClaimed = _userProfile?.hasClaimedMonthlyReport ?? true;
    final String? creditTier = _userProfile?.monthlyReportCreditTier?.toLowerCase();

    final bool canClaimBasic = hasActiveSub && !hasClaimed && creditTier == 'basic';
    final bool canClaimPro = hasActiveSub && !hasClaimed && creditTier == 'pro';
    final bool canClaimDeluxe = hasActiveSub && !hasClaimed && creditTier == 'deluxe';

    return Column(
      children: [
        _buildFreeReportSection(),
        if (basicProduct != null)
          _buildReportTierCard(
            product: basicProduct,
            tier: ReportTier.basic,
            features: ['Overall Daaymn Score', 'Popularity Score', 'Engagement Score', 'Community Grade'],
            iapService: iapService,
            canClaim: canClaimBasic, // Pass claim status
          ),
        if (proProduct != null)
          _buildReportTierCard(
            product: proProduct,
            tier: ReportTier.pro,
            features: ['All Basic Features', 'Detailed Score Breakdowns', 'Personalized Improvement Tips'],
            iapService: iapService,
            isPopular: true,
            canClaim: canClaimPro, // Pass claim status
          ),
        if (deluxeProduct != null)
          _buildReportTierCard(
            product: deluxeProduct,
            tier: ReportTier.deluxe,
            features: ['All Pro Features!', 'Deep-Dive Statistics!', 'Check your Overall Stats!'],
            iapService: iapService,
            canClaim: canClaimDeluxe, // Pass claim status
          ),
      ],
    );
  }

  Widget _buildReportTierCard({
    required ProductDetails product,
    required ReportTier tier,
    required List<String> features,
    required InAppPurchaseService iapService,
    bool isPopular = false,
    bool canClaim = false, // This is for subscription credit
  }) {
    return Consumer<PromoCodeService>(
      builder: (context, promoService, child) {
        final isPromoClaimable = promoService.redeemedProductId == product.id;
        final showClaimButton = canClaim || isPromoClaimable;

        return Card(
          elevation: isPopular ? 12 : 8,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          clipBehavior: Clip.antiAlias,
          color: Colors.black.withValues(alpha: isPopular ? 0.4 : 0.2),
          child: InkWell(
            onTap: () {
              if (isPromoClaimable) {
                // *** FIX: Set the pending tier so the UI knows to show the report after claiming. ***
                setState(() {
                  _pendingReportTier = tier;
                });
                iapService.claimProduct(product.id);
                promoService.clearRedeemedProduct();
              } else if (canClaim) {
                _claimMonthlyReport();
              } else {
                _unlockReport(iapService, tier);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (isPopular)
                    const Text(
                      'MOST POPULAR',
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  if (isPopular) const SizedBox(height: 8),
                  Text(
                    product.title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Bungee',
                      fontSize: 24,
                      color: isPopular ? Colors.greenAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!showClaimButton)
                    Text(product.price, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))
                  else if (isPromoClaimable)
                    const Text('PROMO CODE APPLIED', style: TextStyle(fontSize: 14, color: Colors.greenAccent, fontWeight: FontWeight.bold))
                  else
                    const Text('INCLUDED WITH YOUR SUBSCRIPTION', style: TextStyle(fontSize: 14, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white24, height: 32),
                  ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(feature, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 24),
                  Text(
                    showClaimButton ? 'Claim the Daaymn Truth' : 'Reveal the Truth',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: showClaimButton ? Colors.blueAccent : Colors.red,
                          blurRadius: 10.0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  // --- This is the FINAL, WORKING implementation ---

// Step 2.2: Replace the export function with a simple, correct version.
// This function has no modification logic. It just captures and saves.
  Future<void> _exportWidgetWithSignature({
    required GlobalKey boundaryKey,
    required String fileName,
    String? signature, // This is no longer used but kept for the calling function
  }) async {
    try {
      RenderRepaintBoundary boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception("Could not get byte data from image");
      }

      // There is no modification. Just get the bytes and save them.
      Uint8List imageBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$fileName').create();
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'My official #DaaymnScore. See where you stand!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export image: ${e.toString()}')),
        );
      }
    }
  }


  // --- FINAL DIAGNOSTIC: THE RED LINE TEST ---
// This function attempts to do only one thing: draw a thick red line
// across the image. If this line does not appear, the entire method is impossible.

  // This is an example of a button action that would call the export function.
  void _triggerExport() {
    if (_reportData == null) return;

    // Recreate the signature to be embedded.
    final String? verificationSignature;
    if (_unlockedTier != null && _unlockedTier != ReportTier.free) {
      final uniqueId = const Uuid().v4();
      final score = _reportData!.daaymnScore.toStringAsFixed(1);
      verificationSignature = '$uniqueId@$score';
      // You would save this to your DB here as well.
    } else {
      verificationSignature = null;
    }

    _exportWidgetWithSignature(
      boundaryKey: _shareKey, // The GlobalKey of your shareable card.
      fileName: 'DaaymnReport.png',
      signature: verificationSignature,
    );
  }

  Widget _buildImprovementSection() {
    final advice = _getImprovementAdvice();
    if (advice.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to Improve', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ...advice.map((item) => ListTile(
                  leading: Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                  title: Text(item.title),
                  subtitle: Text(item.description),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDeluxeStatsSection() {
    return Card(
      margin: const EdgeInsets.only(top: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deluxe Stats', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16.0,
              runSpacing: 16.0,
              children: [
                _StatChip(label: 'Likes Received', value: _reportData!.likesReceived.toString()),
                _StatChip(label: 'Dislikes Received', value: _reportData!.dislikesReceived.toString()),
                _StatChip(label: 'Likes Sent', value: _reportData!.likesSent.toString()),
                _StatChip(label: 'Total Matches', value: _reportData!.matches.toString()),
                _StatChip(label: 'OTMs Sent', value: _reportData!.otmsSent.toString()),
                _StatChip(label: 'Ghosting Rate', value: _reportData!.ghostingRate, isPercentage: true),
                _StatChip(label: 'Attractiveness Ratio', value: _reportData!.attractivenessRatio, isPercentage: true),
                _StatChip(label: 'Match Rate', value: _reportData!.matchRate, isPercentage: true),
                _StatChip(label: 'Times Blocked', value: _reportData!.timesBlocked.toString(), isNegative: true),
                _StatChip(label: 'Reports Against You', value: _reportData!.reportsAgainst.toString(), isNegative: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_ImprovementAdvice> _getImprovementAdvice() {
    final advice = <_ImprovementAdvice>[];

    if (_reportData!.popularityScore < 6) {
      advice.add(_ImprovementAdvice(
        icon: Icons.photo_camera,
        title: 'Refresh Your Photos',
        description: 'Your photos are your first impression. Try adding new, high-quality pictures that show off your personality.',
      ));
    }
    if (_reportData!.engagementScore < 6) {
      advice.add(_ImprovementAdvice(
        icon: Icons.chat,
        title: 'Start a Conversation',
        description: 'Don\'t just match, message! Your engagement score will thank you for it.',
      ));
    }
    if (_reportData!.bioLength < 50) {
      advice.add(_ImprovementAdvice(
        icon: Icons.edit,
        title: 'Flesh out Your Bio',
        description: 'A longer bio gives potential matches more to connect with. Tell them something interesting about yourself.',
      ));
    }
    if (_reportData!.safetyScore < 8) {
      advice.add(_ImprovementAdvice(
        icon: Icons.shield,
        title: 'Review Community Guidelines',
        description: 'Make sure you\'re following the rules to create a safe and positive experience for everyone.',
      ));
    }

    return advice;
  }

  Widget _buildHeartsDisplay(int baseCount, int bonusCount) {
    List<Widget> hearts = [];
    // Base hearts
    for (int i = 0; i < baseCount; i++) {
      hearts.add(const Icon(Icons.favorite, color: Colors.white70, size: 22));
    }
    // Bonus hearts
    for (int i = 0; i < bonusCount; i++) {
      hearts.add(const Icon(Icons.favorite, color: Colors.greenAccent, size: 30)); // Bigger
    }

    return Wrap(
      spacing: 2.0,
      runSpacing: 2.0,
      children: hearts,
    );
  }

  Widget _buildPurchaseOption({
    required ProductDetails product,
    required int baseLikes,
    required int bonusLikes,
    required InAppPurchaseService iapService,
  }) {
    return Consumer<PromoCodeService>(
      builder: (context, promoService, child) {
        final isClaimable = promoService.redeemedProductId == product.id;
        final String valueText = bonusLikes > 0 ? '$baseLikes + $bonusLikes FREE' : '$baseLikes';

        return Card(
          elevation: 8,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          clipBehavior: Clip.antiAlias,
          color: Colors.black.withValues(alpha: 0.2),
          child: InkWell(
            onTap: () {
              if (isClaimable) {
                iapService.claimProduct(product.id);
                promoService.clearRedeemedProduct(); // Clear the code after claiming
              } else {
                if (_isDevelopment) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulating purchase...')));
                } else {
                  iapService.buyProduct(product);
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              valueText,
                              style: const TextStyle(
                                fontFamily: 'Bungee',
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Likes',
                              style: TextStyle(
                                fontFamily: 'Pacifico',
                                fontSize: 22,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isClaimable ? "CLAIM" : product.price,
                        style: TextStyle(
                          fontSize: 18,
                          color: isClaimable ? Colors.greenAccent : Colors.grey[300],
                          fontWeight: isClaimable ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHeartsDisplay(baseLikes, bonusLikes),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on img.ExifData {
  set userComment(String userComment) {}
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isPercentage;
  final bool isNegative;
  final bool isLocked; // New property

  const _StatChip({
    required this.label,
    required this.value,
    this.isPercentage = false,
    this.isNegative = false,
    this.isLocked = false
  });

  @override
  Widget build(BuildContext context) {
    final lockedColor = Colors.grey[800];
    final lockedTextColor = Colors.grey[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLocked
            ? lockedColor?.withAlpha(50)
            : (isNegative ? Colors.red.withAlpha(25) : Colors.black.withAlpha(25)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isLocked
                ? lockedColor!
                : (isNegative ? Colors.red.withAlpha(128) : Colors.grey.withAlpha(128))),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: isLocked ? lockedTextColor : Colors.grey)),
          const SizedBox(height: 4),
          Text(
            // Show percentage sign only if not locked
            isLocked
                ? value
                : (isPercentage ? '${double.tryParse(value)?.toStringAsFixed(1) ?? value}%' : value),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              // Use green accent for the "Unlock" text
              color: isLocked
                  ? Colors.greenAccent
                  : (isNegative ? Colors.redAccent : Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final bool isFinal;

  const _ScoreBadge({required this.score, this.isFinal = false});

  Color _getScoreColor(double score) {
    if (score >= 9.0) return Colors.greenAccent[400]!;
    if (score >= 7.0) return Colors.lightGreen;
    if (score >= 5.0) return Colors.yellow[600]!;
    if (score >= 3.0) return Colors.orange[700]!;
    return Colors.red[700]!;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(score);
    return Container(
      padding: EdgeInsets.all(isFinal ? 24 : 12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white.withAlpha(204), width: isFinal ? 4 : 2),
        boxShadow: [
          BoxShadow(color: color.withAlpha(178), blurRadius: 15, spreadRadius: 3),
          BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
                fontSize: isFinal ? 48 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 2, color: Colors.black38, offset: Offset(1, 1))]),
          ),
          if (isFinal)
            const Text(
              '/ 10',
              style: TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}

class _CurvedText extends StatelessWidget {
  const _CurvedText({
    required this.text,
    required this.radius,
    required this.textStyle,
    this.startAngle = 0,
  });

  final String text;
  final double radius;
  final TextStyle textStyle;
  final double startAngle;

  @override
  Widget build(BuildContext context) {
    // The ShaderMask is no longer needed here.
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: _buildTextCharacters(),
    );
  }

  List<Widget> _buildTextCharacters() {
    // 1. Create the Paint object with the gradient shader as you suggested.
    // The Rect is sized to generously cover the text area.
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0.0, 0.0, 150, 50));

    // 2. Create the new TextStyle using the foreground paint.
    final gradientStyle = textStyle.copyWith(foreground: paint);

    final characters = <Widget>[];
    final characterAngle = (textStyle.fontSize ?? 14) / radius;
    final totalAngle = (text.length - 1) * characterAngle;
    final double firstCharAngle = startAngle - totalAngle / 2;

    for (int i = 0; i < text.length; i++) {
      final double charAngle = firstCharAngle + i * characterAngle;
      characters.add(
        Transform(
          transform: Matrix4.identity()
            ..translate(radius * math.sin(charAngle), -radius * math.cos(charAngle))
            ..rotateZ(charAngle),
          alignment: Alignment.center,
          // 3. Apply the new gradientStyle to each character.
          child: Text(text[i], style: gradientStyle, textAlign: TextAlign.center),
        ),
      );
    }
    return characters;
  }
}

class _ImprovementAdvice {
  final IconData icon;
  final String title;
  final String description;

  _ImprovementAdvice({required this.icon, required this.title, required this.description});
}
