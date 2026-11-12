import 'dart:io';

import 'package:daaymn/demo/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';

// Every photo the web demo shows must be in tool/seed-photos/ai/, which the
// upload-demo-photos workflow puts in the public seed-photos/ai/ bucket.
void main() {
  test('every demo photo is in tool/seed-photos/ai', () {
    final urls = <String>{
      for (final p in [
        ...demoDiscover,
        ...demoLikedYou,
        ...demoYourLikes().map((l) => l.profile),
        demoOtmFrom,
        ...demoMatches,
      ])
        ...p.imageUrls,
      ...demoMyAllPhotos,
    };
    expect(urls.length, greaterThan(60));
    final missing = [
      for (final u in urls)
        if (!File('tool/seed-photos/ai/${u.split('/').last}').existsSync()) u,
    ];
    expect(missing, isEmpty);
  });
}
