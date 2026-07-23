import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:daaymn/cryptography_service.dart' as crypto_service;
import 'package:daaymn/notification_provider.dart';
import 'package:daaymn/otm.dart';
import 'package:daaymn/profile_detail_screen.dart';
import 'package:daaymn/services/message_cache_service.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:daaymn/tutorial_overlay.dart';
import 'package:daaymn/tutorial_service.dart';
import 'package:daaymn/widgets/online_indicator.dart';
import 'package:daaymn/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'globals.dart';

// Data class for outgoing likes
class LikedProfile {
  final Profile profile;
  final DateTime likedAt;
  int superLikeLevel;
  bool isExpanded;

  LikedProfile({
    required this.profile,
    required this.likedAt,
    required this.superLikeLevel,
    this.isExpanded = false,
  });

  LikedProfile copyWith({Profile? profile}) {
    return LikedProfile(
      profile: profile ?? this.profile,
      likedAt: likedAt,
      superLikeLevel: superLikeLevel,
      isExpanded: isExpanded,
    );
  }
}

class YourLikesScreen extends StatefulWidget {
  final VoidCallback showOutOfLikesDialog;
  const YourLikesScreen({super.key, required this.showOutOfLikesDialog});

  @override
  State<YourLikesScreen> createState() => _YourLikesScreenState();
}

class _YourLikesScreenState extends State<YourLikesScreen> {
  List<LikedProfile> _likedProfiles = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, TextEditingController> _messageControllers = {};

  final TutorialService _tutorialService = TutorialService();
  static const String _pageKey = 'your_likes';
  List<ShowcaseItem>? _showcaseItems;
  int _currentShowcaseStep = -1;

  RealtimeChannel? _profileSubscription;

  final _superLikeKey = GlobalKey();
  final _messageBoxKey = GlobalKey();
  final _timerKey = GlobalKey();
  final crypto_service.CryptographyService _cryptographyService = crypto_service.CryptographyService();
  final OtmService _otmService = OtmService();
  final MessageCacheService _messageCache = serviceLocator.messageCache;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupProfileSubscription();
  }

  @override
  void dispose() {
    _profileSubscription?.unsubscribe();
    for (final controller in _messageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setupProfileSubscription() {
    _profileSubscription = supabase.channel('public:profiles').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'profiles',
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          final updatedProfile = Profile.fromJson(payload.newRecord);
          if (mounted) {
            setState(() {
              final index = _likedProfiles
                  .indexWhere((p) => p.profile.id == updatedProfile.id);
              if (index != -1) {
                _likedProfiles[index] =
                    _likedProfiles[index].copyWith(profile: updatedProfile);
              }
            });
          }
        }
      },
    ).subscribe();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    if (_likedProfiles.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

      // 1. Get IDs of users YOU have liked that are still active
      final myLikesResponse = await supabase
          .from('likes')
          .select('liked_user_id, created_at, super_like_level')
          .eq('user_id', currentUserId)
          .gte('created_at', threeDaysAgo); // Server-side filter to reduce payload

      final myLikedIds = myLikesResponse.map((e) => e['liked_user_id'].toString()).toSet();

      if (myLikedIds.isEmpty) {
        if (mounted) {
          setState(() {
            _likedProfiles = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Get IDs of users who have liked YOU (who are matches)
      final otherLikesResponse = await supabase
          .from('likes')
          .select('user_id')
          .eq('liked_user_id', currentUserId)
          .inFilter('user_id', myLikedIds.toList());
          
      final otherLikedIds = otherLikesResponse.map((e) => e['user_id'].toString()).toSet();

      // 3. Filter out the matches to get only one-sided likes
      final profilesToShowIds = myLikedIds.difference(otherLikedIds).toList();

      if (profilesToShowIds.isEmpty) {
        if (mounted) {
          setState(() {
            _likedProfiles = [];
            _isLoading = false;
          });
        }
        return;
      }
      
      final profilesResponse = await supabase.from('profiles').select().inFilter('id', profilesToShowIds);
      final profiles = profilesResponse.map((data) => Profile.fromJson(data)).toList();

      final List<LikedProfile> myLikes = [];
      final likesDataForNonMatches = myLikesResponse.where((like) => profilesToShowIds.contains(like['liked_user_id']));

      for (var like in likesDataForNonMatches) {
        try {
          final profile = profiles.firstWhere((p) => p.id == like['liked_user_id'].toString());
          final likedAt = DateTime.parse(like['created_at']);

          // FINAL FIX: This precise check ensures no expired profiles are ever added to the list.
          if (likedAt.add(const Duration(days: 3)).isAfter(DateTime.now())) {
            myLikes.add(LikedProfile(
              profile: profile,
              likedAt: likedAt,
              superLikeLevel: like['super_like_level'] ?? 0,
            ));
          }
        } catch (e) { /* Safely skip */ }
      }

      if (mounted) {
        setState(() {
          _likedProfiles = myLikes;
          _isLoading = false;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowTutorial());
      }
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _checkAndShowTutorial() async {
    if (!mounted || _likedProfiles.isEmpty) return;

    final shouldShow = await _tutorialService.shouldShowTutorial(_pageKey);
    if (shouldShow) {
      _setupShowcase();
      setState(() => _currentShowcaseStep = 0);
    }
  }

  void _setupShowcase() {
    _showcaseItems = [
      ShowcaseItem(key: _superLikeKey, description: 'Spend your likes here. Fill up the heart to send a Daaymn OTM (One-Time-Message)!', shape: const CircleBorder()),
      ShowcaseItem(key: _messageBoxKey, description: 'Once you fill up the Daaymn likes, your message box will appear here!', shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
      ShowcaseItem(key: _timerKey, description: "This is how long the profile will stay in your likes list! Don't waste your Daaymn time!", shape: const CircleBorder()),
    ];
  }

  void _nextShowcaseStep() {
    if (_showcaseItems == null) return;
    if (_currentShowcaseStep + 1 < _showcaseItems!.length) {
      setState(() => _currentShowcaseStep++);
    } else {
      _tutorialService.markTutorialAsSeen(_pageKey);
      setState(() => _currentShowcaseStep = -1);
    }
  }

  Future<void> _handleLikeExpired(String likedUserId) async {
    final currentUserId = supabase.auth.currentUser!.id;
    try {
      // Atomically delete both the like and the notification
      await supabase.rpc('handle_expired_like', params: {
        'p_user_id': currentUserId,
        'p_liked_user_id': likedUserId
      });

      if (mounted) {
        context.read<NotificationProvider>().refresh();
        setState(() {
          _likedProfiles.removeWhere((lp) => lp.profile.id == likedUserId);
        });
      }
    } catch (e) {
      // silent error
    }
  }

  Future<void> _incrementSuperLike(LikedProfile likedProfile) async {
    if (likedProfile.superLikeLevel >= 5) return;
    try {
      final newLevel = await supabase.rpc('increment_super_like', params: {'p_liked_user_id': likedProfile.profile.id}) as int;
      if (mounted) {
        setState(() {
          likedProfile.superLikeLevel = newLevel;
          if (newLevel >= 5) likedProfile.isExpanded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('insufficient likes')) {
          widget.showOutOfLikesDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _sendMessage(LikedProfile likedProfile) async {
    final controller = _messageControllers[likedProfile.profile.id];
    if (controller == null || controller.text.trim().isEmpty) return;
    final content = controller.text.trim();
    try {
      final otherUserResponse = await supabase.from('profiles').select('public_key').eq('id', likedProfile.profile.id).single();
      final otherUserPublicKeyString = otherUserResponse['public_key'] as String?;
      if (otherUserPublicKeyString == null || otherUserPublicKeyString.isEmpty) {
        throw Exception('This user cannot receive encrypted messages yet.');
      }
      final otherUserPublicKey = _cryptographyService.publicKeyFromPem(otherUserPublicKeyString);
      final encryptedContent = _cryptographyService.encryptString(content, otherUserPublicKey);
      if (encryptedContent == null) {
        throw Exception('Failed to encrypt message.');
      }
      
      final sentOtm = await _otmService.sendOtm(receiverId: likedProfile.profile.id, encryptedContent: encryptedContent);
      // FIX: Convert int ID to String for cache key
      await _messageCache.cacheMessage(sentOtm.id.toString(), content);

      await supabase.rpc('reset_super_like', params: {'p_liked_user_id': likedProfile.profile.id});

      if (mounted) {
        // CORRECTED: Reset the state of the card instead of removing it.
        setState(() {
          final profileIndex = _likedProfiles.indexWhere((p) => p.profile.id == likedProfile.profile.id);
          if (profileIndex != -1) {
            _likedProfiles[profileIndex].superLikeLevel = 0;
            _likedProfiles[profileIndex].isExpanded = false;
          }
        });
        controller.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your Daaymn OTM has been sent!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending message: ${e.toString()}')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Your Likes', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchData,
            child: Stack(
              children: [
                _buildBody(),
                if (_showcaseItems != null && _currentShowcaseStep != -1)
                  TutorialOverlay(
                    items: _showcaseItems!,
                    currentStep: _currentShowcaseStep,
                    onNext: _nextShowcaseStep,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!)));
    if (_likedProfiles.isEmpty) {
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
                "Your likes are looking a little empty. Get out there and say ‘Daaymn!’ to someone.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return _buildLikedProfilesList();
  }

  Widget _buildLikedProfilesList() {
    return ListView.builder(
      itemCount: _likedProfiles.length,
      itemBuilder: (context, index) {
        final likedProfile = _likedProfiles[index];
        final controller = _messageControllers.putIfAbsent(likedProfile.profile.id, () => TextEditingController());
        final isFirst = index == 0;
        final isOnline = likedProfile.profile.lastSeen != null && DateTime.now().difference(likedProfile.profile.lastSeen!).inMinutes < 5;
        return Card(
          key: ValueKey(likedProfile.profile.id), // FIX: Add unique key
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfileDetailScreen(profiles: _likedProfiles.map((p) => p.profile).toList(), startIndex: index))),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[800],
                        child: ClipOval(
                          child: (likedProfile.profile.imageUrl != null && likedProfile.profile.imageUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: likedProfile.profile.imageUrl!,
                                memCacheWidth: 180,
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                placeholder: (context, url) => Container(color: Colors.grey[800]),
                                errorWidget: (context, url, error) => const Icon(Icons.person, size: 28, color: Colors.white30),
                              )
                            : const Icon(Icons.person, size: 28, color: Colors.white30),
                        ),
                      ),
                    ),
                    Positioned(bottom: -10, child: _CountdownTag(key: isFirst ? _timerKey : null, likedAt: likedProfile.likedAt, onTimerEnd: () => _handleLikeExpired(likedProfile.profile.id))),
                  ],
                ),
                title: Row(
                  children: [
                    if (isOnline) const OnlineIndicator(size: 12),
                    const SizedBox(width: 8),
                    Text('${likedProfile.profile.name}, ${likedProfile.profile.age}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    VerifiedBadge(profile: likedProfile.profile, size: 14),
                  ],
                ),
                trailing: _buildTrailingWidget(likedProfile, key: isFirst ? _superLikeKey : null),
                onTap: () {
                  if (likedProfile.superLikeLevel >= 5) {
                    setState(() => likedProfile.isExpanded = !likedProfile.isExpanded);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProfileDetailScreen(profiles: _likedProfiles.map((p) => p.profile).toList(), startIndex: index)));
                  }
                },
              ),
              if (likedProfile.isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      TextField(controller: controller, decoration: const InputDecoration(hintText: 'Send your one-time message...', border: OutlineInputBorder()), maxLength: 280, maxLines: 3),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Send'),
                        onPressed: () => _sendMessage(likedProfile),
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                      )
                    ],
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrailingWidget(LikedProfile likedProfile, {Key? key}) {
    final level = likedProfile.superLikeLevel;
    if (level >= 5) {
      return Column(
        key: key,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, color: Colors.red),
          Text('5/5', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('Send Message', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      );
    }
    return InkWell(
      key: key,
      onTap: () => _incrementSuperLike(likedProfile),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, color: Colors.pinkAccent),
          Text('$level/5', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('Fill me up', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _CountdownTag extends StatefulWidget {
  final DateTime likedAt;
  final Function() onTimerEnd;
  const _CountdownTag({super.key, required this.likedAt, required this.onTimerEnd});
  @override
  State<_CountdownTag> createState() => _CountdownTagState();
}

class _CountdownTagState extends State<_CountdownTag> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.likedAt.add(const Duration(days: 3));
    _remaining = expiresAt.difference(DateTime.now());
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTimerEnd();
      });
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final newRemaining = expiresAt.difference(DateTime.now());
        if (newRemaining.isNegative) {
          setState(() => _remaining = Duration.zero);
          timer.cancel();
          widget.onTimerEnd();
        } else {
          setState(() => _remaining = newRemaining);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return Container();
    String timeText;
    final days = _remaining.inDays;
    if (days > 0) {
      timeText = '$days${days == 1 ? ' day' : ' days'} remaining';
    } else {
      final hours = _remaining.inHours;
      final minutes = _remaining.inMinutes.remainder(60);
      timeText = '${hours}h ${minutes}m remaining';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _remaining.inHours < 24 ? Colors.red.shade700 : Colors.black.withAlpha(179),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 0.5),
      ),
      child: Text(timeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
