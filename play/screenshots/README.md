# Play Store phone screenshots

Eight 1440 × 2560 PNGs in `phone/`, in upload order. Google Play accepts
**between 2 and 8** phone screenshots, so eight is the maximum the listing
can hold — there is no ninth slot to fill.

| # | File | Screen | Headline |
|---|------|--------|----------|
| 1 | `01-home.png` | Dashboard | Every past question. One app. |
| 2 | `02-practice.png` | Practice set-up, step 3 of 3 | Train the way you will be tested. |
| 3 | `03-sitting.png` | A JAMB mock mid-sitting | A real CBT, down to the clock. |
| 4 | `04-result.png` | Result, scored over 400 | Your score, the second you submit. |
| 5 | `05-analysis.png` | Performance analysis | See where your marks are going. |
| 6 | `06-classroom.png` | A subject shelf | Notes, videos and files to keep. |
| 7 | `07-vault.png` | Offline vault | Download once. Study with no data. |
| 8 | `08-climb.png` | The Climb | Fifteen rungs. Three lifelines. |

## Where the pixels come from

Nothing here is invented styling. The palette is read out of
`lib/design/tokens.dart` — `LipColors.light` for the surfaces and text tiers,
`LipHues.lightSet` for the twelve feature hues, each screenshot's background
wash being a deepened form of the hue the app itself assigns that feature. The
on-screen copy is quoted from the Dart source: `feature_catalogue.dart` for the
grid, `practice_flow_screen.dart` for the set-up steps and their labels,
`practice_session_screen.dart` for the sitting and the result sentences,
`analysis_screen.dart`, `classroom_screen.dart`, `vault_screen.dart` and
`climb_screen.dart` for the rest. `LipLabel` uppercases its text in the app, so
the section labels are uppercased here too.

The sample data is representative rather than captured from one account: a
265/400 mock, a 12-day streak, five downloaded packs.

## Regenerating

```
cd play/screenshots
npm i playwright            # PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 if a browser is already present
node gen.mjs                # all eight into out/
node gen.mjs 04             # just the one whose name contains "04"
```

`gen.mjs` pins `executablePath` to a Chromium that exists on the build box;
change that line if yours lives elsewhere. The page is laid out at 720 × 1280
CSS pixels and captured at `deviceScaleFactor: 2`, which is what makes the
output 1440 × 2560 and keeps the text sharp. Edit a headline in `gen.mjs`, a
screen's markup in `screens.mjs`, the palette or device frame in `ui.mjs`.

## Still to produce, if the listing asks for them

* **Feature graphic** — 1024 × 500, already made separately.
* **Tablet screenshots** — only required if the listing is published to
  tablets; the same generator with a wider viewport covers it.
