import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/glass.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/design/tokens.dart';
import 'package:lockinpoint/features/content/content_repository.dart';
import 'package:lockinpoint/features/home/dashboard_screen.dart';
import 'package:lockinpoint/features/home/feature_catalogue.dart';
import 'package:lockinpoint/features/home/feature_grid.dart';
import 'package:lockinpoint/features/home/home_carousel.dart';

/// ===========================================================================
/// THE HOME SCREEN
///
/// The old home was a vertical list of identical blue rows. These tests exist
/// so it cannot quietly become that again:
///
///   · the grid renders MANY colours, not one
///   · a feature keeps its colour for life, so the eye can learn it
///   · admin can rename, recolour and badge a tile without a release
///   · admin CANNOT invent a screen by naming a key the app does not have
///   · the carousel ships empty rather than inventing content
/// ===========================================================================
class _FakeDashboard extends DashboardController {
  _FakeDashboard(this._payload);
  final Map<String, dynamic> _payload;
  @override
  Future<Map<String, dynamic>> build() async => _payload;
}

const _student = {
  'ok': true,
  'frozen': false,
  'student': {
    'name': 'Adaeze',
    'surname': 'Okafor',
    'email': 'a@example.com',
    'activated': true,
    'emailVerified': true,
    'streak': 3,
  },
  'counts': {'questions': 100, 'attempts': 2, 'notes': 5},
  // The home screen leads with the STUDENT's numbers now, not the platform's.
  'you': {
    'accuracy': 68,
    'answered': 240,
    'sittings': 2,
    'dueToday': 3,
    'bestStreak': 12,
  },
  'resume': null,
};

/// Mounts the real dashboard against a fixed payload, with the providers it
/// reaches for stubbed out so the test is about layout and not the network.
Future<void> pumpDashboard(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardProvider.overrideWith(() => _FakeDashboard(_student)),
        featureTilesProvider.overrideWith((ref) async => const []),
        carouselProvider.overrideWith((ref) async => const []),
        supportContactsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const DashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  List<Map<String, dynamic>> tiles = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [featureTilesProvider.overrideWith((ref) async => tiles)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: FeatureGrid())),
      ),
    ),
  );
  /* The grid mounts tiles lazily, and each one schedules its entrance a few
     frames later — so settling once is not enough to drain them all. Pump
     past the longest stagger, then settle, or the test ends holding timers. */
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group(
    'the home screen shows the student, not the platform',
    _theirOwnNumbers,
  );

  group('the grid is colourful, not blue', () {
    testWidgets('renders every feature the app knows', (tester) async {
      await _pumpGrid(tester);
      expect(find.byType(FeatureTile), findsNWidgets(kFeatures.length));
    });

    testWidgets('uses MANY different hues, not one repeated', (tester) async {
      await _pumpGrid(tester);
      final fills = tester
          .widgetList<GlassSurface>(find.byType(GlassSurface))
          .map((g) => g.hue?.tint.toARGB32())
          .whereType<int>()
          .toSet();
      /* The whole point of the redesign. If someone ever makes every tile
         the brand colour again, this fails. */
      expect(
        fills.length,
        greaterThanOrEqualTo(8),
        reason: 'a grid of one colour is the list this replaced',
      );
    });

    test('colour still tells tiles apart, band by band', () {
      /* THE OLD RULE WAS "every tile has a unique hue", and it held while
         there were twelve tiles and twelve hues. There are twenty-two rooms
         now and still twelve hues, so that rule is arithmetically impossible
         — and dropping it would throw away the thing it protected.

         The scanning unit is the BAND: a student looking for Pointgram looks
         under Community, and only needs it to be unmistakable among the tiles
         beside it. So the invariant is uniqueness WITHIN a band, which is
         both achievable and the one that actually does the work. */
      for (final band in FeatureBand.values) {
        final inBand = kFeatures.where((f) => f.band == band).toList();
        final hues = inBand.map((f) => f.hue).toList();
        expect(
          hues.toSet().length,
          hues.length,
          reason:
              'two tiles in ${band.label} share a hue and cannot be told '
              'apart at a glance: '
              '${inBand.map((f) => "${f.title}=${f.hue.name}").join(", ")}',
        );
      }
    });

    test('semantic colour meanings hold', () {
      LipHue hueOf(String key) =>
          kFeatures.firstWhere((f) => f.key == key).hue.of(LipColors.light);
      expect(hueOf('practice'), LipColors.light.hues.blue);
      expect(hueOf('classroom'), LipColors.light.hues.violet);
      expect(hueOf('leaderboard'), LipColors.light.hues.pink);
      expect(hueOf('analysis'), LipColors.light.hues.indigo);
      expect(hueOf('bookmarks'), LipColors.light.hues.lime);
      expect(hueOf('history'), LipColors.light.hues.green);
      /* The offline vault is teal. Notes are not a tile of their own — they
         are classroom content, which is how the backend models them too. */
      expect(hueOf('vault'), LipColors.light.hues.teal);
      expect(kFeatures.any((f) => f.key == 'notes'), isFalse);
    });
  });

  group('admin owns the grid, within limits', () {
    testWidgets('a tile can be renamed and badged without a release', (
      tester,
    ) async {
      await _pumpGrid(
        tester,
        tiles: [
          {'key': 'practice', 'title': 'Practice JAMB', 'badge': 'NEW'},
        ],
      );
      expect(find.text('Practice JAMB'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
    });

    test('a tile can be recoloured', () {
      final merged = mergeFeatureTiles([
        {'key': 'practice', 'hue': 'green'},
      ]);
      expect(merged.first.key, 'practice');
      expect(merged.first.hue, FeatureHue.green);
    });

    test('admin CANNOT invent a screen the app does not have', () {
      final merged = mergeFeatureTiles([
        {'key': 'teleportation', 'title': 'Teleport', 'hue': 'pink'},
      ]);
      expect(
        merged.any((f) => f.key == 'teleportation'),
        isFalse,
        reason: 'a row cannot conjure a screen; it would be a dead tile',
      );
      // and the real grid survives intact
      expect(merged.length, kFeatures.length);
    });

    test('a tile admin never mentions still appears', () {
      final merged = mergeFeatureTiles([
        {'key': 'practice', 'title': 'Practice'},
      ]);
      expect(merged.length, kFeatures.length);
      expect(merged.first.key, 'practice');
    });
  });

  group('the carousel', () {
    testWidgets('shows NOTHING when the team has configured nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [carouselProvider.overrideWith((ref) async => [])],
          child: MaterialApp(
            theme: LipTheme.light(),
            home: const Scaffold(body: HomeCarousel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders the slides an admin actually wrote', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            carouselProvider.overrideWith(
              (ref) async => [
                {
                  'headline': 'JAMB 2026 registration is open',
                  'subtext': 'Closes 14 March',
                },
              ],
            ),
          ],
          child: MaterialApp(
            theme: LipTheme.light(),
            home: const Scaffold(body: HomeCarousel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('JAMB 2026 registration is open'), findsOneWidget);
      expect(find.text('Closes 14 March'), findsOneWidget);
    });
  });

  group('the home screen itself', () {
    testWidgets('greets the student and offers the drawer and the bell', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardProvider.overrideWith(() => _FakeDashboard(_student)),
            featureTilesProvider.overrideWith((ref) async => []),
            carouselProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            theme: LipTheme.light(),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(
                drawer: Drawer(child: Text('menu')),
                body: DashboardScreen(embedded: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, Adaeze'), findsOneWidget);
      expect(find.byTooltip('Menu'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });
  });
}

/// ===========================================================================
/// THE HOME SCREEN SHOWS THE STUDENT, NOT THE PLATFORM.
///
/// It used to lead with "100 questions live" and "5 notes & videos" — the size
/// of the bank. That is a sales figure: identical for every student, identical
/// tomorrow, and nothing they can act on. These hold the replacement.
/// ===========================================================================
void _theirOwnNumbers() {
  testWidgets('the platform question count is gone from the home screen', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.text('questions live'), findsNothing);
    expect(find.text('notes & videos'), findsNothing);
  });

  testWidgets('their accuracy, sittings and best streak are there instead', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.text('your accuracy'), findsOneWidget);
    expect(find.text('68%'), findsOneWidget);
    expect(find.text('sittings done'), findsOneWidget);
    expect(find.text('best streak'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('what the plan says to do today names a next action', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(
      find.text('3 tasks from your study plan are waiting'),
      findsOneWidget,
    );
  });
}
