# Put the demo's design specs in the repo, and land the demo branch on master

## What is true now (checked 2026-10-24, before writing this)
- **Specs:** three design specs are in `.symbiot/design/`: screen addresses, critic round 1, and this one. All of `.symbiot/` is untracked and not in `.gitignore`. It holds 26 MB of `agent.log*`, run state and seed data, so `git add .symbiot` must never happen.
- **"Uncommitted demo-screen address changes":** none remain. The address routes (`/welcome`, `/discover/empty`, `/profile`, `_tabPaths`) are already in HEAD (`bfbdcff`, `e3a0e49`, merge `613d0ab`). The branch `fix/profile-photo-tap-targets` matches its remote, is 4 ahead and 0 behind `origin/master`, and is open as PR #2 (base `master`, CI `android` green, mergeable, auto-merge **off**).
- **"Sync with origin/main":** this is the wrong base. `origin/HEAD` is `master`, PR #1 merged into `master`, and `origin/main` is an older, separate landing-page line (79 behind / 43 ahead). Merging `main` in would drag the old landing page back over the demo. **Decision: master is the base. Do not touch `main`.**

## The job
This is for Garth and for the next builder or critic in the daaymn lane. Done means:
- the design specs that steer the Flutter web demo are versioned in the repo, so a builder on another machine or run can read them;
- the demo work on this branch lands on `master` through PR #2, the normal way: tests green, CI green, auto-merge set;
- the builder's next task comes from the spec, not from memory.

No app screen changes in this round.

## The bar
GitHub's own flow, the way well-run repos use it (Linear's or Vercel's public repos): one PR per change, a clear title and body, CI checks shown, auto-merge armed so it lands by itself when the checks and the required review pass, and design docs kept next to the code (`docs/design/` style) rather than in a private folder.

## Flows (all in this round)
1. **Keep the specs, ignore the rest.** Add to `.gitignore`:
   ```
   .symbiot/*
   !.symbiot/design/
   ```
   Then `git add .gitignore .symbiot/design/*.md`. `git status` shows only those files staged, and every other `.symbiot` file is ignored.
2. **Commit** on `fix/profile-photo-tap-targets`: `Keep Symbiot design specs in the repo; ignore Symbiot run files`. Push.
3. **Sync:** `git fetch && git merge origin/master`. It is already up to date; if it isn't, merge and push. Never merge `origin/main`.
4. **Test:** `flutter test`. All must pass: `test/demo_app_test.dart` plus the other two files, 19+ tests. On a failure, stop, fix it if it is in `lib/demo/`, and otherwise report it word for word.
5. **PR #2:** retitle it to `Demo: screen addresses, missing flows, 44 px photo buttons; design specs in repo`, then add a body listing the 4+1 commits and the test count. Arm auto-merge: `gh pr merge 2 --auto --merge`. Symbiot's membrane still holds the merge until the critic's round 3 pass, which is expected. Say so in the tick, and don't treat it as an error.
6. **Queue the builder's first task from the spec.** Add one line to TASKS.md under Tests & CI: `Design critic round 3: judge /profile photo buttons (44x44 tap area, 8 px inset) on PR #2 against .symbiot/design/act-as-symbiot-s-design-critic-for-the-daaymn-lane-judge-the.md and .symbiot/shots/review/r3/; pass releases the auto-merge.` This is the only open item that blocks the merge, so it comes first.
7. **Undo:** each step can be undone. `git revert` the spec commit, `gh pr merge 2 --disable-auto`, and the TASKS line can be deleted.
8. **Errors:**
   - If `gh` is signed out, start `gh auth login --web` yourself in Symbiot's browser (github.com is linked).
   - If auto-merge is refused because the repo setting is off, enable it in the repo settings by API (`gh api -X PATCH repos/GAWdessey/Daaymn -f allow_auto_merge=true`), then retry once.

## Screens
No app UI changes. The visible results are the PR #2 page and the Workdesk.

```
Desktop 1440 — github.com/GAWdessey/Daaymn/pull/2
┌──────────────────────────────────────────────────────────────┐
│ Demo: screen addresses, missing flows, 44 px photo buttons;  │
│ design specs in repo                              #2  Open   │
│ fix/profile-photo-tap-targets → master                        │
├──────────────────────────────────────────────────────────────┤
│ Body: what's in it (commits) · flutter test 19/19 · shots r3  │
│ Files: lib/demo/…, .gitignore, .symbiot/design/*.md (3)       │
│ ✓ android                                                     │
│ [ Auto-merge enabled — merge commit ]   (main action, sticks) │
└──────────────────────────────────────────────────────────────┘
Phone 390: same order, stacked: title, branch line, checks, auto-merge banner.
```

## States
- **Loading:** CI is running → the PR shows "Some checks haven't completed yet", and auto-merge waits.
- **Success:** "✓ All checks have passed" with "Auto-merge enabled".
- **Error:** a red check. The tick stays open, and the task line gets `(waits on: <check name> failing: <first error line>)`.
- **Locked:** the membrane holds for the critic. The tick line reads `waits on: design critic round 3`.

## Words
- Commit: `Keep Symbiot design specs in the repo; ignore Symbiot run files`
- PR title: `Demo: screen addresses, missing flows, 44 px photo buttons; design specs in repo`
- TASKS line: as in flow 6, word for word.

## Out of scope
- No changes to `lib/` or `test/`, and no new demo flows.
- Nothing on `origin/main`: no merge, no delete, no retarget.
- Logs, run files and seed data in `.symbiot/`.
- Merging PR #2 by hand, or bypassing the critic.

## Acceptance (check on screenshots or `git`/`gh` output)
- [ ] `git ls-files .symbiot` lists exactly the 3 `design/*.md` files and nothing else.
- [ ] `git status` is clean, with no `?? .symbiot/`.
- [ ] `git rev-list --left-right --count origin/master...HEAD` shows `0` on the left.
- [ ] `flutter test` output shows all tests passed, run after the last commit.
- [ ] The PR #2 page shows the new title, base `master`, ✓ android, and "Auto-merge enabled".
- [ ] TASKS.md has the critic round 3 line from flow 6.
- [ ] `origin/main` is unchanged: same SHA `74098a3`.
