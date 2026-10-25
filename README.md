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

Each key screen has its own address:

| Address | Screen |
|---|---|
| `/` | Discover: faces to browse |
| `/match` | The match pop-up |
| `/chat` | A chat with a match |
| `/score` | Daaymn Score |
| `/vibe` | Vibe picker |
| `/matches` | Matches list |

Capture the Play-listing set, in listing order:
`symbiot capture Daaymn --url http://127.0.0.1:8099 --screens /match,/chat,/score,/vibe`
(capture always takes `/` first).
