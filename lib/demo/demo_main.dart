import 'dart:async';

import 'package:daaymn/demo/demo_data.dart';
import 'package:daaymn/globals.dart';
import 'package:daaymn/widgets/profile_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

// Demo mode entrypoint: no Supabase, no Firebase, no login. Run with
// tool/run_demo.sh (see README). Shows the real ProfileCard on made-up people.
// Every key screen has its own path (/welcome, /, /discover/empty, /match, /matches,
// /matches/empty, /chat, /score, /vibe, /profile) so a screenshot tool can open each one.
void main() {
  usePathUrlStrategy();
  runApp(DemoApp(initialPath: Uri.base.path));
}

/// Completes once the first screens' photos are in memory (or after 4 s, so a dead
/// network can't hold the cards back). Discover builds its cards only after this, so
/// ProfileCard finds Isla's photo cached and draws it in full at once, with no fade-in.
/// Tests, which have no network, replace it with a finished future.
Future<void> demoPhotosReady = precacheDemoPhotos().timeout(
  const Duration(seconds: 4),
  onTimeout: () {},
);

/// Loads the first Discover card (as ProfileCard asks for it) and the match and chat
/// avatars into the image cache. Images found there are drawn at once, with no fade.
Future<void> precacheDemoPhotos() async {
  Future<void> load(ImageProvider provider) {
    final done = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        if (!done.isCompleted) done.complete();
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!done.isCompleted) done.complete();
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return done.future;
  }

  await Future.wait([
    load(
      ResizeImage.resizeIfNeeded(
        1080,
        null,
        CachedNetworkImageProvider(demoDiscover.first.imageUrl!),
      ),
    ),
    for (final p in demoDiscover.skip(1))
      load(
        ResizeImage.resizeIfNeeded(
          1080,
          null,
          CachedNetworkImageProvider(p.imageUrl!),
        ),
      ),
    for (final p in demoMatches) load(NetworkImage(p.imageUrl!)),
    // The full-screen match shows your photo next to theirs.
    for (final url in [demoMyPhotos.first, demoMatchPopup.imageUrl!])
      load(CachedNetworkImageProvider(url)),
    // The verified badge is an SVG asset; load it now so it is drawn with the first card.
    () async {
      const badge = SvgAssetLoader('assets/images/daaymnv.svg');
      await svg.cache.putIfAbsent(
        badge.cacheKey(null),
        () => badge.loadBytes(null),
      );
    }(),
  ]);
}

const _tabPaths = ['/discover', '/matches', '/score', '/vibe', '/profile'];

/// Where an address lands: a tab, plus an optional match pop-up, open chat or special state.
class _Start {
  final int tab;
  final bool match;
  final bool chat;
  final bool welcome;
  final bool deckDone;
  final bool noMatches;
  final bool known;
  const _Start(
    this.tab, {
    this.match = false,
    this.chat = false,
    this.welcome = false,
    this.deckDone = false,
    this.noMatches = false,
    this.known = true,
  });

  static _Start of(String path) {
    final p = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    switch (p) {
      case '':
      case '/':
      case '/discover':
        return const _Start(0);
      case '/welcome':
        return const _Start(0, welcome: true);
      case '/discover/empty':
        return const _Start(0, deckDone: true);
      case '/match':
        return const _Start(0, match: true);
      case '/matches':
        return const _Start(1);
      case '/matches/empty':
        return const _Start(1, noMatches: true);
      case '/chat':
        return const _Start(1, chat: true);
      case '/score':
        return const _Start(2);
      case '/vibe':
        return const _Start(3);
      case '/profile':
        return const _Start(4);
      default:
        return const _Start(0, known: false);
    }
  }
}

void _setAddress(String path) {
  if (kIsWeb)
    SystemNavigator.routeInformationUpdated(
      uri: Uri(path: path),
      replace: true,
    );
}

// Ends in a darker blue, not cyan, so white text over either end stays readable.
const _gradient = LinearGradient(
  colors: [Color(0xFFFC00FF), Color(0xFF2A76C3)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _accent = Color(0xFF8B4A5E);
const _muted = Color(0xFF6B6B6B);

// ---------- Shared demo state ----------

/// Everything the demo screens share: the deck, who you matched, the chats, your profile.
class DemoStore extends ChangeNotifier {
  DemoStore({bool deckDone = false, bool noMatches = false, int tab = 0})
    : tab = tab,
      index = deckDone ? demoDiscover.length : 0,
      matches = noMatches ? [] : [...demoMatches] {
    if (!noMatches) {
      demoChats.forEach((id, chat) => chats[id] = [...chat]);
      unread.addAll(demoUnread);
    }
    photos = [
      ...demoMyPhotos,
      ...List<String?>.filled(6 - demoMyPhotos.length, null),
    ];
  }

  int tab;
  int index;
  final List<int> passed = [];
  final List<Profile> matches;
  final Map<String, List<DemoMessage>> chats = {};
  final Map<String, String> times = {...demoChatTimes};
  final Set<String> unread = {};
  final Set<String> vibes = {...demoStartVibes};
  String name = demoMyName;
  String age = '$demoMyAge';
  String job = demoMyJob;
  late List<String?> photos; // six slots; null is empty

  bool get deckDone => index >= demoDiscover.length;
  Profile? get current => deckDone ? null : demoDiscover[index];
  Profile? get lastPassed => passed.isEmpty ? null : demoDiscover[passed.last];

  void goTab(int i) {
    tab = i;
    _setAddress(i == 0 && deckDone ? '/discover/empty' : _tabPaths[i]);
    notifyListeners();
  }

  /// Moves to the next card; returns the profile if this like is a mutual match.
  Profile? swipe({required bool like}) {
    final p = current;
    if (p == null) return null;
    index++;
    if (!like) passed.add(index - 1);
    notifyListeners();
    if (like && demoMutualIds.contains(p.id)) {
      addMatch(p);
      return p;
    }
    return null;
  }

  /// Brings back the last passed card; returns it, or null if there was none.
  Profile? undo() {
    if (passed.isEmpty) return null;
    index = passed.removeLast();
    notifyListeners();
    return demoDiscover[index];
  }

  void addMatch(Profile p) {
    if (matches.any((m) => m.id == p.id)) return;
    matches.insert(0, p);
    notifyListeners();
  }

  List<DemoMessage> chatOf(Profile p) => chats[p.id] ?? const [];

  void send(Profile p, String text) {
    chats[p.id] = [...chatOf(p), DemoMessage(true, text)];
    times[p.id] = 'Now';
    notifyListeners();
  }

  void markRead(Profile p) {
    if (unread.remove(p.id)) notifyListeners();
  }

  void changed() => notifyListeners();
}

class _StoreScope extends InheritedNotifier<DemoStore> {
  const _StoreScope({required DemoStore store, required super.child})
    : super(notifier: store);

  static DemoStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StoreScope>()!.notifier!;
}

class DemoApp extends StatefulWidget {
  final String initialPath;
  const DemoApp({super.key, this.initialPath = '/'});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final _Start start = _Start.of(widget.initialPath);
  late final DemoStore store = DemoStore(
    deckDone: start.deckDone,
    noMatches: start.noMatches,
    tab: start.tab,
  );

  @override
  void initState() {
    super.initState();
    if (!start.known)
      WidgetsBinding.instance.addPostFrameCallback((_) => _setAddress('/'));
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Daaymn (demo)',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        // A phone-width column on wide windows, so a desktop capture looks like the app.
        builder: (context, child) => ColoredBox(
          color: const Color(0xFFF3F0F7),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Color(0x14000000), blurRadius: 24),
                  ],
                ),
                child: ClipRect(child: child),
              ),
            ),
          ),
        ),
        // Never reached for the first screens (onGenerateInitialRoutes builds those), but a
        // route handler is what makes MaterialApp build a Navigator at all.
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const DemoHome()),
        onGenerateInitialRoutes: (_) => [
          if (start.welcome)
            MaterialPageRoute<void>(builder: (_) => const DemoWelcome())
          else
            MaterialPageRoute<void>(
              builder: (_) => DemoHome(showMatch: start.match),
            ),
          if (start.chat)
            MaterialPageRoute<void>(
              builder: (_) => DemoChat(profile: demoMatches.first),
            ),
        ],
      ),
    );
  }
}

// ---------- Welcome (first use) ----------

class DemoWelcome extends StatelessWidget {
  const DemoWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        padding: const EdgeInsets.all(32),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Daaymn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pacifico',
                  color: Colors.white,
                  fontSize: 56,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Real people near you. Rated on how they treat each other.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.pink.shade700,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () {
                  _setAddress('/');
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => const DemoHome()),
                  );
                },
                child: const Text(
                  'Start browsing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DemoHome extends StatefulWidget {
  final bool showMatch;
  const DemoHome({super.key, this.showMatch = false});

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    final index = store.tab;
    final pages = <Widget>[
      DemoDiscover(showMatchOnStart: widget.showMatch, active: index == 0),
      const DemoMatches(),
      const DemoScoreScreen(),
      const DemoVibePicker(),
      const DemoProfileEditor(),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _gradient),
        ),
        title: const Row(
          children: [
            Text(
              'Daaymn ',
              style: TextStyle(
                fontFamily: 'Pacifico',
                color: Colors.white,
                fontSize: 24,
              ),
            ),
            Text('| ', style: TextStyle(color: Colors.white, fontSize: 16)),
            Flexible(
              child: Text(
                'Dating, rated on respect',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: store.goTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _accent,
        unselectedItemColor: _muted,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Matches',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Score'),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Vibe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------- Discover (faces / browse, with a match pop-up) ----------

class DemoDiscover extends StatefulWidget {
  final bool showMatchOnStart;
  final bool active;
  const DemoDiscover({
    super.key,
    this.showMatchOnStart = false,
    this.active = true,
  });

  @override
  State<DemoDiscover> createState() => _DemoDiscoverState();
}

class _DemoDiscoverState extends State<DemoDiscover> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.showMatchOnStart)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showMatch(demoMatchPopup),
      );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _swipe(DemoStore store, {required bool like}) {
    final match = store.swipe(like: like);
    if (store.deckDone) _setAddress('/discover/empty');
    if (match != null) _showMatch(match);
  }

  void _undo(DemoStore store) {
    final back = store.undo();
    if (back == null) return;
    _setAddress('/discover');
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Brought back ${back.name}.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showMatch(Profile who) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, _, _) => _MatchScreen(
          who: who,
          onKeepBrowsing: () {
            Navigator.of(context).pop();
            _setAddress('/discover');
          },
          onSayHi: () {
            Navigator.of(context).pop();
            _setAddress('/chat');
            _StoreScope.of(this.context).addMatch(who);
            Navigator.of(this.context).push(
              MaterialPageRoute(
                builder: (_) => DemoChat(profile: who, backPath: '/discover'),
              ),
            );
          },
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    return FutureBuilder<void>(
      future: demoPhotosReady,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const _DeckPlaceholder();
        if (store.deckDone) return const _EndOfDeck();
        return Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (_, event) {
            if (!widget.active || event is! KeyDownEvent)
              return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _swipe(store, like: false);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _swipe(store, like: true);
            } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
              _undo(store);
            } else {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: LayoutBuilder(
            builder: (context, box) {
              // Pin the card under the app bar and give it all the height left.
              final aspect = ((box.maxWidth - 32) / (box.maxHeight - 32)).clamp(
                0.5,
                0.9,
              );
              final profile = store.current!;
              return Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ProfileCard(
                    key: ValueKey(profile.id),
                    profile: profile,
                    aspectRatio: aspect.toDouble(),
                    onLike: () => _swipe(store, like: true),
                    onDislike: () => _swipe(store, like: false),
                    imageFadeIn: Duration.zero,
                    extraAction: _UndoButton(
                      onPressed: store.passed.isEmpty
                          ? null
                          : () => _undo(store),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Full-screen "It's a match": your photo and theirs side by side, then Say hi.
class _MatchScreen extends StatelessWidget {
  final Profile who;
  final VoidCallback onKeepBrowsing;
  final VoidCallback onSayHi;
  const _MatchScreen({
    required this.who,
    required this.onKeepBrowsing,
    required this.onSayHi,
  });

  Widget _face(String url, String label, double turn) => Transform.rotate(
    angle: turn,
    child: Semantics(
      label: label,
      image: true,
      child: Container(
        width: 136,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 16),
          ],
          image: DecorationImage(
            image: CachedNetworkImageProvider(url),
            fit: BoxFit.cover,
          ),
          color: Colors.white24,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                "It's a Daaymn match!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pacifico',
                  color: Colors.white,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You and ${who.name} liked each other.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _face(demoMyPhotos.first, 'Your photo', -0.08),
                  const SizedBox(width: 16),
                  _face(who.imageUrl!, "${who.name}'s photo", 0.08),
                ],
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.pink.shade700,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: onSayHi,
                child: const Text(
                  'Say hi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: onKeepBrowsing,
                child: const Text(
                  'Keep browsing',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same solid treatment as Pass/Like, smaller: white fill, dark icon, 44 px.
class _UndoButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _UndoButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: 'Undo',
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.undo,
          size: 22,
          color: on ? const Color(0xFF2A2230) : Colors.black38,
        ),
        style:
            IconButton.styleFrom(
              backgroundColor: Colors.white,
              disabledBackgroundColor: Colors.white,
              elevation: 4,
              shadowColor: Colors.black,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : BorderSide.none,
              ),
            ),
      ),
    );
  }
}

/// Shown while the first photos load: a card of the same size and place, with a soft
/// shimmer and the two buttons drawn but not working. The real card replaces it at once.
class _DeckPlaceholder extends StatefulWidget {
  const _DeckPlaceholder();

  @override
  State<_DeckPlaceholder> createState() => _DeckPlaceholderState();
}

class _DeckPlaceholderState extends State<_DeckPlaceholder>
    with SingleTickerProviderStateMixin {
  late final _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final aspect = ((box.maxWidth - 32) / (box.maxHeight - 32)).clamp(
          0.5,
          0.9,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Align(
            alignment: Alignment.topCenter,
            child: Card(
              elevation: 8,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: aspect.toDouble(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmer,
                        builder: (context, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: const [
                                Color(0xFFEEE8EC),
                                Color(0xFFF7F3F6),
                                Color(0xFFEEE8EC),
                              ],
                              stops: const [0.2, 0.5, 0.8],
                              begin: Alignment(-1.5 + 3 * _shimmer.value, 0),
                              end: Alignment(-0.5 + 3 * _shimmer.value, 0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Row(
                        children: [
                          _ghostButton(Icons.close, Colors.red),
                          const SizedBox(width: 12),
                          _ghostButton(Icons.favorite, Colors.pinkAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ghostButton(IconData icon, Color color) => Material(
    color: color.withValues(alpha: 0.35),
    shape: const CircleBorder(),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Icon(icon, color: Colors.white, size: 32),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                // Web uses compact density, which would take 8 px off the 44.
                visualDensity: VisualDensity.standard,
              ),
              onPressed: onAction,
              child: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndOfDeck extends StatelessWidget {
  const _EndOfDeck();

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    return _EmptyState(
      icon: Icons.favorite_border,
      title: "You've seen everyone for now",
      body: 'New people show up every day.',
      action: 'See your matches',
      onAction: () => store.goTab(1),
    );
  }
}

// ---------- Matches list ----------

class DemoMatches extends StatelessWidget {
  const DemoMatches({super.key});

  void _open(BuildContext context, Profile p) {
    _StoreScope.of(context).markRead(p);
    _setAddress('/chat');
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DemoChat(profile: p)));
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    if (store.matches.isEmpty) {
      return _EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No matches yet',
        body: "Like someone on Discover and they'll show up here.",
        action: 'Start browsing',
        onAction: () => store.goTab(0),
      );
    }
    final fresh = [
      for (final p in store.matches)
        if (store.chatOf(p).isEmpty) p,
    ];
    final talking = [
      for (final p in store.matches)
        if (store.chatOf(p).isNotEmpty) p,
    ];
    const heading = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (fresh.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('New matches', style: heading),
          ),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in fresh)
                  InkWell(
                    onTap: () => _open(context, p),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: NetworkImage(p.imageUrl!),
                          ),
                          const SizedBox(height: 4),
                          Text(p.name, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (talking.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Messages', style: heading),
          ),
          for (final p in talking)
            _ThreadRow(
              profile: p,
              last: store.chatOf(p).last,
              time: store.times[p.id] ?? '',
              unread: store.unread.contains(p.id),
              onTap: () => _open(context, p),
            ),
        ],
      ],
    );
  }
}

/// One Messages row: photo, name, last line, and when it came in; unread rows are bold
/// with an accent dot.
class _ThreadRow extends StatelessWidget {
  final Profile profile;
  final DemoMessage last;
  final String time;
  final bool unread;
  final VoidCallback onTap;
  const _ThreadRow({
    required this.profile,
    required this.last,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(profile.imageUrl!),
      ),
      title: Text(
        '${profile.name}, ${profile.age}',
        style: TextStyle(
          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '${last.mine ? 'You: ' : ''}${last.text}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread ? Colors.black87 : _muted,
          fontWeight: unread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: unread ? _accent : _muted,
              fontWeight: unread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: unread ? 'Unread' : null,
            child: Container(
              key: unread ? const ValueKey('unread-dot') : null,
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: unread ? _accent : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ---------- Chat ----------

class DemoChat extends StatefulWidget {
  final Profile profile;
  final String backPath;
  const DemoChat({
    super.key,
    required this.profile,
    this.backPath = '/matches',
  });

  @override
  State<DemoChat> createState() => _DemoChatState();
}

class _DemoChatState extends State<DemoChat> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send(DemoStore store) {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    store.send(widget.profile, t);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = _StoreScope.of(context);
    final profile = widget.profile;
    final messages = store.chatOf(profile);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _gradient),
        ),
        foregroundColor: Colors.white,
        leading: BackButton(
          onPressed: () {
            Navigator.of(context).maybePop();
            _setAddress(widget.backPath);
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(profile.imageUrl!),
            ),
            const SizedBox(width: 10),
            Text(profile.name, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: NetworkImage(profile.imageUrl!),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You matched with ${profile.name} today.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say something about her photos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final m in messages.reversed)
                        Align(
                          alignment: m.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: m.mine
                                  ? scheme.primary
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              m.text,
                              style: TextStyle(
                                color: m.mine ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(store),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton.filled(
                      tooltip: 'Send',
                      padding: EdgeInsets.zero,
                      onPressed: () => _send(store),
                      icon: const Icon(Icons.send, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Daaymn Score ----------

class DemoScoreScreen extends StatelessWidget {
  const DemoScoreScreen({super.key});

  Widget _pillar(String label, double value, String what) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 136,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: value / 10,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            what,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Daaymn Score',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: BoxDecoration(
            gradient: _gradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Text(
                demoScore.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '#DaaymnScore',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Pacifico',
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                demoScoreNote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'SCORE BREAKDOWN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        const SizedBox(height: 8),
        _pillar(
          'Popularity',
          demoPopularity,
          'How many people like your profile back.',
        ),
        _pillar(
          'Engagement',
          demoEngagement,
          'How quickly and kindly you reply to matches.',
        ),
        _pillar(
          'Safety · $demoSafetyGrade grade',
          demoSafety,
          'Verified photo, no reports, respectful chats.',
        ),
      ],
    );
  }
}

// ---------- Vibe picker ----------

class DemoVibePicker extends StatelessWidget {
  const DemoVibePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    final picked = store.vibes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "What's your vibe?",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('Pick up to 5. They show on your profile card.'),
                const SizedBox(height: 4),
                Text(
                  '${picked.length} of 5 picked',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final v in demoVibes)
                      FilterChip(
                        label: Text(v),
                        selected: picked.contains(v),
                        onSelected: (on) {
                          if (!on) {
                            picked.remove(v);
                          } else if (picked.length < 5) {
                            picked.add(v);
                          }
                          store.changed();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: picked.isEmpty
                ? null
                : () => ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Vibes saved.'),
                        duration: Duration(seconds: 2),
                      ),
                    ),
            child: const Text(
              'Save vibes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Profile (edit your own) ----------

class DemoProfileEditor extends StatefulWidget {
  const DemoProfileEditor({super.key});

  @override
  State<DemoProfileEditor> createState() => _DemoProfileEditorState();
}

class _DemoProfileEditorState extends State<DemoProfileEditor> {
  late final DemoStore _store = _StoreScope.of(context);
  late final _name = TextEditingController(text: _store.name);
  late final _age = TextEditingController(text: _store.age);
  late final _job = TextEditingController(text: _store.job);

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _job.dispose();
    super.dispose();
  }

  void _add(int slot) {
    final used = _store.photos.whereType<String>().toSet();
    final next =
        demoSparePhotos.where((u) => !used.contains(u)).firstOrNull ??
        demoSparePhotos[slot % demoSparePhotos.length];
    _store.photos[slot] = next;
    _store.changed();
  }

  void _remove(int slot) {
    _store.photos[slot] = null;
    _store.changed();
  }

  void _moveEarlier(int slot) {
    final p = _store.photos;
    final t = p[slot - 1];
    p[slot - 1] = p[slot];
    p[slot] = t;
    _store.changed();
  }

  void _save() {
    _store.name = _name.text;
    _store.age = _age.text;
    _store.job = _job.text;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Profile saved.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    const label = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('YOUR PHOTOS', style: label),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 4 / 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (var i = 0; i < 6; i++) _slot(store, i)],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _job,
          decoration: const InputDecoration(labelText: 'Job'),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'My vibes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            store.vibes.isEmpty
                ? 'None picked yet'
                : (store.vibes.toList()..sort()).join(', '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => store.goTab(3),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _slot(DemoStore store, int i) {
    final url = store.photos[i];
    if (url == null) {
      return InkWell(
        onTap: () => _add(i),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFEEE8EC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: Icon(Icons.add, color: Colors.black54)),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, fit: BoxFit.cover),
        ),
        // The 44x44 hit area sits flush in the corner, so its centred
        // 28 px circle shows 8 px in from the photo's edges.
        Positioned(
          top: 0,
          right: 0,
          child: _chip(Icons.close, 'Remove photo', () => _remove(i)),
        ),
        if (i > 0)
          Positioned(
            bottom: 0,
            left: 0,
            child: _chip(
              Icons.arrow_back,
              'Move earlier',
              () => _moveEarlier(i),
            ),
          ),
      ],
    );
  }

  Widget _chip(IconData icon, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: Semantics(
      button: true,
      label: tip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}
