import 'package:daaymn/globals.dart';

// Demo mode data: made-up people with AI-generated photos. Nothing here
// touches Supabase or Firebase. Photos are the public "seed-photos/ai" set;
// override the base with --dart-define=DEMO_PHOTO_BASE=<url or folder url>.
const demoPhotoBase = String.fromEnvironment(
  'DEMO_PHOTO_BASE',
  defaultValue:
      'https://rrbsjmfwahaerkfhpegv.supabase.co/storage/v1/object/public/seed-photos/ai',
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
    lastSeen: online
        ? DateTime.now()
        : DateTime.now().subtract(const Duration(days: 1)),
  );
}

final demoDiscover = <Profile>[
  _person('isla', 'Isla', 28, 'Marine biologist', [
    'Diving',
    'Books',
    'Surf',
  ], verified: true),
  _person('alex', 'Alex', 30, 'Software engineer', [
    'Climbing',
    'Games',
    'Tea',
  ]),
  _person('jessica', 'Jessica', 26, 'Photographer', [
    'Art',
    'Road trips',
    'Wine',
  ]),
  _person('ben', 'Ben', 34, 'Teacher', [
    'Football',
    'Podcasts',
    'Cooking',
  ], verified: true),
  _person('chris', 'Chris', 31, 'Architect', ['Hiking', 'Jazz', 'Coffee']),
  _person('ethan', 'Ethan', 29, 'Pastry chef', ['Baking', 'Travel', 'Cinema']),
];

final demoMatchPopup = _person('hannah', 'Hannah', 26, 'Illustrator', [
  'Anime',
  'Plants',
  'Vinyl',
], verified: true);

// Fiona, Grace, David and Noah have chats going; Hannah is a new match with nothing said yet.
final demoMatches = <Profile>[
  _person('fiona', 'Fiona', 28, 'Vet', [
    'Dogs',
    'Trail runs',
    'Pottery',
  ], verified: true),
  _person('grace', 'Grace', 27, 'Journalist', ['Poetry', 'Gigs', 'Cycling']),
  _person('david', 'David', 31, 'Sound engineer', [
    'Vinyl',
    'Braai',
    'Mountain bikes',
  ]),
  // The "sam" photo set; the demo user is called Sam, so this person is Noah.
  _person('sam', 'Noah', 30, 'Paramedic', ['Surf', 'Coffee', 'Comedy']),
  demoMatchPopup,
];

/// Only a like on one of these people is a match; every other like just moves on.
const demoMutualIds = {'demo-jessica'};

/// The demo user's own profile: first photos filled, spare ones to add from.
const demoMyName = 'Sam';
const demoMyAge = 29;
const demoMyJob = 'Product designer';
final demoMyPhotos = [for (var i = 1; i <= 3; i++) demoPhoto('chris', i)];
final demoSparePhotos = [
  for (final k in ['ben', 'alex', 'ethan']) demoPhoto(k, 2),
];

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

/// Every chat the demo opens with, by match id, newest thread first.
final demoChats = <String, List<DemoMessage>>{
  'demo-fiona': demoChat,
  'demo-grace': const [
    DemoMessage(
      false,
      'You said you know the best koeksisters in Cape Town. Prove it.',
    ),
    DemoMessage(true, 'Bo-Kaap, Saturday morning. Bring an appetite.'),
    DemoMessage(true, 'Saturday market then?'),
  ],
  'demo-david': const [
    DemoMessage(true, 'A sound engineer who also braais? Go on.'),
    DemoMessage(
      false,
      'Ha, I mix records and boerewors. Gig at the Waiting Room on Friday?',
    ),
  ],
  'demo-sam': const [
    DemoMessage(false, 'Muizenberg or Big Bay?'),
    DemoMessage(true, 'Muizenberg, early, before the wind picks up.'),
    DemoMessage(false, 'Respect. Dawn patrol on Sunday?'),
    DemoMessage(true, "I'm in. I'll bring the coffee."),
  ],
};

/// When each thread's last message came in, as the list shows it.
const demoChatTimes = {
  'demo-fiona': '2m',
  'demo-grace': '1h',
  'demo-david': '3h',
  'demo-sam': 'Yesterday',
};

/// Threads whose last message you haven't read yet.
const demoUnread = {'demo-fiona', 'demo-david'};

const demoStartVibes = {'Adventurer', 'Foodie', 'Music head'};

const demoVibes = <String>[
  'Early bird',
  'Night owl',
  'Adventurer',
  'Homebody',
  'Foodie',
  'Bookworm',
  'Gym rat',
  'Music head',
  'Creative',
  'Gamer',
  'Beach bum',
  'Old soul',
];

// Daaymn Score pillars (same three the real report shows).
const demoScore = 8.4;
const demoPopularity = 8.9;
const demoEngagement = 7.6;
const demoSafety = 8.7;
const demoSafetyGrade = 'A';
const demoScoreNote =
    'Top 15% in Cape Town this week. Reply faster to raise Engagement.';
