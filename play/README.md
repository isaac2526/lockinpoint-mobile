# Play Console assets

Everything the LockInPoint listing asks for, at the maximum count each slot
accepts. All 33 images validate against Play's published limits.

| Folder | Slot | Count | Pixels | Ratio | Play's rule |
|---|---|---|---|---|---|
| `feature-graphic/` | Feature graphic | 1 | 1024 × 500 | — | exactly 1024 × 500, ≤ 15 MB |
| `screenshots/phone/` | Phone | 8 | 1440 × 2560 | 9:16 | 2–8, sides 320–3840 px, ≤ 8 MB |
| `tablet-7/` | 7-inch tablet | 6 | 2560 × 1440 | 16:9 | ≤ 8, sides 320–3840 px, ≤ 8 MB |
| `tablet-10/` | 10-inch tablet | 6 | 3200 × 1800 | 16:9 | ≤ 8, sides 1080–7680 px, ≤ 8 MB |
| `desktop/` | Desktop | 6 | 2880 × 1620 | 16:9 | 4–8, sides 1080–7680 px, ≤ 8 MB |
| `xr/` | Android XR | 6 | 2560 × 1440 | 16:9 | 4–8, sides 720–7680 px, ≤ 15 MB |

Phone screenshots max out at eight because that is the slot's ceiling, not
because the set ran out — there is no ninth.

## Two layouts, not one stretched

The phone set is the app as a phone shows it: a bottom bar of Home, Practice,
Ranking, Profile, and one column of content.

The wide set — tablet, desktop and XR — is the app as a wide screen shows it:
the bottom bar becomes a persistent rail carrying the drawer's *Learning*
group, and the content runs in two working columns. The sitting puts the
question beside its options; the classroom puts the shelf beside the note it
opened; analysis puts the trend beside the topic breakdown. Those three
families share one 872 × 572 screen and differ only in housing — a bezelled
slate, a window with a title bar, a pane floating in space — so a change to a
screen reaches all three at once.

## Where the pixels come from

Nothing here is invented styling. The palette is read out of
`lib/design/tokens.dart` — `LipColors.light` for surfaces and text tiers,
`LipHues.lightSet` for the twelve feature hues — and every background wash is a
deepened form of the hue the app itself assigns that feature, so practice is
blue, the classroom violet, the vault teal and the Climb gold.

The copy is quoted from the Dart: the grid from `feature_catalogue.dart`, the
set-up steps from `practice_flow_screen.dart`, *"Sharp. Keep this pace."* and
the result breakdown from `practice_session_screen.dart`, the rail from
`app/shell.dart`, and the rest from `analysis_screen.dart`,
`classroom_screen.dart`, `vault_screen.dart` and `climb_screen.dart`.
`LipLabel` uppercases its text in the app, so section labels are uppercased
here too. The tagline on the feature graphic, *Lock in. Pass everything.*, is
the splash screen's own.

Sample data is representative rather than captured from one account: a 265/400
mock, a twelve-day streak, five downloaded packs.

## Regenerating

```
cd play/screenshots
npm i playwright          # PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 if a browser is present
node gen.mjs              # 8 phone shots      -> out/
node gen-wide.mjs         # feature graphic + all 4 wide families
node gen.mjs 04           # just the one whose name contains "04"
```

Both scripts pin `executablePath` to a Chromium that exists on the build box;
change that line if yours lives elsewhere.

The phone page is laid out at 720 × 1280 CSS px and captured at
`deviceScaleFactor: 2`. The wide page is laid out once at 1280 × 720 and
captured at 2, 2.5 and 2.25 — which is how one markup satisfies four different
Play minimums with no reflow, and why the type is sharp rather than upscaled.

| File | Holds |
|---|---|
| `ui.mjs` | palette, icon set, phone frame, portrait page shell |
| `screens.mjs` | the eight phone screens |
| `wide.mjs` | the rail, the six landscape screens, their headlines |
| `frames.mjs` | tablet / desktop / XR housings, and the feature graphic |
| `gen.mjs`, `gen-wide.mjs` | the capture loops |

## A caveat worth keeping

These are reconstructions built from the source, not captures of a running
build — this machine has no Flutter SDK. Layout order, copy, colours and hues
are taken from the code, but if a screen has drifted since, fix it in
`screens.mjs` or `wide.mjs` and re-run rather than editing a PNG.
