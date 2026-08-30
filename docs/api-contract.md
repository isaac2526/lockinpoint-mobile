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

**`answer` and `explanation` are absent in every mode except a fresh
`practice` start**, and absent on `resume` in all modes. That single exception
is what lets the untimed practice room mark instantly and work in a tunnel;
everywhere else — a timed CBT, a JAMB mock, any resumed sitting — marking
happens on the server at submit, and the app must never assume a key is
present. The Offline Vault is the other exception and has its own signed,
encrypted, account-bound pack format: see `docs/offline-vault.md` when that
phase lands.

Verified against the real backend, 2026-08-30: a `practice` start carries
`answer` and `explanation`; a `cbt` start and every `resume` do not.

### Content format

`question`, each option, `explanation` and a passage `body` are **sanitised
HTML** from `lib/rich-text.ts` — a small tag set (`b i u s sup sub p span div
ul ol li table tr td th small mark code pre blockquote hr br`), no attributes
beyond `colspan`/`rowspan`/`scope`, no links, no scripts.

LaTeX is left **inside** that HTML between three delimiters, and the app
renders it with the same meaning KaTeX gives it on the website:

| Delimiter | Renders |
|---|---|
| `\( … \)` | inline |
| `\[ … \]` | display |
| `$$ … $$` | display |

## Modes and the clock

`action: "start"` takes `mode`, one of `practice`, `cbt`, `jamb_mock`,
`jamb_mini`, and answers with `duration`, the seconds remaining:

| Mode | duration | Marking |
|---|---|---|
| `practice` | `0` (untimed) | instantly on the phone, from the key in the payload |
| `cbt` | `minutes × 60` | server side, at submit |
| `jamb_mock` | `7200` | server side, at submit |
| `jamb_mini` | `40 × questions` | server side, at submit |

On `resume`, `duration` is recomputed by the server from the attempt's
creation time, so **closing the app cannot buy a student extra minutes**. The
phone turns that number into a deadline once and measures against the wall
clock; it never decrements a counter, which would drift whenever the process
is frozen.

## Progress and grading

`action: "progress"` takes `{ attemptId, answers, checked, flags, idx }` and
answers `{ ok }`. It is best effort by design: a failed autosave must never
interrupt a student mid-question.

`action: "submit"` takes `{ attemptId, answers }` and answers with `score`
plus a `corrections` array, one entry per question:

```json
{ "id": "...", "question": "<html>", "options": ["..."],
  "chosen": "A", "right": "B", "isRight": false,
  "explanation": "<html>", "media": {} }
```

Corrections carry **no `letters` array** — the letter is the option's position
(`ABCDEFGH`[i]), exactly as the server assembled it. `chosen` is empty when
the question was left blank.

## Continue Practice

`GET /api/mobile/dashboard` returns `resume` only for an **untimed practice**
sitting, in progress, started within seven days. A timed paper is deliberately
never offered back, so the app tells a student leaving a CBT that the clock
keeps running and offers to submit instead.

## Not yet built

- `GET /api/packs/manifest` and `GET /api/packs/:id` — the Offline Vault
- push notification registration
- `GET /api/mobile/config` — minimum supported build, feature switches
