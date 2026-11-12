import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:daaymn/demo/demo_data.dart';
import 'package:daaymn/demo/demo_main.dart';
import 'package:daaymn/demo/demo_script.dart';
import 'package:daaymn/widgets/photo_fallback.dart';
import 'package:daaymn/widgets/profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => demoPhotosReady = Future.value());

  // Network photos can't load in tests; that's reported as an exception we ignore.
  Future<void> open(
    WidgetTester tester,
    String path, {
    bool photosReady = true,
    Size size = const Size(430, 900),
  }) async {
    // Made here, in the test's own zone, so its completion runs under the fake clock.
    if (photosReady) demoPhotosReady = Future.value();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DemoApp(initialPath: path));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
  }

  Finder tab(String label) => find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text(label),
  );

  testWidgets('the header and tabs are the shipped app\'s', (tester) async {
    await open(tester, '/');
    expect(find.text('Daaymn '), findsOneWidget);
    expect(
      find.textContaining('Likes Left!', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('24', findRichText: true), findsOneWidget);
    expect(find.text('Buy'), findsOneWidget);
    expect(find.byTooltip('Edit your profile'), findsOneWidget);
    expect(find.text('Dating, rated on respect'), findsNothing);

    // Five tabs with the app's icons; only the selected one shows its label.
    for (final icon in [
      Icons.search,
      Icons.favorite_outline,
      Icons.whatshot,
      Icons.chat_bubble_outline,
      Icons.settings,
    ]) {
      expect(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(icon),
        ),
        findsWidgets,
      );
    }
    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.items.map((i) => i.label), [
      'Discover',
      'Your Likes',
      'Liked You',
      'Messages',
      'Settings',
    ]);
    expect(bar.showUnselectedLabels, isFalse);
    // No invented screens.
    for (final gone in ['Score', 'Vibe', 'Matches', 'Profile']) {
      expect(tab(gone), findsNothing);
    }
  });

  testWidgets('Discover: title, named hourglass and refresh, no undo', (
    tester,
  ) async {
    await open(tester, '/');
    expect(find.text('Discover'), findsWidgets);
    expect(find.byTooltip('Discovery preferences'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsNothing);
    await tester.tap(find.byTooltip('Discovery preferences'));
    await settle(tester);
    expect(find.text('Discovery Preferences'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
  });

  testWidgets(
    'a like spends one; a plain like goes to Your Likes; Jessica matches',
    (tester) async {
      await open(tester, '/');
      expect(find.text('Isla, 28'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite));
      await settle(tester);
      expect(find.text('Alex, 30'), findsOneWidget);
      expect(find.textContaining('23', findRichText: true), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close)); // pass Alex
      await settle(tester);
      expect(find.text('Jessica, 26'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite)); // Jessica: mutual
      await settle(tester);

      await tester.tap(tab('Discover'));
      await tester.tap(find.byIcon(Icons.favorite_outline).last);
      await settle(tester);
      expect(find.text('Isla, 28'), findsOneWidget); // in Your Likes now
      expect(find.text('Jessica, 26'), findsNothing);

      await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
      await settle(tester);
      expect(find.text('Jessica'), findsOneWidget);
      expect(find.text('New Match!'), findsOneWidget);
    },
  );

  testWidgets('keyboard: right likes, left passes', (tester) async {
    await open(tester, '/');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text('Alex, 30'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(find.text('Jessica, 26'), findsOneWidget);
  });

  testWidgets('end of the deck: review your dislikes brings passes back', (
    tester,
  ) async {
    await open(tester, '/');
    for (var i = 0; i < demoDiscover.length; i++) {
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
    }
    expect(find.textContaining("You've seen everyone!"), findsOneWidget);
    await tester.tap(find.text('Review your dislikes'));
    await settle(tester);
    expect(find.text('Isla, 28'), findsOneWidget);
  });

  testWidgets('/discover/empty has the app\'s end card', (tester) async {
    await open(tester, '/discover/empty');
    expect(find.text('Daaymn!'), findsWidgets);
    expect(find.textContaining("You've seen everyone!"), findsOneWidget);
    await tester.tap(find.text('Review your dislikes'));
    await settle(tester);
    expect(find.text('Alex, 30'), findsOneWidget);
  });

  testWidgets('Discover shows its cards only once the photos are loaded', (
    tester,
  ) async {
    final photos = Completer<void>();
    demoPhotosReady = photos.future;
    addTearDown(() => demoPhotosReady = Future.value());
    await open(tester, '/', photosReady: false);
    expect(find.text('Isla, 28'), findsNothing);
    photos.complete();
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(find.text('Isla, 28'), findsOneWidget);
  });

  testWidgets('/liked-you: Hannah, like her back and she is in Messages', (
    tester,
  ) async {
    await open(tester, '/liked-you');
    expect(find.text('Liked You'), findsWidgets);
    expect(find.text('Hannah, 26'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite).first);
    await settle(tester);
    expect(find.text('Hannah, 26'), findsNothing);
    expect(find.text('Zara, 25'), findsOneWidget);
    expect(find.textContaining('23', findRichText: true), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
    await settle(tester);
    expect(find.text('Hannah'), findsOneWidget);
    expect(find.text('New Match!'), findsOneWidget);
  });

  testWidgets('/match lands on Liked You', (tester) async {
    await open(tester, '/match');
    expect(find.text('Hannah, 26'), findsOneWidget);
    expect(find.text("It's a Daaymn match!"), findsNothing);
  });

  testWidgets('/likes: fill the heart to 5/5, then send a One-Time Message', (
    tester,
  ) async {
    await open(tester, '/likes');
    expect(find.text('Your Likes'), findsWidgets);
    expect(find.text('Grace, 27'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('2 days remaining'), findsOneWidget);
    final heart = find.byKey(const ValueKey('heart-demo-grace'));
    await tester.tap(heart);
    await tester.pump();
    expect(find.text('4/5'), findsNWidgets(2)); // Grace's, and Naledi's
    await tester.tap(heart);
    await tester.pump();
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('Send Message'), findsOneWidget);
    expect(find.textContaining('22', findRichText: true), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Koeksisters on Saturday?');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Your Daaymn OTM has been sent!'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('/likes: the countdown sits inside the card, under the name', (
    tester,
  ) async {
    await open(tester, '/likes', size: const Size(390, 844));
    final card = tester.getRect(
      find.ancestor(of: find.text('Grace, 27'), matching: find.byType(Card)),
    );
    final name = tester.getRect(find.text('Grace, 27'));
    final chip = tester.getRect(find.text('2 days remaining'));
    expect(chip.top, greaterThanOrEqualTo(name.bottom));
    expect(chip.left, greaterThanOrEqualTo(card.left + 16));
    // The chip's box lines up with the name; its text sits 8 px inside it.
    expect(chip.left, closeTo(name.left + 8, 1));
  });

  testWidgets('a photo that fails to load shows an initial and a retry', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 375,
          child: PhotoFallback(name: 'Isla', onRetry: () => retried++),
        ),
      ),
    );
    expect(find.text('I'), findsOneWidget);
    expect(find.text("Photo didn't load. Tap to retry"), findsOneWidget);
    await tester.tap(find.byType(PhotoFallback));
    expect(retried, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.square(
          dimension: 56,
          child: PhotoFallback(name: 'grace', compact: true),
        ),
      ),
    );
    expect(find.text('G'), findsOneWidget);
    expect(find.textContaining("didn't load"), findsNothing);
  });

  testWidgets('/likes/otm opens with the message box ready', (tester) async {
    await open(tester, '/likes/otm');
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('Send your one-time message...'), findsOneWidget);
  });

  testWidgets('/vibe lands on Your Likes', (tester) async {
    await open(tester, '/vibe');
    expect(find.text('Grace, 27'), findsOneWidget);
    expect(find.text("What's your vibe?"), findsNothing);
  });

  testWidgets(
    '/messages: One-Time Messages first, then Matches, unread counts',
    (tester) async {
      await open(tester, '/messages');
      final otmHeader = tester.getTopLeft(find.text('One-Time Messages')).dy;
      final matchHeader = tester.getTopLeft(find.text('Matches')).dy;
      expect(otmHeader, lessThan(matchHeader));
      expect(find.text('David'), findsOneWidget);
      expect(find.text('Mia'), findsOneWidget);
      expect(find.text('Fiona'), findsOneWidget);
      expect(find.text('Noah'), findsOneWidget);
      expect(find.text('Daaymn, you had me at coffee.'), findsOneWidget);
      expect(find.text("You: I'm in. I'll bring the coffee."), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-demo-fiona')), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('New matches'), findsNothing);
    },
  );

  testWidgets('/matches lands on Messages', (tester) async {
    await open(tester, '/matches');
    expect(find.text('One-Time Messages'), findsOneWidget);
  });

  testWidgets('/messages/empty has the app\'s empty line', (tester) async {
    await open(tester, '/messages/empty');
    expect(
      find.textContaining('This is where the magic happens.'),
      findsOneWidget,
    );
  });

  testWidgets('an OTM: Accept Match shows It\'s a Match! and opens the chat', (
    tester,
  ) async {
    await open(tester, '/messages');
    await tester.tap(find.text('David'));
    await settle(tester);
    expect(find.text(demoOtmText), findsOneWidget);
    expect(find.text('Accept Match'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Accept Match'));
    await settle(tester);
    expect(find.text("It's a Match!"), findsOneWidget);
    expect(find.text('You can now chat with David.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('One-Time Messages'), findsNothing);
  });

  testWidgets('the deck has 12 different people, then the end card', (
    tester,
  ) async {
    expect(demoDiscover.length, 12);
    expect({for (final p in demoDiscover) p.id}.length, 12);
    expect(demoDiscover.skip(4).map((p) => p.name), [
      'Thandi',
      'Marco',
      'Lerato',
      'Kyle',
      'Priya',
      'Sipho',
      'Amy',
      'Johan',
    ]);
    await open(tester, '/');
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
    }
    expect(find.text('Johan, 38'), findsOneWidget);
    expect(find.text("Demo · AI-made photo"), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    expect(find.textContaining("You've seen everyone!"), findsOneWidget);
  });

  testWidgets('liking Kyle is a match, with a snack', (tester) async {
    await open(tester, '/');
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
    }
    expect(find.text('Kyle, 27'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite));
    await settle(tester);
    expect(
      find.text('You and Kyle matched. Say hi in Messages.'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.chat_bubble_outline).last);
    await settle(tester);
    expect(find.text('Kyle'), findsOneWidget);
    expect(find.text('New Match!'), findsOneWidget);
  });

  testWidgets('the demo tag is on Liked You and Your Likes cards', (
    tester,
  ) async {
    await open(tester, "/liked-you");
    expect(find.text("Demo · AI-made photo"), findsWidgets);
    await open(tester, '/likes');
    expect(find.text('Demo · AI-made photo'), findsWidgets);
    expect(find.text('Naledi, 30', skipOffstage: false), findsOneWidget);
    expect(find.text('1 day remaining', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the Welcome screen says everyone is made up', (tester) async {
    await open(tester, '/welcome');
    expect(
      find.text('Everyone here is made up. Photos are AI-made.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'every chat has the scripted strip; a reply arrives after a send',
    (tester) async {
      await open(tester, '/chat');
      expect(find.text('Demo chat: replies are scripted.'), findsOneWidget);
      final before = find.byType(Text).evaluate().length;
      await tester.enterText(find.byType(TextField), 'hey');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(find.text('hey'), findsOneWidget);
      expect(find.byKey(const ValueKey('typing')), findsNothing);
      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.byKey(const ValueKey('typing')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2100));
      tester.takeException();
      expect(find.byKey(const ValueKey('typing')), findsNothing);
      expect(find.byType(Text).evaluate().length, before + 2); // 'hey' + reply
    },
  );

  testWidgets('"are you real?" gets the honest line, word for word', (
    tester,
  ) async {
    await open(tester, '/chat');
    await tester.enterText(find.byType(TextField), 'are you real?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 2100));
    tester.takeException();
    expect(find.text(demoHonestLine), findsOneWidget);
  });

  testWidgets('leaving while the dots show: the reply lands unread', (
    tester,
  ) async {
    await open(tester, '/chat');
    await tester.enterText(find.byType(TextField), 'hey');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.byKey(const ValueKey('typing')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 2100));
    tester.takeException();
    expect(find.byKey(const ValueKey('unread-demo-fiona')), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  test(
    'replies: never the same line twice in a row, no repeats until used up',
    () {
      final used = <String>{};
      final rng = Random(1);
      String? last;
      for (var i = 0; i < 40; i++) {
        final r = demoReplyFor('demo-mia', 'hey', used, rng);
        expect(r, isNot(last));
        last = r;
      }
      expect(demoCueName('are you a bot?'), 'honest');
      expect(demoCueName('fuck off'), 'rude');
      expect(demoCueName('Coffee on Saturday'), 'plan');
      expect(demoReplyFor('demo-nobody', 'whatever', {}, rng), isNotEmpty);
      expect(demoHasScript('demo-kyle'), isTrue);
    },
  );

  testWidgets('/chat: Fiona, the app\'s menu, sending works', (tester) async {
    await open(tester, '/chat');
    expect(find.text('Send a message...'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'See you at 5');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.text('See you at 5'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Unmatch'), findsOneWidget);
  });

  testWidgets('a chat opened at /chat reads as read back on the list', (
    tester,
  ) async {
    await open(tester, '/chat');
    await tester.enterText(find.byType(TextField), 'Coffee sounds perfect.');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('You: Coffee sounds perfect.'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-demo-fiona')), findsNothing);
    expect(
      find.byKey(const ValueKey('unread-demo-david')),
      findsOneWidget,
    ); // his OTM
  });

  testWidgets('/settings: the app\'s sections; verification is coming soon', (
    tester,
  ) async {
    await open(tester, '/settings');
    for (final t in [
      'Sign Out',
      'Verify Your Profile',
      'Coming soon',
      'Ghost Mode',
      'Theme',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tap(find.text('Theme'));
    await settle(tester);
    expect(find.text('Daaymnbow Sprinkle'), findsOneWidget);
  });

  testWidgets('Buy opens Store -> Reports with the report card', (
    tester,
  ) async {
    await open(tester, '/');
    await tester.tap(find.text('Buy'));
    await settle(tester);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text(demoReportHeadline), findsOneWidget);
    expect(find.text('POPULARITY'), findsOneWidget);
    expect(find.text('Grade: A'), findsOneWidget);
    expect(find.textContaining('Top 15%'), findsNothing);
    await tester.tap(find.text('BREAKDOWN'));
    await tester.pump();
    expect(find.text('SCORE BREAKDOWN'), findsOneWidget);
    expect(find.text('Safety (A)'), findsOneWidget);
  });

  testWidgets('/score and /store open the Store on Reports', (tester) async {
    await open(tester, '/score');
    expect(find.text(demoReportHeadline), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('Buy'), findsOneWidget);
  });

  testWidgets('/welcome leads to Discover', (tester) async {
    await open(tester, '/welcome');
    await tester.tap(find.text('Start browsing'));
    await settle(tester);
    expect(find.byType(ProfileCard), findsOneWidget);
  });

  testWidgets('unknown address falls back to Discover', (tester) async {
    await open(tester, '/nope');
    expect(find.text('Isla, 28'), findsOneWidget);
  });

  List<String> photoUrls(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .map((i) => i.image)
      .whereType<CachedNetworkImageProvider>()
      .map((n) => n.url)
      .toList();

  testWidgets('the header photo opens Edit Profile; no vibes row', (
    tester,
  ) async {
    await open(tester, '/');
    await tester.tap(find.byTooltip('Edit your profile'));
    await settle(tester);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('My vibes'), findsNothing);
    expect(photoUrls(tester), demoMyPhotos);
  });

  testWidgets('profile: remove a photo, save', (tester) async {
    await open(tester, '/profile');
    expect(find.byIcon(Icons.add), findsNWidgets(4));
    await tester.tap(find.byTooltip('Remove photo').first);
    await tester.pump();
    expect(find.byIcon(Icons.add), findsNWidgets(5));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Profile saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('profile at 390: photo buttons take a tap outside the circle', (
    tester,
  ) async {
    await open(tester, '/profile', size: const Size(390, 844));
    final photo = tester.getRect(find.byType(Image).first);
    final remove = tester.getRect(find.byTooltip('Remove photo').first);
    expect(remove.size, const Size(44, 44));
    expect(remove.topRight, photo.topRight);
    final move = tester.getRect(find.byTooltip('Move earlier').first);
    expect(move.size, const Size(44, 44));

    final before = photoUrls(tester);
    await tester.tapAt(move.bottomLeft + const Offset(3, -3));
    await tester.pump();
    expect(photoUrls(tester), [before[1], before[0], ...before.sublist(2)]);
  });

  testWidgets('profile: Add puts in Sam\'s own photo, never a repeat', (
    tester,
  ) async {
    await open(tester, '/profile');
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();
    expect(photoUrls(tester), demoMyAllPhotos);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(photoUrls(tester), demoMyAllPhotos);
    expect(find.text("That's all your photos for now."), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  test('nobody else wears Sam\'s photos, and no face is two people', () {
    final people = [
      ...demoDiscover,
      ...demoLikedYou,
      ...demoMatches,
      demoOtmFrom,
      for (final l in demoYourLikes()) l.profile,
    ];
    final urls = [for (final p in people) ...p.imageUrls];
    expect(urls.toSet().intersection(demoMyAllPhotos.toSet()), isEmpty);
    expect(urls.toSet().length, urls.length);
  });
}
