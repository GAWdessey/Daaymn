import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:daaymn/create_profile_screen.dart';
import 'package:daaymn/globals.dart';
import 'package:daaymn/tutorial_service.dart';
import 'package:flutter/material.dart';

class ProfileDetailScreen extends StatefulWidget {
  final List<Profile> profiles;
  final int startIndex;
  final Future<bool> Function()? onLike;
  final VoidCallback? showOutOfLikesDialog;
  final Map<String, int>? dislikeCounts;

  const ProfileDetailScreen({
    super.key,
    required this.profiles,
    required this.startIndex,
    this.onLike,
    this.showOutOfLikesDialog,
    this.dislikeCounts,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> with TickerProviderStateMixin {
  final TutorialService _tutorialService = TutorialService();
  static const String _pageKey = 'profile_detail';

  late int _currentIndex;
  late Profile _currentProfile;
  Profile? _viewingUser;
  bool _isProcessing = false;
  late bool _isMyProfile;

  final List<String> _actionedProfileIds = [];

  late AnimationController _animationController;
  late Animation<double> _animation;
  IconData? _overlayIcon;
  Color? _overlayIconColor;

  bool _showTutorialOverlay = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _currentProfile = widget.profiles[_currentIndex];
    _isMyProfile = _currentProfile.id == supabase.auth.currentUser!.id;
    _loadViewingUser();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _loadViewingUser() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase.from('profiles').select().eq('id', userId).single();
      if (mounted) {
        setState(() {
          _viewingUser = Profile.fromJson(response);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToNextProfile() {
    if (!mounted) return;

    if (_currentIndex + 1 < widget.profiles.length) {
      setState(() {
        _currentIndex++;
        _currentProfile = widget.profiles[_currentIndex];
        _isProcessing = false;
        _animationController.reset();
        _overlayIcon = null;
      });
    } else {
      Navigator.of(context).pop(_actionedProfileIds);
    }
  }

  Future<void> _checkAndShowTutorial() async {
    if (_isMyProfile) return;
    final shouldShow = await _tutorialService.shouldShowTutorial(_pageKey);
    if (shouldShow && mounted) {
      setState(() => _showTutorialOverlay = true);
    }
  }

  Future<void> _dismissTutorial() async {
    await _tutorialService.markTutorialAsSeen(_pageKey);
    if (mounted) {
      setState(() => _showTutorialOverlay = false);
    }
  }

  Future<void> _triggerAnimation(IconData icon, Color color) async {
    if (!mounted) return;
    setState(() {
      _overlayIcon = icon;
      _overlayIconColor = color;
    });
    await _animationController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _goToNextProfile();
    }
  }

  // REPLACE the existing _likeUser method with this corrected version.

  Future<void> _likeUser() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    bool likeConsumed = false;
    try {
      // Perform the same RPC as the discover screen to ensure consistency
      await supabase.rpc('create_like_and_remove_dislike', params: {
        'p_liked_user_id': _currentProfile.id,
      });
      likeConsumed = true;
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('insufficient likes')) {
          // Use the callback from the discover screen to show the 'Out of Likes' dialog
          if (widget.showOutOfLikesDialog != null) {
            widget.showOutOfLikesDialog!();
          } else {
            // Fallback snackbar if the dialog callback isn't available
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have no likes left for today!'), backgroundColor: Colors.orange));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error liking profile: $e')));
        }
      }
    }

    // Only proceed if the like was successfully consumed by the database
    if (likeConsumed) {
      _actionedProfileIds.add(_currentProfile.id);
      _triggerAnimation(Icons.favorite, Colors.pinkAccent);
    } else {
      // If the like failed (e.g., out of likes), reset the processing state
      // so the user can try another action without being stuck.
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _dislikeUser() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _actionedProfileIds.add(_currentProfile.id);

    try {
      await supabase.rpc('increment_dislike', params: {
        'p_disliked_user_id': _currentProfile.id,
      });
    } catch (e) {
      // Error is handled silently
    } finally {
      _triggerAnimation(Icons.heart_broken, Colors.grey);
    }
  }

  Future<void> _editProfile() async {
    final result = await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (context) => CreateProfileScreen(
          profileToEdit: _currentProfile,
          onProfileSaved: (updatedProfile) {
            Navigator.of(context).pop(updatedProfile);
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _currentProfile = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _currentProfile;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(_actionedProfileIds);
          },
        ),
        title: _isMyProfile
            ? const Text('My Profile')
            : RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  children: [const TextSpan(text: "Daaymn it's ", style: TextStyle(fontFamily: 'Pacifico')), TextSpan(text: profile.name)],
                ),
              ),
        actions: _buildActions(),
      ),
      body: GestureDetector(
        onDoubleTapDown: !_isMyProfile ? _handleDoubleTap : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_viewingUser != null)
              ListView(padding: const EdgeInsets.only(bottom: 40), children: _buildContentList(context, profile))
            else
              const Center(child: CircularProgressIndicator()),
            if (_overlayIcon != null) _buildAnimationOverlay(),
            if (_showTutorialOverlay) _buildTutorialOverlay(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    List<Widget> actions = [];
    if (_isMyProfile) {
      actions.add(IconButton(icon: const Icon(Icons.edit), onPressed: _editProfile));
    }
    return actions;
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (_isProcessing) return;
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 2) {
      _dislikeUser();
    } else {
      _likeUser();
    }
  }

  Widget _buildAnimationOverlay() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - _animation.value,
          child: Transform.scale(
            scale: 1.0 + (_animation.value * 0.5),
            child: Icon(_overlayIcon, color: _overlayIconColor, size: 150),
          ),
        );
      },
    );
  }

  Widget _buildTutorialOverlay() {
    return GestureDetector(
      onTap: _dismissTutorial,
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            _buildTutorialSection(isLeft: true, icon: Icons.heart_broken_outlined, textSpans: [const TextSpan(text: 'double tap this side to TRASH this profile.. '), const TextSpan(text: 'Daaymn', style: TextStyle(fontFamily: 'Pacifico')), const TextSpan(text: ' Savage')]),
            _buildTutorialSection(isLeft: false, icon: Icons.favorite_border, textSpans: [const TextSpan(text: 'double tap this side to show your LOVE interest.. | '), const TextSpan(text: 'Daaymn!', style: TextStyle(fontFamily: 'Pacifico')), const TextSpan(text: ' Keep going!')]),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialSection({required bool isLeft, required IconData icon, required List<TextSpan> textSpans}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final semiCircleHeight = screenWidth * 0.99;

    return Expanded(
      child: Center(
        child: Container(
          width: screenWidth / 2,
          height: semiCircleHeight,
          decoration: BoxDecoration(
            color: const Color(0xB2000000),
            borderRadius: isLeft ? BorderRadius.only(topRight: Radius.circular(semiCircleHeight / 2), bottomRight: Radius.circular(semiCircleHeight / 2)) : BorderRadius.only(topLeft: Radius.circular(semiCircleHeight / 2), bottomLeft: Radius.circular(semiCircleHeight / 2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, color: Colors.white, size: 60), const SizedBox(height: 16), Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: RichText(textAlign: TextAlign.center, text: TextSpan(style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.3), children: textSpans)))]
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentList(BuildContext context, Profile profile) {
    final items = <Widget>[];
    final dislikeCount = widget.dislikeCounts?[profile.id] ?? 0;

    if (profile.imageUrl != null && profile.imageUrl!.isNotEmpty) {
      items.add(_buildStyledImageWithDislikeCount(profile.imageUrl!, dislikeCount));
    }
    items.add(_buildDetailsSection(context, profile));

    final remainingPhotos = profile.imageUrls.skip(1).toList();
    final bioTopics = profile.bioTopics.entries.toList();
    int photoIndex = 0;
    int topicIndex = 0;

    while (photoIndex < remainingPhotos.length || topicIndex < bioTopics.length) {
      if (topicIndex < bioTopics.length) {
        items.add(_buildBioTopicCard(bioTopics[topicIndex++]));
      }
      if (photoIndex < remainingPhotos.length) {
        items.add(_buildStyledImage(remainingPhotos[photoIndex++]));
      }
    }

    return items;
  }

  Widget _buildStyledImage(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            placeholder: (context, url) => Container(color: Colors.grey[800]),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.person, size: 80, color: Colors.white30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledImageWithDislikeCount(String imageUrl, int dislikeCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Center(
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.6,
                alignment: Alignment.center,
                placeholder: (context, url) => Container(color: Colors.grey[800]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[800],
                  child: const Icon(Icons.person, size: 80, color: Colors.white30),
                ),
              ),
            ),
            if (dislikeCount > 0)
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(178),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                      children: [
                        const TextSpan(text: 'Daaymn', style: TextStyle(fontFamily: 'Pacifico')),
                        TextSpan(text: ' Dislike Count: $dislikeCount!'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatHeight(double cm, String system) {
    if (system == 'Imperial') {
      final inches = cm / 2.54;
      final feet = inches / 12;
      final remainingInches = inches % 12;
      return "${feet.floor()}'${remainingInches.round()}\"";
    } else {
      return '${cm.toStringAsFixed(0)} cm';
    }
  }

  String _formatWeight(double kg, String system) {
    if (system == 'Imperial') {
      final lbs = kg * 2.20462;
      return '${lbs.round()} lbs';
    } else {
      return '${kg.toStringAsFixed(0)} kg';
    }
  }

  Widget _buildDetailsSection(BuildContext context, Profile profile) {
    final metricSystem = _viewingUser?.metricSystem ?? 'Metric';

    final rows = <TableRow>[
      _buildInfoRow(context, Icons.cake_outlined, 'Age', profile.age.toString()),
      _buildInfoRow(context, Icons.transgender, 'Gender', profile.gender),
      _buildInfoRow(context, Icons.tag_faces, 'Pronouns', profile.pronouns),
      _buildInfoRow(context, Icons.group, 'Ethnicity', profile.ethnicity),
      if (profile.dominantHand?.show ?? false)
        _buildInfoRow(context, Icons.pan_tool_outlined, 'Dominant Hand', profile.dominantHand!.value),
      if (profile.devicePreference?.show ?? false)
        _buildInfoRow(context, Icons.devices, 'Device Preference', profile.devicePreference!.value),
      if (profile.work?.show ?? false) _buildInfoRow(context, Icons.work_outline, 'Work', profile.work!.value),
      if (profile.religion?.show ?? false)
        _buildInfoRow(context, Icons.church_outlined, 'Religion', profile.religion!.value),
      if (profile.heightCm?.show ?? false)
        _buildInfoRow(context, Icons.height, 'Height', _formatHeight(profile.heightCm!.value, metricSystem)),
      if (profile.weightKg?.show ?? false)
        _buildInfoRow(context, Icons.scale, 'Weight', _formatWeight(profile.weightKg!.value, metricSystem)),
    ].where((row) => row.children.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
              text: TextSpan(style: Theme.of(context).textTheme.headlineSmall, children: [
            TextSpan(text: "${profile.name}'s "),
            const TextSpan(text: 'Daaymn', style: TextStyle(fontFamily: 'Pacifico')),
            const TextSpan(text: ' Details')
          ])),
          const Divider(),
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: IntrinsicColumnWidth(),
              2: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: rows,
          ),
        ],
      ),
    );
  }

  Widget _buildBioTopicCard(MapEntry<String, String> topic) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(topic.key, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 8), Text(topic.value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold))],
        ),
      ),
    );
  }

  TableRow _buildInfoRow(BuildContext context, IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const TableRow(children: [SizedBox.shrink(), SizedBox.shrink(), SizedBox.shrink()]);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
