import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/core/smart_cache.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/leaderboard/leaderboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ===========================================================================
/// THE LAST GOOD ANSWER, AND HOW OLD IT IS
///
/// The leaderboard had NO CACHE. Off signal a student got an error card in
/// place of a position they had already been shown — which helps nobody,
/// because their rank from this morning is very nearly right.
///
/// This is the whole journey, not a unit: fetch it online, lose the network,
/// see the SAME board with a line saying how old it is, get the network back,
/// and watch it come up to date.
/// ===========================================================================

/// A server that can be switched off, and whose answers can change.
class _Flaky extends Fake implements Api {
  _Flaky();

  bool online = true;
  int points = 900;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    calls++;
    if (!online) throw ApiFailure('No connection. Try again in a moment.');
    return {
      'ok': true,
      'total': 2,
      'scopes': const [
        {'key': 'national', 'label': 'Nigeria'},
      ],
      'rows': [
        {'rank': 1, 'name': 'Chidi', 'points': points, 'me': false},
        {'rank': 2, 'name': 'Isaac', 'points': points - 100, 'me': true},
      ],
      'me': {'rank': 2, 'name': 'Isaac', 'points': points - 100, 'me': true},
    };
  }
}

/// A COLD START, every time.
///
/// Pumping a second ProviderScope of the same type at the same position lets
/// Flutter REUSE the element — so the container, and every provider in it,
/// survives. The second "launch" was quietly showing the first launch's
/// answer, which made the offline case look like it worked when nothing had
/// been read from storage at all. An empty tree in between forces the real
/// thing: a new container, a new read, exactly as reopening the app does.
Future<void> _pumpBoard(WidgetTester tester, _Flaky api) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: LipTheme.light(),
        home: const LeaderboardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('online it shows the live board and says nothing about age', (
    tester,
  ) async {
    final api = _Flaky();
    await _pumpBoard(tester, api);

    expect(find.text('Chidi'), findsOneWidget);
    expect(find.textContaining('Showing what we had'), findsNothing);
  });

  testWidgets('OFFLINE it shows the same board, marked as old', (tester) async {
    // First, a real fetch, so there is something to remember.
    final api = _Flaky();
    await _pumpBoard(tester, api);
    expect(find.text('Chidi'), findsOneWidget);

    // Now the network goes. A fresh screen must not show an error card.
    api.online = false;
    await _pumpBoard(tester, api);

    expect(
      find.text('Chidi'),
      findsOneWidget,
      reason:
          'the board a student was already shown must survive going off '
          'signal — an error card in its place helps nobody',
    );
    expect(
      find.textContaining('Showing what we had'),
      findsOneWidget,
      reason:
          'a stale rank presented as live tells a student something '
          'false about their own work',
    );
    expect(find.textContaining('back online'), findsOneWidget);
  });

  testWidgets('back online, it catches up on its own', (tester) async {
    final api = _Flaky();
    await _pumpBoard(tester, api);

    api.online = false;
    await _pumpBoard(tester, api);
    expect(find.textContaining('Showing what we had'), findsOneWidget);

    // The network returns, AND the board has moved on while it was away.
    api.online = true;
    api.points = 1500;
    await _pumpBoard(tester, api);

    expect(find.textContaining('Showing what we had'), findsNothing);
    /* The board moved on while the phone was away: Isaac was on 800 and is
       now on 1400. The STORED figures must not be what is on screen. */
    expect(
      find.text('1400'),
      findsWidgets,
      reason: 'the fresh figures should be on screen, not the stored ones',
    );
    expect(find.text('800'), findsNothing, reason: 'that is the old number');
  });

  testWidgets('a FIRST launch with no network fails honestly', (tester) async {
    /* There is nothing to fall back on, and inventing an empty board would
       be worse than saying so. */
    final api = _Flaky()..online = false;
    await _pumpBoard(tester, api);

    expect(find.text('Chidi'), findsNothing);
    expect(find.text('That did not load'), findsOneWidget);
    expect(find.textContaining('No connection'), findsWidgets);
  });

  group('how old it is, in words a person uses', () {
    test('the age line reads like a person wrote it', () {
      final now = DateTime.now();
      String age(Duration d) =>
          Cached(value: 1, savedAt: now.subtract(d), live: false).age;

      expect(age(const Duration(seconds: 5)), 'just now');
      expect(age(const Duration(minutes: 8)), '8 minutes ago');
      expect(age(const Duration(hours: 1)), '1 hour ago');
      expect(age(const Duration(hours: 5)), '5 hours ago');
      expect(age(const Duration(days: 1, hours: 2)), 'yesterday');
      expect(age(const Duration(days: 3)), '3 days ago');
      expect(age(const Duration(days: 40)), 'a while ago');
    });

    test('live content never claims to be stale', () {
      const fresh = Cached(value: 1);
      expect(fresh.isStale, isFalse);
      expect(fresh.staleLine, '');
    });
  });

  group('what the cache must NOT do', () {
    test("a server saying 'no' is an answer, not a network failure", () async {
      /* "You are not in any school yet" is the server ANSWERING. Replacing
         that with a week-old board would be a lie of a different and worse
         kind. */
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(_Refuses())],
      );
      addTearDown(container.dispose);

      final got = await readCached(
        container.read(_refProvider),
        key: 'k',
        path: '/x',
      );
      expect(got.live, isTrue);
      expect(got.value['ok'], false);
    });
  });
}

class _Refuses extends Fake implements Api {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => {'ok': false, 'message': 'You are not in any school yet.'};
}

/// Hands a Ref to a plain test.
final _refProvider = Provider<Ref>((ref) => ref);
