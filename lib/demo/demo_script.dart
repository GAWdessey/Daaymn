import 'dart:math';

// Scripted replies for the web demo. Everything runs in the browser: no network
// call, no AI model. Each person who can become a match has their own lines per cue;
// the honest line and the rude-message line are shared and fixed.

enum DemoCue { greeting, plan, compliment, question, laugh, goodbye, other }

const demoHonestLine =
    "I'm a demo profile, so my replies are scripted. In the app, this is a real person on the other end.";
const demoRudeLine =
    "Let's keep it friendly. In the app, you can report or block anyone from the ⋮ menu.";

const _realWords = ['real', 'bot', 'ai', 'fake', 'human'];
const _rudeWords = [
  'fuck',
  'shit',
  'bitch',
  'slut',
  'whore',
  'sex',
  'nude',
  'nudes',
  'dick',
  'cock',
  'pussy',
  'horny',
  'bastard',
  'cunt',
  'idiot',
  'stupid',
  'ugly',
];
const _greetings = [
  'hi',
  'hey',
  'hello',
  'howzit',
  'sawubona',
  'molo',
  'hallo',
  'heita',
];
const _plans = [
  'coffee',
  'drink',
  'dinner',
  'date',
  'meet',
  'weekend',
  'friday',
  'saturday',
  'sunday',
  'tonight',
  'walk',
  'hike',
  'surf',
];
const _compliments = [
  'cute',
  'beautiful',
  'pretty',
  'handsome',
  'love your',
  'nice photo',
  'great smile',
];
const _questionStarts = ['what', 'where', 'how', 'why', 'do you', 'are you'];
const _laughs = ['haha', 'lol', '😂'];
const _goodbyes = ['bye', 'night', 'later', 'cheers'];

List<String> _words(String lower) =>
    RegExp(r"[a-z']+").allMatches(lower).map((m) => m.group(0)!).toList();

bool _hasWord(List<String> words, List<String> list) =>
    words.any(list.contains);

bool _hasPhrase(String lower, List<String> list) =>
    list.any((w) => RegExp('\\b${RegExp.escape(w)}').hasMatch(lower));

/// Which cue a visitor's message is. Returns null for the two fixed cues; see
/// [demoReplyFor] for those. Checked in the order the spec lists them.
String demoCueName(String text) {
  final lower = text.toLowerCase().trim();
  final words = _words(lower);
  if (_hasWord(words, _realWords)) return 'honest';
  if (_hasWord(words, _rudeWords)) return 'rude';
  if (_hasWord(words, _greetings)) return 'greeting';
  if (_hasPhrase(lower, _plans)) return 'plan';
  if (_hasPhrase(lower, _compliments)) return 'compliment';
  if (lower.endsWith('?') || _questionStarts.any(lower.startsWith)) {
    return 'question';
  }
  if (_laughs.any(lower.contains)) return 'laugh';
  if (_hasPhrase(lower, _goodbyes)) return 'goodbye';
  return 'other';
}

/// Picks the reply: a line of the cue that this thread hasn't used until all of that
/// cue's lines have been; never the same line twice in a row. [used] is the thread's
/// record of lines already sent (the caller keeps it).
String demoReplyFor(
  String personId,
  String text,
  Set<String> used,
  Random rng,
) {
  final cue = demoCueName(text);
  if (cue == 'honest') return demoHonestLine;
  if (cue == 'rude') return demoRudeLine;
  final lines =
      (_scripts[personId] ?? _sharedLines)[DemoCue.values.byName(cue)]!;
  var fresh = lines.where((l) => !used.contains(l)).toList();
  if (fresh.isEmpty) {
    // Every line of this cue has been used: start the cue again, but not on the
    // line that was sent last.
    final last = used.isEmpty ? null : used.last;
    used.removeAll(lines);
    fresh = lines.where((l) => l != last).toList();
  }
  final line = fresh[rng.nextInt(fresh.length)];
  used
    ..remove(line)
    ..add(line); // LinkedHashSet: the newest line goes last
  return line;
}

/// Lines for a person with no script (should not happen); never silent.
final _sharedLines = <DemoCue, List<String>>{
  DemoCue.greeting: [
    'Hey you! Good to hear from you.',
    "Hi! I was hoping you'd say something.",
    'Howzit! How is your day going?',
    'Hello! Nice to meet you properly.',
  ],
  DemoCue.plan: [
    "That sounds good to me. What time works?",
    "I'm in. Pick the place?",
    'Yes, let us do that. Somewhere with good coffee.',
    "Daaymn, you had me at that. I'm free this weekend.",
  ],
  DemoCue.compliment: [
    'Ha, thank you. That made my day.',
    "Stop it, you're making me blush.",
    'Kind of you to say. Your photos are great too.',
    "Thank you! I'll take that.",
  ],
  DemoCue.question: [
    'Good question. Let me think about it.',
    'Honestly, a bit of everything. You?',
    "Ha, I'd say yes. What about you?",
    'Depends on the day. Tell me yours first.',
  ],
  DemoCue.laugh: [
    "Glad that landed. I'm still smiling.",
    'Ha! You are funny.',
    'Okay, that one got me.',
    'Right? I could not help it.',
  ],
  DemoCue.goodbye: [
    'Chat soon. Have a good one!',
    'Night! Talk tomorrow?',
    'Later! This was fun.',
    'Cheers, speak soon.',
  ],
  DemoCue.other: [
    'Tell me more about that.',
    "Interesting. I didn't expect that from you.",
    'Ha, go on.',
    "I like where this is going. What else?",
  ],
};

DemoCue _c(String s) => DemoCue.values.byName(s);

Map<DemoCue, List<String>> _s(Map<String, List<String>> m) => {
  for (final e in m.entries) _c(e.key): e.value,
};

final _scripts = <String, Map<DemoCue, List<String>>>{
  'demo-mia': _s({
    'greeting': [
      'Hey you! Flowers are done for the morning. What are you up to?',
      "Hi! I'm elbow-deep in roses. Say something nice.",
      'Howzit! Perfect timing, I just sat down with a coffee.',
      "Hello! I'm at the market until noon, talk to me.",
    ],
    'plan': [
      "I'm at the market all morning, flowers don't buy themselves. Coffee after 12?",
      'Saturday works. I have a sea swim at 7, then I am yours.',
      "Yes! Truth on Buitenkant, you're buying. I'll bring a flower.",
      "I'm in. Bonus if there's a view of the water.",
    ],
    'compliment': [
      'Stop it, I smell like eucalyptus and I am very happy about it.',
      'Thank you! Sea swims do wonders for the skin.',
      'You are sweet. I took that photo on film, so you got lucky.',
      "Ha, noted. You're not bad yourself.",
    ],
    'question': [
      'Good question. Film photography, mostly. I am terrible with phones.',
      'Honestly? Peonies. Nothing else comes close.',
      'Sea swims, markets and a flat white. You?',
      "Depends on the day. Tell me yours and I'll tell you mine.",
    ],
    'laugh': [
      'Ha! My stall neighbour just heard me laugh.',
      "You are funny. I'm keeping you.",
      'Okay, that one made me snort.',
      "Right? Flowers don't laugh back, so thank you.",
    ],
    'goodbye': [
      'Chat later! Customers are lining up.',
      'Night! Dream of peonies.',
      'Cheers, see you Saturday maybe.',
      'Bye for now. Do not forget the coffee.',
    ],
    'other': [
      'Tell me more. I like where this is going.',
      'Interesting. I would have guessed something else.',
      'Ha, go on. I have a few minutes between bunches.',
      'Mhm. And then what happened?',
    ],
  }),
  'demo-fiona': _s({
    'greeting': [
      'Hey! I just got out of surgery, the dog is fine, I am fine.',
      'Hi you. Two Labradors and I say hello.',
      'Howzit! Perfect timing, I am on my break.',
      "Hello! I've been waiting for you to say something.",
    ],
    'plan': [
      "Coffee sounds good. I'll bring the dog if that's okay.",
      'Sunday trail run, then breakfast? I earned a big one.',
      'Saturday, yes! Pottery class in the morning, free after.',
      'Daaymn, you had me at coffee. Name a place.',
    ],
    'compliment': [
      'Thank you! The dogs like you already.',
      "That's kind. I'm covered in fur, but thank you.",
      'Stop it, I will blush in front of a patient.',
      "Ha, you're sweet. Your hiking photo is still unfair.",
    ],
    'question': [
      'Good question. Vet life is mostly cuddles and paperwork.',
      'I have two dogs and one very opinionated cat. You?',
      'Trail runs on weekends, pottery when it rains.',
      'Honestly? A bit of everything. Tell me yours first.',
    ],
    'laugh': [
      'Ha! The whole clinic heard me.',
      'You are funny. The dogs approve.',
      'Okay, that one got me.',
      "Right? I can't stop smiling now.",
    ],
    'goodbye': [
      'Chat soon! Duty calls.',
      'Night! Say hi to the sunrise for me.',
      'Cheers, have a good one.',
      'Later! Do not forget the coffee.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I didn't expect that.",
      'Ha, go on. I have ten minutes.',
      'I like where this is going. What else?',
    ],
  }),
  'demo-sam': _s({
    'greeting': [
      'Howzit! Wind is picking up, so I am inside for now.',
      'Hey, you. Dawn patrol still on?',
      'Hello! I was just checking the swell report.',
      "Hi! Perfect timing, I'm making coffee.",
    ],
    'plan': [
      'Sunday, 6am, Muizenberg. I will bring the wetsuit, you bring the coffee.',
      "I'm in. Surf first, breakfast after.",
      "Saturday works too if the wind plays nice.",
      'Daaymn, yes. Let us do the early session.',
    ],
    'compliment': [
      'Ha, thanks. Paramedics are tougher than we look.',
      "That's kind. I'm mostly salt and sunscreen.",
      "Stop it, you'll make my shift easier.",
      "Thank you! Your photos aren't bad either.",
    ],
    'question': [
      'Good question. Mostly surf, coffee and comedy shows.',
      "Honestly? Early mornings. You?",
      'Depends on the swell. Tell me yours first.',
      'I would say yes. What about you?',
    ],
    'laugh': [
      'Ha! You should do stand-up.',
      "Okay, that one got me. I'm still laughing.",
      'Right? Comedy is my second love after surf.',
      "You are funny. I'm keeping you.",
    ],
    'goodbye': [
      'Chat later! Shift starts soon.',
      'Night! Dream of glassy waves.',
      'Cheers, see you on the sand.',
      'Later! Do not forget the coffee.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I didn't expect that.",
      'Ha, go on. I have a long break.',
      'Mhm. And then what happened?',
    ],
  }),
  'demo-david': _s({
    'greeting': [
      'Hey! Soundcheck just finished, perfect timing.',
      "Hi you. I've got a record on, say something good.",
      'Howzit! Glad you accepted.',
      'Hello! The Waiting Room is calling.',
    ],
    'plan': [
      'Friday at the Waiting Room: I mix, you tell me what you think.',
      "Braai on Sunday? I'll bring the records.",
      "Yes! Doors are at 8, I'll put you on the list.",
      'Daaymn, you had me at gig. Friday it is.',
    ],
    'compliment': [
      'Ha, thank you. I only mix when someone is watching.',
      'Stop it, I will turn the volume up to hide my face.',
      "That's kind. You're not bad yourself.",
      "Thank you! I'll take it.",
    ],
    'question': [
      'Good question. Mostly vinyl, braai and mountain bikes.',
      'Honestly? A good bassline fixes most things.',
      'Sound engineer by day, DJ by night. You?',
      'Depends on the room. Tell me yours first.',
    ],
    'laugh': [
      'Ha! You are funny. Is that your real laugh?',
      'Okay, that one got me.',
      "Right? Comedy and records, my two loves.",
      "Glad that landed. I'm still smiling.",
    ],
    'goodbye': [
      'Chat soon! Load-in time.',
      'Night! I will play something slow for you.',
      'Cheers, see you Friday maybe.',
      'Later! Bring your good dancing shoes.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I did not expect that.",
      'Ha, go on. I am only plugging cables.',
      'I like where this is going. What else?',
    ],
  }),
  'demo-jessica': _s({
    'greeting': [
      'Hey! Golden hour is on, I am out with the camera.',
      "Hi you. I'm editing, but I have time for you.",
      'Howzit! Glad you said something.',
      'Hello! I was hoping this would happen.',
    ],
    'plan': [
      "Road trip to the West Coast on Saturday? I'll bring the camera.",
      'Coffee sounds good. Somewhere with great light.',
      "I'm in. Wine at sunset, then photos.",
      'Daaymn, you had me at road trip. When?',
    ],
    'compliment': [
      'Thank you! Photographers love being on this side of the lens.',
      "That's kind. The light did half the work.",
      "Stop it, I'll blush on camera.",
      "Ha, you're sweet. Your profile is nice too.",
    ],
    'question': [
      'Good question. I shoot people, sunsets and the occasional dog.',
      'Honestly? Art, road trips and a good glass of wine.',
      'Depends on the light. Tell me yours first.',
      "I'd say yes. What about you?",
    ],
    'laugh': [
      'Ha! You should be in front of the camera.',
      'Okay, that one made me snort.',
      'Right? I caught myself smiling at my phone.',
      "You are funny. I'm keeping you.",
    ],
    'goodbye': [
      'Chat later! Light is fading and I need that shot.',
      'Night! Dream of golden hour.',
      'Cheers, talk soon.',
      'Later! Do not forget the wine.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I'd love to photograph that.",
      'Ha, go on. I have a few minutes.',
      'Mhm. And then what happened?',
    ],
  }),
  'demo-kyle': _s({
    'greeting': [
      'Howzit! Just got off a job, the lights stay on.',
      'Hey you! Fire is going, say something.',
      "Hi! Glad you liked me back. Or first. I forget.",
      'Hello! Was just about to message you.',
    ],
    'plan': [
      'Braai on Saturday? I bring the wors, you bring the stories.',
      "Fishing at Kalk Bay on Sunday, if you're keen.",
      "I'm in. Rugby on first, then a drink?",
      'Daaymn, yes. Name a time.',
    ],
    'compliment': [
      'Ha, thanks. Mostly sparks and sunburn.',
      "That's kind. You are not bad yourself.",
      "Stop it, I'll burn the wors.",
      "Thank you! I'll take that.",
    ],
    'question': [
      'Good question. Electrician by day, braai master by night.',
      "Honestly? Fishing, rugby and a cold one.",
      'Depends on the weather. Tell me yours first.',
      'I would say yes. What about you?',
    ],
    'laugh': [
      'Ha! You are funny.',
      'Okay, that one got me.',
      'Right? I am still smiling.',
      "Glad that landed. You've got a good sense of humour.",
    ],
    'goodbye': [
      'Chat later! Another job to finish.',
      'Night! Dream of a big catch.',
      'Cheers, speak soon.',
      'Later! Do not forget the coals.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I didn't expect that.",
      'Ha, go on. I am only checking a fuse box.',
      'I like where this is going. What else?',
    ],
  }),
  'demo-hannah': _s({
    'greeting': [
      'Hey! I have ink on my fingers, say hi anyway.',
      'Hi you. Vinyl is spinning, perfect timing.',
      'Howzit! I was sketching your name, in a good way.',
      'Hello! Glad you liked me back.',
    ],
    'plan': [
      'Coffee sounds good. I will bring a sketchbook.',
      "Vinyl shop on Saturday, then lunch? I'll show you my favourites.",
      "I'm in. Somewhere with plants and good light.",
      'Daaymn, yes. When?',
    ],
    'compliment': [
      'Thank you! I draw faces, so that means a lot.',
      "That's kind. My plants say thanks too.",
      "Stop it, I'll blush and smudge the ink.",
      "Ha, you're sweet. Your photos are great.",
    ],
    'question': [
      'Good question. Illustration, anime and a lot of plants.',
      'Honestly? A good record and a quiet afternoon.',
      'Depends on the day. Tell me yours first.',
      "I'd say yes. What about you?",
    ],
    'laugh': [
      'Ha! You should be in my comic.',
      'Okay, that one got me.',
      "Right? I'm still smiling.",
      "You are funny. I'm keeping you.",
    ],
    'goodbye': [
      'Chat later! Deadline calls.',
      'Night! Dream of ink and vinyl.',
      'Cheers, talk soon.',
      'Later! Water your plants.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I'd draw that.",
      'Ha, go on. I have a few minutes.',
      'Mhm. And then what happened?',
    ],
  }),
  'demo-zara': _s({
    'greeting': [
      'Hey! Just off a night shift, say something fun.',
      'Hi you. I am on my break, perfect timing.',
      'Howzit! Glad you liked me back.',
      'Hello! I was hoping you would.',
    ],
    'plan': [
      'Beach on Sunday? I need sun after all these nights.',
      'Sushi on Friday, my treat if you dance.',
      "I'm in. Dance class first, then a drink?",
      'Daaymn, yes. When?',
    ],
    'compliment': [
      'Thank you! Nurses love a compliment after a long shift.',
      "That's kind. Your smile is nice too.",
      "Stop it, I'll blush at the nurses' station.",
      "Ha, you're sweet.",
    ],
    'question': [
      'Good question. Nursing, dancing and a lot of sushi.',
      'Honestly? Sunday beach and no alarm.',
      'Depends on the shift. Tell me yours first.',
      "I'd say yes. What about you?",
    ],
    'laugh': [
      'Ha! I needed that after my shift.',
      'Okay, that one got me.',
      'Right? I am still smiling.',
      "You are funny. I'm keeping you.",
    ],
    'goodbye': [
      'Chat later! Back on the ward.',
      'Night! Dream of beaches.',
      'Cheers, talk soon.',
      'Later! Do not forget the sunscreen.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I didn't expect that.",
      'Ha, go on. I have a few minutes.',
      'Mhm. And then what happened?',
    ],
  }),
  'demo-tom': _s({
    'greeting': [
      'Hey! Just landed. Perfect timing.',
      "Hi you. I'm at 30,000 feet, figuratively.",
      'Howzit! Glad you liked me back.',
      'Hello! I was hoping you would say something.',
    ],
    'plan': [
      'Golf on Saturday morning, then lunch? You can keep score.',
      "Coffee sounds good. I'm in town until Monday.",
      "I'm in. Somewhere with a view of the runway, ha.",
      'Daaymn, yes. When are you free?',
    ],
    'compliment': [
      'Thank you! Pilots love flattery on the ground.',
      "That's kind. You are not bad yourself.",
      "Stop it, I'll miss my gate.",
      "Ha, you're sweet.",
    ],
    'question': [
      'Good question. Flying, golf and too many podcasts.',
      'Honestly? Window seat, every time.',
      'Depends on the route. Tell me yours first.',
      "I'd say yes. What about you?",
    ],
    'laugh': [
      'Ha! You are funny. Smooth air ahead.',
      'Okay, that one got me.',
      'Right? I am still smiling.',
      "Glad that landed. I'm keeping you.",
    ],
    'goodbye': [
      'Chat later! Boarding soon.',
      'Night! Safe travels in your dreams.',
      'Cheers, talk soon.',
      'Later! Fasten your seatbelt.',
    ],
    'other': [
      'Tell me more about that.',
      "Interesting. I didn't expect that.",
      'Ha, go on. I have a layover.',
      'Mhm. And then what happened?',
    ],
  }),
};

/// People who can reply: the nine with scripts. Anyone else uses the shared set.
bool demoHasScript(String id) => _scripts.containsKey(id);
