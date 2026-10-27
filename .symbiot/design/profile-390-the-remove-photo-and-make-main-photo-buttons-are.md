# Daaymn demo /profile: photo buttons you can hit with a thumb

## The job
This is for the person editing their own profile on a phone, and for the Play-listing reviewer who sees /profile in the demo. Each photo has two small round buttons: × (Remove photo, top right) and ← (Move earlier, bottom left). They're 28 px circles that sit about 4 px from the photo's corner, and the tap area is only 28 px, so a thumb misses them or catches the photo. They're done when each button still looks like the same small dark circle, sits 8 px in from the photo's corner, and a tap anywhere in the 44x44 square around it works.

State of play: this was built in `e3a0e49` (PR #2), and the critic passed it in round 3 (`.symbiot/UI-REVIEW.md`, shots in `.symbiot/shots/review/r3/`). This spec writes down that target so the builder keeps it and the critic can judge against it. No new build work unless a check below fails.

## The bar
Hinge and Bumble's "My photos" grid: small round controls laid over the photo corners, quiet enough not to hide the face, each with a hit area of at least 44x44 (Apple HIG 44 pt; Material asks for 48 dp, but 44 is the bar set for this round). Buttons sit clear of the rounded corner so the circle never gets clipped, and the two controls on one photo never compete for the same tap.

## Flows
In this round:
1. **Remove a photo (phone, 390).** Tap × on any filled slot, including a tap on the 44x44 square just outside the circle → the photo goes and the slot becomes an empty grey tile with "+". No dialog.
2. **Move a photo earlier.** Tap ← on any photo except the first → it swaps with the photo to its left. Do it on the 2nd photo and that photo becomes the main photo (slot 1). The first photo has no ← button.
3. **Add a photo (unchanged).** Tap an empty "+" tile → a demo photo fills it, with its × and, if it isn't slot 1, its ←.
4. **Desktop, 1440.** Same grid in the phone column. The buttons look and behave the same; mouse hover shows the tooltip ("Remove photo" / "Move earlier").
5. **Keyboard and screen readers.** Each button is announced as a button with its label ("Remove photo", "Move earlier").

Not in this round: undo after remove, drag to reorder, picking your own photo.

## Screens
The look doesn't change. Same "YOUR PHOTOS" label, 3x2 grid, 8 px gaps, 4:5 tiles with 12 px rounded corners, black-54% circles with white 16 px icons.

**Phone, 390x844**
```
[ Daaymn | Dating, rated on respect          ]  gradient app bar
YOUR PHOTOS
+-----------+ +-----------+ +-----------+
|        (x)| |        (x)| |        (x)|   (x) circle 8 px from top and right edges
|           | |           | |           |
|   photo   | |   photo   | |   photo   |
|           | |(<-)       | |(<-)       |   (<-) circle 8 px from bottom and left edges
+-----------+ +-----------+ +-----------+   slot 1 has no (<-)
+-----------+ +-----------+ +-----------+
|     +     | |     +     | |     +     |   empty slots, no buttons
+-----------+ +-----------+ +-----------+
Name ____________   Age ___
Job _____________________
My vibes  Adventurer, Foodie, Music head  >
[              Save              ]           the one main action
[Discover][Matches][Score][Vibe][Profile]    bottom bar, sticks
```
Each circle is 28 px, centred in an invisible 44x44 square that sits flush in the photo's corner. That centring is what puts the circle 8 px in: (44 − 28) / 2 = 8.

**Desktop, 1440x900:** the same layout in the centred phone-width column (about 430 px) on the lavender background. Nothing else changes.

## States
- **Filled slot:** photo with × (and ← unless it's slot 1).
- **Empty slot:** grey tile with "+", no buttons.
- **Only one photo left:** it still shows ×. Removing it leaves six empty tiles (allowed in the demo).
- **Loading / error:** demo photos are bundled URLs; none to design this round.
- **Success:** the grid updates at once; no message.

## Words
- Section label: **YOUR PHOTOS**
- Remove button tooltip and screen-reader label: **Remove photo**
- Reorder button tooltip and screen-reader label: **Move earlier** (keep it; it says what the button does, one slot left. The round 2 report called it "Make main photo", which is only true on slot 2.)
- Save confirmation (unchanged): **Profile saved.**

## Out of scope
- Undo, confirmation dialog, drag-to-reorder, a real photo picker.
- Moving to 48x48 hit areas or changing the circle size, colour or icons.
- Any other screen, field or spacing on /profile.

## Acceptance
On `.symbiot/shots/review/r3/profile-390x844.png` and `profile-1440x900.png` (or a fresh shoot of /profile at both sizes):
- [ ] Every filled photo shows a dark × circle in its top-right corner, with a clear gap (8 px at 390) between the circle and the photo's top and right edges.
- [ ] Every filled photo except the first shows a dark ← circle in its bottom-left corner, 8 px from the bottom and left edges. The first photo has no ←.
- [ ] The circles are the same size as before (28 px). They aren't bigger and have no visible 44 px ring or background.
- [ ] No circle is clipped by the photo's rounded corner, and no button touches or overlaps a neighbouring tile.
- [ ] Empty "+" tiles show no buttons.
- [ ] Nothing else on /profile moved: the label, grid, fields, My vibes, Save and bottom bar match the round 2 shots.
- [ ] In a widget test at 390x844, a tap 3 px inside the corner of the 44x44 area (outside the circle) removes or moves the photo. `flutter test test/demo_app_test.dart` passes.
