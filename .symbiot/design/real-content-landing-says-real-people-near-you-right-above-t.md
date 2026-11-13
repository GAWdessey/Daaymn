# Landing hero: "Singles near you", not "Real people, near you"

## The job
The Daaymn landing page (`docs/index.html`, served at the GitHub Pages root) is for someone deciding whether to install the app or try the web demo. Under the two buttons there are two small grey lines. Right now the first says "Real people, near you" and the line straight below says "The people are made up." Read together, they contradict each other and make the page look careless or dishonest. Done means the two lines agree: the first describes the app, the second is the honest note about the demo, and nobody reads them as a clash.

## The bar
Hinge, Bumble and Tinder landing pages: the small print under the store buttons is short and factual (price, age limit), with no claims the next line contradicts. Any demo or sample content is labelled plainly, and nothing nearby says the opposite.

## Flows
- In this round: a visitor lands, reads the headline, the two buttons, then the two lines of small print. They understand the app is free, 18+ and about singles near them, and that the demo needs no sign-up and uses made-up people.
- Not changed: the buttons, their links and every other section.

## Screens
Desktop (1440) and phone (390) keep the layout they have now. Only the words in the first small-print line change.

```
Desktop 1440 (centred column, hero)
  [ OUT NOW ON GOOGLE PLAY ]
  Dating that's actually
  worth your time.
  Discover local singles near you in real time. ...
  [ GET IT ON Google Play ]  [ Try the demo → ]
  Free to download · 18+ · Singles near you          <- changed
  No sign-up for the demo. The people are made up.  <- unchanged
```

```
Phone 390 (stacked)
  [ OUT NOW ON GOOGLE PLAY ]
  Dating that's actually / worth your time.
  sub copy
  [ GET IT ON Google Play ]   (full width)
  [ Try the demo → ]          (full width)
  Free to download · 18+ · Singles near you          <- changed, fits on one line
  No sign-up for the demo. The people are made up.
```

Nothing sticks on scroll. The style stays the same: `.rate` class, muted grey, 13px, centred.

## States
This is static text, so there are no loading, empty, error or locked states.

## Words
- Line 1, exactly: `Free to download · 18+ · Singles near you` (middle dots with a space on each side, as now; capital S; no full stop).
- Line 2 stays exactly as it is: `No sign-up for the demo. The people are made up.`

## Out of scope
- The headline, sub copy, buttons, screenshots strip and its caption.
- The "Discover locals" feature card ("See real singles near you, right now"). It is further down and describes the app, not the demo, so it is left alone this round.
- The demo app itself, other pages in `docs/`, and the Play listing.

## Acceptance
- [ ] At 1440 and 390, the line under the buttons reads exactly "Free to download · 18+ · Singles near you".
- [ ] The words "Real people" no longer appear anywhere in the hero section.
- [ ] The next line still reads exactly "No sign-up for the demo. The people are made up."
- [ ] Both lines keep the same grey, size, centring and spacing as before. At 390 the first line fits on one line.
- [ ] No other text on the page has changed (the diff touches only `docs/index.html` line 110).
