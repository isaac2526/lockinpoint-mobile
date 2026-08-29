# Working on this repository

## Before you push

```
dart format .
flutter analyze --fatal-infos
flutter test
```

CI runs exactly these three on every push and takes about three minutes. The
Android build is a separate workflow, so a typo fix never costs half an hour.

## Conventions

- One folder per feature under `lib/features/`, each with `data/`, `domain/`
  and `ui/`. Everything about the sitting engine lives in one place.
- A screen never touches HTTP or SQL. It talks to a controller; the controller
  talks to a repository; only the repository knows whether an answer came from
  the network or the offline vault.
- Colours, spacing, radii and motion come from `lib/design/tokens.dart`. If you
  are typing a hex value inside a screen, the design system is missing
  something — add it there instead.
