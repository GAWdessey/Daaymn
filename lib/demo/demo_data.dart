import 'package:daaymn/globals.dart';

// Demo mode data: made-up people with AI-generated photos. Nothing here
// touches Supabase or Firebase. Photos are the public "seed-photos/ai" set;
// override the base with --dart-define=DEMO_PHOTO_BASE=<url or folder url>.
const demoPhotoBase = String.fromEnvironment(
  'DEMO_PHOTO_BASE',
  defaultValue: 'https://rrbsjmfwahaerkfhpegv.supabase.co/storage/v1/object/public/seed-photos/ai',
);

String demoPhoto(String name, int n) => '$demoPhotoBase/${name}_$n.jpg';

Profile _person(
  String key,
  String name,
  int age,
  String job,
  List<String> interests, {
  bool verified = false,
  bool online = true,
  String? bio,
}) {
  final urls = [for (var i = 1; i <= 3; i++) demoPhoto(key, i)];
  return Profile(
    id: 'demo-$key',
    name: name,
    age: age,
    bio: bio,
    imageUrl: urls.first,
    imageUrls: urls,
    likeCount: 6,
    isVerified: verified,
    jobTitle: job,
    interests: interests,
    lastSeen: online ? DateTime.now() : DateTime.now().subtract(const Duration(days: 1)),
  );
}

final demoDiscover = <Profile>[
  _person('isla', 'Isla', 28, 'Marine biologist', ['Diving', 'Books', 'Surf'], verified: true),
  _person('alex', 'Alex', 30, 'Software engineer', ['Climbing', 'Games', 'Tea']),
  _person('jessica', 'Jessica', 26, 'Photographer', ['Art', 'Road trips', 'Wine']),
  _person('ben', 'Ben', 34, 'Teacher', ['Football', 'Podcasts', 'Cooking'], verified: true),
  _person('chris', 'Chris', 31, 'Architect', ['Hiking', 'Jazz', 'Coffee']),
  _person('ethan', 'Ethan', 29, 'Pastry chef', ['Baking', 'Travel', 'Cinema']),
];

final demoMatches = <Profile>[
  _person('fiona', 'Fiona', 28, 'Vet', ['Dogs', 'Trail runs', 'Pottery'], verified: true),
  _person('grace', 'Grace', 27, 'Journalist', ['Poetry', 'Gigs', 'Cycling']),
];

final demoMatchPopup = _person('hannah', 'Hannah', 26, 'Illustrator', ['Anime', 'Plants', 'Vinyl'], verified: true);

class DemoMessage {
  final bool mine;
  final String text;
  const DemoMessage(this.mine, this.text);
}

const demoChat = <DemoMessage>[
  DemoMessage(false, 'Okay, your hiking photo is unfairly good.'),
  DemoMessage(true, 'Ha! That was a very lucky sunrise.'),
  DemoMessage(false, 'Lucky sunrise, or you got up at 4am?'),
  DemoMessage(true, 'Both. Coffee after? I know a place.'),
  DemoMessage(false, 'Daaymn, you had me at coffee.'),
];

const demoVibes = <String>[
  'Early bird', 'Night owl', 'Adventurer', 'Homebody', 'Foodie', 'Bookworm',
  'Gym rat', 'Music head', 'Creative', 'Gamer', 'Beach bum', 'Old soul',
];

// Daaymn Score pillars (same three the real report shows).
const demoScore = 8.4;
const demoPopularity = 8.9;
const demoEngagement = 7.6;
const demoSafety = 8.7;
const demoSafetyGrade = 'A';
