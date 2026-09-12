import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/json.dart';
import '../../design/components.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../practice/practice_repository.dart';

/// ===========================================================================
/// WHICH EXAM, AND WHICH SUBJECT
///
/// THE ARENA NEVER ASKED. gamePool() sent a count and nothing else, and
/// /api/games/pool has accepted `exam` and `subject` since the day it was
/// written — it says so in its own header. So a WAEC science candidate was
/// handed Yoruba, Literature and whatever else happened to be in the bank.
///
/// Being asked a question from a subject you do not offer is not a game. It is
/// a reason to close the app, and it is what the owner meant by "the games
/// must ask subject and examination — no Yoruba".
///
/// IT ASKS ONCE. The choice is remembered, so the second game starts on the
/// screen the first one ended on rather than making a student re-pick their
/// own subject every time they want sixty seconds of practice.
/// ===========================================================================
class ArenaChoice {
  const ArenaChoice({
    this.examSlug = '',
    this.examName = '',
    this.subjectId = '',
    this.subjectName = '',
  });

  final String examSlug;
  final String examName;
  final String subjectId;
  final String subjectName;

  bool get isSet => examSlug.isNotEmpty;

  /// "WAEC · Chemistry", or "WAEC · every subject".
  String get label => !isSet
      ? ''
      : '$examName · ${subjectName.isEmpty ? 'every subject' : subjectName}';
}

/// What the student picked last time. Held in preferences rather than in
/// memory so it survives the app being killed, which is the only version of
/// "remembered" that is worth anything on a cheap phone.
class ArenaChoiceStore extends AsyncNotifier<ArenaChoice> {
  static const _key = 'lip.arena-choice';

  @override
  Future<ArenaChoice> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key);
      if (raw == null || raw.length < 4) return const ArenaChoice();
      return ArenaChoice(
        examSlug: raw[0],
        examName: raw[1],
        subjectId: raw[2],
        subjectName: raw[3],
      );
    } catch (_) {
      return const ArenaChoice();
    }
  }

  Future<void> set(ArenaChoice c) async {
    state = AsyncData(c);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [
        c.examSlug,
        c.examName,
        c.subjectId,
        c.subjectName,
      ]);
    } catch (_) {
      // Remembering is a convenience; failing to remember is not a failure.
    }
  }
}

final arenaChoiceProvider =
    AsyncNotifierProvider<ArenaChoiceStore, ArenaChoice>(ArenaChoiceStore.new);

final _arenaExamsProvider = FutureProvider<List<ExamOption>>(
  (ref) => ref.watch(practiceRepositoryProvider).exams(),
);

final _arenaSubjectsProvider =
    FutureProvider.family<List<SubjectOption>, String>(
      (ref, slug) => ref.watch(practiceRepositoryProvider).subjects(slug),
    );

/// The two questions, asked once, before the first game.
class ArenaSetupSheet extends ConsumerStatefulWidget {
  const ArenaSetupSheet({super.key});

  @override
  ConsumerState<ArenaSetupSheet> createState() => _ArenaSetupSheetState();
}

class _ArenaSetupSheetState extends ConsumerState<ArenaSetupSheet> {
  String _slug = '';
  String _examName = '';

  @override
  Widget build(BuildContext context) {
    final c = context.lip;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _slug.isEmpty ? 'Which examination?' : 'Which subject?',
              style: LipType.title.copyWith(color: c.text1),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              _slug.isEmpty
                  ? 'So the arena never asks you a question from a subject '
                        'you do not offer.'
                  : 'Pick one, or take every subject in $_examName.',
              style: LipType.small.copyWith(color: c.text3),
            ),
            const SizedBox(height: Gap.lg),

            if (_slug.isEmpty)
              Consumer(
                builder: (context, ref, _) => ref
                    .watch(_arenaExamsProvider)
                    .when(
                      skipLoadingOnReload: true,
                      skipLoadingOnRefresh: true,
                      loading: () => const LipSkeleton(height: 44),
                      error: (e, _) => LipError(
                        message: humanError(e, doing: 'load the examinations'),
                        onRetry: () => ref.invalidate(_arenaExamsProvider),
                      ),
                      data: (exams) => Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.sm,
                        children: [
                          for (final x in exams)
                            LipChip(
                              x.shortName.isEmpty ? x.fullName : x.shortName,
                              onTap: () => setState(() {
                                _slug = x.slug;
                                _examName = x.shortName.isEmpty
                                    ? x.fullName
                                    : x.shortName;
                              }),
                            ),
                        ],
                      ),
                    ),
              )
            else
              Consumer(
                builder: (context, ref, _) => ref
                    .watch(_arenaSubjectsProvider(_slug))
                    .when(
                      skipLoadingOnReload: true,
                      skipLoadingOnRefresh: true,
                      loading: () => const LipSkeleton(height: 88),
                      error: (e, _) => LipError(
                        message: humanError(e, doing: 'load the subjects'),
                        onRetry: () =>
                            ref.invalidate(_arenaSubjectsProvider(_slug)),
                      ),
                      data: (subjects) => Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.sm,
                        children: [
                          // Everything in the exam is a legitimate answer for
                          // a candidate who wants a broad warm-up.
                          LipChip(
                            'Every subject',
                            onTap: () => _pick(context, '', ''),
                          ),
                          for (final s in subjects)
                            LipChip(
                              s.name,
                              onTap: () => _pick(context, s.id, s.name),
                            ),
                        ],
                      ),
                    ),
              ),

            if (_slug.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              TextButton(
                onPressed: () => setState(() {
                  _slug = '';
                  _examName = '';
                }),
                child: const Text('Back to the examinations'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    String subjectId,
    String subjectName,
  ) async {
    final choice = ArenaChoice(
      examSlug: _slug,
      examName: _examName,
      subjectId: subjectId,
      subjectName: subjectName,
    );
    await ref.read(arenaChoiceProvider.notifier).set(choice);
    if (context.mounted) Navigator.of(context).pop(choice);
  }
}

/// Asks only when there is nothing remembered. Returns null when the student
/// backs out, which must NOT start a game.
Future<ArenaChoice?> ensureArenaChoice(
  BuildContext context,
  WidgetRef ref,
) async {
  final known = await ref.read(arenaChoiceProvider.future);
  if (known.isSet) return known;
  if (!context.mounted) return null;
  return showModalBottomSheet<ArenaChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ArenaSetupSheet(),
  );
}
