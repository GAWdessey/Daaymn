# Daaymn critic round 8: judge the demo against the real app's screens, and list every hole

## The job
This is for Garth, and through him for anyone who sees Daaymn before installing it: the Play listing and the landing page at the GitHub Pages site (`origin/main`).

The review hasn't actually stalled. Critic round 7 passed the web demo at `db132f8` on 2026-10-30 (`.symbiot/UI-REVIEW.md`, `.symbiot/ui-verdict.json`, 12 of 12 passed), and the fixes merged to `master` in PR #5. Nothing under `lib/` or `test/` has changed since: `git diff db132f8 origin/master -- lib test` is empty.

The hole is something no round has checked. Every round judged the demo against **its own spec**, and none against **the real app** that's live on Play as 1.0.5 (79). The demo exists so Marketing can capture the Play-listing pictures from it, and those pictures have to show the app people download. Today they don't:

| | Real app (`lib/main.dart:1223-1236`, `lib/discover_screen.dart`) | Demo (`lib/demo/demo_main.dart:455-467`), passed in round 7 |
|---|---|---|
| Tabs | Discover · Your Likes · Liked You · Messages · Settings | Discover · Matches · Score · Vibe · Profile |
| App bar | "Daaymn \| 1116 Likes Left!", a **Buy** button, own photo | "Daaymn \| Dating, rated on respect" |
| Discover | a list of compact teal cards, each with a heart and a delete button; hourglass and refresh icons | one full-photo card, undo/pass/like row |
| Vibe picker | none (grep finds "vibe" only in a tutorial line, `lib/polls_screen.dart:215`) | a whole tab, "What's your vibe?" |
| Undo | a "profiles you passed on before" list (`lib/discover_screen.dart:300`) | a round undo button and a "Brought back Isla." toast |

The landing page's screenshots (`origin/main:screenshot-*.png`, last changed 2025-11-01) show the real app a year ago. `screenshot-stats.png` reads "0.0%" four times and "0" eight times. `screenshot-discover.png` shows real users' photos and names ("Mr big", "Mo", "Gemu").

Done means the critic, in one sitting, puts the demo, the landing shots and the real app side by side. It writes one verdict that names every hole, each with what it should be, and answers on its first line: **do the listing pictures show the app people download?**

## The bar
**Hinge's and Bumble's Play listings.** People expect:
- every picture is a real screen of the shipped app, with its real tabs, real header and real flows, dressed with good demo data;
- one moment per picture, with a caption that says what it does;
- no zeros, no empty lists, no real users' faces, no test names.

Google Play's metadata policy asks for the same: screenshots that depict the app as it is.

## Flows
There's one flow this round: the critic's review run. It changes no code.

1. **Start.** Write the commit (`git rev-parse --short HEAD`) and today's date in the report.
2. **Demo, as built.** Serve it with `tool/run_demo.sh 8140`. Confirm the round-7 pictures still come out the same: run `capture daaymn --url http://127.0.0.1:8140 --screens /match,/chat,/score,/vibe` into `.symbiot/shots/review/r8/demo/`. Open each picture. This is a regression check only; don't re-judge round 7.
3. **Real app, as shipped.** Run the real app on web: `flutter run -d web-server -t lib/main.dart --web-hostname 127.0.0.1 --web-port 8141 --release`. Sign in with the screenshot test account in `.test-account.env` at the repo root (never paste its contents into the report). Then shoot every tab, plus Store/Reports, a chat, a profile detail and the empty Discover, at 390×844 and 1440×900, into `.symbiot/shots/review/r8/real/<screen>/`.
   - If the web build fails or sign-in doesn't work, use the landing screenshots and the code as the real-app evidence, and say so on the report's line 3. That still counts as a finished review, marked **Partly verified**.
   - Don't like, message, buy, report or change anything on the test account. Look only.
4. **Landing page.** Extract each `screenshot-*.png` from `origin/main` into `.symbiot/shots/review/r8/landing/` with `git show`. Judge each one against the standard. Don't edit, commit or push the landing page.
5. **Side by side.** For each of the five listing pictures (Discover, match, chat, Score, Vibe), pair the demo picture with the matching real-app screen and mark it:
   - **same**: same layout and words, demo data only;
   - **dressed**: the same screen with nicer data, which is fine;
   - **invented**: a screen, tab, control or claim the real app doesn't have, which is a hole.
6. **Holes.** List every hole found, worst first, sorted into the four kinds below. Each one gets its proof shot and a "should be".
   - **Invented**: in the demo or listing, but not in the real app. Example: the Vibe tab, the undo button, the "Dating, rated on respect" line.
   - **Missing**: in the real app, but not in the demo or listing. Example: Liked You, Your Likes, Likes Left / Buy, OTM, Settings.
   - **Stale or unsafe**: on the landing page. Example: zero stats, real users' photos.
   - **Real-app standard fails**: seen in step 3, against the eleven points in `UI-CRITIC.md`.
7. **Recommend one direction, not a survey.** The default is that the demo moves to look like the real app: its tabs, header and Discover list, with good data. Only recommend the other way (the real app gains Vibe or undo) if the real app's code already has most of it, and quote the file.
8. **Write** both files and stop.

## Screens
The deliverable is two files. There's no UI to build.

**`.symbiot/UI-REVIEW.md`**
```
# <Listing matches the app | Must change: <worst hole> | Blocked: <why>>
<one line: the answer to "do the listing pictures show the app people download?">
Commit <sha> · demo :8140 · real app :8141 (or "real app from landing shots + code") · judged <date>

## Demo regression (round 7): PASS | FAIL
## Side by side
| Listing picture | Demo shot | Real-app shot | same / dressed / invented | Should be |
## Holes
1. [Invented|Missing|Stale|Real-app] <screen>: <what's wrong>. Should be: <what>. Proof: <shot>
## Real app against the standard
- 11 lines, pass or fix
## Landing page
| File | What it shows | Keep / replace, and with what |
## Screenshots
```

**`.symbiot/ui-verdict.json`**, in the shape `UI-CRITIC.md` gives:
- one item for the "What to judge" task, with its wording copied exactly;
- one item per hole, named `"Hole: <screen>: <what>"`, with `pass: false`, a fix, and shots;
- the eleven standard points (named as in `ui-review.json`), judged on the **real app**.

## States
- **Matches** (no invented screens, landing clean): title **Listing matches the app**. Every item passes.
- **Must change**: title **Must change: \<worst hole\>**, for example "Must change: listing shows a Vibe tab the app doesn't have". The holes are numbered, worst first.
- **Partly verified**: the real app couldn't be run. Line 3 says "real app from landing shots + code". Holes that rest only on code are marked "(from code)".
- **Blocked**: the demo won't build. The title is **Blocked: \<first error line\>**, the next line says what would unblock it, and every item gets `pass: false` with "Review blocked: \<reason\>". The file is still written.
- **Needs Garth**: the direction is a product call (does the real app get Vibe and undo, or does the demo lose them?). Add one question to `.symbiot/QUESTIONS.md` with the recommended option first, and still write the verdict.

## Words
Report titles, word for word:
- **Listing matches the app**
- **Must change: \<worst hole\>**
- **Blocked: \<why\>**

The answer line is one of these:
- "Yes: every listing picture is a real Daaymn screen."
- "No: \<n\> of 5 listing pictures show screens the app doesn't have."

The hole kinds are written exactly as **Invented**, **Missing**, **Stale**, **Real-app**.

The QUESTIONS.md question, if it's needed: **"The Play pictures show a Vibe tab and an undo button the app doesn't have. Make the demo match the app, or build those into the app?"**
- 🤖 Agent: make the demo match the app (recommended)
- 🤖 Agent: build Vibe and undo into the app first

## Out of scope
- Any code change by the critic, and any commit, push, merge, deploy, landing-page edit, Play upload or listing change.
- Re-judging round 7's fixes (step 2 only confirms they haven't regressed).
- Dark mode in the real app, the store's payment flow beyond looking at it, and face verification (it's off: `faceVerificationEnabled` is false).
- Changing anything on the test account.
- The listing's wording (`.symbiot/DAAYMN-LISTING-DRAFT.md` waits on its own OK). Only the pictures are judged here.

## Acceptance
- [ ] `.symbiot/UI-REVIEW.md` line 1 is one of the three titles, line 2 is one of the two answer lines, and line 3 has the commit.
- [ ] `.symbiot/ui-verdict.json` parses (`node -e 'JSON.parse(require("fs").readFileSync(".symbiot/ui-verdict.json"))'`). It has the task item, one item per hole, and the eleven standard points, and every failed item has a fix naming a screen and what it should be.
- [ ] The side-by-side table has all five listing pictures, each with a demo shot, a real-app shot (or a landing/code source) and a same/dressed/invented mark.
- [ ] `.symbiot/shots/review/r8/real/` has 390×844 and 1440×900 shots of every real-app tab, or line 3 says why not.
- [ ] Every `origin/main:screenshot-*.png` is in the landing table with keep or replace.
- [ ] No hole's text, and no shot in the report, shows the test account's password or a real user's face uncovered.
- [ ] `git status --short lib test` is empty, and nothing was committed or pushed by the critic.
