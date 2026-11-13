import 'dart:async';
import 'dart:math';

import 'package:daaymn/demo/demo_data.dart';
import 'package:daaymn/demo/demo_script.dart';
import 'package:daaymn/globals.dart';
import 'package:daaymn/widgets/photo_fallback.dart';
import 'package:daaymn/widgets/profile_card.dart';
import 'package:daaymn/widgets/verified_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:url_launcher/url_launcher.dart';

// Demo mode entrypoint: no Supabase, no Firebase, no login. Run with
// tool/run_demo.sh (see README). It draws the shipped app's screens (its header,
// its five tabs, its Discover card, Liked You, Your Likes, Messages, Settings and
// Store -> Reports) on made-up people, so the Play pictures show the app people get.
// Every key screen has its own address so a screenshot tool can open each one:
//   /welcome, /, /discover/empty, /likes, /likes/otm, /liked-you, /messages,
//   /messages/empty, /chat, /otm, /settings, /store, /profile
// Older addresses still land on the screen that replaced them:
//   /match -> /liked-you, /matches -> /messages, /score -> /store, /vibe -> /likes.
void main() {
  usePathUrlStrategy();
  runApp(DemoApp(initialPath: demoPathFor(Uri.base.path)));
}

/// On the public build (served under /Daaymn/demo/) the page address carries that
/// prefix. Strip it, and let the bare /Daaymn/demo/ link open Welcome (a visitor's
/// first screen); any other address under it is resolved by [_Start.of] as usual.
String demoPathFor(String pagePath) {
  const prefix = '/Daaymn/demo';
  if (pagePath != prefix && !pagePath.startsWith('$prefix/')) return pagePath;
  final rest = pagePath.substring(prefix.length);
  return rest.isEmpty || rest == '/' ? '/welcome' : rest;
}

const playListing =
    'https://play.google.com/store/apps/details?id=com.daaymn.daaymn';

/// Completes once the first screens' photos are in memory (or after 4 s, so a dead
/// network can't hold the cards back). Discover builds its cards only after this, so
/// ProfileCard finds Isla's photo cached and draws it in full at once, with no fade-in.
/// Tests, which have no network, replace it with a finished future.
Future<void> demoPhotosReady = precacheDemoPhotos().timeout(
  const Duration(seconds: 4),
  onTimeout: () {},
);

/// Loads the Discover and Liked You cards (as ProfileCard asks for them) and the list
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

  // The first four cards are waited for; the rest load in the background so later
  // cards don't flash.
  unawaited(
    Future.wait([
      for (final p in [...demoDiscover.skip(4), ...demoLikedYou.skip(1)])
        load(ResizeImage.resizeIfNeeded(1080, null, demoImage(p.imageUrl!))),
    ]),
  );
  await Future.wait([
    for (final p in [...demoDiscover.take(4), ...demoLikedYou.take(1)])
      load(ResizeImage.resizeIfNeeded(1080, null, demoImage(p.imageUrl!))),
    for (final p in [
      ...demoMatches,
      demoOtmFrom,
      for (final l in demoYourLikes()) l.profile,
    ])
      load(demoImage(p.imageUrl!)),
    load(demoImage(demoMyPhotos.first)),
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

/// A demo photo fetched as bytes (HttpGet). The browser-decoded default (HtmlImage) paints
/// black when a card is drawn a second time.
/// A round demo avatar. A photo that fails to load shows the person's initial
/// on the app's gradient instead of a blank circle.
Widget _demoAvatar(String name, String url, double radius) => SizedBox.square(
  dimension: radius * 2,
  child: ClipOval(
    child: Image(
      image: demoImage(url),
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => PhotoFallback(name: name, compact: true),
    ),
  ),
);

CachedNetworkImageProvider demoImage(String url) => CachedNetworkImageProvider(
  url,
  imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
);

const _tabPaths = [
  '/discover',
  '/likes',
  '/liked-you',
  '/messages',
  '/settings',
];

/// Where an address lands: a tab, plus an optional screen opened over it.
class _Start {
  final int tab;
  final String? over; // 'chat', 'otm', 'store', 'profile'
  final bool welcome;
  final bool deckDone;
  final bool noMessages;
  final bool otmOpen;
  final String?
  rename; // the address to show instead (old or unknown addresses)
  const _Start(
    this.tab, {
    this.over,
    this.welcome = false,
    this.deckDone = false,
    this.noMessages = false,
    this.otmOpen = false,
    this.rename,
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
      case '/likes':
        return const _Start(1);
      case '/vibe':
        return const _Start(1, rename: '/likes');
      case '/likes/otm':
        return const _Start(1, otmOpen: true);
      case '/liked-you':
        return const _Start(2);
      case '/match':
        return const _Start(2, rename: '/liked-you');
      case '/messages':
        return const _Start(3);
      case '/matches':
        return const _Start(3, rename: '/messages');
      case '/messages/empty':
        return const _Start(3, noMessages: true);
      case '/matches/empty':
        return const _Start(3, noMessages: true, rename: '/messages/empty');
      case '/chat':
        return const _Start(3, over: 'chat');
      case '/otm':
        return const _Start(3, over: 'otm');
      case '/settings':
        return const _Start(4);
      case '/store':
        return const _Start(0, over: 'store');
      case '/score':
        return const _Start(0, over: 'store', rename: '/store');
      case '/profile':
        return const _Start(0, over: 'profile');
      default:
        return const _Start(0, rename: '/');
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

/// The shipped app's header and Store gradient (lib/main.dart, lib/buy_likes_screen.dart).
const _gradient = LinearGradient(
  colors: [Color(0xFFFC00FF), Color(0xFF00DBDE)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// The app puts this soft shadow under white text on the gradient, so it reads on cyan too.
const _shadow = [Shadow(blurRadius: 2, color: Colors.black38)];

// ---------- Shared demo state ----------

/// A conversation in Messages: a One-Time Message waiting for an answer, or a match.
class DemoThread {
  final Profile profile;
  bool otm;
  DemoThread(this.profile, {this.otm = false});
}

/// Everything the demo screens share: the deck, likes, the chats, your profile.
class DemoStore extends ChangeNotifier {
  DemoStore({bool deckDone = false, bool noMessages = false, int tab = 0})
    : tab = tab,
      index = deckDone ? demoDiscover.length : 0 {
    if (!noMessages) {
      threads.add(DemoThread(demoOtmFrom, otm: true));
      chats[demoOtmFrom.id] = const [DemoMessage(false, demoOtmText)];
      unread[demoOtmFrom.id] = 1;
      for (final p in demoMatches) threads.add(DemoThread(p));
      demoChats.forEach((id, chat) => chats[id] = [...chat]);
      unread.addAll(demoUnread);
    }
    // At the end of the deck you had passed on Alex and Ben, so there is something to review.
    if (deckDone) passed.addAll([demoDiscover[1], demoDiscover[3]]);
    photos = [
      ...demoMyPhotos,
      ...List<String?>.filled(6 - demoMyPhotos.length, null),
    ];
  }

  int tab;
  int index;
  int likes = demoMyLikes;
  bool reviewing = false; // Discover shows the profiles you passed on
  final List<Profile> passed = [];
  List<Profile> review = [];
  final List<Profile> likedYou = [...demoLikedYou];
  final List<DemoLiked> yourLikes = demoYourLikes();
  final List<DemoThread> threads = [];
  final Map<String, List<DemoMessage>> chats = {};
  final Map<String, int> unread = {};
  final Set<String> typing = {}; // threads whose person is typing a reply
  final Map<String, Timer> _replyTimers = {};
  final Map<String, Set<String>> _usedLines = {};
  final Random _rng = Random();
  String? openChat; // the thread on screen, so a reply there is not "unread"
  bool _disposed = false;
  String name = demoMyName;
  String age = '$demoMyAge';
  String job = demoMyJob;
  late List<String?> photos; // six slots; null is empty

  bool get deckDone =>
      reviewing ? review.isEmpty : index >= demoDiscover.length;
  Profile? get current =>
      deckDone ? null : (reviewing ? review.first : demoDiscover[index]);

  int get messagesBadge => unread.values.fold(0, (a, b) => a + b);

  void goTab(int i) {
    tab = i;
    _setAddress(i == 0 && deckDone ? '/discover/empty' : _tabPaths[i]);
    notifyListeners();
  }

  /// Like or pass the card on top. A like spends one of your likes; a like on someone
  /// who already liked you is a match in Messages, any other like goes to Your Likes.
  void swipe({required bool like}) {
    final p = current;
    if (p == null) return;
    if (like) {
      if (likes == 0) return;
      likes--;
      if (demoMutualIds.contains(p.id)) {
        addMatch(p);
      } else if (!yourLikes.any((l) => l.profile.id == p.id)) {
        yourLikes.insert(0, DemoLiked(p, 0, '3 days remaining'));
      }
    }
    if (reviewing) {
      review.removeAt(0);
      if (like) passed.remove(p);
    } else {
      index++;
      if (!like) passed.add(p);
    }
    notifyListeners();
  }

  /// "Review your dislikes?": the profiles you passed on come round again.
  void reviewDislikes() {
    reviewing = true;
    review = [...passed];
    notifyListeners();
  }

  /// Refresh: back to new people (the demo has no more, so the end card stays).
  void refresh() {
    reviewing = false;
    notifyListeners();
  }

  void likeBack(Profile p) {
    if (likes == 0) return;
    likes--;
    likedYou.remove(p);
    addMatch(p);
  }

  void passLikedYou(Profile p) {
    likedYou.remove(p);
    notifyListeners();
  }

  void fillHeart(DemoLiked l) {
    if (l.level >= 5 || likes == 0) return;
    likes--;
    l.level++;
    if (l.level == 5) l.open = true;
    notifyListeners();
  }

  /// The OTM goes out and the heart empties again, as in the app.
  void sendOtm(DemoLiked l) {
    l
      ..level = 0
      ..open = false;
    notifyListeners();
  }

  void addMatch(Profile p) {
    if (threads.any((t) => t.profile.id == p.id)) return;
    final firstMatch = threads.indexWhere((t) => !t.otm);
    threads.insert(firstMatch < 0 ? threads.length : firstMatch, DemoThread(p));
    unread[p.id] = 1; // the "New Match!" row counts as one new thing
    notifyListeners();
  }

  void acceptOtm(Profile p) {
    final t = threads.firstWhere((t) => t.profile.id == p.id);
    threads.remove(t);
    t.otm = false;
    final firstMatch = threads.indexWhere((t) => !t.otm);
    threads.insert(firstMatch < 0 ? threads.length : firstMatch, t);
    notifyListeners();
  }

  void declineOtm(Profile p) {
    threads.removeWhere((t) => t.profile.id == p.id);
    chats.remove(p.id);
    unread.remove(p.id);
    notifyListeners();
  }

  List<DemoMessage> chatOf(Profile p) => chats[p.id] ?? const [];

  /// Sends a message. A match answers by script: 1 to 2 s of nothing, 1 to 2 s of
  /// typing dots, then the reply. Several sends before the reply make one reply,
  /// timed from the last send.
  void send(Profile p, String text) {
    chats[p.id] = [...chatOf(p), DemoMessage(true, text)];
    unread.remove(p.id);
    _replyTimers.remove(p.id)?.cancel();
    typing.remove(p.id);
    final t = threads.where((t) => t.profile.id == p.id);
    if (t.isNotEmpty && !t.first.otm) {
      _replyTimers[p.id] = Timer(_wait(), () {
        typing.add(p.id);
        notifyListeners();
        _replyTimers[p.id] = Timer(_wait(), () {
          _replyTimers.remove(p.id);
          typing.remove(p.id);
          final reply = demoReplyFor(
            p.id,
            text,
            _usedLines.putIfAbsent(p.id, () => <String>{}),
            _rng,
          );
          chats[p.id] = [...chatOf(p), DemoMessage(false, reply)];
          if (openChat != p.id) unread[p.id] = (unread[p.id] ?? 0) + 1;
          notifyListeners();
        });
      });
    }
    notifyListeners();
  }

  Duration _wait() => Duration(milliseconds: 1000 + _rng.nextInt(1001));

  @override
  void dispose() {
    _disposed = true;
    for (final t in _replyTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void markRead(Profile p) {
    if (unread.remove(p.id) != null) notifyListeners();
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
    noMessages: start.noMessages,
    tab: start.tab,
  );

  @override
  void initState() {
    super.initState();
    if (start.otmOpen)
      store.yourLikes.first
        ..level = 5
        ..open = true;
    final rename = start.rename;
    if (rename != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => _setAddress(rename));
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
        // The shipped app's light theme (lib/main.dart): pink seed, white page, Pacifico
        // for the page titles (the default font choice).
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          textTheme: const TextTheme(
            displaySmall: TextStyle(fontFamily: 'Pacifico'),
          ).apply(bodyColor: Colors.black, displayColor: Colors.black),
          listTileTheme: const ListTileThemeData(
            subtitleTextStyle: TextStyle(color: Colors.black54),
          ),
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
            MaterialPageRoute<void>(builder: (_) => const DemoHome()),
          if (start.over == 'chat')
            MaterialPageRoute<void>(
              builder: (_) => DemoChat(
                profile: demoMatches.firstWhere((p) => p.id == 'demo-fiona'),
              ),
            ),
          if (start.over == 'otm')
            MaterialPageRoute<void>(
              builder: (_) => DemoChat(profile: demoOtmFrom),
            ),
          if (start.over == 'store')
            MaterialPageRoute<void>(builder: (_) => const DemoStoreScreen()),
          if (start.over == 'profile')
            MaterialPageRoute<void>(builder: (_) => const DemoProfileEditor()),
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
                  shadows: _shadow,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Like who you like. Fill the heart to send a One-Time Message.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: _shadow,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Everyone here is made up. Photos are AI-made.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: _shadow,
                ),
              ),
              const SizedBox(height: 36),
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
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => launchUrl(
                  Uri.parse(playListing),
                  webOnlyWindowName: '_blank',
                ),
                child: const Text(
                  'Get Daaymn on Google Play',
                  style: TextStyle(
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Home: the app's header and five tabs ----------

class DemoHome extends StatelessWidget {
  const DemoHome({super.key});

  void _openStore(BuildContext context) {
    _setAddress('/store');
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DemoStoreScreen()));
  }

  void _openProfile(BuildContext context) {
    _setAddress('/profile');
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DemoProfileEditor()));
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    final index = store.tab;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _gradient),
        ),
        title: Row(
          children: [
            const Text(
              'Daaymn ',
              style: TextStyle(
                fontFamily: 'Pacifico',
                color: Colors.white,
                fontSize: 24,
                shadows: _shadow,
              ),
            ),
            const Text(
              '| ',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: _shadow,
                    ),
                    children: [
                      TextSpan(
                        text: '${store.likes}',
                        style: TextStyle(
                          color: store.likes < 5
                              ? Colors.redAccent
                              : Colors.white,
                        ),
                      ),
                      const TextSpan(
                        text: ' Likes Left!',
                        style: TextStyle(
                          fontFamily: 'Pacifico',
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              label: 'Buy likes and reports',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openStore(context),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xE6141420),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(51)),
                  ),
                  child: const Text(
                    'Buy',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 8, color: Color(0xFFFFD700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Edit your profile',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openProfile(context),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: store.photos.first == null
                        ? CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade300,
                            child: const Icon(Icons.person, size: 20),
                          )
                        : _demoAvatar(store.name, store.photos.first!, 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          DemoDiscover(active: index == 0),
          const DemoYourLikes(),
          const DemoLikedYou(),
          const DemoMessages(),
          const DemoSettings(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: store.goTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade700,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Discover',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            label: 'Your Likes',
          ),
          BottomNavigationBarItem(
            icon: _Badge(icon: Icons.whatshot, count: store.likedYou.length),
            label: 'Liked You',
          ),
          BottomNavigationBarItem(
            icon: _Badge(
              icon: Icons.chat_bubble_outline,
              count: store.messagesBadge,
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// The app's red count on a tab icon (NotificationBadge in lib/main.dart).
class _Badge extends StatelessWidget {
  final IconData icon;
  final int count;
  const _Badge({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// A tab's title, as every tab of the app draws it: Pacifico, display size.
class _PageTitle extends StatelessWidget {
  final String text;
  final List<Widget> actions;
  const _PageTitle(this.text, {this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontSize: 32),
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// The app's empty state: "Daaymn!" and one line saying what goes here.
class _DaaymnEmpty extends StatelessWidget {
  final String body;
  final String? action;
  final VoidCallback? onAction;
  const _DaaymnEmpty({required this.body, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Daaymn!',
              style: TextStyle(
                fontFamily: 'Pacifico',
                fontSize: 40,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  visualDensity: VisualDensity.standard,
                ),
                onPressed: onAction,
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
}

// ---------- Discover ----------

class DemoDiscover extends StatefulWidget {
  final bool active;
  const DemoDiscover({super.key, this.active = true});

  @override
  State<DemoDiscover> createState() => _DemoDiscoverState();
}

class _DemoDiscoverState extends State<DemoDiscover> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _swipe(DemoStore store, {required bool like}) {
    if (like && store.likes == 0) {
      _snack(context, "You're out of likes. Tap Buy to get more.");
      return;
    }
    final p = store.current;
    store.swipe(like: like);
    if (like && p != null && demoMutualIds.contains(p.id)) {
      _snack(context, "You and ${p.name} matched. Say hi in Messages.");
    }
    if (store.deckDone) _setAddress('/discover/empty');
  }

  void _preferences() {
    showDialog<void>(
      context: context,
      builder: (_) => const _PreferencesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    return Column(
      children: [
        _PageTitle(
          'Discover',
          actions: [
            IconButton(
              tooltip: 'Discovery preferences',
              icon: const Icon(Icons.hourglass_empty, size: 28),
              onPressed: _preferences,
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh, size: 28),
              onPressed: store.refresh,
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<void>(
            future: demoPhotosReady,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done)
                return const _DeckPlaceholder();
              if (store.deckDone) {
                if (store.reviewing)
                  return const _DaaymnEmpty(
                    body:
                        "You've seen all your dislikes. Hit refresh to see who's new.",
                  );
                return _DaaymnEmpty(
                  body:
                      "You've seen everyone! Why not review your dislikes? You might have missed a Daaymn good one.",
                  action: store.passed.isEmpty ? null : 'Review your dislikes',
                  onAction: () {
                    store.reviewDislikes();
                    _setAddress('/discover');
                  },
                );
              }
              return Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: (_, event) {
                  if (!widget.active || event is! KeyDownEvent)
                    return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _swipe(store, like: false);
                  } else if (event.logicalKey ==
                      LogicalKeyboardKey.arrowRight) {
                    _swipe(store, like: true);
                  } else {
                    return KeyEventResult.ignored;
                  }
                  return KeyEventResult.handled;
                },
                child: LayoutBuilder(
                  builder: (context, box) {
                    final aspect = ((box.maxWidth - 32) / (box.maxHeight - 24))
                        .clamp(0.5, 0.9);
                    final profile = store.current!;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ProfileCard(
                        key: ValueKey('${store.reviewing}-${profile.id}'),
                        profile: profile,
                        aspectRatio: aspect.toDouble(),
                        onLike: () => _swipe(store, like: true),
                        onDislike: () => _swipe(store, like: false),
                        imageFadeIn: Duration.zero,
                        imageRenderMethodForWeb:
                            ImageRenderMethodForWeb.HttpGet,
                        demoTag: true,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Discovery Preferences, as the hourglass opens it in the app: pronouns and age range.
class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog();

  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  String _pronouns = 'All';
  RangeValues _ages = const RangeValues(24, 36);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Discovery Preferences'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _pronouns,
            decoration: const InputDecoration(
              labelText: 'Pronouns',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final p in ['All', 'he/him', 'she/her', 'they/them'])
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => _pronouns = v!),
          ),
          const SizedBox(height: 20),
          Text(
            'Age Range: ${_ages.start.round()} - ${_ages.end.round()}',
            style: const TextStyle(fontSize: 16),
          ),
          RangeSlider(
            values: _ages,
            min: 18,
            max: 100,
            divisions: 82,
            onChanged: (v) => setState(() => _ages = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Apply'),
        ),
      ],
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
        final aspect = ((box.maxWidth - 32) / (box.maxHeight - 24)).clamp(
          0.5,
          0.9,
        );
        return Align(
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

// ---------- Your Likes (fill the heart, send a One-Time Message) ----------

class DemoYourLikes extends StatefulWidget {
  const DemoYourLikes({super.key});

  @override
  State<DemoYourLikes> createState() => _DemoYourLikesState();
}

class _DemoYourLikesState extends State<DemoYourLikes> {
  final Map<String, TextEditingController> _text = {};

  @override
  void dispose() {
    for (final c in _text.values) c.dispose();
    super.dispose();
  }

  void _fill(DemoStore store, DemoLiked l) {
    if (store.likes == 0) {
      _snack(context, "You're out of likes. Tap Buy to get more.");
      return;
    }
    store.fillHeart(l);
  }

  void _send(DemoStore store, DemoLiked l) {
    final c = _text[l.profile.id]!;
    if (c.text.trim().isEmpty) return;
    c.clear();
    store.sendOtm(l);
    _setAddress('/likes');
    _snack(context, 'Your Daaymn OTM has been sent!');
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    return Column(
      children: [
        const _PageTitle('Your Likes'),
        Expanded(
          child: store.yourLikes.isEmpty
              ? _DaaymnEmpty(
                  body:
                      "Your likes are looking a little empty. Get out there and say ‘Daaymn!’ to someone.",
                  action: 'Go to Discover',
                  onAction: () => store.goTab(0),
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  children: [for (final l in store.yourLikes) _card(store, l)],
                ),
        ),
      ],
    );
  }

  Widget _card(DemoStore store, DemoLiked l) {
    final p = l.profile;
    final c = _text.putIfAbsent(p.id, TextEditingController.new);
    final full = l.level >= 5;
    return Card(
      key: ValueKey(p.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DemoTag(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            child: Row(
              children: [
                _demoAvatar(p.name, p.imageUrl!, 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${p.name}, ${p.age}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          VerifiedBadge(profile: p, size: 14),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: l.left.contains('h ')
                              ? Colors.red.shade700
                              : Colors.blueGrey.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l.left,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: !full,
                  label: full
                      ? 'Heart full, 5 of 5: send a message'
                      : 'Fill the heart, ${l.level} of 5. Spends one like',
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('heart-${p.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: full ? null : () => _fill(store, l),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            full ? Icons.favorite : Icons.favorite_border,
                            color: full ? Colors.red : Colors.pinkAccent,
                            size: 28,
                          ),
                          Text(
                            '${l.level}/5',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            full ? 'Send Message' : 'Fill me up',
                            style: TextStyle(
                              fontSize: 12,
                              color: full
                                  ? Colors.green.shade800
                                  : Colors.grey.shade700,
                              fontWeight: full
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (l.open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: c,
                    maxLength: 280,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Send your one-time message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(Icons.send),
                    label: const Text('Send'),
                    onPressed: () => _send(store, l),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Liked You ----------

class DemoLikedYou extends StatelessWidget {
  const DemoLikedYou({super.key});

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    return Column(
      children: [
        const _PageTitle('Liked You'),
        Expanded(
          child: store.likedYou.isEmpty
              ? const _DaaymnEmpty(
                  body:
                      "Nobody’s said ‘Daaymn!’ yet. Once they do, you’ll find them here.",
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    final aspect = ((box.maxWidth - 32) / (box.maxHeight - 24))
                        .clamp(0.5, 0.9);
                    return ListView(
                      children: [
                        for (final p in store.likedYou)
                          ProfileCard(
                            key: ValueKey('liked-${p.id}'),
                            profile: p,
                            aspectRatio: aspect.toDouble(),
                            imageFadeIn: Duration.zero,
                            imageRenderMethodForWeb:
                                ImageRenderMethodForWeb.HttpGet,
                            demoTag: true,
                            onLike: () {
                              if (store.likes == 0) {
                                _snack(
                                  context,
                                  "You're out of likes. Tap Buy to get more.",
                                );
                                return;
                              }
                              store.likeBack(p);
                              _snack(
                                context,
                                "You and ${p.name} matched. Say hi in Messages.",
                              );
                            },
                            onDislike: () => store.passLikedYou(p),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------- Messages ----------

class DemoMessages extends StatelessWidget {
  const DemoMessages({super.key});

  void _open(BuildContext context, DemoThread t) {
    final store = _StoreScope.of(context);
    if (!t.otm) store.markRead(t.profile);
    _setAddress(t.otm ? '/otm' : '/chat');
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DemoChat(profile: t.profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    final otms = [
      for (final t in store.threads)
        if (t.otm) t,
    ];
    final matches = [
      for (final t in store.threads)
        if (!t.otm) t,
    ];
    return Column(
      children: [
        const _PageTitle('Messages'),
        Expanded(
          child: store.threads.isEmpty
              ? _DaaymnEmpty(
                  body:
                      'This is where the magic happens. Make a match to start a Daaymn good conversation.',
                  action: 'Go to Discover',
                  onAction: () => store.goTab(0),
                )
              : ListView(
                  children: [
                    if (otms.isNotEmpty) ...[
                      const _SectionHeader('One-Time Messages'),
                      for (final t in otms) _row(context, store, t),
                    ],
                    if (matches.isNotEmpty) ...[
                      const _SectionHeader('Matches'),
                      for (final t in matches) _row(context, store, t),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, DemoStore store, DemoThread t) {
    final p = t.profile;
    final chat = store.chatOf(p);
    final unread = store.unread[p.id] ?? 0;
    final subtitle = chat.isEmpty
        ? 'New Match!'
        : '${chat.last.mine ? 'You: ' : ''}${chat.last.text}';
    final online =
        p.lastSeen != null &&
        DateTime.now().difference(p.lastSeen!).inMinutes < 5;
    return ListTile(
      minTileHeight: 72,
      leading: _demoAvatar(p.name, p.imageUrl!, 28),
      title: Row(
        children: [
          if (online) ...[
            Semantics(
              label: 'Online',
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          VerifiedBadge(profile: p, size: 14),
        ],
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.black87,
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: unread > 0
          ? Semantics(
              label: '$unread unread',
              excludeSemantics: true,
              child: CircleAvatar(
                key: ValueKey('unread-${p.id}'),
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            )
          : null,
      onTap: () => _open(context, t),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------- Chat (and a One-Time Message waiting for an answer) ----------

class DemoChat extends StatefulWidget {
  final Profile profile;
  const DemoChat({super.key, required this.profile});

  @override
  State<DemoChat> createState() => _DemoChatState();
}

class _DemoChatState extends State<DemoChat> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  DemoStore? _store;

  bool _isOtm(DemoStore store) =>
      store.threads.any((t) => t.otm && t.profile.id == widget.profile.id);

  @override
  void initState() {
    super.initState();
    // Opened from any route (the list, /chat): a match's thread is read now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = _StoreScope.of(context);
      store.openChat = widget.profile.id;
      if (!_isOtm(store)) store.markRead(widget.profile);
    });
  }

  @override
  void dispose() {
    if (_store?.openChat == widget.profile.id) _store!.openChat = null;
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _back() {
    if (_store?.openChat == widget.profile.id) _store!.openChat = null;
    Navigator.of(context).maybePop();
    _setAddress('/messages');
  }

  void _send(DemoStore store) {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    store.send(widget.profile, t);
    _text.clear();
    _focus.requestFocus();
  }

  Future<void> _accept(DemoStore store) async {
    store.acceptOtm(widget.profile);
    store.markRead(widget.profile);
    _setAddress('/chat');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "It's a Match!",
          style: TextStyle(fontFamily: 'Pacifico'),
        ),
        content: Text('You can now chat with ${widget.profile.name}.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _decline(DemoStore store) {
    store.declineOtm(widget.profile);
    _back();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = _StoreScope.of(context);
    _store = store;
    final profile = widget.profile;
    final messages = store.chatOf(profile);
    final typing = store.typing.contains(profile.id);
    final otm = _isOtm(store);
    final online =
        profile.lastSeen != null &&
        DateTime.now().difference(profile.lastSeen!).inMinutes < 5;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _gradient),
        ),
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: _back),
        titleSpacing: 0,
        title: Row(
          children: [
            _demoAvatar(profile.name, profile.imageUrl!, 16),
            const SizedBox(width: 10),
            Text(
              profile.name,
              style: const TextStyle(color: Colors.white, shadows: _shadow),
            ),
            const SizedBox(width: 6),
            VerifiedBadge(profile: profile, size: 18),
            if (online) ...[
              const SizedBox(width: 8),
              const Icon(Icons.circle, color: Colors.white, size: 10),
              const SizedBox(width: 4),
              const Text(
                'Online',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  shadows: _shadow,
                ),
              ),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => _snack(
              context,
              v == 'report'
                  ? 'In the app, this opens a report to the Daaymn team.'
                  : v == 'block'
                  ? 'In the app, this blocks ${profile.name}.'
                  : 'In the app, this unmatches you and ${profile.name}.',
            ),
            itemBuilder: (_) => [
              if (!otm)
                const PopupMenuItem(
                  value: 'unmatch',
                  child: ListTile(
                    leading: Icon(Icons.person_remove),
                    title: Text('Unmatch'),
                  ),
                ),
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  leading: Icon(Icons.flag),
                  title: Text('Report'),
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: ListTile(
                  leading: Icon(Icons.block),
                  title: Text('Block'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (otm)
            Container(
              width: double.infinity,
              color: const Color(0xFFFCE4F1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                '${profile.name} filled the heart to send you a One-Time Message. Accept to match and chat.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo chat: replies are scripted.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _demoAvatar(profile.name, profile.imageUrl!, 32),
                          const SizedBox(height: 16),
                          Text(
                            'You matched with ${profile.name}.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Say hi. Something about their photos is a good start.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (typing) _TypingBubble(name: profile.name),
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
                              borderRadius: BorderRadius.circular(16),
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
            child: otm
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(77),
                          spreadRadius: 2,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.delete_forever, size: 32),
                          label: const Text('Decline'),
                          onPressed: () => _decline(store),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.favorite, size: 32),
                          label: const Text('Accept Match'),
                          onPressed: () => _accept(store),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            focusNode: _focus,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(store),
                            decoration: const InputDecoration(
                              hintText: 'Send a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          height: 44,
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

/// Three dots fading in turn, in the shape of a received bubble.
class _TypingBubble extends StatefulWidget {
  final String name;
  const _TypingBubble({required this.name});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Semantics(
      label: '${widget.name} is typing…',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('typing'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 56,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    opacity:
                        0.3 +
                        0.7 *
                            max(
                              0.0,
                              sin((_c.value * 2 - i * 0.3) * pi).toDouble(),
                            ),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------- Settings ----------

class DemoSettings extends StatefulWidget {
  const DemoSettings({super.key});

  @override
  State<DemoSettings> createState() => _DemoSettingsState();
}

class _DemoSettingsState extends State<DemoSettings> {
  bool _ghost = false;
  String _theme = 'Light';

  void _pickTheme() {
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Theme'),
        children: [
          for (final t in ['Light', 'Dark', 'Daaymnbow Sprinkle'])
            ListTile(
              title: Text(t),
              trailing: t == _theme ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => _theme = t);
                Navigator.of(context).pop();
                if (t != 'Light')
                  _snack(
                    this.context,
                    'In the app, $t recolours every screen.',
                  );
              },
            ),
        ],
      ),
    );
  }

  void _inApp(String what) => _snack(context, 'In the app, $what.');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PageTitle('Settings'),
        Expanded(
          child: ListView(
            children: [
              const _SettingsHeader('Account'),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Sign Out'),
                onTap: () => _inApp('this signs you out'),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                textColor: Colors.red.shade700,
                title: const Text('Delete Account'),
                onTap: () => _inApp('this asks before deleting your account'),
              ),
              const Divider(),
              const _SettingsHeader('Verification'),
              const ListTile(
                leading: Icon(Icons.security),
                title: Text('Verify Your Profile'),
                subtitle: Text('Coming soon'),
              ),
              const Divider(),
              const _SettingsHeader('Core Preferences'),
              ListTile(
                leading: const Icon(Icons.person_search_outlined),
                title: const Text('Interests'),
                subtitle: const Text('Women'),
                onTap: () => _inApp('you choose who you see here'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Ghost Mode'),
                subtitle: const Text('Hide your online status from others'),
                value: _ghost,
                onChanged: (v) => setState(() => _ghost = v),
              ),
              const Divider(),
              const _SettingsHeader('Display'),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                subtitle: Text(_theme),
                onTap: _pickTheme,
              ),
              ListTile(
                leading: const Icon(Icons.font_download_outlined),
                title: const Text('Font'),
                subtitle: const Text('Default'),
                onTap: () => _inApp('you pick Default, Modern or Funky'),
              ),
              const Divider(),
              const _SettingsHeader('Support'),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification Settings'),
                onTap: () => _inApp('you choose which alerts you get'),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Invite a friend on WhatsApp'),
                subtitle: const Text('Sends them a link to get Daaymn'),
                onTap: () => _inApp('this opens WhatsApp with a link'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report a Problem'),
                onTap: () => _inApp('this sends a report to the team'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String text;
  const _SettingsHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// ---------- Store -> Reports (reached from Buy) ----------

class DemoStoreScreen extends StatefulWidget {
  const DemoStoreScreen({super.key});

  @override
  State<DemoStoreScreen> createState() => _DemoStoreScreenState();
}

class _DemoStoreScreenState extends State<DemoStoreScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this, initialIndex: 1);
  bool _breakdown = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _back() {
    Navigator.of(context).maybePop();
    final store = _StoreScope.of(context);
    _setAddress(_tabPaths[store.tab]);
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(onPressed: _back),
        title: const Text(
          'Store',
          style: TextStyle(
            fontFamily: 'Pacifico',
            color: Colors.white,
            shadows: _shadow,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withAlpha(204),
          indicatorColor: Colors.white,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.favorite), text: 'Likes'),
            Tab(icon: Icon(Icons.assessment), text: 'Reports'),
            Tab(icon: Icon(Icons.slow_motion_video), text: 'Freebies'),
            Tab(icon: Icon(Icons.lock_open), text: 'Unlock'),
            Tab(icon: Icon(Icons.star), text: 'Subs'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        // The Scaffold hands the app bar's height down as top padding; SafeArea keeps
        // the tabs' content below it.
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.zero,
            child: TabBarView(
              controller: _tabs,
              children: [
                _likesTab(store),
                _reportTab(),
                _elsewhere(
                  'Watch a short ad for a free like or a free day of infinite scrolling.',
                ),
                _elsewhere(
                  'Unlock Ghost Mode, Rewind and infinite scrolling for good.',
                ),
                _elsewhere(
                  'Subscribe for a monthly stack of likes and every report.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _elsewhere(String what) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        '$what\n\nPurchases happen in the app from Google Play.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          shadows: _shadow,
        ),
      ),
    ),
  );

  Widget _likesTab(DemoStore store) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'You have ${store.likes} likes',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          shadows: _shadow,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Each like says Daaymn to someone, or fills a heart one step.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 15, shadows: _shadow),
      ),
      const SizedBox(height: 24),
      // Live Google Play prices (.symbiot/DAAYMN-PRICES.md, 2026-10-08).
      for (final (pack, price) in const [
        ('1 Like', 'R2.29'),
        ('10 Likes', 'R22.99'),
        ('20 Likes', 'R45.99'),
      ])
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
            title: Text(
              pack,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Text(
              price,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onTap: () =>
                _snack(context, 'In the app, Google Play takes the payment.'),
          ),
        ),
    ],
  );

  Widget _reportTab() {
    Widget pill(String text, bool on, VoidCallback tap) => InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: tap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: on ? Colors.black.withAlpha(70) : null,
          border: Border.all(color: Colors.white.withAlpha(on ? 38 : 0)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Your Pro report',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: _shadow,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            pill(
              'SCORECARD',
              !_breakdown,
              () => setState(() => _breakdown = false),
            ),
            const SizedBox(width: 8),
            pill(
              'BREAKDOWN',
              _breakdown,
              () => setState(() => _breakdown = true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!_breakdown) _scorecard() else _breakdownView(),
      ],
    );
  }

  Widget _scorecard() => Card(
    elevation: 8,
    color: Colors.black.withValues(alpha: 0.22),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Semantics(
            label: 'Daaymn Score ${demoScore.toStringAsFixed(1)} out of 10',
            excludeSemantics: true,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.lightGreen,
                border: Border.all(
                  color: Colors.white.withAlpha(204),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.lightGreen.withAlpha(178),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    demoScore.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: _shadow,
                    ),
                  ),
                  const Text(
                    '/ 10',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      shadows: _shadow,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '#DaaymnScore',
            style: TextStyle(
              fontFamily: 'Pacifico',
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            demoReportHeadline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            demoReportBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _pillar('Popularity', demoPopularity),
              _pillar('Engagement', demoEngagement),
              _pillar('Safety', demoSafety, grade: demoSafetyGrade),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _pillar(String title, double score, {String? grade}) => Expanded(
    child: Column(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (grade != null)
          Text(
            'Grade: $grade',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
      ],
    ),
  );

  Widget _breakdownView() {
    Widget row(String label, double v, String what) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${v.toStringAsFixed(1)} / 10',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: v / 10,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text(
            what,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SCORE BREAKDOWN',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            row(
              'Popularity',
              demoPopularity,
              'How often people like you back.',
            ),
            row(
              'Engagement',
              demoEngagement,
              'How quickly and kindly you reply.',
            ),
            row(
              'Safety ($demoSafetyGrade)',
              demoSafety,
              'No reports against you, and respectful chats.',
            ),
            const Divider(height: 24),
            const Text(
              'How to Improve',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bolt),
              title: Text('Reply a little faster'),
              subtitle: Text('Answering within a day lifts Engagement most.'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Profile (edit your own, from the photo in the header) ----------

class DemoProfileEditor extends StatefulWidget {
  const DemoProfileEditor({super.key});

  @override
  State<DemoProfileEditor> createState() => _DemoProfileEditorState();
}

class _DemoProfileEditorState extends State<DemoProfileEditor> {
  late final DemoStore _store = _StoreScope.of(context);
  final _photoAttempt = <int, int>{};
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

  /// Fills the first empty slot with one of Sam's own photos not shown yet; never a repeat.
  void _add() {
    final p = _store.photos;
    final next = demoMyAllPhotos.where((u) => !p.contains(u)).firstOrNull;
    if (next == null) {
      _snack(context, "That's all your photos for now.");
      return;
    }
    p[p.indexOf(null)] = next;
    _store.changed();
  }

  /// Takes the photo out and closes the gap, so empty slots stay at the end.
  void _remove(int slot) {
    _store.photos
      ..removeAt(slot)
      ..add(null);
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
    _store.changed();
    _snack(context, 'Profile saved.');
  }

  void _back() {
    Navigator.of(context).maybePop();
    _setAddress(_tabPaths[_store.tab]);
  }

  @override
  Widget build(BuildContext context) {
    final store = _StoreScope.of(context);
    const label = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _gradient),
        ),
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: _back),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, shadows: _shadow),
        ),
      ),
      body: ListView(
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
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _slot(DemoStore store, int i) {
    final url = store.photos[i];
    if (url == null) {
      return Semantics(
        button: true,
        label: 'Add photo',
        child: InkWell(
          onTap: _add,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFEEE8EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Icon(Icons.add, color: Colors.black54)),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            key: ValueKey('$url#${_photoAttempt[i] ?? 0}'),
            image: demoImage(url),
            fit: BoxFit.cover,
            semanticLabel: i == 0 ? 'Your main photo' : 'Your photo ${i + 1}',
            errorBuilder: (_, _, _) => PhotoFallback(
              name: _store.name,
              onRetry: () async {
                await demoImage(url).evict();
                if (mounted) {
                  setState(
                    () => _photoAttempt[i] = (_photoAttempt[i] ?? 0) + 1,
                  );
                }
              },
            ),
          ),
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
