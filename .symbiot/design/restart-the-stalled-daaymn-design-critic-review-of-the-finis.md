# Daaymn demo: the critic's closing pass, one verdict for the whole demo

## The job
This is for Garth, and through him for Marketing's Play-listing shots. The demo UI work is built, but nothing has closed it. The critic last looked at the whole demo on 2026-10-24 (round 2, `.symbiot/UI-REVIEW-round2.md`). Rounds 3–5 only looked at /profile, and round 5 passed it on 2026-10-27 (`.symbiot/UI-REVIEW.md`). No critic has ever written `.symbiot/ui-verdict.json`, the file Symbiot reads to close or return work, so the work has sat unjudged as far as Symbiot can tell. The "addresses and capture" verdict from the critic brief (`.symbiot/design/act-as-symbiot-s-design-critic-for-the-daaymn-lane-judge-the.md`) has never been given.

Done means that in one sitting the critic:
- judges the demo as it is at HEAD,
- writes `.symbiot/ui-verdict.json` and `.symbiot/UI-REVIEW.md`,
- answers one question in its first line: **can Marketing capture the Play-listing shots now?**

Every fail comes with what it should be. If the critic can't run the demo, that is a verdict too. The review must never stall again without a file saying why.

What's there now (checked 2026-10-30):
- Nothing under `lib/demo/` has changed since `79e133d` (2026-10-24). The only UI-adjacent change since is `lib/notification_provider.dart` (the Liked You badge, real app, not the demo).
- The first-frame photo fix is in: `precacheDemoPhotos()` with a timeout (`lib/demo/demo_main.dart:26-33`) and `fadeInDuration: imageFadeIn` (`lib/widgets/profile_card.dart:63`).
- All eleven addresses are routed (`lib/demo/demo_main.dart:110-129`).
- No demo server is running. Start one with `tool/run_demo.sh <port>`.

## The bar
**Hinge** (Bumble second), and their Play-listing shots. People expect:
- one profile at a time, photo first, and a clear pass and like;
- undo of the last pass;
- a match moment with "keep going" or "message";
- a matches list showing each row's last message, with new matches kept apart;
- a working chat;
- a profile editor;
- a short first-use intro;
- a designed end of deck.

In the listing shots, each picture shows one moment, every photo is fully loaded, and nothing is grey or half-drawn. Round 2 shots show the demo near this bar: `.symbiot/shots/review/r2/home/home-390x844.png` has Isla full-strength, undo/pass/like on their own row, and the "Dating, rated on respect" bar. This pass confirms that, at HEAD.

## Flows
This round has one flow, the review run. The demo flows it judges are listed in step 4.

1. **Start.**
   - Build and serve: `tool/run_demo.sh 8140`. Write one line in the report: the port and the commit (`git rev-parse --short HEAD`).
   - If it fails to build, or the tooling is missing, go straight to the Blocked state (States). Don't wait and don't retry endlessly.
2. **Shoot every address cold, at 1440×900 and 390×844**, into `.symbiot/shots/review/r6/<name>/`:
   - the eleven addresses are `/`, `/discover`, `/welcome`, `/discover/empty`, `/match`, `/matches`, `/matches/empty`, `/chat`, `/score`, `/vibe`, `/profile`, plus `/nope`;
   - use `node "/home/odessey/.nvm/versions/node/v20.20.2/lib/node_modules/symbiot/index.mjs" shoot http://127.0.0.1:8140<path> --out .symbiot/shots/review/r6/<name>`;
   - use `--full` for /profile and /score.
3. **Run the capture Marketing will run:**
   - `node "…/symbiot/index.mjs" capture daaymn --url http://127.0.0.1:8140 --screens /match,/chat,/score,/vibe`;
   - list the five pictures in order: Discover, match, chat, Score, Vibe;
   - open each one: every photo full-strength, no grey card on Discover, no black card behind the match pop-up.
4. **Click-through** (Chrome over DevTools, as in round 2). For each flow, mark present, missing or broken, with a screenshot:
   - **Undo:** pass Isla, then undo. Isla comes back with the toast "Brought back Isla.". The undo button is greyed out when there's nothing to undo.
   - **Like:**
     - a like on a non-mutual card goes to the next card;
     - a like on the mutual card opens /match;
     - "Keep browsing" goes to /discover;
     - "Say hi" goes to /chat with that person, not Fiona's script.
   - **Chat:** type a message and press Enter. A right-hand bubble appears and the field clears. A new match opens to "You matched with Hannah today."
   - **Matches:** a "New matches" avatar row, then "Messages". Previews show the last line, with "You: " when it's yours.
   - **End of deck:** passing the last card lands on /discover/empty.
   - **Profile:** add, remove and move a photo; Save shows "Profile saved."
   - **Address bar:** tabs update the address, a reload stays put, and the chat's back arrow goes to /matches.
5. **Checks:**
   - `flutter test test/demo_app_test.dart`: quote the pass count;
   - `git diff --stat`: must show no change under `lib/` or `test/` made by the critic.
6. **Judge.** Go through the eleven points of the standard in `UI-CRITIC.md`, against the r6 shots. Compare each screen with its r2 shot and name anything that moved.
7. **Write** both files (Screens below) and stop. Don't commit, push, deploy or tick. Symbiot routes the result.

Not in this round: building anything, the real app (`lib/main.dart`), dark mode (the demo has none), and the Play upload.

## Screens
The deliverable is two files. There is no UI to build.

**`.symbiot/UI-REVIEW.md`**
```
# <Passed: Marketing can capture now | Must change: <screen>: <what> | Blocked: <why>>

Commit <sha> · demo on :8140 · judged 2026-10-30

## Capture: PASS | FAIL
- the capture command, then the 5 picture paths in order, one line each on what shows

## Every address
| Address | 1440 | 390 | Matches r2? |   (one row each, 12 rows incl. /nope)

## Flows
| Flow | Present / missing / broken | Shot | Should be (if not present) |

## The standard
- 11 lines, one per point: pass, or the fix ("screen, what's wrong, what it should be")

## Checks
- flutter test: N passed · git diff --stat: no lib/ or test/ changes

## Screenshots
- grouped by address, then the flow-*.png shots
```

**`.symbiot/ui-verdict.json`**, in the shape `UI-CRITIC.md` gives:
- one item for each task listed under "What to judge" in `UI-CRITIC.md`, with the wording copied exactly;
- one item for each of the eleven points of the standard, named as `ui-review.json` names them ("The job first", "First look", "Hierarchy and grouping", "Type", "Colour", "Real content", "States", "Responsive", "Accessible", "Motion only where it explains a change", "A demo tells a story");
- every item has `pass` and `shots` (r6 paths), and every failed item has at least one fix.

## States
- **Running:** nothing is shown to the user. While the critic works, `.symbiot/UI-REVIEW.md` keeps the round 5 report until the new one replaces it in one write.
- **Passed:** title **Passed: Marketing can capture now**. The next line is the exact capture command. Every item in `ui-verdict.json` has `"pass": true`.
- **Must change:** title **Must change: \<screen\>: \<what\>**, naming the worst fail. Each fail is a numbered fix with its screenshot. Only the failed items go back to the builder.
- **Blocked** (the demo won't build or serve, `flutter` is missing, or `shoot`/`capture` errors):
  - title **Blocked: \<one line, e.g. "flutter build fails: <first error line>"\>**;
  - the next line names what would unblock it;
  - `ui-verdict.json` gets each item with `"pass": false` and the fix "Review blocked: \<reason\>. Re-run the critic once \<unblock\>.";
  - if the unblock needs Garth (a key, a paid service), the critic adds one question to `.symbiot/QUESTIONS.md`.
  
  A blocked verdict is still a finished review. It is never left unwritten.
- **Grey or late shot:** re-shoot with `capture` before failing it. If `capture` is clean and `shoot` isn't, that's the tool, not the app: put it under Notes and don't fail the item.

## Words
Report titles, word for word:
- **Passed: Marketing can capture now**
- **Must change: \<screen\>: \<what\>** (e.g. "Must change: /match: Isla's card is black behind the pop-up")
- **Blocked: \<why\>**

Demo copy the critic checks for, word for word:
- **Brought back Isla.**
- **You've seen everyone for now** / "New people show up every day." / **See your matches**
- **No matches yet** / "Like someone on Discover and they'll show up here." / **Start browsing**
- **New matches**, **Messages**, **You:**
- "You matched with Hannah today." / **Say something about her photos**
- "Real people near you. Rated on how they treat each other." / **Start browsing**
- **YOUR PHOTOS**, **Remove photo**, **Move earlier**, **Profile saved.**
- App bar: **Daaymn | Dating, rated on respect**

If the built copy differs only in name (e.g. "Brought back Alex." when Alex was passed), it passes. A real change of meaning is a fix.

## Out of scope
- Any code change by the critic, and any commit, push, merge, deploy or Play upload.
- New features beyond the flows above: drag-to-reorder, a real photo picker, sign-in, keyboard shortcuts on Discover, and keyboard focus on the profile photo buttons (round 5 noted this as out of scope).
- Re-judging the round 5 /profile tap areas beyond confirming they haven't moved.
- Browser Back/Forward through tab history.
- The real app and `lib/notification_provider.dart`.

## Acceptance
- [ ] `.symbiot/ui-verdict.json` exists, is valid JSON (`node -e 'JSON.parse(require("fs").readFileSync(".symbiot/ui-verdict.json"))'` exits 0), and covers every "What to judge" item plus the eleven standard points.
- [ ] Every failed item has a fix that names a screen and says what it should be. Every item lists at least one r6 shot path.
- [ ] `.symbiot/UI-REVIEW.md` has a first line in one of the three title forms, and the commit sha on line 3.
- [ ] `.symbiot/shots/review/r6/` has a 1440×900 and a 390×844 PNG for all 12 addresses (24 files minimum).
- [ ] The report lists five capture pictures in listing order. In each, every photo is full colour: no grey Discover card, no black card behind /match.
- [ ] Every flow in Flows step 4 is marked present, missing or broken, with a shot.
- [ ] The `flutter test test/demo_app_test.dart` pass count is quoted (round 5 had 20).
- [ ] `git status` shows no changes under `lib/` or `test/`.
- [ ] If the review was blocked: the title starts "Blocked:", the unblock is named, and the verdict file still exists.
