# daaymn

Flutter dating app (Supabase + Firebase backend).

## Demo-data mode (for screenshots and clips)

Runs the key screens (Discover cards, match pop-up, chat, Daaymn Score, vibe picker) on made-up
people with AI-generated photos, labelled "Demo profiles". No Supabase/Firebase login, nothing is
written anywhere. The photos load from the public `seed-photos/ai` bucket (set
`--dart-define=DEMO_PHOTO_BASE=<url>` in `tool/run_demo.sh` to point elsewhere).

Start it (first build takes a minute or two):

    tool/run_demo.sh            # serves on http://127.0.0.1:8099
    tool/run_demo.sh 9000       # or pick a port

Address: **http://127.0.0.1:8099**. Capture with `symbiot capture Daaymn --url http://127.0.0.1:8099`.
Tap the heart on a card for the match pop-up; "Say hi" opens the chat; the bottom bar has
Matches, Daaymn Score and Vibe.
