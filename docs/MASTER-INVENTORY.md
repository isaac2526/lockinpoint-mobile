# LockInPoint — MASTER FEATURE INVENTORY & IMPLEMENTATION PLAN

Built from **30 reference screenshots** (TestDriller UTME, studied one by one across six
batches) cross-referenced against a **14-agent audit of both LockInPoint repositories**
— every route, every migration, every Dart file.

The reference app is the **UX specification**. LockInPoint's existing backend, exam
structure, authentication and payments are the **functional specification**. Where the two
disagree, LockInPoint wins.

---

## 0. THE THREE LAWS OF THIS REBUILD

1. **AUTHENTICATION IS PROTECTED.** `/api/auth/*`, `SessionStore`, `SessionRefresher`,
   `Api._followSameSite` and `AppConfig.apiBase` are not to be rewritten. The login works.
   Visual redesign of the login *screen* is allowed; the token flow is not.
2. **NOTHING THAT ALREADY WORKS GETS REBUILT.** 26 of the reference app's features already
   exist in LockInPoint, several of them better. They get ported or improved, never
   duplicated.
3. **NOTHING AN ADMIN SHOULD EDIT IS COMPILED INTO THE APK.** If the answer to "can the
   team change this without shipping a new build?" is no, it is a bug.

---

## 1. CLASSIFICATION KEY

| Code | Meaning |
|---|---|
| **HAVE** | Already exists and works. Do not rebuild. |
| **UIUX** | Exists and works, but the experience needs the redesign. |
| **PART** | Half-built: some pieces exist, something essential is missing. |
| **NEW** | Does not exist anywhere in either repo. |
| **PORT** | Works on the backend; the Flutter app cannot reach it yet. |
| **API** | Exists on the website as a server-rendered page; needs a JSON route before the app can use it. |
| **SKIP** | Deliberately not doing it, with a reason. |

Scope: **A** = app-only · **W** = website-only · **S** = shared app + website.

---

## 2. THE INVENTORY

### 2.1 Identity, profile and onboarding

| # | Feature | Class | Scope | Evidence / what is actually there |
|---|---|---|---|---|
| 1 | Email/username login, refresh, logout | **HAVE** | S | `/api/auth/*`, bearer + cookie envelopes. **PROTECTED.** |
| 2 | Signup form | **UIUX** | S | `/api/auth/signup` requires only surname, first_name, email, password. |
| 3 | Phone at signup | **PART** | S | App enforces it (`signup_screen.dart:479`), **server does not**. Must become required server-side. |
| 4 | Country on profile | **PART** | S | `profiles.country_code` exists, already constrained to NG/GH/SL/LR/GM. No country *name*, no full world list. |
| 5 | **State / region on profile** | **NEW** | S | Grep of all 14 migrations: `state` appears only on `institutions.state` and `gram_presence.state`. **The student has no state.** |
| 6 | Institution choice on profile | **NEW** | S | `profiles.uploader_school_id` is dead code — zero references in `src/`, no FK. |
| 7 | Subject combination at signup | **PART** | S | `/api/suggestions` already maps course → subject hints. Nothing captures the student's own combination. |
| 8 | **pushForm backfill for existing accounts** | **NEW** | S | Nothing resembling it. Compulsory, one-time, never shown to new accounts. |
| 9 | Profile screen | **UIUX** | A | `profile_screen.dart` exists (built last session). |
| 10 | Student-facing profile update endpoint | **NEW** | S | No `PATCH /api/me`, no `/api/profile`. All 17 profile updates are admin ops. |
| 11 | Email verification screen | **PORT** | A | `/api/auth/verify` accepts Bearer; app has no screen. |
| 12 | Edit-profile entry from a drawer header | **NEW** | A | App has no drawer at all yet. |

### 2.2 The question bank and the sitting

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 13 | Exam types JAMB/WAEC/NECO/NABTEB/GCE/Post-UTME | **HAVE** | S | `exams → subjects` are **rows, not an enum** (`0001_init.sql:40,53`). Exam type is already first-class. |
| 14 | Years, topics, tutorial-vs-past split | **HAVE** | S | `pick_question_ids(...p_kind)` (`0018:80-114`), real topic tree (`0014:34-109`). |
| 15 | Test configurator (exam/subject/source/count/mode/minutes) | **UIUX** | S | `PracticeChooser.tsx`. Richer than the reference already. |
| 16 | Four test modes: practice, cbt, jamb_mock, jamb_mini | **HAVE** | S | `attempts/route.ts`. Reference has three. |
| 17 | Timer with auto-submit | **HAVE** | S | `ExamEngine.tsx` |
| 18 | Question navigator + flag-for-review | **HAVE** | S | `ExamEngine.tsx` |
| 19 | Multi-subject tabs in one sitting | **HAVE** | S | `subjects[]` already returned by `attempts` start. |
| 20 | In-test calculator | **HAVE** | S | `Calculator.tsx` |
| 21 | Read question aloud (TTS) | **HAVE** | W | Browser TTS. **App needs a native equivalent** → PART for mobile. |
| 22 | Bookmark a question | **HAVE / PORT** | S | `/api/qmark {op:'save'}` + `/saved`. App cannot reach it. |
| 23 | Report a bad question | **HAVE / PORT** | S | `/api/qmark {op:'flag'}` → `question_flags` → `/admin/flags`. Full loop already closed. |
| 24 | Ask AI about *this* question | **HAVE / PORT** | S | Ask Lumi inside `ExamEngine`, practice mode only. |
| 25 | Autosave + resume an unfinished sitting | **HAVE** | S | 1.2s debounce + `sendBeacon`; 7-day resume card. |
| 26 | Comprehension passages kept intact when shuffling | **HAVE** | S | `attempts/route.ts:167-208`. A detail the reference does not have. |
| 27 | Question search | **HAVE / UIUX** | S | `/api/search`, `ilike` over raw HTML, 3-char min. Needs a real index and a non-empty empty-state. |
| 28 | **Shuffle options** | **NEW** | S | No shuffle code, no flag, no column. The same answer is always in the same position. |
| 29 | Free-form question count / duration | **NEW** | S | Fixed chips only, both platforms. |
| 30 | Practice-my-bookmarks as a generated sitting | **NEW** | S | `saved_ids` exist; nothing turns them into a paper. |
| 31 | Handwriting maths pad | **NEW** | A | Students cannot type maths. High value, pairs with Lumi. |

### 2.3 Results and analysis

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 32 | Result history | **HAVE / API** | S | `/history` is an RSC querying `attempts` directly. **No JSON route** → app blocked. |
| 33 | Per-subject score breakdown | **HAVE** | S | `attempts.score` blob carries `perSubject[]`, `scaled[]`, `projected`. |
| 34 | Performance analysis charts | **HAVE / API + UIUX** | S | `/analysis`, 8 sections, hand-rolled SVG kit. RSC only. |
| 35 | Corrections after a sitting | **PART** | S | Built in memory, returned once at submit, **never persisted**. No `/api/attempts/[id]`. |
| 36 | Review screen | **HAVE** | A | `review_screen.dart` already exists in the app and is good. |
| 37 | Per-topic strength/weakness per student | **NEW** | S | Ingredients all exist (`question_topics`, `attempts.answers`); nothing joins them per user. |
| 38 | Plain-English insight under a chart | **NEW** | S | Lumi never receives attempt data. This is the thing that beats every reference screen. |
| 39 | Streak | **HAVE** | S | `effectiveStreak`, bumped once per calendar day. |

### 2.4 Learning / classroom

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 40 | Notes, videos, documents per subject | **HAVE / API** | S | RSCs with `adminDb()`. **No `/api/notes` exists** — the mobile contract names one; it lies. |
| 41 | Watermarked PDF reader | **HAVE** | W | `/api/doc/[id]` streams per-page name-watermarked PDF. Excellent, keep. |
| 42 | Classroom / materials / hub / theatre | **HAVE / API** | S | `/classroom`, `/materials`, `/hub`, `/watch`. |
| 43 | Per-subject progress ring | **NEW** | S | No note-read, video-position or document-open record of any kind. |
| 44 | Per-subject offline download | **NEW** | **A** | Mobile only. **Never for the website.** |
| 45 | Study plan / timetable | **NEW** | S | No table, route, page or column. |
| 46 | Exercises attached to a note | **NEW** | S | No note→question link. |
| 47 | Per-subject illustration + colour identity | **NEW** | S | Needs a `subjects.art` / `subjects.colour` admin field. |

### 2.5 Games, leaderboard, competition

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 48 | Educational games | **HAVE / PORT** | S | Blitz 60, Survival, Road to 400, Daily Ten via `/api/games/pool`. |
| 49 | **The Climb** | **HAVE / PORT** | S | Server-authoritative 15-rung ladder, 5 lifelines incl. Ask-the-Class from real `question_stats`. **Strictly better than the reference's "Millionaire".** |
| 50 | Leaderboard | **HAVE / UIUX** | S | `/api/leaderboard`, public, points recomputed per request. |
| 51 | **Country + state on the leaderboard** | **NEW** | S | Selects `id,first_name,surname,username,streak_count,streak_date` only. No geography at all. |
| 52 | Leaderboard filters + own rank pinned | **NEW** | S | No query params, no `me`, no filters. |
| 53 | Documented tie-break | **PART** | S | Stable sort accidentally means "oldest account wins". Must become score-then-time, stated. |
| 54 | **Scheduled competition rounds + prizes** | **NEW** | S | No tournament/round/season/prize table in any of the 14 migrations. |
| 55 | Winner announcements | **NEW** | S | Depends on #54 and the news system. |

### 2.6 Career and institution

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 56 | Institution catalogue | **HAVE / API** | S | `institutions`, `departments`, `schools`, `universities` + `/aggregate`. RSC only. |
| 57 | Cut-off marks as data | **PART** | S | `departments.cutoff_text` is **prose**. No numeric model → no "who offers Medicine under 60?". |
| 58 | Aggregate formula | **PART** | S | `institutions.aggregate_body` is HTML prose. No weights, no divisor. |
| 59 | Cross-institution course search | **NEW** | S | Departments queryable one institution at a time only. |
| 60 | Career guide | **NEW** | S | No `careers`, `career_paths`, aptitude or interest table anywhere. |
| 61 | Course recommendation from subjects/scores | **NEW** | S | No `course_requirements`, no `utme_combinations`. |

### 2.7 Communication, content and support

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 62 | Notice/announcement system with per-user read state | **PART** | S | **Exists twice, incompatibly** — `activity_log type='notice_ack'` (the gate) vs `profiles.announcements_seen_at` (the bell). They never reconcile. |
| 63 | Rich notification body + multiple CTA buttons | **NEW** | S | `notices` has only `id, title, body, active, created_at`. No link, image, priority, expiry or targeting. |
| 64 | **NEWS** (distinct from announcements) | **NEW** | S | No news table, `/news` route, `/admin/news`, changelog or feed. |
| 65 | Dashboard promo carousel | **NEW** | S | Nothing. |
| 66 | Quote of the Day | **PART** | S | `quotes` table + 12 rows + full admin CRUD **exist and nothing reads them**. Three rival hardcoded sources render instead. **Wire it, do not build it.** |
| 67 | **Support contact management** | **NEW** | S | Every phone/WhatsApp/email is a hardcoded literal in 8+ files. `site_content.support_email_display` is editable and then **ignored** by `Footer.tsx`. |
| 68 | Social links | **HAVE** | S | `social_links` table + `/admin/socials`. |
| 69 | Onboarding tour as a notification | **NEW** | S | Best idea in the reference: an admin-editable feature tour, no app update needed. |
| 70 | "NEW" badge on a feature | **NEW** | S | Needs an admin-settable flag per feature tile. |
| 71 | Push notifications | **NEW** | A | No FCM, OneSignal or web-push in either repo. |

### 2.8 Money

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 72 | Account-based activation | **HAVE** | S | `profiles.activated` via `activationOpen()`. **Better than the reference's device lock. Keep.** |
| 73 | Paystack checkout | **HAVE / PORT** | S | `/api/pay/init`, server-priced from `country_prices` by `country_code`, HMAC webhook + independent callback confirm. |
| 74 | Bank transfer with proof upload | **HAVE / PORT** | S | `/api/upload-proof` → `pending_transfers` → admin `transfer_decide`. |
| 75 | Activation keys | **HAVE / PORT** | S | 7-digit, batch-minted at `/admin/keys`, auto-issued per account at signup. |
| 76 | Receipts + PDF | **HAVE / PORT** | S | `/api/receipt-pdf/[reference]`. |
| 77 | Referral code + ₦500 + withdrawals | **HAVE / PORT** | S | `referral_code`, `referred_by`, `/api/referrals`. |
| 78 | **Discount / referral code at checkout** | **NEW** | S | `/api/pay/init` takes no body at all. This is the missing half of the referral loop. |
| 79 | Referral earnings ledger | **PART** | S | Balance recomputed live on every request; no credit event. |
| 80 | Tabbed activation surface (key / PIN / buy / terms) | **UIUX** | S | All the routes exist; the surface does not. |
| 81 | Device-locked licensing | **SKIP** | — | Ours is account-based and better. Losing a phone must not cost a student what they paid. |

### 2.9 Admin

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 82 | Admin cockpit, 41 pages, 31 tables, 40 named ops | **HAVE** | W | HMAC `bmxd_admin` cookie over `admin_accounts`. |
| 83 | Student row action buttons | **HAVE** | W | **Six already exist**: Open file, Activate/Deactivate, Reset device, Freeze/Unfreeze, Edit, Delete (`admin/users/page.tsx:27-42`). ⚠️ *Open question — see §6.* |
| 84 | Whole-table CSV + PDF export | **HAVE** | W | Live on all 31 desks via `/api/admin/export`. |
| 85 | Four importers + staged AI importer | **HAVE** | W | MyQuest, ALOC, bulk, PDF. |
| 86 | Bank X-ray, duplicate finder, flags desk | **HAVE** | W | |
| 87 | Admin visibility into a single sitting | **NEW** | W | No page can open an attempt, replay a paper or void a result. |
| 88 | Admin role/permission model + action audit log | **NEW** | W | Every admin can do everything. |
| 89 | Desks for: news, contacts, carousel, rounds, prizes, careers, courses, badges, tour | **NEW** | W | All required by the features above. |

### 2.10 Guardian

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 90 | Guardian/parent portal + result upload | **NEW** | S | A whole second audience. Scoped but deferred — see §6. |

### 2.11 Shell, design and performance

| # | Feature | Class | Scope | Evidence |
|---|---|---|---|---|
| 91 | Design system | **UIUX** | A | Gradient/glass everywhere. 56% of type references are ≤13px. Must be rebuilt: solid surfaces, blue brand, per-feature colour, true-black dark mode, bigger type. |
| 92 | Splash / startup | **UIUX** | A | ~10s to usable. Target 3–5s, honestly. |
| 93 | Bottom navigation | **NEW** | A | App pushes routes; there is no persistent nav. |
| 94 | Navigation drawer, grouped by audience | **NEW** | A | |
| 95 | Contact sheet from the app bar | **NEW** | A | Depends on #67. |
| 96 | Bottom-sheet picker for tiles with sub-items | **NEW** | A | |
| 97 | Offline vault | **PART** | **A** | `drift` + `sqlite3_flutter_libs` are in `pubspec.yaml`; **no Dart file references them**. Scaffolding only. **Never for the website.** |
| 98 | Searchable country/state picker | **NEW** | S | Reference has a 200-item unsearchable list. We fix it. |

---

## 3. NEW BACKEND / ADMIN STRUCTURE REQUIRED

Everything below is content the LockInPoint team must be able to change **without a new APK**.

| Structure | Purpose | Admin desk |
|---|---|---|
| `countries` + `regions` (constant, versioned, shared) | Full world country list; states/regions for NG, GH, LR, GM, SL only | seeded, not edited |
| `profiles.state_code`, `country_code` (widened), `institution_id`, `subject_combination` | The signup + backfill fields | `/admin/users/[id]` |
| `profile_completion_prompts` | Drives the one-time compulsory `pushForm` | — |
| `news` | Title, body (rich), cover, category, published, pinned, publish_at | `/admin/news` |
| `announcements` (rework of `notices`) | + type, icon, priority, expiry, targeting, **0..N CTA actions**, one read-state mechanism | `/admin/announcements` |
| `announcement_actions` | Label + target per CTA button | same |
| `carousel_slides` | Image, headline, subtext, link, order, active, date window | `/admin/carousel` |
| `support_contacts` | **channel** (phone/whatsapp/email/link), label, value, icon, description, order, active — **many rows per channel** | `/admin/contacts` |
| `quotes` (**exists — wire it**) | + `active`, `show_on` date; delete the three hardcoded sources | `/admin/quotes` (exists) |
| `feature_flags` / `feature_tiles` | Tile title, subtitle, icon, colour, route, **NEW badge**, order, active | `/admin/features` |
| `challenge_rounds` + `challenge_entries` | Exam type, subjects, start, duration, prize text, question set, published | `/admin/challenges` |
| `prizes` | Attached to a round | same |
| `careers`, `career_courses` | Career info, required courses | `/admin/careers` |
| `courses` + `course_requirements` | Numeric cut-offs, UTME subject combinations, per institution | `/admin/courses` |
| `subjects.colour`, `subjects.art` | Per-subject identity | `/admin/exams` |
| `content_progress` | Per-student note/video/document progress | — |
| `attempt_details` or `/api/attempts/[id]` | Persisted corrections | `/admin/attempts` (new) |
| `topic_performance` (view or RPC) | Per-student per-topic strength | — |
| `payment_discounts` | Referral/discount code accepted at checkout | `/admin/prices` |
| `referral_ledger` | Credit events instead of live recompute | `/admin/withdrawals` |

**No fake data will be entered anywhere.** Each desk ships empty, with the correct shape.

---

## 4. THE 14-PHASE PLAN

Executed in dependency order, autonomously, with tests + analysis + format after each module.

| Phase | Contents | Depends on |
|---|---|---|
| **1 — Foundation & performance** | Bundle fonts as assets (kill 3 runtime font fetches); collapse the sequential `/api/me` → dashboard chain into one parallel start; persist + render the last dashboard snapshot instantly; fix the `src/middleware.ts` matcher so `/api/*` stops paying a Supabase round trip; measure before/after honestly | — |
| **2 — Design system** | New tokens: solid surfaces, white light / true-black dark, blue brand + a 12-hue feature palette in one lightness band; type scale raised throughout; new components (feature tile, stat, section header, sheet, badge, empty state); dark mode designed independently | 1 |
| **3 — Core navigation & home** | Animated splash (logo, tagline, footer); bottom nav; grouped drawer; the colour-coded home grid; promo carousel; notification bell; contact sheet | 2 |
| **4 — Question / test experience** | The sitting rebuilt to reference quality on LockInPoint's engine — blue=selection, green=forward, amber=time, orange=submit; navigator, subject tabs, bookmark, report, calculator, native TTS, Ask Lumi; exam type first-class throughout | 2, 3 |
| **5 — Learning / classroom** | `/api/notes` + list routes; classroom with per-subject art, colour and progress; per-subject offline download (**app only**); the reader | 2, 4 |
| **6 — AI / Lumi** | Markdown answers, read-aloud, image attach, voice input, reset, contextual "ask about this question"; feed Lumi attempt data | 4 |
| **7 — Results & analysis** | `/api/attempts` list + `[id]` detail with persisted corrections; result history redesigned (score dial, per-subject bars, mode badge); native charts with y clamped at 0 and filter chips; **per-topic strength/weakness**; plain-English insight lines | 4 |
| **8 — Games, challenges, leaderboards** | Port the four games + The Climb; leaderboard with **country + state**, filters, pinned own rank, documented score-then-time tie-break; challenge rounds with countdown, join, prizes; **fix the `action`/`type` points bug** | 7 |
| **9 — Career & institution** | Numeric cut-off + course-requirement model; school finder; cross-institution course search; career guide; course recommendation from the student's subjects | 2 |
| **10 — Notifications & news** | Unify the two read-state mechanisms into one; rich announcements with 0..N CTAs; news feed; carousel; quote of the day **wired to the existing table**; onboarding tour as a notification | 3 |
| **11 — Activation & payment** | Tabbed activation surface on the existing account-based architecture; key redemption, transfer + proof, Paystack in a WebView, receipts; **discount/referral code at checkout**; micro-help links | 2 |
| **12 — Admin & backend** | Every desk in §3: news, contacts, carousel, features/badges, challenges, prizes, careers, courses, attempt inspector; migrations for everything, **including recovering the missing 0003–0006 DDL** | as needed |
| **13 — Website parity** | Signup fields + backfill on the web; leaderboard geography; news, contacts, carousel, challenges on the site. **Offline vault is excluded — mobile only.** | 12 |
| **14 — QA & release** | Full test sweep; APK + AAB; iOS build validated as far as the sandbox allows with the **Apple signing dependency stated plainly, not hidden**; desktop where supported — one codebase, one design | all |

---

## 5. BUGS FOUND DURING THE AUDIT

| # | Severity | Finding |
|---|---|---|
| B1 | **High** | `/api/leaderboard:17` does `.select("user_id,action").in("type",[…])`. `ORDERS.md` Order 31 states the column is `type`, never `action`. PostgREST errors, the error is swallowed, so the "+5 per app entry" points term contributes **zero**. Six other call sites repeat it. |
| B2 | **High** | The bell (`profiles.announcements_seen_at`) and the announcement gate (`activity_log type='notice_ack'`) are two rival read-state systems that never reconcile. Acking every notice leaves the bell lit. |
| B3 | Medium | `/admin/site-content` edits `support_email_display`, `Footer.tsx` fetches it — then renders a hardcoded `mailto:` anyway. The edited value is never used. |
| B4 | Medium | `src/middleware.ts` runs `supabase.auth.getUser()` — a network round trip — on `/api/*`, so every bearer call from the app pays a cookie-session refresh it never uses. Directly costs mobile startup time. |
| B5 | **High** | Migrations **0003–0006 were never committed** (confirmed via `git log`). Missing DDL for `profiles.referral_code`, `referred_by`, `announcements_seen_at`, `attempts.created_at`, and the tables `activity_log`, `notices`, `withdrawals`, `countdowns`, `universities`. A fresh database cannot run signup or the leaderboard. |
| B6 | **CRITICAL — SECURITY** | `src/lib/keys.ts`, `src/lib/keys-server.ts` and `src/lib/ai-config.ts` are **tracked in git** and hold the Supabase URL + anon key, the **service-role key** and a Gemini key. `keys-server.ts:60` derives `ADMIN_COOKIE_SECRET` from the service-role key — its own comment says *"anyone who can read this repository can forge an admin session."* Plaintext superadmin credentials are committed in `src/app/api/setup/route.ts:9-19` and `src/lib/seed-admins.ts:5-8`. `ORDERS.md`'s own Golden Key Rule forbids shipping these files. **These keys need rotating.** |
| B7 | Low | `src/app/manifest.ts` ships a PWA manifest although `ORDERS.md` Orders 25 and 31 forbid PWA. |
| B8 | Low | The hidden `gst` exam has no key in the export whitelist, so the door Order 24 promised returns 400. |

---

## 6. OPEN QUESTIONS — answers change what gets built

1. **Admin student action button.** Six per-row buttons already exist (Open file, Activate/Deactivate, Reset device, Freeze/Unfreeze, Edit, Delete). Something specific is missing — *which action?*
2. **Guardian portal (#90).** A parent audience is a large build: separate accounts, linking, permissions, result sharing. In or out of this cycle?
3. **Virtual labs.** Simulated experiments are a product in themselves. Placeholder tile now, or skip?
4. **Activation price.** `country_prices` already drives pricing per country. Confirm the app should read it rather than show a fixed figure.

Work proceeds on everything else regardless; these four are held.
