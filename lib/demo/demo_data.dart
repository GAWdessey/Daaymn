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
  _person('thandi', 'Thandi', 24, 'Architecture student', [
    'Sketching',
    'Jazz',
    'Hiking',
  ], verified: true),
  _person('marco', 'Marco', 33, 'Chef', ['Food markets', 'Padel', 'Wine']),
  _person('lerato', 'Lerato', 31, 'GP', ['Running', 'Brunch', 'Series']),
  _person('kyle', 'Kyle', 27, 'Electrician', ['Fishing', 'Rugby', 'Braai']),
  _person('priya', 'Priya', 29, 'Data analyst', [
    'Yoga',
    'Board games',
    'Curry',
  ]),
  _person(
    'sipho',
    'Sipho',
    36,
    'Architect',
    ['Jazz', 'Cycling', 'Coffee'],
    verified: true,
    online: false,
  ),
  _person('amy', 'Amy', 22, 'Barista', ['Thrifting', 'Indie music', 'Dogs']),
  _person('johan', 'Johan', 38, 'Winemaker', ['Hiking', 'Rugby', 'Dogs']),
];

/// Liked You: people who liked Sam first. Liking one back makes a match in Messages.
final demoLikedYou = <Profile>[
  _person('hannah', 'Hannah', 26, 'Illustrator', [
    'Anime',
    'Plants',
    'Vinyl',
  ], verified: true),
  _person('zara', 'Zara', 25, 'Nurse', ['Dance', 'Sushi', 'Beach']),
  _person('tom', 'Tom', 32, 'Pilot', [
    'Travel',
    'Golf',
    'Podcasts',
  ], verified: true),
];

/// Your Likes: people Sam liked who haven't liked back yet. Each fill of the heart
/// spends a like; at 5/5 Sam can send them a One-Time Message.
class DemoLiked {
  final Profile profile;
  int level;
  String
  left; // what the countdown tag reads: the like expires 3 days after it's sent
  bool open = false;
  DemoLiked(this.profile, this.level, this.left);
}

List<DemoLiked> demoYourLikes() => [
  DemoLiked(
    _person('grace', 'Grace', 27, 'Journalist', ['Poetry', 'Gigs', 'Cycling']),
    3,
    '2 days remaining',
  ),
  DemoLiked(
    _person('ethan', 'Ethan', 29, 'Pastry chef', [
      'Baking',
      'Travel',
      'Cinema',
    ]),
    1,
    '18h 20m remaining',
  ),
  DemoLiked(
    _person('naledi', 'Naledi', 30, 'Lawyer', ['Theatre', 'Wine', 'Tennis']),
    4,
    '1 day remaining',
  ),
];

/// One-Time Messages: David filled his heart for Sam and sent one line. Accepting it
/// makes a match ("It's a Match!") and opens the chat.
final demoOtmFrom = _person('david', 'David', 31, 'Sound engineer', [
  'Vinyl',
  'Braai',
  'Mountain bikes',
], online: false);
const demoOtmText =
    'A designer who surfs? I mix records and braai. Gig at the Waiting Room on Friday?';

// Fiona and Noah have chats going.
final demoMatches = <Profile>[
  _person('mia', 'Mia', 27, 'Florist', [
    'Markets',
    'Sea swims',
    'Film photography',
  ]),
  _person('fiona', 'Fiona', 28, 'Vet', [
    'Dogs',
    'Trail runs',
    'Pottery',
  ], verified: true),
  // The "sam" photo set; the demo user is called Sam, so this person is Noah.
  _person('sam', 'Noah', 30, 'Paramedic', ['Surf', 'Coffee', 'Comedy']),
];

/// Only a like on one of these people is a match; every other like goes to Your Likes.
const demoMutualIds = {'demo-jessica', 'demo-kyle'};

/// The demo user's own profile. Sam wears the "chris" photo set, which nobody in the
/// deck or the matches uses; he starts with two of its three photos, and Add puts in his own.
const demoMyName = 'Sam';
const demoMyAge = 29;
const demoMyJob = 'Product designer';
const demoMyLikes = 24;
final demoMyAllPhotos = [for (var i = 1; i <= 3; i++) demoPhoto('chris', i)];
final demoMyPhotos = demoMyAllPhotos.take(2).toList();

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
  'demo-mia': const [
    DemoMessage(false, 'Your coffee photo, is that Truth on Buitenkant?'),
    DemoMessage(true, 'It is. Best flat white in town.'),
    DemoMessage(false, 'Bold claim. Prove it on Saturday?'),
  ],
  'demo-fiona': demoChat,
  'demo-sam': const [
    DemoMessage(false, 'Muizenberg or Big Bay?'),
    DemoMessage(true, 'Muizenberg, early, before the wind picks up.'),
    DemoMessage(false, 'Respect. Dawn patrol on Sunday?'),
    DemoMessage(true, "I'm in. I'll bring the coffee."),
  ],
};

/// Unread messages per thread, as the Messages list counts them.
const demoUnread = {'demo-mia': 1, 'demo-fiona': 2};

// Store -> Reports: Sam's Pro report card (the same three pillars the real report shows).
const demoScore = 8.4;
const demoPopularity = 8.9;
const demoEngagement = 7.6;
const demoSafety = 8.7;
const demoSafetyGrade = 'A';
// The real report's words for a score of 8.0 to 8.9 (lib/services/report_service.dart).
const demoReportHeadline = "You're Hot Property.";
const demoReportBody =
    "Your profile is on fire and your game is strong. You're getting noticed for all the right reasons.";
