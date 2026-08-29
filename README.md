# LockInPoint Mobile

The native Flutter application for LockInPoint — a client of the existing
LockInPoint backend, not a second product with a second database.

Students are the same students, the questions are the same questions, and the
admin panel on the website remains the single control centre for content.

## Where things are

```
lib/
  app/      shell, theme controller, and (for now) the component gallery
  design/   tokens · typography · theme · glass · aura · components
  core/     api client, database, secure storage        (Phase 1)
  features/ one folder per feature: auth, practice, engine, vault, games …
```

## Running it

```
flutter pub get
flutter analyze
flutter test
flutter run          # needs an Android SDK or a connected device
```

## Getting an APK

`flutter build apk` needs the Android SDK. If you do not have it locally, the
**build** workflow produces an installable debug APK: open the repository's
Actions tab → *build* → *Run workflow*, and download `lockinpoint-debug-apk`
from the finished run.

## The rules this project holds to

- **The identity never changes.** `com.lockinpoint.app`, one signing key. Change
  either and every existing installation loses the ability to update.
- **Colours come from the theme, never from a literal.** Both themes are built
  from the same shape, and tests assert contrast in each.
- **Glass blurs only on chrome.** `GlassSurface` does not blur by default,
  because a `BackdropFilter` on every card in a list drops frames on a cheap
  Android phone. A test enforces the default.
- **Every screen has all four states**: loading, empty, error, content.
