# Daaymn web demo: 12 more labelled demo people, and chats that answer back

Source: the plan on Reports, "Daaymn: plan for more demo profiles and a chat companion" (`.symbiot/DAAYMN-DEMO-PROFILES-AND-CHAT-COMPANION-PLAN.md`, steps 2 and 3). Code touched: `lib/demo/demo_data.dart`, `lib/demo/demo_main.dart`, `docs/index.html` (one line). Run with `tool/run_demo.sh`.

## The job
The web demo (`lib/demo/`) lets a visitor (a store reviewer, a possible user from the landing page, Garth showing it to someone) try Daaymn with no account. Today it runs dry fast: Discover has 4 cards, so the deck ends after four swipes, and in Messages you can type but nobody ever answers. Done looks like this: a visitor swipes through 12 people without hitting the end card, likes a few, gets a match, sends a message and sees a reply arrive a second or two later, the way a real chat feels. Every made-up person is visibly marked as a demo person with an AI-made photo, and every demo chat says its replies are scripted, so nobody is misled about who is on the other side.

## The bar
Tinder's and Hinge's own in-store demo videos and onboarding tours: a deck that never stalls in the first minute, a match moment, and a chat that feels alive (a typing indicator, then a reply that fits what you said). Bumble's "Bumble Bee" and Duolingo's scripted chats set the honesty bar: the scripted party is plainly labelled, it answers in character, and it says what it is when asked. People now expect: no dead ends in a demo, a reply within ~2 seconds, replies that refer to what you wrote, and no pretending a bot is a person.

## Who is in the demo (all in `lib/demo/demo_data.dart`, none in the live database)
Today: 11 people (Isla, Alex, Jessica, Ben on Discover; Hannah in Liked You; Grace and Ethan in Your Likes; David's One-Time Message; Fiona and Noah as matches; Sam is the visitor). Add these 12, for 23 in all (12 women, 10 men, plus Sam). Ages 22 to 38. Cape Town setting, like the existing chats (Muizenberg, braai, the Waiting Room).

Discover: 8 new, after Ben, alternating women and men so the deck stays mixed:
1. Thandi, 24, Architecture student · Sketching, Jazz, Hiking · verified
2. Marco, 33, Chef · Food markets, Padel, Wine
3. Lerato, 31, GP · Running, Brunch, Series
4. Kyle, 27, Electrician · Fishing, Rugby, Braai · **mutual: a like on Kyle is a match** (add `demo-kyle` to `demoMutualIds`, next to Jessica)
5. Priya, 29, Data analyst · Yoga, Board games, Curry
6. Sipho, 36, Architect · Jazz, Cycling, Coffee · verified · not online
7. Amy, 22, Barista · Thrifting, Indie music, Dogs
8. Johan, 38, Winemaker · Hiking, Rugby, Dogs

Liked You: 2 new, after Hannah: Zara, 25, Nurse · Dance, Sushi, Beach; Tom, 32, Pilot · Travel, Golf, Podcasts · verified.

Your Likes: 1 new, after Ethan: Naledi, 30, Lawyer · Theatre, Wine, Tennis · heart at 4 of 5 · "1 day remaining" (one more fill opens the One-Time Message box, so that flow is one tap away).

Matches: 1 new, first in the list (newest): Mia, 27, Florist · Markets, Sea swims, Film photography · 1 unread. Her opening chat:
- Mia: "Your coffee photo, is that Truth on Buitenkant?"
- Sam: "It is. Best flat white in town."
- Mia: "Bold claim. Prove it on Saturday?"

Photos: each new person needs 3 AI-made photos, made the same way as the existing set (`.symbiot/seed-photos-ai/SOURCE.md`, script `/mnt/storage/aiphotos/gen.py`: same face across the 3, adult, fully clothed, no lettering), uploaded as `seed-photos/ai/<key>_1.jpg` to `_3.jpg` (keys: thandi, marco, lerato, kyle, priya, sipho, amy, johan, zara, tom, naledi, mia). Add each to SOURCE.md. Do not create any profile, user or row in Supabase: only photos go to storage.

## Flows
In this round: 1, 2, 3, 4, 5, 6, 7.

1. **First use (Welcome).** Welcome shows "Daaymn", the tagline, then a new line under it: "Everyone here is made up. Photos are AI-made." Then "Start browsing".
2. **Browsing Discover.** The deck shows 12 cards in order (Isla, Alex, Jessica, Ben, then the 8 above). Each card has the demo tag in its top-left corner. Pass (✕ or ←) and Like (♥ or →) work as today. After the 12th card, the existing end card shows ("You've seen everyone! …" with "Review your dislikes"). Refresh and Review your dislikes work as today, over all 12.
3. **Getting a match.** Liking Jessica or Kyle makes a match: the snack "You and Kyle matched. Say hi in Messages." shows (same words as Liked You), the Messages badge goes up by 1, and Kyle appears at the top of Messages as "New Match!". Liking anyone else adds them to Your Likes with "3 days remaining", as today. Liking back Hannah, Zara or Tom in Liked You makes a match, as today.
4. **Chatting with a scripted reply.** Open any match (Mia, Fiona, Noah, or a new one). Under the app bar is the line "Demo chat: replies are scripted." Type and press Enter or the send button: your bubble appears at once, the field clears and keeps focus. About 1 to 2 seconds later (random in that range), a grey bubble with three animated dots appears on the left ("Mia is typing…" for screen readers). It shows for 1 to 2 seconds, then turns into the reply. If you send several messages before the reply lands, only one reply comes, timed from your last message.
5. **Leaving before the reply lands.** Go back to Messages while the dots show: the reply still arrives. The thread's row shows the reply text as its last line, its unread count becomes 1, and the Messages tab badge goes up by 1. Opening the thread clears it.
6. **One-Time Message, then chat.** David's One-Time Message works as today (Decline / Accept Match, "It's a Match!"). After Accept, the input appears; when you write to David, he replies by script like any match.
7. **Your Likes to One-Time Message.** Naledi's heart is at 4/5: fill it once and the box opens, as Grace's and Ethan's do today. Sending works as today (no reply: she hasn't matched you).

Not in this round: the real app's "Daaymn Coach" (plan step 4), hiding live seed profiles (plan step 1, already done in commit b1dd007), a working Pronouns filter in Discovery Preferences.

## How the scripted replies pick a line
- Each person who can become a match has their own script: Mia, Fiona, Noah, David, Jessica, Kyle, Hannah, Zara, Tom. 9 scripts.
- Each script has lines for these cues, checked in this order against the visitor's message (lower-cased): 
  1. **Are you real / a bot / AI** ("real", "bot", "ai", "fake", "human"): always the honest line: "I'm a demo profile, so my replies are scripted. In the app, this is a real person on the other end."
  2. **Rude or explicit** (a short block list): "Let's keep it friendly. In the app, you can report or block anyone from the ⋮ menu."
  3. **Greeting** (hi, hey, hello, howzit, sawubona, molo, hallo)
  4. **Plan** (coffee, drink, dinner, date, meet, weekend, friday, saturday, sunday, tonight, walk, hike, surf)
  5. **Compliment** (cute, beautiful, pretty, handsome, love your, nice photo, great smile)
  6. **Question** (ends with "?" or starts with what, where, how, why, do you, are you)
  7. **Laugh** (haha, lol, 😂)
  8. **Goodbye** (bye, night, later, cheers)
  9. **Anything else** (fallback)
- At least 4 lines per cue for cues 3 to 9, so 30 to 40 lines per person (cues 1 and 2 are shared, fixed lines). Lines speak in character and use the person's job and interests ("I'm at the market all morning, flowers don't buy themselves. Coffee after 12?").
- A line is not repeated in a thread until every line of that cue has been used.
- Lines are 1 to 2 short sentences, plain, warm, a bit playful, in the tone of the existing chats ("Daaymn, you had me at coffee."). No sexual content, no asking for personal details (number, address, socials), no money, no pressure to buy.
- All of this runs in the browser. No network call, no AI model.

## Screens
The demo always draws the phone layout; at 1440 wide it is the same ~430 px column, centred, on the light lilac background (as in `.symbiot/shots/r11/discover/`). So both wireframes below are that column; the 1440 version only adds the empty margins.

### Discover card (390 and inside the 1440 column)
```
┌──────────────────────────────────────┐
│ Daaymn | 24 Likes Left!   [Buy] (o)  │  gradient header (as today)
│ Discover                     ⌛  ⟳   │
│ ┌──────────────────────────────────┐ │
│ │ [Demo · AI-made photo]           │ │  ← NEW tag, top-left, 12 px in
│ │                                  │ │
│ │            photo                 │ │
│ │                                  │ │
│ │ ● Thandi, 24  ✓                  │ │
│ │ 🗂 Architecture student           │ │
│ │ (Sketching) (Jazz) (Hiking)      │ │
│ │                        (✕)  (♥)  │ │  ← main action: Like
│ └──────────────────────────────────┘ │
│  🔍   ♡   🔥¹   💬³   ⚙               │  bottom tabs (as today)
└──────────────────────────────────────┘
```
Tag: a pill, 12 px from the photo's top and left edges, height 24, padding 10 px sides, 12 px medium white text "Demo · AI-made photo", background black at 55% opacity, radius 12, like the interest chips but filled. It sits over the photo, the photo-failed fallback and the loading placeholder alike. The same tag goes on Liked You cards and on Your Likes cards (top-left of the photo). Avatars in Messages and the chat header are too small for it and get none.

### Chat (390 and inside the 1440 column)
```
┌──────────────────────────────────────┐
│ ←  (o) Mia  ● Online            ⋮    │  gradient app bar (as today), sticks
├──────────────────────────────────────┤
│ ⓘ Demo chat: replies are scripted.   │  ← NEW strip, sticks under the bar
├──────────────────────────────────────┤
│ ( Your coffee photo, is that Truth   │
│   on Buitenkant? )                   │
│              ( It is. Best flat      │
│                white in town. )      │
│ ( Bold claim. Prove it on Saturday?) │
│                  ( Saturday, 10? )   │  just sent
│ ( • • • )                            │  ← NEW typing bubble, then the reply
├──────────────────────────────────────┤
│ ( Send a message...          ) (➤)   │  input, sticks at bottom
└──────────────────────────────────────┘
```
Strip: full width, light grey (`Colors.grey.shade100`), 13 px text in grey 700 (at least 4.5:1), info icon 16 px, 8 px top and bottom. On a One-Time Message thread the existing pink strip stays and this strip goes under it.

Typing bubble: the same shape, colour and left alignment as a received bubble (grey 200, radius 16), 56 × 36, three 6 px dots in grey 600 fading in turn.

### Messages list (390 and inside the 1440 column)
As today, plus Mia's row at the top of the matches ("Bold claim. Prove it on Saturday?", 1 unread) and any new match rows ("New Match!"). A reply that lands while you're away updates the row's last line and adds 1 to its unread count.

### Welcome
As today, with one new line under the tagline, same style but 14 px and grey: "Everyone here is made up. Photos are AI-made."

### Landing page (`docs/index.html`)
One line under the screenshot strip (the `.shots` block), centred, small and grey: "Screens from the Daaymn demo. The people shown are made up and their photos are AI-made."

## States
- **Loading:** the existing deck placeholder (shimmer card) shows until the first photos load; the demo tag shows on it too. Precache the first photos of the first 4 cards as today, and the rest in the background so later cards don't flash.
- **Empty:** end of deck: the existing words ("You've seen everyone! Why not review your dislikes? You might have missed a Daaymn good one." and "Review your dislikes"). A new match with no messages: the existing "You matched with Kyle." / "Say hi. Something about their photos is a good start." The scripted strip shows above it.
- **Error:** a photo that fails to load: the existing fallback (initial on the gradient, "Photo didn't load. Tap to retry"), with the demo tag on top. A person with no script (should not happen): they reply from a shared fallback set, never stay silent.
- **Success:** a reply arrives; a match shows the snack "You and Kyle matched. Say hi in Messages."
- **Out of likes:** as today: "You're out of likes. Tap Buy to get more." (24 likes is enough to like all 12 and fill Naledi's heart.)
- **Reload:** the demo keeps nothing: a page reload starts again from the Welcome screen with the opening chats. This is as today.

## Words
- Tag on every demo card: **Demo · AI-made photo** (screen reader: "Demo profile, AI-made photo")
- Chat strip: **Demo chat: replies are scripted.**
- Typing (screen reader only): **Mia is typing…**
- Welcome line: **Everyone here is made up. Photos are AI-made.**
- Landing line: **Screens from the Daaymn demo. The people shown are made up and their photos are AI-made.**
- Match snack from Discover: **You and Kyle matched. Say hi in Messages.**
- Honest reply: **I'm a demo profile, so my replies are scripted. In the app, this is a real person on the other end.**
- Rude-message reply: **Let's keep it friendly. In the app, you can report or block anyone from the ⋮ menu.**

## Out of scope
- Daaymn Coach in the real app, and any AI model in the demo.
- Any change to the live app, its database or `public_profiles`; no new seed users.
- Making Discovery Preferences (Pronouns, Age Range) filter the deck.
- Saving demo state across reloads.
- Replies to One-Time Messages Sam sends from Your Likes (those people haven't matched him).
- Photos inside chats, voice notes, read receipts.

## Acceptance
- [ ] Discover shows 12 different people before the end card; the 5th to 12th are Thandi, Marco, Lerato, Kyle, Priya, Sipho, Amy, Johan, each with 3 photos that load (no fallback card at normal speed).
- [ ] Every card on Discover, Liked You and Your Likes has the "Demo · AI-made photo" pill in the photo's top-left, readable on both light and dark photos, at 390 and 1440.
- [ ] Liked You shows Hannah, Zara and Tom; Your Likes shows Grace, Ethan and Naledi (heart 4/5, "1 day remaining"); Messages lists Mia first among matches with 1 unread.
- [ ] Liking Kyle shows "You and Kyle matched. Say hi in Messages." and Kyle appears in Messages as "New Match!".
- [ ] Every chat shows "Demo chat: replies are scripted." under the app bar, including OTM threads (under the pink strip) and empty new matches.
- [ ] Sending "hey" to Mia shows three-dot typing within ~2 s, then a reply in Mia's voice; sending "are you real?" to anyone gets the honest scripted line word for word.
- [ ] Sending 5 messages in a row to one person gets 5 different replies or fewer, never the same line twice in a row.
- [ ] Leaving a chat while the dots show: the Messages row shows the reply and an unread count of 1.
- [ ] Welcome shows "Everyone here is made up. Photos are AI-made."; the landing page shows the line under the screenshots.
- [ ] 12 new photo sets exist at `seed-photos/ai/<key>_1..3.jpg` and are listed in SOURCE.md; no new rows in Supabase (`public_profiles` still returns the same count as before the change).
- [ ] Existing demo tests still pass, plus tests for: deck length 12, Kyle mutual match, the scripted strip, a reply arriving after a send, the honest line.
