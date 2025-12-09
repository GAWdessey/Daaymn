import 'dart:async';
import 'package:daaymn/cryptography_service.dart' as crypto_service;
import 'package:daaymn/daaymn_dialog.dart';
import 'package:daaymn/globals.dart';
import 'package:daaymn/notification_provider.dart';
import 'package:daaymn/otm.dart';
import 'package:daaymn/services/message_cache_service.dart';
import 'package:daaymn/services/service_locator.dart';
import 'package:daaymn/widgets/verified_badge.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final Profile otherUser;
  final bool isOtm;
  final bool isMatch;
  final Message? initialMessage;

  const ChatScreen({
    super.key,
    required this.otherUser,
    this.isOtm = false,
    this.isMatch = false,
    this.initialMessage,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final String _currentUserId;
  late final String _chatRoomId;
  List<Message> _messages = [];
  bool _isLoading = true;

  final MessageCacheService _messageCache = serviceLocator.messageCache;

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _typingChannel;

  bool _isOtherUserTyping = false;
  Timer? _typingIndicatorTimer;
  DateTime? _lastTypingSendTime;

  final crypto_service.CryptographyService _cryptographyService = crypto_service.CryptographyService();
  final OtmService _otmService = OtmService();
  pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey>? _myKeyPair;
  pc.RSAPublicKey? _otherUserPublicKey;
  bool _keysLoaded = false;
  String? _errorMessage;

  bool _isOtmReviewMode = false;
  bool _emojiShowing = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = supabase.auth.currentUser!.id;
    final userIds = [_currentUserId, widget.otherUser.id]..sort();
    _chatRoomId = 'chat_${userIds.join('_')}';

    _isOtmReviewMode = widget.isOtm && !widget.isMatch;

    _setupKeysAndInitialMessages();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _emojiShowing = false;
        });
      }
    });
    _textController.addListener(() {
      setState(() {
        _charCount = _textController.text.length;
      });
    });
  }

  Future<void> _setupKeysAndInitialMessages() async {
    await _setupKeys();
    if (_keysLoaded && mounted) {
      if (_isOtmReviewMode) {
        if (widget.initialMessage != null) {
          final decryptedMessage = await _decryptMessage(widget.initialMessage!);
          setState(() {
            _messages = [decryptedMessage];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        await _fetchInitialMessagesAndMarkAsRead();
        _setupMessageListener();
        _setupTypingListener();
      }
    }
  }

  @override
  void dispose() {
    if (_messageChannel != null) {
      supabase.removeChannel(_messageChannel!);
    }
    if (_typingChannel != null) {
      supabase.removeChannel(_typingChannel!);
    }
    _textController.dispose();
    _focusNode.dispose();
    _typingIndicatorTimer?.cancel();
    super.dispose();
  }

  void _setupMessageListener() {
    _messageChannel = supabase.channel('public:messages:$_chatRoomId');
    _messageChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) async {
        if (!mounted) return;

        if (payload.eventType == PostgresChangeEvent.insert) {
            final newMessage = Message.fromJson(payload.newRecord);
             if (mounted && newMessage.senderId == widget.otherUser.id) {
                final decryptedMessage = await _decryptMessage(newMessage);
                setState(() {
                  _messages.insert(0, decryptedMessage);
                });
                await _markMessageAsRead(newMessage.id);
             }
        } else if (payload.eventType == PostgresChangeEvent.update) {
            final updatedMessage = Message.fromJson(payload.newRecord);
            if (updatedMessage.senderId == _currentUserId) {
                 setState(() {
                    final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
                    if (index != -1) {
                        _messages[index] = _messages[index].copyWith(isRead: updatedMessage.isRead);
                    }
                });
            }
        }
      },
    ).subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('Chat message listener failed: $error');
        }
    });
  }

  void _setupTypingListener() {
    _typingChannel = supabase.channel('typing_status_listener_$_chatRoomId');
    _typingChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'typing_status',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'chat_room_id',
        value: _chatRoomId,
      ),
      callback: (payload) {
        final record = payload.newRecord;
        if (mounted && record['user_id'] != _currentUserId) {
          setState(() => _isOtherUserTyping = true);
          _typingIndicatorTimer?.cancel();
          _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _isOtherUserTyping = false);
          });
        }
      },
    ).subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('Typing listener failed: $error');
        }
    });
  }

  Future<void> _onTextChanged(String text) async {
    if (text.length > 500) {
      _textController.text = text.substring(0, 500);
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
    if (text.isNotEmpty) {
      final now = DateTime.now();
      if (_lastTypingSendTime == null || now.difference(_lastTypingSendTime!).inSeconds > 2) {
        try {
          await supabase.from('typing_status').upsert({
            'chat_room_id': _chatRoomId,
            'user_id': _currentUserId,
            'updated_at': now.toIso8601String(),
          });
          _lastTypingSendTime = now;
        } catch (e) {
          debugPrint('Error sending typing status: $e');
        }
      }
    }
  }

  Future<void> _setupKeys() async {
    try {
      _myKeyPair = await _cryptographyService.getOrCreateKeyPair(_currentUserId);

      final otherUserPublicKeyPem = await _cryptographyService.getPublicKey(widget.otherUser.id);
      if (otherUserPublicKeyPem == null) {
        throw Exception('Could not retrieve the public key for the other user.');
      }
      _otherUserPublicKey = _cryptographyService.publicKeyFromPem(otherUserPublicKeyPem);

      if (mounted) setState(() => _keysLoaded = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _keysLoaded = false;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Message> _decryptMessage(Message message) async {
    if (message.senderId == _currentUserId) {
      // FIX: Convert int ID to String for cache key
      final cachedContent = await _messageCache.getCachedMessage(message.id.toString());
      return message.copyWith(content: cachedContent ?? '[Message Sent]');
    }

    // FIX: Convert int ID to String for cache key
    final cachedDecryptedContent = await _messageCache.getCachedMessage(message.id.toString());
    if (cachedDecryptedContent != null) {
      return message.copyWith(content: cachedDecryptedContent);
    }

    if (message.content.isEmpty || !_keysLoaded || _myKeyPair == null) {
      return message.copyWith(content: '[Message not available]');
    }

    try {
      final decryptedContent = _cryptographyService.decryptString(message.content, _myKeyPair!.privateKey);

      if (decryptedContent == null) {
        return message.copyWith(content: '[Could not decrypt message]');
      }
      
      // FIX: Convert int ID to String for cache key
      await _messageCache.cacheMessage(message.id.toString(), decryptedContent);
      return message.copyWith(content: decryptedContent);

    } catch (e) {
      // FIX: Use toString() for safety in string interpolation
      debugPrint('Error decrypting message ${message.id.toString()}: $e');
      return message.copyWith(content: '[Could not decrypt message]');
    }
  }

  Future<void> _fetchInitialMessagesAndMarkAsRead() async {
    if (_isOtmReviewMode) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
          .or('sender_id.eq.${widget.otherUser.id},receiver_id.eq.${widget.otherUser.id}')
          .order('created_at', ascending: false)
          .limit(50);

      if (!mounted) return;

      final loadedMessages = (response as List).map((data) => Message.fromJson(data)).toList();

      final decryptedMessages = await Future.wait(loadedMessages.map((msg) => _decryptMessage(msg)).toList());

      if (mounted) {
        setState(() {
          _messages = decryptedMessages;
          _isLoading = false;
        });
      }

      final unreadMessageIds = decryptedMessages
          .where((msg) => msg.receiverId == _currentUserId && !msg.isRead)
          .map((msg) => msg.id)
          .toList();

      if (unreadMessageIds.isNotEmpty) {
        await supabase.from('messages').update({'is_read': true}).inFilter('id', unreadMessageIds);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load messages: ${e.toString()}";
        });
      }
    }
  }

  // FIX: Changed parameter type from String to int to match Message model
  Future<void> _markMessageAsRead(int messageId) async {
    try {
      await supabase.from('messages').update({'is_read': true}).eq('id', messageId);
    } catch (e) {
      if (kDebugMode) print('Error marking message as read: $e');
    }
  }

  // PASTE THIS ENTIRE METHOD INTO chat_screen.dart

  Future<void> _sendMessage() async {
    if (!_keysLoaded || _otherUserPublicKey == null) {
      await _showErrorDialog(_errorMessage ?? "Cannot send message: encryption keys are not set up.");
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final encryptedContent = _cryptographyService.encryptString(text, _otherUserPublicKey!);
    if (encryptedContent == null) {
      await _showErrorDialog('Failed to encrypt message.');
      return;
    }

    //
    // THIS IS THE FIX: Use a temporary NEGATIVE INTEGER for the optimistic UI.
    //
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final optimisticMessage = Message(
      id: tempId,
      senderId: _currentUserId,
      receiverId: widget.otherUser.id,
      content: text,
      createdAt: DateTime.now(),
      isRead: false, // Start as not read
      messageType: 'text',
      isOtm: _isOtmReviewMode,
    );

    if (mounted) {
      _textController.clear();
      setState(() => _messages.insert(0, optimisticMessage));
    }

    try {
      final response = await supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': widget.otherUser.id,
        'content': encryptedContent,
        'is_otm': _isOtmReviewMode,
      }).select();

      final sentMessage = Message.fromJson(response[0]);

      // FIX: Convert int ID to String for cache key
      await _messageCache.cacheMessage(sentMessage.id.toString(), text);

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _messages[index] = sentMessage.copyWith(content: text);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to send message: $e');
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == tempId));
        await _showErrorDialog('Could not send message.');
      }
    }
  }

  Future<void> _acceptOtm() async {
    if (widget.initialMessage == null) return;
    try {
      await _otmService.acceptOtm(widget.initialMessage!);
      if (mounted) {
        context.read<NotificationProvider>().refresh();
        await showDialog(
          context: context,
          builder: (context) => DaaymnDialog(
            title: "It's a Match!",
            message: 'You can now chat with ${widget.otherUser.name}.',
            buttonText: 'OK',
            onButtonPressed: () => Navigator.of(context).pop(),
          ),
        );
        setState(() {
          _isOtmReviewMode = false;
        });
        await _fetchInitialMessagesAndMarkAsRead();
        _setupMessageListener();
        _setupTypingListener();
      }
    } catch (e) {
      if (mounted) await _showErrorDialog('Error accepting match: ${e.toString()}');
    }
  }

  // PASTE THIS ENTIRE METHOD INTO chat_screen.dart

  // PASTE THIS ENTIRE METHOD INTO chat_screen.dart

  Future<void> _rejectOtm() async {
    if (widget.initialMessage == null) return;
    try {
      // THIS IS THE FINAL FIX:
      // We are now calling the dedicated, secure database function 'delete_otm'.
      // This function runs on the server and safely deletes the message
      // if the current user is the receiver, bypassing the RLS permission
      // issue that was causing the silent failure.
      await supabase.rpc('delete_otm', params: {
        'message_id_to_delete': widget.initialMessage!.id,
      });

      if(mounted) {
        context.read<NotificationProvider>().refresh();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) await _showErrorDialog('Error rejecting message: ${e.toString()}');
    }
  }

  Future<void> _unmatch() async {
    try {
      await supabase.rpc('unmatch_users', params: {
        'p_user_one_id': _currentUserId,
        'p_user_two_id': widget.otherUser.id,
      });
      
      if (!mounted) return;
      context.read<NotificationProvider>().refresh();

      await showDialog(
        context: context,
        builder: (dialogContext) => DaaymnDialog(
          title: 'Unmatched',
          message: 'You have unmatched with ${widget.otherUser.name}.',
          buttonText: 'OK',
          onButtonPressed: () {
            Navigator.of(dialogContext).pop();
          },
        ),
      );
      if (mounted) {
        Navigator.of(context).pop({'action': 'unmatch', 'userId': widget.otherUser.id});
      }
    } catch (e) {
      if (mounted) {
        await _showErrorDialog('Error unmatching: ${e.toString()}');
      }
    }
  }

  Future<void> _block() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (context) => DaaymnDialog(
            title: 'Block ${widget.otherUser.name}?',
            message:
                'This is permanent. It will delete your conversation, unmatch you, and prevent you from seeing each other again. Are you sure?',
            buttonText: 'Yes, Block Forever',
            onButtonPressed: () => Navigator.of(context).pop(true),
            secondButtonText: 'Cancel',
            onSecondButtonPressed: () => Navigator.of(context).pop(false),
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await supabase.rpc('nuke_connection', params: {
        'p_user_a_id': _currentUserId,
        'p_user_b_id': widget.otherUser.id,
      });

      final prefs = await SharedPreferences.getInstance();
      final blockedUsers = prefs.getStringList('blocked_users') ?? [];
      if (!blockedUsers.contains(widget.otherUser.id)) {
        blockedUsers.add(widget.otherUser.id);
        await prefs.setStringList('blocked_users', blockedUsers);
        if (kDebugMode) {
          print('Daaymn - User ${widget.otherUser.id} added to local block list.');
        }
      }

      if (!mounted) return;
      context.read<NotificationProvider>().refresh();

      await showDialog(
        context: context,
        builder: (dialogContext) => DaaymnDialog(
          title: 'Blocked',
          message: 'You have permanently blocked ${widget.otherUser.name}.',
          buttonText: 'OK',
          onButtonPressed: () {
            Navigator.of(dialogContext).pop();
          },
        ),
      );

      if (mounted) {
        Navigator.of(context).pop({'action': 'block', 'userId': widget.otherUser.id});
      }
    } catch (e) {
      if (mounted) {
        await _showErrorDialog('Error blocking user: ${e.toString()}');
      }
    }
  }

  Future<void> _report(List<String> reasons, String? customReason) async {
    try {
      await supabase.from('reports').insert({
        'reporter_id': _currentUserId,
        'reported_id': widget.otherUser.id,
        'reasons': reasons,
        'custom_reason': customReason,
      });

      await _block();

    } catch (e) {
      if (mounted) {
        await _showErrorDialog('Error reporting user: ${e.toString()}');
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    return showDialog(
      context: context,
      builder: (context) => DaaymnDialog(
        title: 'Error',
        message: message,
        buttonText: 'OK',
        onButtonPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase.from('profiles').stream(primaryKey: ['id']).eq('id', widget.otherUser.id),
          builder: (context, snapshot) {
            final otherUserProfile = snapshot.hasData ? Profile.fromJson(snapshot.data!.first) : widget.otherUser;
            final isOnline = otherUserProfile.lastSeen != null && DateTime.now().difference(otherUserProfile.lastSeen!).inMinutes < 5;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(otherUserProfile.name),
                const SizedBox(width: 8),
                VerifiedBadge(profile: otherUserProfile, size: 20),
                if (isOnline && !otherUserProfile.isGhostModeEnabled)
                  const Row(
                    children: [
                      SizedBox(width: 8),
                      Icon(Icons.circle, color: Colors.green, size: 10),
                      SizedBox(width: 4),
                      Text('Online', style: TextStyle(fontSize: 12, color: Colors.green)),
                    ],
                  ),
              ],
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'unmatch') _unmatch();
              if (value == 'block') _block();
              if (value == 'report') _showReportDialog();
            },
            itemBuilder: (BuildContext context) {
              final items = <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'report',
                  child: ListTile(leading: Icon(Icons.flag), title: Text('Report')),
                ),
                const PopupMenuItem<String>(
                  value: 'block',
                  child: ListTile(leading: Icon(Icons.block), title: Text('Block')),
                ),
              ];

              if (!_isOtmReviewMode) {
                items.insert(
                  0,
                  const PopupMenuItem<String>(
                    value: 'unmatch',
                    child: ListTile(leading: Icon(Icons.person_remove), title: Text('Unmatch')),
                  ),
                );
              }
              return items;
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _keysLoaded
                  ? _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          reverse: true,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) => _buildMessage(_messages[index]),
                        )
                  : Center(
                      child: _errorMessage != null
                          ? Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, textAlign: TextAlign.center))
                          : const CircularProgressIndicator(),
                    ),
            ),
            if (_isOtherUserTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text('${widget.otherUser.name} is typing...', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
            if (_isOtmReviewMode) _buildOtmReviewControls() else _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(Message message) {
    final bool isMe = message.senderId == _currentUserId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary : Colors.grey[300],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(message.content, style: TextStyle(color: isMe ? Colors.white : Colors.black))),
            if (isMe) ...[
              const SizedBox(width: 8),
              Icon(
                message.isRead ? Icons.done_all : Icons.done,
                color: message.isRead ? Colors.blue : Colors.grey,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOtmReviewControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.grey.withAlpha(77), spreadRadius: 2, blurRadius: 5)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red, size: 35), onPressed: _rejectOtm, tooltip: 'Decline'),
          IconButton(icon: const Icon(Icons.favorite, color: Colors.green, size: 35), onPressed: _acceptOtm, tooltip: 'Accept Match'),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_emojiShowing ? Icons.keyboard_arrow_down : Icons.emoji_emotions_outlined, color: Colors.grey),
                  onPressed: () {
                    if (!_emojiShowing) {
                      _focusNode.unfocus();
                      setState(() => _emojiShowing = true);
                    } else {
                      _focusNode.requestFocus();
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: const InputDecoration.collapsed(hintText: 'Send a message...'),
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _sendMessage(),
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
                Text('$_charCount/500', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ),
        Offstage(
          offstage: !_emojiShowing,
          child: SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _textController.text = _textController.text + emoji.emoji;
              },
              config: Config(
                height: 256,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.20 : 1.0),
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: const CategoryViewConfig(),
                bottomActionBarConfig: const BottomActionBarConfig(),
                searchViewConfig: const SearchViewConfig(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final reasons = {
          'Inappropriate photos': false,
          'Feels like spam': false,
          'Inappropriate messages': false,
          'Underage user': false,
        };
        final customReasonController = TextEditingController();
        bool otherSelected = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                children: [
                  const Text('Daaymn', style: TextStyle(fontFamily: 'Pacifico', fontSize: 40, color: Colors.pinkAccent)),
                  const SizedBox(height: 16),
                  Text('What did ${widget.otherUser.name} do!?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...reasons.keys.map((reason) {
                      return CheckboxListTile(
                        title: Text(reason),
                        value: reasons[reason],
                        onChanged: (bool? value) {
                          setState(() {
                            reasons[reason] = value!;
                          });
                        },
                      );
                    }),
                    CheckboxListTile(
                      title: const Text('Other'),
                      value: otherSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          otherSelected = value!;
                        });
                      },
                    ),
                    if (otherSelected)
                      TextField(
                        controller: customReasonController,
                        decoration: const InputDecoration(
                          hintText: 'Please specify',
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text('Submit'),
                  onPressed: () async {
                    final selectedReasons = reasons.entries.where((e) => e.value).map((e) => e.key).toList();
                    if (otherSelected) {
                      selectedReasons.add('Other');
                    }
                    
                    Navigator.of(dialogContext).pop(); 
                    
                    await _report(selectedReasons, otherSelected ? customReasonController.text : null);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
