#!/usr/bin/env python3
"""Creates (or refreshes) the screenshot test account on the live project.

The account is for recording store screenshots and clips on an emulator. It is
not a member: it's flagged is_seed_profile like the 10 stock-photo seed
profiles, it only likes and matches with those seeds, and it blocks every real
member, so no real face or name reaches its screens and members never see it.
Re-run it before a recording session: members who joined since get blocked too.

Credentials live in .test-account.env at the repo root (gitignored). The
service key comes from the signed-in Supabase CLI and is never written down.

    python3 supabase/scripts/test_account.py
"""
import json
import pathlib
import secrets
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

REF = 'rrbsjmfwahaerkfhpegv'
URL = f'https://{REF}.supabase.co'
EMAIL = 'daaymnco+screenshots@gmail.com'
CREDS = pathlib.Path(__file__).resolve().parents[2] / '.test-account.env'
SEED_PHOTOS = f'{URL}/storage/v1/object/public/seed-photos'

# Seeds by name. The account is a man interested in women, so Discover shows
# only the five female seeds; Ethan's photos stand in for the account's own.
LIKED_BY = ['Fiona', 'Grace', 'Isla']  # Liked You; Fiona and Grace are matches
LIKES = ['Fiona', 'Grace', 'Hannah']   # Your Likes; Hannah is one-sided


def service_key():
    out = subprocess.run(
        ['supabase', 'projects', 'api-keys', '--project-ref', REF, '-o', 'json'],
        check=True, capture_output=True, text=True).stdout
    return next(k['api_key'] for k in json.loads(out) if k['name'] == 'service_role')


KEY = service_key()


def call(method, path, body=None, prefer=None):
    req = urllib.request.Request(URL + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header('apikey', KEY)
    req.add_header('Authorization', f'Bearer {KEY}')
    req.add_header('Content-Type', 'application/json')
    if prefer:
        req.add_header('Prefer', prefer)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise SystemExit(f'{method} {path}: {e.code} {e.read().decode()}')


def password():
    if CREDS.exists():
        for line in CREDS.read_text().splitlines():
            if line.startswith('DAAYMN_TEST_PASSWORD='):
                return line.split('=', 1)[1]
    return secrets.token_urlsafe(18)


def ensure_user(pw):
    users = call('GET', '/auth/v1/admin/users?per_page=1000')['users']
    user = next((u for u in users if u.get('email') == EMAIL), None)
    if user:
        call('PUT', f"/auth/v1/admin/users/{user['id']}", {'password': pw, 'email_confirm': True})
        return user['id']
    return call('POST', '/auth/v1/admin/users',
                {'email': EMAIL, 'password': pw, 'email_confirm': True})['id']


def main():
    pw = password()
    uid = ensure_user(pw)
    CREDS.write_text(
        '# Daaymn screenshot test account (production Supabase). Not a member.\n'
        '# Sign in with email + password. Refresh with supabase/scripts/test_account.py\n'
        f'DAAYMN_TEST_EMAIL={EMAIL}\nDAAYMN_TEST_PASSWORD={pw}\nDAAYMN_TEST_USER_ID={uid}\n')
    CREDS.chmod(0o600)

    seeds = {p['name']: p['id'] for p in
             call('GET', '/rest/v1/profiles?select=id,name&is_seed_profile=eq.true')}
    year = (datetime.now(timezone.utc) + timedelta(days=365)).isoformat()
    call('POST', '/rest/v1/profiles?on_conflict=id', {
        'id': uid,
        'name': 'Sam',
        'age': 27,
        'gender': 'Male',
        'pronouns': 'he/him',
        'interested_in': ['Female'],
        'city': 'Cape Town',
        'image_urls': [f'{SEED_PHOTOS}/person_5_{i}.jpg' for i in (1, 2, 3)],
        'best_photo_index': 1,
        'metric_system': 'Metric',
        'work': {'show': True, 'value': 'Designer'},
        'religion': {'show': False, 'value': ''},
        'height_cm': {'show': True, 'value': 1.8},
        'weight_kg': {'show': False, 'value': None},
        'dominant_hand': {'show': True, 'value': 'Right'},
        'device_preference': {'show': True, 'value': 'Android'},
        'bio_topics': {
            'My simple pleasures': 'Sunday markets, strong coffee and a good playlist.',
            "I'm looking for...": 'Someone who laughs at their own jokes.',
            "A hill I'm willing to die on": 'Pineapple belongs on pizza.',
        },
        'like_count': 20,
        'purchased_ghost_mode_until': year,
        'purchased_infinite_scroll_until': year,
        'is_seed_profile': True,
    }, prefer='resolution=merge-duplicates')

    have = {(l['user_id'], l['liked_user_id']) for l in call(
        'GET', f'/rest/v1/likes?select=user_id,liked_user_id&or=(user_id.eq.{uid},liked_user_id.eq.{uid})')}
    want = [(seeds[n], uid) for n in LIKED_BY] + [(uid, seeds[n]) for n in LIKES]
    new = [{'user_id': a, 'liked_user_id': b} for a, b in want if (a, b) not in have]
    if new:
        call('POST', '/rest/v1/likes', new)

    members = {p['id'] for p in call('GET', '/rest/v1/profiles?select=id&is_seed_profile=eq.false')}
    blocked = {b['blocked_id'] for b in call(
        'GET', f'/rest/v1/blocks?select=blocked_id&blocker_id=eq.{uid}')}
    todo = [{'blocker_id': uid, 'blocked_id': m} for m in sorted(members - blocked)]
    if todo:
        call('POST', '/rest/v1/blocks', todo)

    print(f'{EMAIL} ({uid}): {len(new)} likes added, {len(todo)} members newly blocked '
          f'({len(members)} in all). Credentials in {CREDS}')


main()
