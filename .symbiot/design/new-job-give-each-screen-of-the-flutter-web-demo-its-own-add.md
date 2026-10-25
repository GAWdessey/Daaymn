# Daaymn demo: every key screen has its own address

## The job
This is for Marketing, and for Symbiot's capture working on Marketing's behalf. They need the five
Play-listing pictures in order: faces/browse, a match, a chat, the Daaymn Score, the vibe picker.
`symbiot capture` takes one picture per address. Today the demo has one address, so a capture gets
only Discover. They're done when a single capture command, with no taps and no scripts, puts five
pictures in the tray, each one the right screen, in listing order, each looking like a phone app
and each carrying the "Demo profiles" label.

Two facts from the code decide the design. The builder must not "simplify" them away:
1. **Addresses are paths, not `?tab=` queries.** Symbiot's capture strips `?…` and `#…` from every
   `--screens` entry (`routeOf` in symbiot `capture.mjs:55`), so `/?tab=score` reaches the
   capture as `/` and comes back as a second Discover shot. The demo must use Flutter's path URL
   strategy (`usePathUrlStrategy()` from `flutter_web_plugins`, called once in the demo's `main`).
   I checked that the demo server already sends `index.html` for `/score` (HTTP 200), so the server
   needs no changes.
2. **Capture shoots at 1440×900.** At that width the demo today shows a grey, cropped face that
   fills the whole screen. Isla's name, her job and the like/pass buttons all fall below the fold
   (`.symbiot/shots/design/home-1440x900.png`). That picture can't go on a Play listing. So on a
   wide window the app must sit in a phone-width column. Without that, the addresses alone don't
   finish the job.

## The bar
Tinder and Hinge on the web: every view has a real URL that you can paste, reload or share, and
it opens straight to that view. The address bar follows the tab you're on. On a desktop browser
the app stays phone-shaped and centred rather than stretched. Play-listing screenshots from
Bumble or Hinge show the app as it looks on a phone, with one moment per picture: a card, the
"match!" moment, a chat, a feature.

## Flows
In this round:
1. **Open an address directly (capture's flow).** Load `http://127.0.0.1:8099/<path>` → that
   screen is fully shown on the first frame, with no tap and no animation to wait for. The
   page-load spinner is the only thing before it.
2. **Discover, the home screen.** `/` or `/discover` → the Discover tab with Isla's card first.
3. **Match moment.** `/match` → the Discover tab with Isla's card behind it and the "It's a
   Daaymn match!" pop-up for Hannah already open. "Keep browsing" closes it, leaves you on
   Discover and changes the address to `/discover`. "Say hi" opens the chat with Hannah.
4. **Matches list.** `/matches` → the Matches tab (Fiona, Grace).
5. **Chat.** `/chat` → the chat with Fiona (the first match), all five demo messages visible,
   newest at the bottom. The back arrow goes to the Matches list (`/matches`), not to a blank
   page or out of the app.
6. **Daaymn Score.** `/score` → the Score tab: 8.4 hero, then the three pillars.
7. **Vibe picker.** `/vibe` → the Vibe tab with Adventurer, Foodie and Music head already picked.
8. **Moving around.** Tapping a bottom tab changes the address to that tab's path (`/discover`,
   `/matches`, `/score`, `/vibe`). Reloading keeps you on that screen.
9. **An unknown address.** `/anything-else` → Discover, with the address corrected to `/`. The
   demo never shows an error screen or a blank page.
10. **Phone.** The same addresses work at 390×844, where the column fills the width.

Not in this round: browser Back/Forward stepping through tab history (see Out of scope).

## Screens
The look doesn't change: the same gradient app bar ("Daaymn | Demo profiles"), the same
ProfileCard, bottom bar, chat bubbles, score card and chips. The only new layout is the
phone column on wide windows.

**Desktop, 1440×900 (every screen):**
```
┌──────────────────────────────── page background: #F3F0F7 (soft lilac-grey) ─────────────────────────────┐
│                                   ┌──────────── 430 px column, white ───────────┐                        │
│                                   │ ▓▓ Daaymn | Demo profiles ▓▓ (gradient bar) │                        │
│                                   │                                              │                        │
│                                   │      [ screen body, exactly as on phone ]    │                        │
│                                   │                                              │                        │
│                                   │                                              │                        │
│                                   │ ─────────────────────────────────────────── │                        │
│                                   │  🔍 Discover   💬   📈   ✨  (bottom bar)    │                        │
│                                   └──────────────────────────────────────────────┘                        │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```
- The column is 430 px wide (a large phone), full height and centred, with a soft shadow
  (blur 24, black at 8%) and no rounded corners top or bottom, because it runs edge to edge
  vertically.
- Everything sits inside the column: the app bar, the body, the bottom bar, the match dialog and
  the chat screen. Nothing spans the full 1440.
- The match dialog shows over the column. Its dimmed backdrop may cover the whole window, but the
  dialog itself is centred on the column.

**Phone, 390×844:** the column is the full width with no side background. It looks the same as
today's phone shot (`.symbiot/shots/design/home-390x844.png`).

What each address shows inside the column:
```
/  /discover          /match                       /matches
┌──────────────┐      ┌──────────────┐             ┌──────────────┐
│ app bar      │      │ app bar      │             │ app bar      │
│ ┌──────────┐ │      │ ░┌────────┐░ │             │ (◯) Fiona, 28│
│ │ Isla, 28 │ │      │ ░│It's a  │░ │             │  Coffee after│
│ │ ✓ Marine │ │      │ ░│Daaymn  │░ │             │ (◯) Grace, 27│
│ │ biologist│ │      │ ░│match!  │░ │             │  Say hi to…  │
│ │ chips ✕ ♥│ │      │ ░│ (Hannah)│░│             │              │
│ └──────────┘ │      │ ░│Keep|Say│░ │             │              │
│ ●Discover …  │      │ ░└────────┘░ │             │ … ●Matches … │
└──────────────┘      └──────────────┘             └──────────────┘
/chat                 /score                       /vibe
┌──────────────┐      ┌──────────────┐             ┌──────────────┐
│← (◯) Fiona   │      │ app bar      │             │ app bar      │
│   bubble     │      │ ┌──────────┐ │             │What's your   │
│      bubble  │      │ │   8.4    │ │             │vibe?         │
│   bubble     │      │ │#DaaymnSc.│ │             │Pick up to 5… │
│      bubble  │      │ └──────────┘ │             │[chip][chip✓] │
│   bubble     │      │ SCORE BREAK… │             │[chip✓][chip] │
│ [Type a msg] │      │ Popularity ▬ │             │              │
│ (no tab bar) │      │ … ●Score  …  │             │ … ●Vibe      │
└──────────────┘      └──────────────┘             └──────────────┘
```
The chat is a pushed screen, just as it is today: its own gradient bar with a back arrow and
Fiona's avatar, and no bottom bar.

## States
- **Loading (first paint):** Flutter's own loader, unchanged. No new loading UI.
- **Photos still loading:** the card and avatars show their current grey placeholder. Capture
  waits 800 ms after load, so the photos must come from the fast public bucket as they do now.
  Nothing changes here.
- **Empty:** none. Every screen is seeded.
- **Error / unknown address:** falls back to Discover at `/`, with no message.
- **Success:** the requested screen is showing and its bottom-bar item is selected (bold and
  coloured): Discover for `/`, `/discover` and `/match`; Matches for `/matches`; Daaymn Score for
  `/score`; Vibe for `/vibe`.
- **Locked:** not applicable. The demo has no sign-in.

## Words
No copy changes. These existing strings must still show, word for word:
- App bar: **Daaymn** | **Demo profiles** (on every screen except the chat, whose bar shows the match's name)
- Bottom bar: **Discover**, **Matches**, **Daaymn Score**, **Vibe**
- Pop-up: **It's a Daaymn match!**, "You and Hannah liked each other.", buttons **Keep browsing** / **Say hi**
- Score: **8.4**, **#DaaymnScore**, **SCORE BREAKDOWN**, **Popularity**, **Engagement**, **Safety (A)**
- Vibe: **What's your vibe?**, "Pick up to 5. They show on your profile card."
- Chat input hint: **Type a message**

README "Demo-data mode" section: replace the capture line and the "Tap the heart…" line with:

> Each key screen has its own address:
>
> | Address | Screen |
> |---|---|
> | `/` | Discover: faces to browse |
> | `/match` | The match pop-up |
> | `/chat` | A chat with a match |
> | `/score` | Daaymn Score |
> | `/vibe` | Vibe picker |
> | `/matches` | Matches list |
>
> Capture the Play-listing set, in listing order:
> `symbiot capture Daaymn --url http://127.0.0.1:8099 --screens /match,/chat,/score,/vibe`
> (capture always takes `/` first).

The builder's closing reply must give the exact addresses as written above, plus that command.
Marketing runs it next.

## Out of scope
- Browser Back/Forward walking through tab history. The address follows the tabs, but history
  entries per tab aren't required.
- Any change to the real app (`lib/main.dart`, its routing, or its URL strategy). This is
  demo-only.
- A desktop layout beyond the phone column: no side panels, no wide grid of cards.
- New demo content, restyling, dark mode or copy changes.
- The capture itself, which Marketing runs after this lands.
- The pop-up's like-animation: it opens already shown.

## Acceptance
Run `tool/run_demo.sh`, then shoot each address at 1440×900 and 390×844 with `symbiot shoot`:
- [ ] `/` at 1440: a centred column about 430 px wide on a light lilac-grey background. Isla's
      full card (name, "Marine biologist", chips, ✕ and ♥ buttons) is visible above the bottom
      bar. No face fills the screen edge to edge.
- [ ] `/match`: the "It's a Daaymn match!" pop-up with Hannah's photo and both buttons is showing
      with no tap. Discover is selected in the bottom bar behind it.
- [ ] `/chat`: Fiona's name and avatar are in the bar, all five messages are visible, the last one
      reads "Daaymn, you had me at coffee." and the back arrow is present.
- [ ] `/score`: 8.4 big in the gradient card, the three pillars below, Daaymn Score selected.
- [ ] `/vibe`: "What's your vibe?" with Adventurer, Foodie and Music head selected, Vibe selected.
- [ ] `/matches`: Fiona and Grace listed, Matches selected.
- [ ] `/nope`: shows Discover, and the address bar reads `/`.
- [ ] "Demo profiles" shows in the app bar on `/`, `/match`, `/score` and `/vibe`.
- [ ] Every 390×844 shot: the column fills the width, with no lilac sides, no horizontal scroll and
      nothing cut off.
- [ ] Tapping the Matches tab from `/` changes the address to `/matches`, and reloading stays there.
- [ ] `flutter build web -t lib/demo/demo_main.dart --release` succeeds, and
      `test/demo_app_test.dart` passes, extended to cover a start on `/score` and on `/match`.
- [ ] The README shows the address table and the capture command above.
