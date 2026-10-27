# Critic's review of the Daaymn demo addresses: a verdict Garth can act on

## The job
This is for Garth, and through him for Marketing. The builder gave each screen of the Flutter
web demo its own address (`/`, `/discover`, `/match`, `/matches`, `/chat`, `/score`, `/vibe`).
The last review failed it on one point: the photos on `/` and `/match` weren't loaded when
capture took its picture. The fix for that (hold the first frame with `deferFirstFrame` until
the photos are precached) is a separate open task in `TASKS.md`. On 2026-10-24 it was **not in
the code yet**: there's no `deferFirstFrame` or `precacheImage` in `lib/demo/demo_main.dart` on
any branch. The critic judges whatever is there when it runs and changes nothing. Garth is done when one report answers
two questions in its first lines: **can Marketing run the capture now?** and **what does the demo
still lack next to Hinge or Bumble, and what should each gap be?** Every failed point names its
screenshot and the exact thing to build. "Wrong" never appears without "right" next to it.

The report gives two verdicts, kept apart so one doesn't bury the other:
1. **Addresses and capture:** the job that was built, judged against
   `.symbiot/design/new-job-give-each-screen-of-the-flutter-web-demo-its-own-add.md`.
2. **Demo against the Hinge/Bumble bar:** the flows and the visual standard in the task. The task
   says a missing flow fails it, so this verdict will most likely be **fail**. Each gap still
   needs its replacement written out (see Flows), so the fail can go straight to a builder.

## The bar
**Hinge**, with **Bumble** as a second reference. People now expect:
- One profile at a time, photo first, with name, age and job on the photo and a clear pass and
  like.
- A match moment that stops you, with two choices: keep going or send a message.
- A matches list where each row shows the *last message* and who sent it, and new matches set
  apart from conversations.
- A chat with the newest message at the bottom, a working input and a send button.
- Undo of the last pass (Tinder's Rewind, Bumble's Backtrack).
- A designed end-of-deck state ("You've seen everyone for now").
- A profile editor: photos, prompts, vibes.
- First use: a short intro before the first card.
- Bumble's and Hinge's Play-listing shots: one moment per picture, the photo fully loaded, and
  nothing grey or half-drawn.

## Flows
Shoot each one at 1440×900 and 390×844 with
`node "/home/odessey/.nvm/versions/node/v20.20.2/lib/node_modules/symbiot/index.mjs" shoot <url> --out .symbiot/shots/review/<name>`.
Click-through flows go in Chrome over DevTools, as in the last review. For each flow the
report says **present / missing / broken**, and for missing or broken it says what it should be.

**Verdict 1: addresses and capture (judged in this round)**
Every screen of the demo and its own address (from `_Start.of` in `lib/demo/demo_main.dart`):

| Screen | Address |
|---|---|
| Discover (first card) | `/` and `/discover` |
| First use | `/welcome` |
| Discover, end of deck | `/discover/empty` |
| Match pop-up | `/match` |
| Matches list | `/matches` |
| Matches, none yet | `/matches/empty` |
| Chat | `/chat` |
| Score | `/score` |
| Vibe | `/vibe` |
| Profile | `/profile` |
| Anything else (e.g. `/nope`) | shows Discover, address bar reads `/` |

1. **Direct open:** each address shows its screen on the first picture, photos in full, with no
   grey card, no fade and no black card behind the pop-up. `/nope` shows Discover and the
   address bar reads `/`.
2. **The capture itself:** `symbiot capture daaymn --url http://127.0.0.1:8099 --screens /match,/chat,/score,/vibe`
   gives five pictures in listing order (Discover, match, chat, Score, Vibe), each phone-shaped
   with every photo loaded. This is the check Marketing cares about, so the critic runs it and
   doesn't infer it from shoot.
3. **Moving around:** tapping a tab updates the address and a reload stays put; the chat's back
   arrow leads to `/matches`; "Keep browsing" leads to `/discover`; "Say hi" leads to `/chat`.
4. **No regressions:** `flutter test test/demo_app_test.dart` passes, and the release build
   (`tool/run_demo.sh`) compiles.

**Verdict 2: Hinge/Bumble flows (judged, not built, in this round)**
For each flow, what I expect the critic to find in today's code (`lib/demo/demo_main.dart`),
and what to write as the fix. The critic confirms each one on a screenshot before writing it.

| Flow | Expected today | What it should be (write this as the fix) |
|---|---|---|
| First use | Missing: opens straight to Isla's card | `/welcome`: one screen with the Daaymn logo, "Real people near you. Rated on how they treat each other.", and **Start browsing** → `/`. Not part of capture's set. |
| Browse | Present | Leave as is. |
| Like / pass | Present, but **every** like opens Hannah's match | Only a like on a card marked as a mutual like (say Jessica, the third card) shows the pop-up. Other likes just go to the next card. |
| Match | Present (`/match`) | Leave as is. |
| Undo | Missing | A small ↶ button to the left of ✕ on the card (40 px, grey outline). After a pass it brings back the last card; with nothing to undo it's greyed out. Toast: "Brought back Alex." |
| Empty: end of deck | Missing: after Ethan the last card just stays | Centred in the Discover body: a heart outline (64 px, muted), **"You've seen everyone for now"**, "New people show up every day.", and the button **See your matches** → `/matches`. Gets its own address, `/discover/empty`. |
| Empty: no matches | Missing | At `/matches/empty`: "No matches yet", "Like someone on Discover and they'll show up here.", button **Start browsing**. |
| Matches list | Present, but Fiona's preview reads "Coffee after? I know a place.", which is *your* message, not her last one | Preview shows the last message, prefixed with "You: " when it's yours: Fiona → "Daaymn, you had me at coffee." Grace and Hannah sit in a "New matches" row of avatars above "Messages". |
| Chat | Present, but the input is disabled, there's no send button, and "Say hi" to Hannah opens Fiona's script | Input enabled, with a send icon button (40 px, accent). Sending appends a right-hand bubble and clears the field; Enter sends. A new match (Hannah, Grace) opens to an empty chat: their avatar at 64 px, "You matched with Hannah today.", and the hint "Say something about her photos". |
| Profile edit | Missing | A fifth tab, **Profile** (`/profile`): your photo grid of 6 slots (add, remove, reorder), name and age, job, a "My vibes" row linking to `/vibe`, and **Save**. Vibe's "They show on your profile card" then has somewhere to point. |
| Keyboard | Expected missing | On Discover: ← passes, → likes, Backspace undoes. Esc closes the pop-up. Tab order reaches every button, with a visible focus ring (2 px accent). |
| Phone | Present | Check 40 px tap targets: the bottom-bar items, chips and ✕/♥. |

## Screens
The deliverable is the report, not a UI. Its layout:

**`.symbiot/UI-REVIEW.md`**
```
# <one line: "Addresses pass: Marketing can capture now" | "Addresses must change: <what>">

## Verdict 1: addresses and capture: PASS | FAIL
- each address → what showed, screenshot path
- capture tray: 5 pictures, listing order, paths
- what must change (numbered, each with the fix)

## Verdict 2: the demo against Hinge/Bumble: PASS | FAIL
### Missing flows        (table: flow | screenshot | what it should be)
### Visual standard      (headline, one primary action, 4/8 spacing, type, colour, content)
### Notes, not blocking

## Screenshots
(list grouped by address, then the flow-*.png click-through shots)
```

**`.symbiot/ui-verdict.json`**: as `UI-CRITIC.md` lays it out. Two items: the address job,
exactly as listed in `UI-CRITIC.md`, with pass/fail and fixes; and the demo-flows item, with each
missing flow as one fix string phrased "screen, what's wrong, what it should be".

What the visual standard should find. I saw these on 2026-10-24 in
`.symbiot/shots/design/<address>/`; the critic re-checks them on their own shots.
- **Discover, 1440 and 390:** the card floats with ~140 px of empty white above and below. Hinge
  pins the card to the top under the bar. Fix: align the card to the top with 16 px padding, and
  let the photo take the freed height.
- **Discover, 1440:** Isla's blue verified tick shows at 390 but not at 1440. It should show at
  both.
- **The headline:** "Daaymn | Demo profiles" says it's a demo, but not what Daaymn is or who it's
  for. Fine for listing shots (Play adds its own caption), so it's a note, not a fail.
- **Matches, 390:** two rows, then 650 px of white. Fixed by the "New matches" row plus
  "Messages" above.
- **Chat:** the input looks disabled (grey hint, no send). That's the fix in Flows.
- **Colour:** gradient #FC00FF → #00DBDE; accent is the Material seed's mauve (#8B4A5E-ish) on the
  bubbles, "Say hi" and the bars. Check white text on the light-cyan end of the gradient bar
  ("Demo profiles" sits over the left, pink end, which is fine; the chat's name sits further right).
  Check the grey bottom-bar icons against #FFF8F8 for 3:1 non-text contrast.
- **Type:** the app bar mixes Pacifico 24, 20 and 16 bold; Vibe uses 28 bold; Score uses 72. The
  hero numbers are fine. Body text should be 14–16.

## States
How each state should show in the report:
- **Precache fix not built yet** (`grep deferFirstFrame lib/demo/demo_main.dart` finds nothing):
  still shoot and capture everything. If the capture pictures of `/` or `/match` show a grey or
  black card, verdict 1 is **FAIL**, titled "Must change: / and /match: photos not loaded at
  capture". Its fix is the open precache task, written out: `deferFirstFrame`, `precacheImage`
  with `CachedNetworkImageProvider` for Isla, Hannah and the match avatars, a 4 s timeout, then
  `allowFirstFrame`. Don't give a pass just because the shots taken later look fine.
- **Demo not running:** start it with `tool/run_demo.sh` and say so in one line. Don't fail it.
- **A shot that came out grey or late:** re-shoot it with `capture` (which waits for the network)
  before failing it. If capture is clean and shoot isn't, it's the tool, not the app: note it
  under "Notes" and point to the shoot-settle suggestion in `QUESTIONS.md`.
- **Pass:** title "Addresses pass: Marketing can capture now", plus the exact capture command.
- **Fail:** title names the screen and the problem, e.g. "Must change: /chat shows Fiona's
  script for Hannah".
- **Empty / loading / error states inside the demo:** judged as flows (above). Missing = listed
  with its replacement.

## Words
Report titles, word for word:
- Pass: **Addresses pass: Marketing can capture now**
- Fail: **Must change: \<screen\>: \<what\>**
- Verdict 2 heading when flows are missing: **The demo against Hinge: FAIL: \<n\> flows missing**

The demo copy that the fixes above propose, word for word:
- End of deck: **You've seen everyone for now** / "New people show up every day." / **See your matches**
- No matches: **No matches yet** / "Like someone on Discover and they'll show up here." / **Start browsing**
- New-match chat: "You matched with Hannah today." / hint **Say something about her photos**
- Undo toast: "Brought back Alex."
- Matches sections: **New matches**, **Messages**; preview prefix **You: **
- Welcome: "Real people near you. Rated on how they treat each other." / **Start browsing**
- Profile tab: **Profile**, **My vibes**, **Save**

## Out of scope
- Any code change by the critic. It judges; Symbiot routes the fixes.
- Building the verdict-2 flows. They're specified here so the fail is actionable, and they get
  built in a later round on Garth's say-so.
- Real backend, sign-in, the real app's routing (`lib/main.dart`), and dark mode (the demo has
  no dark theme).
- Browser Back/Forward through tab history (out of scope in the address spec).
- The Play-listing upload itself.

## Acceptance
Check these on the report and its screenshots:
- [ ] The report's first line says whether Marketing can capture now.
- [ ] The report says whether the precache fix is in the code (yes or no, and the commit if yes).
- [ ] Two separate verdicts: addresses and capture, and demo against Hinge/Bumble.
- [ ] A screenshot at 1440×900 and 390×844 exists in `.symbiot/shots/review/` for every address,
      including `/discover` and `/nope`.
- [ ] A real `symbiot capture` run is listed, with its 5 picture paths, and every photo in them
      is fully loaded (no grey card on `/`, no black card behind `/match`).
- [ ] Every flow in the Flows table is marked present, missing or broken, with a screenshot path.
- [ ] Every missing or broken item has a "should be" with real words and sizes, not just "add X".
- [ ] The matches-preview mismatch (Fiona's row showing your own line) and "Say hi" opening
      Fiona's script are both reported.
- [ ] `flutter test test/demo_app_test.dart` result and the release-build result are quoted.
- [ ] `.symbiot/ui-verdict.json` is valid JSON with both items, and every fix names a screen.
- [ ] No code under `lib/` or `test/` was changed by the critic (`git diff --stat` matches the
      builder's).
