import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:daaymn/chat_screen.dart';
import 'package:daaymn/cryptography_service.dart' as crypto_service;
import 'package:daaymn/services/message_cache_service.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:daaymn/theme_provider.dart';
import 'package:daaymn/tutorial_overlay.dart';
import 'package:daaymn/tutorial_service.dart';
import 'package:daaymn/widgets/online_indicator.dart';
import 'package:daaymn/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:provider/provider.dart';

import 'globals.dart';
import 'notification_provider.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TutorialService _tutorialService = TutorialService();
  static const String _pageKey = 'messages';

  int _currentShowcaseStep = -1;
  List<ShowcaseItem>? _showcaseItems;

  final _oneTimeHeaderKey = GlobalKey();
  final _matchesHeaderKey = GlobalKey();
  final _firstConversationKey = GlobalKey();

  final MessageCacheService _messageCache = serviceLocator.messageCache;
  final crypto_service.CryptographyService _cryptographyService = crypto_service.CryptographyService();
  pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>? _myKeyPair;
  bool _keysLoaded = false;

  StreamSubscription? _likesSubscription;
  StreamSubscription? _blocksSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
      _setupRealtimeListeners();
    });
  }

  @override
  void dispose() {
    _likesSubscription?.cancel();
    _blocksSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _setupKeys();
    if (mounted) {
      await context.read<MessageProvider>().fetchConversations();
      if (mounted) {
        _checkAndShowTutorial();
      }
    }
  }

  void _setupRealtimeListeners() {
    if (!mounted) return;
    final currentUserId = supabase.auth.currentUser!.id;

    void listener(payload) {
      if (mounted) {
        context.read<MessageProvider>().fetchConversations();
      }
    }

    _likesSubscription = supabase.from('likes').stream(primaryKey: ['id']).listen(listener);

    _blocksSubscription = supabase
        .from('blocks')
        .stream(primaryKey: ['id'])
        .eq('blocked_id', currentUserId)
        .listen(listener);
  }

  Future<void> _setupKeys() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      _myKeyPair = await _cryptographyService.getOrCreateKeyPair(currentUserId);
      if (mounted) {
        setState(() {
          _keysLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading crypto keys: $e");
      if (mounted) {
        setState(() {
          _keysLoaded = true; // Still allow UI to build
        });
      }
    }
  }

  Future<void> _checkAndShowTutorial() async {
    if (!mounted) return;

    final shouldShow = await _tutorialService.shouldShowTutorial(_pageKey);
    if (shouldShow && mounted) {
      final provider = context.read<MessageProvider>();
      final items = _generateShowcaseItems(provider);
      if (items.isNotEmpty) {
        setState(() {
          _showcaseItems = items;
          _currentShowcaseStep = 0;
        });
      }
    }
  }

  List<ShowcaseItem> _generateShowcaseItems(MessageProvider provider) {
    final items = <ShowcaseItem>[];
    if (provider.oneTimeConversations.isNotEmpty) {
      items.add(ShowcaseItem(
          key: _oneTimeHeaderKey,
          description: "Oh Daaymn! Someone sent you a One-Time Message! They spent their Daaymn likes to talk to you before you even matched.",
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))));
    }
    if (provider.matchedConversations.isNotEmpty) {
      items.add(ShowcaseItem(
          key: _matchesHeaderKey,
          description: "And here are your regular conversations. These are the people you've mutually liked and matched with.",
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))));
    }
    if (provider.oneTimeConversations.isNotEmpty || provider.matchedConversations.isNotEmpty) {
      items.add(ShowcaseItem(
          key: _firstConversationKey,
          description: "Tap on a conversation to open the chat and start talking!",
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)))));
    }
    return items;
  }

  void _endTutorial() {
    if (_currentShowcaseStep != -1) {
      _tutorialService.markTutorialAsSeen(_pageKey);
      if (mounted) {
        setState(() => _currentShowcaseStep = -1);
      }
    }
  }

  void _nextShowcaseStep() {
    if (!mounted || _showcaseItems == null) return;

    final nextStep = _currentShowcaseStep + 1;
    if (nextStep < _showcaseItems!.length) {
      final key = _showcaseItems![nextStep].key;
      if (key.currentContext != null) {
        setState(() => _currentShowcaseStep = nextStep);
      } else {
        _endTutorial();
      }
    } else {
      _endTutorial();
    }
  }

  Future<String> _getDecryptedSubtitle(Conversation conversation) async {
    final lastMessage = conversation.lastMessage;
    if (lastMessage == null) {
      return conversation.isMatch ? 'New Match!' : 'Sent you a message';
    }

    final currentUserId = supabase.auth.currentUser!.id;
    final isMe = lastMessage.senderId == currentUserId;

    if (isMe) {
      // FIX: Convert int ID to String for cache key
      final cachedContent = await _messageCache.getCachedMessage(lastMessage.id.toString());
      return 'You: ${cachedContent ?? '...'}'; // We don't decrypt our own messages for the subtitle
    }

    // Attempt to get from cache first
    // FIX: Convert int ID to String for cache key
    final cachedContent = await _messageCache.getCachedMessage(lastMessage.id.toString());
    if (cachedContent != null) {
      return cachedContent;
    }

    // If not cached, and keys aren't loaded, show loading
    if (!_keysLoaded || _myKeyPair == null) {
      return '[loading...]';
    }

    try {
      final decryptedContent = _cryptographyService.decryptString(lastMessage.content, _myKeyPair!.privateKey);
      if (decryptedContent != null) {
        // FIX: Convert int ID to String for cache key
        await _messageCache.cacheMessage(lastMessage.id.toString(), decryptedContent);
        return decryptedContent;
      } else {
        return '[Message is unreadable]';
      }
    } catch (e) {
      // FIX: Use toString() for safety in string interpolation
      debugPrint("Decryption failed for message ${lastMessage.id.toString()}: $e");
      return '[Message is unreadable]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = context.watch<MessageProvider>();

    return RefreshIndicator(
      onRefresh: messageProvider.fetchConversations,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Messages', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody(messageProvider)),
        ],
      ),
    );
  }

  Widget _buildBody(MessageProvider provider) {
    if (provider.isLoading && !_keysLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(provider.errorMessage!, textAlign: TextAlign.center)));
    }

    final hasConversations = provider.oneTimeConversations.isNotEmpty || provider.matchedConversations.isNotEmpty;
    if (!hasConversations) {
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
                "This is where the magic happens. Make a match to start a Daaymn good conversation.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final isTutorialActive = _currentShowcaseStep != -1;

    return Stack(
      children: [
        _buildListView(provider),
        if (isTutorialActive)
          TutorialOverlay(
            items: _showcaseItems!,
            currentStep: _currentShowcaseStep,
            onNext: _nextShowcaseStep,
          ),
      ],
    );
  }

  ListView _buildListView(MessageProvider provider) {
    return ListView(
      children: [
        if (provider.oneTimeConversations.isNotEmpty) ...[
          _buildSectionHeader('One-Time Messages', key: _oneTimeHeaderKey),
          for (int i = 0; i < provider.oneTimeConversations.length; i++)
            _buildConversationTile(provider.oneTimeConversations[i], provider, key: (i == 0) ? _firstConversationKey : null),
        ],
        if (provider.matchedConversations.isNotEmpty) ...[
          _buildSectionHeader('Matches', key: _matchesHeaderKey),
          for (int i = 0; i < provider.matchedConversations.length; i++)
            _buildConversationTile(provider.matchedConversations[i], provider, key: (provider.oneTimeConversations.isEmpty && i == 0) ? _firstConversationKey : null),
        ]
      ],
    );
  }

  Widget _buildSectionHeader(String title, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildConversationTile(Conversation conversation, MessageProvider provider, {Key? key}) {
    final user = conversation.otherUser;
    final isOnline = user.lastSeen != null && DateTime.now().difference(user.lastSeen!).inMinutes < 5;

    return ListTile(
      key: key,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            child: ClipOval(
              child: (user.imageUrl != null && user.imageUrl!.isNotEmpty) 
                ? CachedNetworkImage(
                    imageUrl: user.imageUrl!,
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
          Positioned(
            bottom: 0,
            right: 0,
            child: VerifiedBadge(profile: user, size: 16),
          )
        ],
      ),
      title: Row(
        children: [
          if (isOnline) const OnlineIndicator(size: 12),
          const SizedBox(width: 8),
          Text(user.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          VerifiedBadge(profile: user, size: 14),
        ],
      ),
      subtitle: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return FutureBuilder<String>(
            future: _getDecryptedSubtitle(conversation),
            builder: (context, snapshot) {
              String textToShow;
              if (snapshot.connectionState == ConnectionState.waiting) {
                textToShow = '...';
              } else if (snapshot.hasError) {
                textToShow = '[Error loading message]';
              } else {
                textToShow = snapshot.data ?? '';
              }

              final isDarkMode = Theme.of(context).brightness == Brightness.dark;
              final color = (isDarkMode && !themeProvider.isDaaymnbow) ? Colors.white70 : Colors.black87;

              return Text(
                textToShow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              );
            },
          );
        },
      ),
      trailing: conversation.unreadCount > 0
          ? CircleAvatar(radius: 12, backgroundColor: Theme.of(context).colorScheme.primary, child: Text(conversation.unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)))
          : null,
      onTap: () async {
        final conversationMessage = conversation.isOtm ? conversation.lastMessage : null;
        final navigator = Navigator.of(context);
        await navigator.push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUser: user,
              isOtm: conversation.isOtm,
              isMatch: conversation.isMatch,
              initialMessage: conversationMessage,
            ),
          ),
        );

        if (mounted) {
          provider.fetchConversations();
        }
      },
    );
  }
}
