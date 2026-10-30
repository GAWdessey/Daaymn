import 'dart:async';

import 'package:daaymn/demo/demo_data.dart';
import 'package:daaymn/demo/demo_main.dart';
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
  }) async {
    // Made here, in the test's own zone, so its completion runs under the fake clock.
    if (photosReady) demoPhotosReady = Future.value();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DemoApp(initialPath: path));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
  }

  testWidgets('demo app shows the app bar line and every key screen', (
    tester,
  ) async {
    await open(tester, '/');
    expect(find.text('Dating, rated on respect'), findsOneWidget);

    // Every tab shows its label, not just the selected one.
    for (final label in ['Discover', 'Matches', 'Score', 'Vibe', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Score'));
    await tester.pump();
    expect(find.text('SCORE BREAKDOWN'), findsOneWidget);

    await tester.tap(find.text('Vibe'));
    await tester.pump();
    expect(find.text("What's your vibe?"), findsOneWidget);
  });

  testWidgets('starts on /score', (tester) async {
    await open(tester, '/score');
    expect(find.text('SCORE BREAKDOWN'), findsOneWidget);
    expect(find.text('Dating, rated on respect'), findsOneWidget);
    expect(find.text('Daaymn Score'), findsOneWidget); // page heading
    expect(find.text('Safety · A grade'), findsOneWidget);
    expect(
      find.textContaining('Reply faster to raise Engagement'),
      findsOneWidget,
    );
  });

  testWidgets('/vibe counts picks and has a Save vibes button', (tester) async {
    await open(tester, '/vibe');
    expect(find.text('3 of 5 picked'), findsOneWidget);
    await tester.tap(find.text('Bookworm'));
    await tester.pump();
    expect(find.text('4 of 5 picked'), findsOneWidget);
    await tester.tap(find.text('Save vibes'));
    await tester.pump();
    expect(find.text('Vibes saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('starts on /match with the pop-up open', (tester) async {
    await open(tester, '/match');
    expect(find.text("It's a Daaymn match!"), findsOneWidget);
    expect(find.text('Keep browsing'), findsOneWidget);
    // Full screen, both faces: yours and hers; Isla's card isn't behind it.
    expect(find.bySemanticsLabel('Your photo'), findsOneWidget);
    expect(find.bySemanticsLabel("Hannah's photo"), findsOneWidget);
    expect(find.text('Isla, 28'), findsNothing);
  });

  testWidgets('starts on /chat with Fiona open and a way back', (tester) async {
    await open(tester, '/chat');
    await tester.pump();
    expect(find.text('Type a message'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('unknown address falls back to Discover', (tester) async {
    await open(tester, '/nope');
    expect(find.text('Dating, rated on respect'), findsOneWidget);
  });

  testWidgets('Discover shows its cards only once the photos are loaded', (
    tester,
  ) async {
    final photos = Completer<void>();
    demoPhotosReady = photos.future;
    addTearDown(() => demoPhotosReady = Future.value());
    await open(tester, '/', photosReady: false);
    expect(find.byType(ProfileCard), findsNothing);
    photos.complete();
    await tester.pump();
    await tester.pump();
    tester.takeException();
    expect(find.byType(ProfileCard), findsWidgets);
  });

  testWidgets('placeholder card shows while photos load', (tester) async {
    demoPhotosReady = Completer<void>().future;
    addTearDown(() => demoPhotosReady = Future.value());
    await open(tester, '/', photosReady: false);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('/welcome leads to Discover', (tester) async {
    await open(tester, '/welcome');
    expect(
      find.text('Real people near you. Rated on how they treat each other.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Start browsing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
    expect(find.byType(ProfileCard), findsOneWidget);
  });

  testWidgets(
    'a plain like moves on; only Jessica is a match; undo brings a pass back',
    (tester) async {
      await open(tester, '/');
      expect(find.text('Isla, 28'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.text("It's a Daaymn match!"), findsNothing);
      expect(find.text('Alex, 30'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close)); // pass Alex
      await tester.pump();
      tester.takeException();
      expect(find.text('Jessica, 26'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pump();
      tester.takeException();
      expect(find.text('Alex, 30'), findsOneWidget);
      expect(find.text('Brought back Alex.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      tester.takeException();
      await tester.tap(find.byIcon(Icons.favorite)); // Jessica
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.text("It's a Daaymn match!"), findsOneWidget);
      expect(find.text('You and Jessica liked each other.'), findsOneWidget);
    },
  );

  testWidgets('keyboard: right likes, left passes, backspace undoes', (
    tester,
  ) async {
    await open(tester, '/');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    tester.takeException();
    expect(find.text('Alex, 30'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    tester.takeException();
    expect(find.text('Jessica, 26'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    tester.takeException();
    expect(find.text('Alex, 30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('end of the deck and empty matches', (tester) async {
    await open(tester, '/discover/empty');
    expect(find.text("You've seen everyone for now"), findsOneWidget);
    await tester.tap(find.text('See your matches'));
    await tester.pump();
    tester.takeException();
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('matches empty state', (tester) async {
    await open(tester, '/matches/empty');
    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets('matches list: her last message, New matches row', (
    tester,
  ) async {
    await open(tester, '/matches');
    expect(find.text('Daaymn, you had me at coffee.'), findsOneWidget);
    expect(find.text('New matches'), findsOneWidget);
    expect(find.text('Hannah'), findsOneWidget);
  });

  testWidgets('matches list: four threads with times; unread rows have a dot', (
    tester,
  ) async {
    await open(tester, '/matches');
    for (final name in ['Fiona, 28', 'Grace, 27', 'David, 31', 'Noah, 30']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('You: Saturday market then?'), findsOneWidget);
    for (final t in ['2m', '1h', '3h', 'Yesterday']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('unread-dot')), findsNWidgets(2));
    await tester.tap(find.text('Fiona, 28'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
  });

  testWidgets('Discover: Undo, Pass and Like sit on their own row below the chips', (
    tester,
  ) async {
    await open(tester, '/');
    final chipBottom = tester.getBottomLeft(find.text('Surf')).dy;
    final undoTop = tester.getTopLeft(find.byTooltip('Undo')).dy;
    expect(undoTop, greaterThan(chipBottom));
  });

  testWidgets('chat sends; a new match opens empty', (tester) async {
    await open(tester, '/chat');
    await tester.enterText(find.byType(TextField), 'See you at 5');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    tester.takeException();
    expect(find.text('See you at 5'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Say hi opens an empty chat with the new match', (tester) async {
    await open(tester, '/match');
    await tester.tap(find.text('Say hi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
    expect(find.text('You matched with Hannah today.'), findsOneWidget);
    expect(find.text('Say something about her photos'), findsOneWidget);
  });

  testWidgets('profile tab: remove a photo, save', (tester) async {
    await open(tester, '/profile');
    expect(find.text('YOUR PHOTOS'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNWidgets(4));
    await tester.tap(find.byTooltip('Remove photo').first);
    await tester.pump();
    tester.takeException();
    expect(find.byIcon(Icons.add), findsNWidgets(5));
    await tester.scrollUntilVisible(
      find.text('Save'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Profile saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('profile at 390: photo buttons take a tap outside the circle', (
    tester,
  ) async {
    await open(tester, '/profile');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    tester.takeException();

    List<String> urls() => tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<NetworkImage>()
        .map((n) => n.url)
        .toList();

    // The 28 px circles sit 8 px in from the photo's corners.
    final photo = tester.getRect(find.byType(Image).first);
    final remove = tester.getRect(find.byTooltip('Remove photo').first);
    expect(remove.size, const Size(44, 44));
    expect(remove.topRight, photo.topRight);
    final move = tester.getRect(find.byTooltip('Move earlier').first);
    expect(move.size, const Size(44, 44));

    // 3 px inside each hit area's corner is outside its circle.
    final before = urls();
    await tester.tapAt(move.bottomLeft + const Offset(3, -3));
    await tester.pump();
    tester.takeException();
    expect(urls(), [before[1], before[0], ...before.sublist(2)]);

    await tester.tapAt(remove.topRight + const Offset(-3, 3));
    await tester.pump();
    tester.takeException();
    expect(find.byIcon(Icons.add), findsNWidgets(5));
    expect(urls(), [before[0], ...before.sublist(2)]);
  });

  testWidgets('profile: Add puts in Sam\'s own photo; Remove closes the gap', (
    tester,
  ) async {
    await open(tester, '/profile');
    List<String> urls() => tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<NetworkImage>()
        .map((n) => n.url)
        .toList();
    expect(urls(), demoMyPhotos);

    await tester.tap(find.byIcon(Icons.add).last); // any empty slot
    await tester.pump();
    tester.takeException();
    expect(urls(), demoMyAllPhotos);

    // Remove the first: the other two move up, and the empty slots stay at the end.
    await tester.tap(find.byTooltip('Remove photo').first);
    await tester.pump();
    tester.takeException();
    expect(urls(), demoMyAllPhotos.sublist(1));
    final lastPhoto = tester.getRect(find.byType(Image).last);
    final firstEmpty = tester.getRect(find.byIcon(Icons.add).first);
    expect(firstEmpty.left, greaterThan(lastPhoto.right));
    expect(firstEmpty.top, lessThan(lastPhoto.bottom));
  });

  test('the Discover deck and the matches never show Sam\'s own photos', () {
    final others = {
      for (final p in [...demoDiscover, ...demoMatches]) ...p.imageUrls,
    };
    expect(others.intersection(demoMyAllPhotos.toSet()), isEmpty);
  });

  testWidgets('a chat opened at /chat reads as read back on the list', (
    tester,
  ) async {
    await open(tester, '/chat');
    await tester.enterText(find.byType(TextField), 'Coffee sounds perfect.');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    tester.takeException();
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
    expect(find.text('You: Coffee sounds perfect.'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget); // David's only
  });
}
