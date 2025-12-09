
import 'dart:async';
import 'package:daaymn/notification_provider.dart';
import 'package:daaymn/profile_detail_screen.dart';
import 'package:daaymn/tutorial_overlay.dart';
import 'package:daaymn/tutorial_service.dart';
import 'package:daaymn/widgets/profile_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'globals.dart';

class LikedYouScreen extends StatefulWidget {
  final VoidCallback showOutOfLikesDialog;

  const LikedYouScreen({
    super.key,
    required this.showOutOfLikesDialog,
  });

  @override
  State<LikedYouScreen> createState() => _LikedYouScreenState();
}

class _LikedYouScreenState extends State<LikedYouScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Profile> _likingProfiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ---- NEW: Real-time subscriptions ----
  StreamSubscription? _incomingLikesSubscription;
  StreamSubscription? _myLikesSubscription;
  StreamSubscription? _dislikesSubscription;
  StreamSubscription? _blocksSubscription;

  final TutorialService _tutorialService = TutorialService();
  static const String _pageKey = 'liked_you_v3';
  List<ShowcaseItem>? _showcaseItems;
  int _currentShowcaseStep = -1;

  final _profileCardKey = GlobalKey();
  final _acceptKey = GlobalKey();
  final _rejectKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupRealtimeListeners(); // Listen for remote changes
  }

  @override
  void dispose() {
    // ---- NEW: Cancel subscriptions ----
    _incomingLikesSubscription?.cancel();
    _myLikesSubscription?.cancel();
    _dislikesSubscription?.cancel();
    _blocksSubscription?.cancel();
    super.dispose();
  }

  // ---- NEW: Set up listeners for remote unmatches/blocks ----
  void _setupRealtimeListeners() {
    if (!mounted) return;
    final currentUserId = supabase.auth.currentUser!.id;

    void listener(payload) {
      if (mounted) {
        _fetchData(); // Refetch data on any change
      }
    }

    // Listen for changes in likes, dislikes, and blocks that could affect this list.
    _incomingLikesSubscription = supabase.from('likes').stream(primaryKey: ['id']).eq('liked_user_id', currentUserId).listen(listener);
    _myLikesSubscription = supabase.from('likes').stream(primaryKey: ['id']).eq('user_id', currentUserId).listen(listener);
    _dislikesSubscription = supabase.from('dislikes').stream(primaryKey: ['id']).eq('user_id', currentUserId).listen(listener);
    _blocksSubscription = supabase.from('blocks').stream(primaryKey: ['id']).listen(listener);
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    if (_likingProfiles.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final responses = await Future.wait([
        supabase.from('blocks').select('blocked_id').eq('blocker_id', currentUserId),
        supabase.from('dislikes').select('disliked_user_id').eq('user_id', currentUserId),
        supabase.from('likes').select('liked_user_id').eq('user_id', currentUserId),
        supabase.from('likes').select('user_id').eq('liked_user_id', currentUserId), // Who liked me
      ]);

      final blockedUserIds = (responses[0] as List).map((e) => e['blocked_id'].toString()).toSet();
      final dislikedUserIds = (responses[1] as List).map((e) => e['disliked_user_id'].toString()).toSet();
      final myLikedIds = (responses[2] as List).map((e) => e['liked_user_id'] as String).toSet();
      final incomingLikeIds = (responses[3] as List).map((e) => e['user_id'] as String).toSet();

      final profilesToShowIds = incomingLikeIds
          .difference(myLikedIds)
          .difference(blockedUserIds)
          .difference(dislikedUserIds)
          .toList();

      if (profilesToShowIds.isEmpty) {
        if (mounted) {
          setState(() {
            _likingProfiles = [];
            _isLoading = false;
          });
        }
        return;
      }

      final profilesResponse = await supabase.from('profiles').select().inFilter('id', profilesToShowIds);

      if (mounted) {
        final profiles = (profilesResponse as List).map((data) => Profile.fromJson(data)).toList();

        setState(() {
          _likingProfiles = profiles;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTutorial());
      }

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

  Future<void> _checkAndShowTutorial() async {
    if (!mounted || _likingProfiles.isEmpty) return;

    final shouldShow = await _tutorialService.shouldShowTutorial(_pageKey);
    if (shouldShow) {
        if(mounted) {
          final items = _setupShowcase();
          if (items.first.key.currentContext != null) {
            setState(() {
              _showcaseItems = items;
              _currentShowcaseStep = 0;
            });
          }
        }
    }
  }

  List<ShowcaseItem> _setupShowcase() {
    return [
      ShowcaseItem(
        key: _profileCardKey,
        description: "Someone thinks you're Daaymn fine! Tap the card to check out their full profile.",
      ),
      ShowcaseItem(
        key: _acceptKey,
        description: "Think they're Daaymn fine too? Like them back and see if it’s a match!",
        shape: const CircleBorder(),
      ),
      ShowcaseItem(
        key: _rejectKey,
        description: "Not a Daaymn chance? Send them to the depths by clicking this icon.",
        shape: const CircleBorder(),
      ),
    ];
  }


  void _nextShowcaseStep() {
    if (_showcaseItems != null && _currentShowcaseStep + 1 < _showcaseItems!.length) {
      setState(() => _currentShowcaseStep++);
    } else {
      _tutorialService.markTutorialAsSeen(_pageKey);
      setState(() => _currentShowcaseStep = -1);
    }
  }

  Future<void> _acceptLike(String otherUserId) async {
    if (!mounted) return;

    final profileIndex = _likingProfiles.indexWhere((profile) => profile.id == otherUserId);
    if (profileIndex == -1) return;

    try {
      await supabase.rpc('accept_like', params: {
        'p_other_user_id': otherUserId,
      });

      if(mounted) {
        setState(() {
          _likingProfiles.removeAt(profileIndex);
        });
        context.read<NotificationProvider>().refresh();
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('insufficient likes')) {
          widget.showOutOfLikesDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not create match: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
          _fetchData();
        }
      }
    }
  }

  Future<void> _rejectLike(String otherUserId) async {
    if (!mounted) return;
    final currentUserId = supabase.auth.currentUser!.id;

    final profileIndex = _likingProfiles.indexWhere((profile) => profile.id == otherUserId);
    if (profileIndex == -1) return;
    final removedProfile = _likingProfiles[profileIndex];

    setState(() {
      _likingProfiles.removeAt(profileIndex);
    });

    try {
      await Future.wait([
        supabase.from('likes').delete().match({
          'user_id': otherUserId,
          'liked_user_id': currentUserId,
        }),
        supabase.from('dislikes').insert({
          'user_id': currentUserId,
          'disliked_user_id': otherUserId,
        })
      ]);

      if(mounted) context.read<NotificationProvider>().refresh();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not reject like: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
        setState(() {
          _likingProfiles.insert(profileIndex, removedProfile);
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Liked You', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!)));
    }

    if (_likingProfiles.isEmpty) {
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
                "Nobody’s said ‘Daaymn!’ yet. Once they do, you’ll find them here.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          itemCount: _likingProfiles.length,
          itemBuilder: (context, index) {
            final profile = _likingProfiles[index];
            final isFirst = index == 0;

            return ProfileCard(
              key: isFirst ? _profileCardKey : null,
              profile: profile,
              likeKey: isFirst ? _acceptKey : null,
              dislikeKey: isFirst ? _rejectKey : null,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileDetailScreen(
                      profiles: _likingProfiles,
                      startIndex: index,
                      dislikeCounts: const {},
                    ),
                  ),
                );
              },
              onLike: () => _acceptLike(profile.id),
              onDislike: () => _rejectLike(profile.id),
            );
          },
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
}
