import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/home/feature_catalogue.dart';
import 'package:lockinpoint/features/content/content_repository.dart';
import 'package:lockinpoint/features/home/feature_grid.dart';

/// ===========================================================================
/// EVERY ROOM IS ON THE DASHBOARD, AND EVERY TILE GOES SOMEWHERE.
///
/// The app grew nine rooms — Theory, Practical, Pointgram, the Study Plan, the
/// UTME Challenge, activity history, referrals, receipts, the question harvest
/// — and every one of them was wired into the DRAWER and left off the home
/// grid. So the owner opened the app, looked at the dashboard, and said the
/// new features were not there. He was right: a drawer is where you go when
/// you already know what you want, and a dashboard is how you learn what
/// exists. Building a room and not putting it on the dashboard is the same,
/// to the person using the app, as not building it.
///
/// These tests make that failure impossible to repeat quietly.
/// ===========================================================================
void main() {
  test('every room the app has is on the dashboard grid', () {
    final keys = kFeatures.map((f) => f.key).toSet();

    /* This list is the contract. A room added to the app and left off this
       list fails here, which is the whole point — the next person to build a
       screen is told, by a red test, that a screen nobody can find is not
       finished. */
    const mustBeReachable = {
      'practice',
      'classroom',
      'search',
      'history',
      'analysis',
      'games',
      'challenge',
      'leaderboard',
      'bookmarks',
      'vault',
      'career',
      'tutor',
      'theory',
      'practical',
      'plan',
      'rounds',
      'gram',
      'harvest',
      'referrals',
      'activity',
      'receipts',
      'activate',
    };

    final missing = mustBeReachable.difference(keys);
    expect(
      missing,
      isEmpty,
      reason:
          'These rooms exist in the app but have no tile on the '
          'dashboard, so a student can only reach them from the drawer: '
          '$missing',
    );
  });

  test('every tile on the grid has a screen behind it', () {
    // A tile that answers a tap with "not wired up yet" is worse than no
    // tile: it is a promise the app breaks in front of the student.
    for (final f in kFeatures) {
      expect(
        destinationForFeatureKey(f.key),
        isNotNull,
        reason:
            'The "${f.title}" tile (key ${f.key}) has no destination in '
            'feature_grid.dart, so tapping it shows an apology.',
      );
    }
  });

  test('every tile is banded, and every band is used', () {
    // A band with no tiles draws a heading over empty space.
    final used = kFeatures.map((f) => f.band).toSet();
    expect(
      used.length,
      FeatureBand.values.length,
      reason: 'Unused bands: ${FeatureBand.values.toSet().difference(used)}',
    );
  });

  test('the admin panel cannot invent a room the app does not have', () {
    // mergeFeatureTiles must drop an unknown key rather than render a dead
    // tile, and must keep tiles the admin simply did not mention.
    final merged = mergeFeatureTiles([
      {'key': 'not_a_real_screen', 'title': 'Ghost'},
      {'key': 'theory', 'title': 'Essay papers'},
    ]);
    expect(merged.any((f) => f.title == 'Ghost'), isFalse);
    expect(merged.firstWhere((f) => f.key == 'theory').title, 'Essay papers');
    // Silence is not a request to hide something.
    expect(merged.any((f) => f.key == 'gram'), isTrue);
  });

  testWidgets('the grid renders its bands, with the rooms that were missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // No network in a widget test: featureTilesProvider would fire a real
        // request and leave its timeout timer pending after the tree is gone.
        // These tests are about the catalogue defaults, which is exactly what
        // a student sees before an admin has configured a single row.
        overrides: [featureTilesProvider.overrideWith((ref) async => const [])],
        child: MaterialApp(
          theme: LipTheme.light(),
          home: const Scaffold(
            // Tall, so every band lays out in one pass. A lazy grid inside a
            // shrink-wrapped column builds children during layout, and a tile
            // created late leaves its entrance timer pending.
            body: SizedBox(
              height: 4000,
              child: SingleChildScrollView(child: FeatureGrid()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // LipLabel uppercases what it is given.
    expect(find.text('STUDY'), findsOneWidget);
    expect(find.text('COMPETE'), findsOneWidget);
    expect(find.text('COMMUNITY'), findsOneWidget);
    expect(find.text('YOURS'), findsOneWidget);

    // The owner's exact complaint, as a test: these were built, wired into
    // the drawer, and left off the only surface he looks at.
    expect(find.text('Theory'), findsOneWidget);
    expect(find.text('Practical'), findsOneWidget);
    expect(find.text('Pointgram'), findsOneWidget);
    expect(find.text('UTME Challenge'), findsOneWidget);
    expect(find.text('Study plan'), findsOneWidget);
    expect(find.text('Your activity'), findsOneWidget);
  });
}
