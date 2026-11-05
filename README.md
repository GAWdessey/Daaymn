# daaymn

Flutter dating app (Supabase + Firebase backend).

## Demo-data mode (for screenshots and clips)

Runs the shipped app's screens (its header and five tabs: Discover, Your Likes, Liked You,
Messages, Settings, plus Store -> Reports, chat and Edit Profile) on made-up
people with AI-generated photos. No Supabase/Firebase login, nothing is
written anywhere. The photos load from the public `seed-photos/ai` bucket (set
`--dart-define=DEMO_PHOTO_BASE=<url>` in `tool/run_demo.sh` to point elsewhere).

Start it (first build takes a minute or two):

    tool/run_demo.sh            # serves on http://127.0.0.1:8099
    tool/run_demo.sh 9000       # or pick a port

Each key screen has its own address:

| Address | Screen |
|---|---|
| `/` | Discover: the card deck |
| `/discover/empty` | End of the deck, "Review your dislikes" |
| `/likes` | Your Likes: fill the heart |
| `/likes/otm` | Your Likes with a One-Time Message ready to send |
| `/liked-you` | Liked You |
| `/messages` | Messages: One-Time Messages, then Matches |
| `/chat` | A chat with a match |
| `/otm` | A One-Time Message waiting for Accept / Decline |
| `/settings` | Settings |
| `/store` | Store -> Reports: the report card (from Buy) |
| `/profile` | Edit Profile (from the header photo) |

Old addresses `/match`, `/matches`, `/score` and `/vibe` land on Liked You, Messages, the Store
and Your Likes.

Capture the Play-listing set, in listing order:
`symbiot capture Daaymn --url http://127.0.0.1:8099 --screens /liked-you,/chat,/store,/likes/otm`
(capture always takes `/` first).
