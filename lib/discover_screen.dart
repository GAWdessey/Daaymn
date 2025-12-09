
import 'dart:async';
import 'dart:math';
import 'package:daaymn/buy_likes_screen.dart';
import 'package:daaymn/cryptography_service.dart' as crypto_service;
import 'package:daaymn/globals.dart';
import 'package:daaymn/profile_detail_screen.dart';
import 'package:daaymn/tutorial_overlay.dart';
import 'package:daaymn/tutorial_service.dart';
import 'package:daaymn/widgets/profile_card.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A marker class for the paywall card in the list
class _PaywallMarker {}

class DiscoverScreen extends StatefulWidget {
  final Profile userProfile;
  final VoidCallback showOutOfLikesDialog;

  const DiscoverScreen({
    super.key,
    required this.userProfile,
    required this.showOutOfLikesDialog,
  });

  @override
  State<DiscoverScreen> createState() => DiscoverScreenState();
}

class DiscoverScreenState extends State<DiscoverScreen> with AutomaticKeepAliveClientMixin<DiscoverScreen> {
  List<Profile> _profiles = [];
  Map<String, int> _dislikeCounts = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isReviewingDislikes = false;

  RangeValues _ageRange = const RangeValues(18, 65);
  String _selectedPronouns = 'All';
  String _selectedEthnicity = 'All';

  final TutorialService _tutorialService = TutorialService();
  static const String _discoverPageKey = 'discover_v2';
  static const String _reviewDislikesPageKey = 'review_dislikes_v1';

  List<ShowcaseItem>? _showcaseItems;
  int _currentShowcaseStep = -1;
  bool _hasAttemptedTutorialStart = false;

  RealtimeChannel? _profileSubscription;
  late final FixedExtentScrollController _scrollController;

  final _preferencesKey = GlobalKey();
  final _refreshKey = GlobalKey();
  final _profileCardKey = GlobalKey();
  final _dislikeKey = GlobalKey();
  final _likeKey = GlobalKey();
  final _verifiedBadgeKey = GlobalKey();
  final _dislikeCounterKey = GlobalKey();
  final crypto_service.CryptographyService _cryptographyService = crypto_service.CryptographyService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController();
    _ensureEncryptionKeys().then((_) {
      _loadPreferences().then((_) {
        fetchProfiles();
        _setupProfileSubscription();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _profileSubscription?.unsubscribe();
    super.dispose();
  }
  
  void _setupProfileSubscription() {
    _profileSubscription = supabase
        .channel('public:profiles')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          final updatedProfile = Profile.fromJson(payload.newRecord);
          if (mounted) {
            setState(() {
              final index = _profiles.indexWhere((p) => p.id == updatedProfile.id);
              if (index != -1) {
                _profiles[index] = updatedProfile;
              }
            });
          }
        }
      },
    )
        .subscribe();
  }

  Future<void> _checkAndShowTutorial(List<Profile> newProfiles) async {
    if (!mounted || _hasAttemptedTutorialStart || newProfiles.isEmpty) {
      return;
    }

    _hasAttemptedTutorialStart = true;
    final shouldShow = await _tutorialService.shouldShowTutorial(_discoverPageKey);

    if (shouldShow && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final showcaseItems = _setupShowcase();
        // Ensure all keys have a context before starting.
        if (showcaseItems.every((item) => item.key.currentContext != null)) {
          setState(() {
            _showcaseItems = showcaseItems;
            _currentShowcaseStep = 0;
          });
        } 
      });
    }
  }

  Future<void> _checkAndShowReviewDislikesTutorial(List<Profile> newProfiles) async {
    if (!mounted || newProfiles.isEmpty) return;

    final shouldShow = await _tutorialService.shouldShowTutorial(_reviewDislikesPageKey);
    if (shouldShow && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final showcaseItems = _setupReviewDislikesShowcase();
        if (showcaseItems.every((item) => item.key.currentContext != null)) {
          setState(() {
            _showcaseItems = showcaseItems;
            _currentShowcaseStep = 0;
          });
        }
      });
    }
  }

  Future<void> _ensureEncryptionKeys() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final userProfile = await supabase.from('profiles').select('public_key').eq('id', currentUser.id).single();

      final publicKey = userProfile['public_key'] as String?;

      if (publicKey == null || publicKey.isEmpty) {
        final keyPair = await _cryptographyService.createKeyPair();
        await _cryptographyService.storeKeyPair(currentUser.id, keyPair);
        final publicKeyPem = _cryptographyService.encodePublicKeyToPem(keyPair.publicKey);
        await supabase.from('profiles').update({'public_key': publicKeyPem}).eq('id', currentUser.id);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ageRange = RangeValues(prefs.getDouble('discover_age_start') ?? 18, prefs.getDouble('discover_age_end') ?? 65);
        _selectedPronouns = prefs.getString('discover_pronouns') ?? 'All';
        _selectedEthnicity = prefs.getString('discover_ethnicity') ?? 'All';
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('discover_age_start', _ageRange.start);
    await prefs.setDouble('discover_age_end', _ageRange.end);
    await prefs.setString('discover_pronouns', _selectedPronouns);
    await prefs.setString('discover_ethnicity', _selectedEthnicity);
  }

  Future<void> fetchProfiles() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isReviewingDislikes = false;
    });

    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final likesResponse = await supabase.from('likes').select('liked_user_id').eq('user_id', currentUserId);
      final likedUserIds = likesResponse.map((e) => e['liked_user_id'].toString()).toSet();

      final dislikesResponse = await supabase.from('dislikes').select('disliked_user_id').eq('user_id', currentUserId);
      final dislikedUserIds = dislikesResponse.map((e) => e['disliked_user_id'].toString()).toSet();

      final myBlocksResponse = await supabase.from('blocks').select('blocked_id').eq('blocker_id', currentUserId);
      final myBlockedIds = myBlocksResponse.map((e) => e['blocked_id'].toString()).toSet();

      final otherBlocksResponse = await supabase.from('blocks').select('blocker_id').eq('blocked_id', currentUserId);
      final whoBlockedMeIds = otherBlocksResponse.map((e) => e['blocker_id'].toString()).toSet();

      final interactedUserIds = {...likedUserIds, ...dislikedUserIds, ...myBlockedIds, ...whoBlockedMeIds}.toList();

      var query = supabase.from('profiles').select().neq('id', currentUserId);

      if (interactedUserIds.isNotEmpty) {
        query = query.not('id', 'in', interactedUserIds);
      }

      final interestedIn = widget.userProfile.interestedIn;
      if (interestedIn != null && interestedIn.isNotEmpty && !interestedIn.contains('Everyone')) {
        query = query.filter('gender', 'in', interestedIn);
      }

      if (_selectedPronouns != 'All') query = query.eq('pronouns', _selectedPronouns);
      if (_selectedEthnicity != 'All') query = query.eq('ethnicity', _selectedEthnicity);
      query = query.gte('age', _ageRange.start.round()).lte('age', _ageRange.end.round());

      final response = await query;
      if (!mounted) return;

      final List<Profile> profiles = (response as List).map((data) => Profile.fromJson(data as Map<String, dynamic>)).toList();

      setState(() {
        _profiles = profiles;
        _isLoading = false;
        if (profiles.isEmpty && !_isReviewingDislikes) {
          _showReviewDislikesDialog();
        }
      });

      // Must be called after the list is populated and widgets are built.
      _checkAndShowTutorial(profiles);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  List<ShowcaseItem> _setupShowcase() {
    return [
      ShowcaseItem(
        key: _profileCardKey,
        description: 'Daaymn! Check out this profile. Tap it to see more pics and info.',
      ),
      ShowcaseItem(
        key: _verifiedBadgeKey,
        description: "See this orb? That's a Daaymn-verified user. They're legit!",
        shape: const CircleBorder(),
      ),
      ShowcaseItem(
        key: _likeKey,
        description: "See someone you like? That's a Daaymn fine choice! Hit the heart to make your move.",
        shape: const CircleBorder(),
      ),
      ShowcaseItem(
        key: _dislikeKey,
        description: "Not your type? No worries. Hit the X to pass. Plenty more Daaymn fish in the sea!",
        shape: const CircleBorder(),
      ),
      ShowcaseItem(
        key: _preferencesKey,
        description: 'Want to fine-tune your feed? Set your Daaymn preferences here.',
        shape: const CircleBorder(),
      ),
      ShowcaseItem(
        key: _refreshKey,
        description: 'Out of people? Hit refresh to see who else is out there. Daaymn!',
        shape: const CircleBorder(),
      ),
    ];
  }

  List<ShowcaseItem> _setupReviewDislikesShowcase() {
    return [
      ShowcaseItem(
        key: _profileCardKey,
        description: 'Second thoughts? Daaymn, it happens. Here are the profiles you passed on before.',
      ),
      ShowcaseItem(
        key: _dislikeCounterKey,
        description: "This shows how many times you've disliked this profile. After 10 dislikes, they're gone for good. Choose wisely!",
        shape: const StadiumBorder(),
      ),
      ShowcaseItem(
        key: _likeKey,
        description: "Changed your mind? Give them a Daaymn like! This will remove them from your dislikes.",
        shape: const CircleBorder(),
      ),
      ShowcaseItem(
        key: _dislikeKey,
        description: "Still not feeling it? Another dislike will push them further down the list.",
        shape: const CircleBorder(),
      ),
    ];
  }

  void _nextShowcaseStep() {
    final isReviewing = _isReviewingDislikes;
    final key = isReviewing ? _reviewDislikesPageKey : _discoverPageKey;

    if (_showcaseItems != null && _currentShowcaseStep + 1 < _showcaseItems!.length) {
      setState(() => _currentShowcaseStep++);
    } else {
      _tutorialService.markTutorialAsSeen(key);
      setState(() => _currentShowcaseStep = -1);
    }
  }

  Future<void> _fetchDislikedProfiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final dislikedResponse = await supabase
          .from('dislikes')
          .select('disliked_user_id, dislike_count')
          .eq('user_id', currentUserId)
          .lt('dislike_count', 10);

      if (!mounted) return;

      final dislikedUserIds = dislikedResponse.map((row) => row['disliked_user_id'] as String).toList();
      final dislikeCounts = {for (var row in dislikedResponse) row['disliked_user_id'] as String: row['dislike_count'] as int};

      if (dislikedUserIds.isEmpty) {
        setState(() {
          _profiles = [];
          _dislikeCounts = {};
          _isLoading = false;
          _isReviewingDislikes = true;
        });
        return;
      }

      var profilesQuery = supabase.from('profiles').select().inFilter('id', dislikedUserIds);

      final interestedIn = widget.userProfile.interestedIn;
      if (interestedIn != null && interestedIn.isNotEmpty && !interestedIn.contains('Everyone')) {
        profilesQuery = profilesQuery.filter('gender', 'in', interestedIn);
      }

      if (_selectedPronouns != 'All') profilesQuery = profilesQuery.eq('pronouns', _selectedPronouns);
      if (_selectedEthnicity != 'All') profilesQuery = profilesQuery.eq('ethnicity', _selectedEthnicity);
      profilesQuery = profilesQuery.gte('age', _ageRange.start.round()).lte('age', _ageRange.end.round());

      final profilesResponse = await profilesQuery;

      if (!mounted) return;

      final List<Profile> profiles = (profilesResponse as List).map((data) => Profile.fromJson(data as Map<String, dynamic>)).toList();

      setState(() {
        _profiles = profiles;
        _dislikeCounts = dislikeCounts;
        _isLoading = false;
        _isReviewingDislikes = true;
      });

      _checkAndShowReviewDislikesTutorial(profiles);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReviewDislikesDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          backgroundColor: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Daaymn', style: TextStyle(fontFamily: 'Pacifico', fontSize: 40, color: Colors.pinkAccent)),
                const SizedBox(height: 24),
                const Text('You are out of Daaymn people!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _fetchDislikedProfiles();
                  },
                  child: const Text('Review Dislikes?', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Maybe Later", style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _PreferencesDialog(
          initialAgeRange: _ageRange,
          initialPronouns: _selectedPronouns,
          initialEthnicity: _selectedEthnicity,
          onApply: (newAgeRange, newPronouns, newEthnicity) {
            setState(() {
              _ageRange = newAgeRange;
              _selectedPronouns = newPronouns;
              _selectedEthnicity = newEthnicity;
            });
            _savePreferences();
            fetchProfiles();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discover', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
                  Row(
                    children: [
                      IconButton(key: _preferencesKey, icon: const Icon(Icons.hourglass_empty, size: 28), onPressed: showPreferencesDialog),
                      IconButton(key: _refreshKey, icon: const Icon(Icons.refresh, size: 28), onPressed: fetchProfiles),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
        if (_showcaseItems != null && _currentShowcaseStep != -1)
          TutorialOverlay(
            items: _showcaseItems!,
            currentStep: _currentShowcaseStep,
            onNext: _nextShowcaseStep,
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Error: ${e.toString()}', style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: fetchProfiles, child: const Text('Retry'))
              ])));
    }
    if (_profiles.isEmpty && !_isReviewingDislikes) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Daaymn!',
                style: TextStyle(fontFamily: 'Pacifico', fontSize: 40, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Text(
                "You've seen everyone! Why not review your dislikes? You might have missed a Daaymn good one.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _showReviewDislikesDialog,
                child: const Text('Review your dislikes?'),
              ),
            ],
          ),
        ),
      );
    }
    if (_profiles.isEmpty && _isReviewingDislikes) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Daaymn!',
                style: TextStyle(fontFamily: 'Pacifico', fontSize: 40, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Text(
                "You've seen all your dislikes. Hit refresh to see who's new.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // UPDATED LOGIC HERE: Check for subscription OR a valid temporary reward.
    final bool hasInfiniteScroll = widget.userProfile.isSubscribed ||
        (widget.userProfile.infiniteScrollUntil != null &&
            widget.userProfile.infiniteScrollUntil!.isAfter(DateTime.now()));

    final List<dynamic> displayItems = [];
    if (!hasInfiniteScroll) {
      displayItems.addAll(_profiles.take(3));
      if (_profiles.length > 3) {
        displayItems.add(_PaywallMarker());
      }
    } else {
      displayItems.addAll(_profiles);
    }

    return ListWheelScrollView.useDelegate(
      controller: _scrollController,
      itemExtent: 500,
      physics: const FixedExtentScrollPhysics(),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: displayItems.length,
        builder: (context, index) {
          final item = displayItems[index];

          if (item is _PaywallMarker) {
            return const _PaywallCard();
          }

          final profile = item as Profile;

          return ProfileCard(
            key: index == 0 ? _profileCardKey : null,
            likeKey: index == 0 ? _likeKey : null,
            dislikeKey: index == 0 ? _dislikeKey : null,
            verifiedBadgeKey: index == 0 ? _verifiedBadgeKey : null,
            dislikeCounterKey: index == 0 ? _dislikeCounterKey : null,
            profile: profile,
            dislikeCount: _isReviewingDislikes ? _dislikeCounts[profile.id] : null,
            onTap: () async {
              final navigator = Navigator.of(context);
              final actionedIds = await navigator.push<List<String>>(
                MaterialPageRoute(
                  builder: (context) => ProfileDetailScreen(
                    profiles: _profiles,
                    startIndex: _profiles.indexWhere((p) => p.id == profile.id),
                    dislikeCounts: _dislikeCounts,
                    showOutOfLikesDialog: widget.showOutOfLikesDialog,
                  ),
                ),
              );

              if (mounted && actionedIds != null && actionedIds.isNotEmpty) {
                setState(() {
                  _profiles.removeWhere((p) => actionedIds.contains(p.id));
                });
              }
            },
            onLike: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final theme = Theme.of(context);
              try {
                await supabase.rpc('create_like_and_remove_dislike', params: {
                  'p_liked_user_id': profile.id,
                });
                if (mounted) {
                  setState(() {
                    _profiles.removeWhere((p) => p.id == profile.id);
                  });
                }
              } catch (e) {
                if (mounted) {
                  if (e.toString().contains('insufficient likes')) {
                    widget.showOutOfLikesDialog();
                  } else {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error liking profile: $e'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
            onDislike: () async {
              await supabase.rpc('increment_dislike', params: {
                'p_disliked_user_id': profile.id,
              });
              if (mounted) {
                setState(() {
                   _profiles.removeWhere((p) => p.id == profile.id);
                });
              }
            },
          );
        },
      ),
    );
  }
}

class _PaywallCard extends StatelessWidget {
  const _PaywallCard();

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey[900]!, Colors.grey[850]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Daaymn!',
                  style: TextStyle(fontFamily: 'Pacifico', fontSize: 40, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 16),
                Text(
                  "Like or pass on a profile to see the next one, or subscribe to unlock 'em all!",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuyLikesScreen()));
                  },
                  child: const Text('Unlock Infinite Scrolling', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ));
  }
}

class _PreferencesDialog extends StatefulWidget {
  final RangeValues initialAgeRange;
  final String initialPronouns;
  final String initialEthnicity;
  final Function(RangeValues, String, String) onApply;

  const _PreferencesDialog({
    required this.initialAgeRange,
    required this.initialPronouns,
    required this.initialEthnicity,
    required this.onApply,
  });

  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  late RangeValues _ageRange;
  late String _pronouns;
  late String _ethnicity;

  final List<String> _pronounOptions = ['All', 'he/him', 'she/her', 'they/them'];
  final List<String> _ethnicityOptions = [
    'All',
    'East Asian',
    'South & Southeast Asian',
    'African',
    'Hispanic / Latinx',
    'Middle Eastern & North African',
    'Native American / Indigenous',
    'Pacific Islander',
    'Caucasian',
    'Multiracial',
    'One for All',
    'All for One',
    'Prefer to self-describe',
    'Prefer not to say'
  ];

  @override
  void initState() {
    super.initState();
    _ageRange = widget.initialAgeRange;
    _pronouns = widget.initialPronouns;
    _ethnicity = widget.initialEthnicity;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Discovery Preferences', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              _buildDropdown('Pronouns', _pronouns, _pronounOptions, (val) => setState(() => _pronouns = val!)),
              const SizedBox(height: 16),
              _buildDropdown('Ethnicity', _ethnicity, _ethnicityOptions, (val) => setState(() => _ethnicity = val!)),
              const SizedBox(height: 20),
              _buildAgeRangeSlider(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      widget.onApply(
                        _ageRange,
                        _pronouns,
                        _ethnicity,
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAgeRangeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Age Range: ${_ageRange.start.round()} - ${_ageRange.end.round()}', style: const TextStyle(fontSize: 16)),
        RangeSlider(
          values: _ageRange,
          min: 18,
          max: 100,
          divisions: 82,
          labels: RangeLabels(_ageRange.start.round().toString(), _ageRange.end.round().toString()),
          onChanged: (values) => setState(() => _ageRange = values),
        ),
      ],
    );
  }
}
