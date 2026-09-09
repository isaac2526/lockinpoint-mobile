import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/vault/vault_db.dart';
import 'package:lockinpoint/core/vault/vault_repository.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/practice/practice_session_screen.dart';
import 'package:lockinpoint/features/vault/vault_screen.dart';

/// ===========================================================================
/// A DOWNLOADED PACK CAN BE SAT.
///
/// It could not. Every piece of offline practice was built and working —
/// `openSitting()` assembled the paper out of the local database,
/// `sittingFromVault()` reshaped it into what the practice screen speaks, and
/// that screen runs happily with no network. NOTHING CALLED THEM.
///
/// The vault listed a downloaded subject, its question count and a delete
/// button, and that was all. The one thing a student downloads a pack in
/// order to do was the one thing they could not do with it — and no test
/// noticed, because every part in isolation worked perfectly.
/// ===========================================================================
class _Vault extends Fake implements VaultRepository {
  _Vault({this.sitting});

  /// Null models a row whose questions are missing — a download interrupted
  /// part-way, which is a real state and must not open an empty screen.
  final OfflineSitting? sitting;

  final List<String> opened = [];

  /// The screen's pending-results banner asks for this on mount. Zero, so the
  /// banner stays out of the way of what these tests are about.
  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<OfflineSitting?> openSitting(
    String subjectId, {
    int count = 40,
    int? seed,
  }) async {
    opened.add(subjectId);
    return sitting;
  }
}

Pack _pack() => Pack(
  subjectId: 's1',
  subjectName: 'Physics',
  examId: 'e1',
  examSlug: 'waec',
  examShort: 'WAEC',
  count: 40,
  downloadedAt: DateTime.utc(2026, 1, 1),
);

Future<_Vault> _open(WidgetTester tester, {OfflineSitting? sitting}) async {
  final vault = _Vault(sitting: sitting);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultProvider.overrideWithValue(vault),
        vaultPacksProvider.overrideWith((ref) async => [_pack()]),
      ],
      child: MaterialApp(theme: LipTheme.light(), home: const VaultScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return vault;
}

void main() {
  testWidgets('the vault says a pack can be practised', (tester) async {
    await _open(tester);
    expect(find.text('Physics'), findsOneWidget);
    // A card that can be tapped has to say so. This one showed a question
    // count and a delete button and nothing else.
    expect(find.textContaining('Tap to practise'), findsOneWidget);
  });

  testWidgets('tapping a pack asks the vault for a sitting', (tester) async {
    final vault = await _open(
      tester,
      sitting: OfflineSitting(
        pack: _pack(),
        questions: const [],
        passages: const {},
      ),
    );
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(vault.opened, ['s1']);
  });

  testWidgets('an interrupted download says so instead of opening nothing', (
    tester,
  ) async {
    // openSitting returns null when the pack row exists but its questions do
    // not. Pushing the practice screen on that would be a blank paper.
    await _open(tester);
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeSessionScreen), findsNothing);
    expect(find.textContaining('incomplete'), findsOneWidget);
  });

  testWidgets('the Download/Update control is in the top corner', (
    tester,
  ) async {
    // There was no `actions:` on this AppBar at all: once the first-launch
    // download finished, nothing on the screen could ever pull again.
    await _open(tester);
    expect(find.byIcon(Icons.cloud_download_rounded), findsOneWidget);
  });
}
