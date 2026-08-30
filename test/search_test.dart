import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/search/search_screen.dart';

/// Question search, driven the way a student drives it: type, wait, read.
class _FakeSearch extends Fake implements SearchRepository {
  final List<({String q, int page})> calls = [];

  @override
  Future<SearchResults> find(String query, {int page = 1}) async {
    calls.add((q: query, page: page));
    if (query.contains('nothing')) {
      return const SearchResults(rows: [], total: 0);
    }
    return const SearchResults(
      rows: [
        SearchHit(
          id: 'q1',
          question: '<p>What is the capital of Ghana?</p>',
          answer: 'C',
          explanation: '<p>Accra has been the capital since 1877.</p>',
          exam: 'WAEC',
          subject: 'Geography',
        ),
      ],
      total: 24,
    );
  }
}

Future<_FakeSearch> _pump(WidgetTester tester) async {
  final repo = _FakeSearch();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [searchRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: LipTheme.light(), home: const SearchScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('opens explaining itself, having asked the server nothing', (
    tester,
  ) async {
    final repo = await _pump(tester);
    expect(find.text('Find any past question'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('under three letters never reaches the server', (tester) async {
    final repo = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(seconds: 1));
    expect(repo.calls, isEmpty);
  });

  testWidgets('typing settles into ONE request, not one per keystroke', (
    tester,
  ) async {
    final repo = await _pump(tester);
    for (final s in ['cap', 'capi', 'capit', 'capital']) {
      await tester.enterText(find.byType(TextField), s);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(repo.calls.length, 1);
    expect(repo.calls.single.q, 'capital');
  });

  testWidgets('a hit hides its answer until asked', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'capital');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.textContaining('capital of Ghana'), findsOneWidget);
    expect(find.textContaining('WAEC'), findsOneWidget);
    // The answer is behind a tap: seeing it with the question teaches nothing.
    expect(find.textContaining('Answer:'), findsNothing);

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    expect(find.text('Answer: C'), findsOneWidget);
    expect(find.textContaining('Accra has been the capital'), findsOneWidget);
  });

  testWidgets('pages walk forward and back', (tester) async {
    final repo = await _pump(tester);
    await tester.enterText(find.byType(TextField), 'capital');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // 24 matches at ten a page is three pages.
    expect(find.text('Page 1 of 3'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(repo.calls.last.page, 2);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 3'), findsOneWidget);
  });

  testWidgets('an empty result says so, and says what to try', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'nothing at all');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing matched'), findsOneWidget);
    expect(find.textContaining('Try fewer words'), findsOneWidget);
  });
}
