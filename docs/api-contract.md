# The API contract

The app is a client of the LockInPoint web backend. This file is the agreed
shape between the two repositories; change it in both or in neither.

## Authentication

Auth is **Supabase Auth**, the same project the website uses. The same email
and password work in both places.

Two envelopes carry the same JWT:

| Client  | How it authenticates |
|---------|----------------------|
| Website | Supabase auth cookies |
| App     | `Authorization: Bearer <access_token>` |

`getSession(req)` on the website opens either. Verification is identical —
`supabase.auth.getUser()` checks the signature with the auth server — so a
forged bearer token fails exactly as a forged cookie does.

`POST /api/auth/login` returns `access_token` and `refresh_token` in its JSON
body. The app stores them in the platform keystore, never in preferences.

## Row Level Security

RLS grants anonymous read on eleven reference tables only: exams, subjects,
topics, exam_extra_years, country_prices, quotes, social_links, schools,
course_suggestions, site_content, and a student's own profile row.

There is **no policy on `questions`**, `attempts`, `notes` or `documents`. The
app therefore cannot read questions directly from Supabase and must not try;
every real read goes through the web API.

## Endpoints the app uses

| Endpoint | Purpose |
|---|---|
| `POST /api/auth/login` · `/signup` · `/forgot` · `/reset` · `/verify` | identity |
| `GET  /api/me` | activation and freeze state |
| `GET  /api/public/exam-tree` | exams · `?subjects=slug` · `?chooser=<subjectId>` |
| `POST /api/attempts` | start · progress · submit · resume |
| `POST /api/qmark` | save · unsave · flag a question · saved ids |
| `POST /api/ai/ask` | Lumi, answer withheld server-side |
| `GET  /api/games/pool` · `POST /api/games/ladder` | the games |
| `GET  /api/doc/[id]` | a watermarked PDF |
| `GET  /api/search` · `/api/leaderboard` · `/api/referrals` | the rest |

## Question payload

`POST /api/attempts` with `action: "start"` returns each question as:

```json
{ "id": "...", "subject_id": "...", "passage_id": null, "section": "",
  "year": 2024, "question": "<sanitised html>",
  "options": ["..."], "letters": ["A","B"], "media": {} }
```

**`answer` and `explanation` are deliberately absent.** Marking happens on the
server when the attempt is submitted. The Offline Vault is the one exception
and has its own signed, encrypted, account-bound pack format — see
`docs/offline-vault.md` when that phase lands.

## Not yet built

- `GET /api/packs/manifest` and `GET /api/packs/:id` — the Offline Vault
- push notification registration
- `GET /api/mobile/config` — minimum supported build, feature switches
