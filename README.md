# LockInPoint Mobile

The native Flutter application for LockInPoint — a client of the existing
LockInPoint backend, not a second product with a second database.

Students are the same students, the questions are the same questions, and the
admin panel on the website remains the single control centre for content.

## What a student can do today

| Screen | What works |
|---|---|
| Welcome, sign up, log in, forgot password | the website's own routes, so the device slot and activity log are kept |
| Dashboard | real name, streak, live counts, Continue Practice, WhatsApp channel |
| Practice | exam → subject → year, topic, random mix or tutorial questions |
| A practice sitting | instant marking, explanations, passages, diagrams, autosave, resume |
| CBT | a server anchored clock, no marking until submit, auto submit at zero |
| Review | every marked question, your answer, the right one, and why |
| Question search | any phrase, paged, answer behind a tap |
| Leaderboard | the ladder and the points law that produces it |

Not built yet: Classroom, the games arena, performance analysis, Lumi, saved
questions, and the Offline Vault.

## Where things are

```
lib/
  app/      shell and theme controller
  design/   tokens · typography · theme · glass · aura · components · motion
  core/     api client, session store, config
  features/ auth · home · practice · search · leaderboard · onboarding
```

## Running it

```
flutter pub get
./scripts/verify.sh        # exactly what CI runs: format, analyze, test
./scripts/verify.sh --fix  # …and write the formatting first
flutter run                # needs an Android SDK or a connected device
```

Run `verify.sh` before every push. CI checks formatting across the WHOLE
repository, so a locally formatted `lib/` and `test/` is not the same thing.

## Getting an APK

`flutter build apk` needs the Android SDK. If you do not have it locally, the
**build** workflow produces an installable debug APK: open the repository's
Actions tab → *build* → *Run workflow*, and download the artifact from the
finished run. It is named `lockinpoint-<version>-<commit>.apk`, so several
downloads stay tellable apart.

The APK is **debug signed**, which installs on any phone but is not a Play
Store upload. A release build needs an upload keystore, created once and then
never lost; `release.yml` is ready for it.

## The rules this project holds to

- **The identity never changes.** `com.lockinpoint.app`, one signing key. Change
  either and every existing installation loses the ability to update.
- **Colours come from the theme, never from a literal.** Both themes are built
  from the same shape, and tests assert contrast in each.
- **Glass blurs only on chrome.** `GlassSurface` does not blur by default,
  because a `BackdropFilter` on every card in a list drops frames on a cheap
  Android phone. A test enforces the default.
- **Every screen has all four states**: loading, empty, error, content.
