import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../core/vault/vault_repository.dart';
import '../home/dashboard_screen.dart';
import '../vault/vault_screen.dart';
import 'practice_repository.dart';
import 'practice_session_screen.dart';

/// ===========================================================================
/// THE PRACTICE CHOOSER · exam → subject → year, topic or random
///
/// The same three questions the website's unified practice flow asks, in the
/// same order, backed by the same routes. No exam is ever assumed: a WAEC
/// student is not funnelled through JAMB to reach their own past questions.
/// ===========================================================================
class PracticeFlowScreen extends ConsumerStatefulWidget {
  const PracticeFlowScreen({super.key, this.embedded = false});

  /// True when this screen is a TAB inside the shell rather than a pushed
  /// route. An embedded screen drops its own app bar and back button — two
  /// headers stacked on one screen is the fastest way to make an app feel
  /// like a collection of pages instead of one product.
  final bool embedded;

  @override
  ConsumerState<PracticeFlowScreen> createState() => _PracticeFlowState();
}

enum _Source { year, topic, random, tutorial }

class _PracticeFlowState extends ConsumerState<PracticeFlowScreen> {
  int _step = 0;

  List<ExamOption>? _exams;
  ExamOption? _exam;
  List<SubjectOption>? _subjects;
  SubjectOption? _subject;
  ChooserData? _chooser;

  _Source _source = _Source.random;
  int? _year;
  TopicCount? _topic;
  int _count = 20;

  /// Which room: the untimed one that marks as you go, or the timed one that
  /// behaves like the real hall.
  bool _timed = false;
  int _minutes = 30;

  bool _busy = false;
  String? _error;

  /// The three subjects chosen BESIDE Use of English for a full UTME mock.
  /// English itself is never in this set: it is compulsory, so it is locked
  /// into the paper rather than offered as a choice a student could un-make.
  final Set<String> _combo = {};

  /// Mini mock: fewer questions, projected onto the 400 scale. The full mock
  /// is the two-hour, four-subject sitting the real hall runs.
  bool _utmeMini = false;

  /// The failure was the NETWORK, not the server — which changes the right
  /// next step from "retry" to "practise what is already on the phone".
  bool _errorOffline = false;

  PracticeRepository get _repo => ref.read(practiceRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _guard(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
      _errorOffline = false;
    });
    try {
      await work();
    } on ApiFailure catch (e) {
      setState(() {
        _error = e.message;
        _errorOffline = e.offline;
      });
    } catch (_) {
      setState(() => _error = 'That did not load. Pull back and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadExams() => _guard(() async {
    final list = await _repo.exams();
    setState(() => _exams = list);
  });

  Future<void> _pickExam(ExamOption exam) => _guard(() async {
    final list = await _repo.subjects(exam.slug);
    setState(() {
      _exam = exam;
      _subjects = list;
      _subject = null;
      _chooser = null;
      /* JAMB IS NOT A SUBJECT LIST. A UTME candidate sits FOUR subjects at
         once, so dropping them straight into single-subject practice - which
         is what this screen did - was the wrong flow for the exam this whole
         product is named for. JAMB forks first: one subject, or the full
         combination. Every other exam goes to its subjects as before. */
      if (exam.slug == 'jamb') {
        _combo.clear();
        _prefillCombination(list);
        _step = 5;
      } else {
        _step = 1;
      }
    });
  });

  /// Open the picker on the student's OWN four, saved from their last mock.
  /// A prefill, never a lock - every chip stays changeable.
  void _prefillCombination(List<SubjectOption> subjects) {
    final saved =
        (ref.read(dashboardProvider).value?['student']
                as Map<String, dynamic>?)?['subjectCombination']
            as String?;
    if (saved == null || saved.isEmpty) return;
    final wanted = saved.toLowerCase();
    for (final s in subjects) {
      if (s.compulsory) continue;
      if (wanted.contains(s.name.toLowerCase()) && _combo.length < 3) {
        _combo.add(s.id);
      }
    }
  }

  SubjectOption? get _english {
    final list = _subjects ?? const [];
    for (final s in list) {
      if (s.compulsory) return s;
    }
    // The flag is data an admin can forget; the name is the safety net.
    for (final s in list) {
      if (s.name.toLowerCase().contains('english')) return s;
    }
    return null;
  }

  Future<void> _startUtme() => _guard(() async {
    final english = _english;
    if (english == null) return;
    final byId = {
      for (final s in _subjects ?? const <SubjectOption>[]) s.id: s,
    };
    final combination = [
      (id: english.id, name: english.name),
      for (final id in _combo)
        if (byId[id] != null) (id: id, name: byId[id]!.name),
    ];
    final sitting = await _repo.startUtme(
      combination: combination,
      mini: _utmeMini,
    );
    // Remembered for next time, never blocking this time.
    unawaited(_repo.saveCombination(combination.map((s) => s.name).toList()));
    if (!mounted) return;
    /* PUSH, NEVER REPLACE. When this flow is the embedded Practice TAB, the
       current route is the shell itself - replacing it swapped the whole
       shell out for the sitting, so "Back to the dashboard" had no dashboard
       behind it and Leave popped into a dead black screen the student had to
       force-close. */
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(sitting: sitting),
      ),
    );
    // The Continue card and counts go stale the moment a sitting ends.
    ref.invalidate(dashboardProvider);
  });

  Future<void> _pickSubject(SubjectOption subject) => _guard(() async {
    final data = await _repo.chooser(subject.id);
    setState(() {
      _subject = subject;
      _chooser = data;
      _source = _Source.random;
      _year = null;
      _topic = null;
      _step = 2;
    });
  });

  String get _label {
    final exam = _exam?.shortName ?? '';
    final subject = _subject?.name ?? '';
    final tail = switch (_source) {
      _Source.year => '$_year',
      _Source.topic => _topic?.name ?? '',
      _Source.tutorial => 'Tutorial questions',
      _Source.random => 'Random mix',
    };
    return [
      exam,
      subject,
      tail,
      if (_timed) 'CBT',
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  Future<void> _start() => _guard(() async {
    final sitting = await _repo.start(
      examSlug: _exam!.slug,
      subjectId: _subject!.id,
      label: _label,
      year: _source == _Source.year ? _year : null,
      topicId: _source == _Source.topic ? _topic!.id : null,
      kind: _source == _Source.tutorial ? 'tutorial' : 'past',
      count: _count,
      mode: _timed ? 'cbt' : 'practice',
      minutes: _minutes,
    );
    if (!mounted) return;
    /* PUSH, NEVER REPLACE. When this flow is the embedded Practice TAB, the
       current route is the shell itself - replacing it swapped the whole
       shell out for the sitting, so "Back to the dashboard" had no dashboard
       behind it and Leave popped into a dead black screen the student had to
       force-close. */
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(sitting: sitting),
      ),
    );
    // The Continue card and counts go stale the moment a sitting ends.
    ref.invalidate(dashboardProvider);
  });

  void _back() {
    if (_step == 0) {
      /* Embedded, step zero IS the top of a tab — there is nothing behind it
         to pop, and popping would tear the shell out from under the student. */
      if (widget.embedded) return;
      Navigator.of(context).pop();
    } else {
      setState(() {
        /* The JAMB branch has its own spine: combination -> fork -> exams,
           and the single-subject list also returns to the fork rather than
           skipping it. Decrementing blindly would strand a student on step
           4 - a screen that does not exist. */
        if (_step == 6) {
          _step = 5;
          return;
        }
        if (_step == 5) {
          _step = 0;
          return;
        }
        if (_step == 1 && _exam?.slug == 'jamb') {
          _step = 5;
          return;
        }
        _step -= 1;
        _error = null;
      });
    }
  }

  /// Ask for a number the chips do not offer.
  ///
  /// Bounded on both sides and the bounds are explained: below 1 there is no
  /// paper, and above 200 a single sitting stops being practice and starts
  /// being a way to time out a phone.
  Future<void> _askCount() => _askNumber(
    title: 'How many questions?',
    hint: 'Between 1 and 200',
    initial: _count,
    min: 1,
    max: 200,
    onPicked: (n) => setState(() => _count = n),
  );

  Future<void> _askMinutes() => _askNumber(
    title: 'How many minutes?',
    hint: 'Between 1 and 240',
    initial: _minutes,
    min: 1,
    max: 240,
    onPicked: (n) => setState(() => _minutes = n),
  );

  Future<void> _askNumber({
    required String title,
    required String hint,
    required int initial,
    required int min,
    required int max,
    required void Function(int) onPicked,
  }) async {
    final controller = TextEditingController(text: '$initial');
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(ctx).pop(int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text.trim())),
            child: const Text('Use it'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (picked == null) return;
    // Clamped rather than refused: a student who typed 500 meant "as many as
    // you have", and an error dialog would just make them type again.
    onPicked(picked.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
              child: Row(
                children: [
                  // At the top of a tab the arrow would point nowhere, so it
                  // becomes the way into the drawer instead.
                  if (widget.embedded && _step == 0)
                    Builder(
                      builder: (context) => IconButton(
                        /* The drawer lives on the SHELL's scaffold; this screen's own
                     inner Scaffold has none, so Scaffold.of() here found a
                     drawerless scaffold and this tap did nothing at all in
                     release builds. */
                        onPressed: () => lipShellKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu_rounded),
                        tooltip: 'Menu',
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _busy ? null : _back,
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(switch (_step) {
                          0 => 'Choose your exam',
                          1 => _exam?.shortName ?? 'Choose your subject',
                          5 => 'JAMB',
                          6 => 'Your combination',
                          _ => _chooser?.subjectName ?? 'Set up your session',
                        }, style: LipType.heading.copyWith(color: c.text1)),
                        Text(
                          /* The counter only counts the classic spine. The
                             JAMB fork is its own short road, and "Step 6 of
                             3" - which this used to print there - is the
                             kind of nonsense that makes an app feel broken
                             even when it works. */
                          switch (_step) {
                            5 => 'One subject, or the full mock',
                            6 => 'Use of English + 3 of yours',
                            _ => 'Step ${_step + 1} of 3',
                          },
                          style: LipType.label.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.sm),
            if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /* NO SIGNAL IS NOT A DEAD END. If the phone is holding
                         downloaded packs, the right answer to "could not
                         load" is the vault, offered right here — not a retry
                         button pointed at a network that is not there. */
                      if (_errorOffline)
                        Consumer(
                          builder: (context, ref, _) {
                            final has =
                                ref.watch(hasVaultProvider).value ?? false;
                            if (!has) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: Gap.lg),
                              child: LipButton(
                                gold: true,
                                icon: Icons.offline_bolt_rounded,
                                label: 'Practise from your vault',
                                expand: false,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const VaultScreen(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      LipError(
                        message: _error!,
                        onRetry: () {
                          switch (_step) {
                            case 0:
                              _loadExams();
                            case 1:
                              _pickExam(_exam!);
                            default:
                              setState(() => _error = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_busy && (_step == 0 ? _exams == null : true)) {
      return ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: const [
          LipSkeleton(height: 84),
          SizedBox(height: Gap.md),
          LipSkeleton(height: 84),
          SizedBox(height: Gap.md),
          LipSkeleton(height: 84),
        ],
      );
    }
    return switch (_step) {
      0 => _examStep(),
      1 => _subjectStep(),
      5 => _jambForkStep(),
      6 => _combinationStep(),
      _ => _chooserStep(),
    };
  }

  Widget _examStep() {
    final exams = _exams ?? const [];
    if (exams.isEmpty) {
      return const Center(
        child: LipEmpty(
          icon: Icons.menu_book_rounded,
          title: 'No exams yet',
          message: 'Pull back and try again in a moment.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.md),
      itemCount: exams.length,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (context, i) {
        final exam = exams[i];
        return Entrance.inList(
          index: i,
          child: LipChoiceCard(
            icon: Icons.workspace_premium_rounded,
            title: exam.shortName,
            subtitle: exam.fullName,
            selected: _exam?.id == exam.id,
            onTap: _busy ? null : () => _pickExam(exam),
          ),
        );
      },
    );
  }

  Widget _subjectStep() {
    final subjects = _subjects ?? const [];
    if (subjects.isEmpty) {
      return Center(
        child: LipEmpty(
          icon: Icons.auto_stories_rounded,
          title: 'No subjects here yet',
          message:
              'The ${_exam?.shortName ?? ''} bank is still loading up. '
              'Try another exam for now.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final s in subjects)
              LipChip(
                s.name,
                selected: _subject?.id == s.id,
                tone: s.compulsory ? ChipTone.gold : ChipTone.neutral,
                onTap: _busy ? null : () => _pickSubject(s),
              ),
          ],
        ),
      ],
    );
  }

  Widget _jambForkStep() {
    final c = context.lip;
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(
          'How do you want to face JAMB today?',
          style: LipType.heading.copyWith(color: c.text1),
        ),
        const SizedBox(height: Gap.md),
        LipChoiceCard(
          icon: Icons.menu_book_rounded,
          title: 'Practise one subject',
          subtitle: 'Drill a single subject - by year, by topic, or mixed',
          selected: false,
          onTap: _busy ? null : () => setState(() => _step = 1),
        ),
        const SizedBox(height: Gap.md),
        LipChoiceCard(
          icon: Icons.workspace_premium_rounded,
          title: 'Full UTME mock - 4 subjects',
          subtitle:
              'Use of English plus your three, sat together and scored '
              'out of 400, exactly like the hall',
          selected: false,
          onTap: _busy ? null : () => setState(() => _step = 6),
        ),
      ],
    );
  }

  Widget _combinationStep() {
    final c = context.lip;
    final english = _english;
    final others = (_subjects ?? const <SubjectOption>[])
        .where((s) => s.id != english?.id)
        .toList();

    if (english == null) {
      return const Center(
        child: LipEmpty(
          icon: Icons.menu_book_rounded,
          title: 'Use of English is missing',
          message:
              'The JAMB bank has no English subject yet, and a UTME sitting '
              'cannot exist without it. Try again shortly.',
        ),
      );
    }

    final ready = _combo.length == 3;
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(
          'Your combination',
          style: LipType.heading.copyWith(color: c.text1),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Use of English sits in every UTME paper. Pick the three subjects '
          'that make up YOUR combination - it is saved for next time.',
          style: LipType.small.copyWith(color: c.text3, height: 1.5),
        ),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            LipChip('${english.name} - always in', tone: ChipTone.gold),
            for (final s in others)
              LipChip(
                s.name,
                selected: _combo.contains(s.id),
                onTap: _busy
                    ? null
                    : () => setState(() {
                        if (_combo.contains(s.id)) {
                          _combo.remove(s.id);
                        } else if (_combo.length < 3) {
                          _combo.add(s.id);
                        } else {
                          /* Full. Say so - a chip that silently refuses reads
                             as a broken chip, which is the exact bug class
                             this build is curing. */
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Three chosen already. Unpick one to swap '
                                  'this one in.',
                                ),
                              ),
                            );
                        }
                      }),
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        const LipLabel('Which sitting'),
        const SizedBox(height: Gap.sm),
        LipChoiceCard(
          icon: Icons.timer_rounded,
          title: 'Full mock',
          subtitle: 'The real thing: four subjects, two hours, one score',
          selected: !_utmeMini,
          onTap: () => setState(() => _utmeMini = false),
        ),
        const SizedBox(height: Gap.md),
        LipChoiceCard(
          icon: Icons.bolt_rounded,
          title: 'Mini mock',
          subtitle: 'Shorter, still projected onto the 400 scale',
          selected: _utmeMini,
          onTap: () => setState(() => _utmeMini = true),
        ),
        const SizedBox(height: Gap.xl),
        LipButton(
          gold: true,
          icon: Icons.play_arrow_rounded,
          label: ready
              ? 'Start: ${english.name} + 3'
              : 'Pick ${3 - _combo.length} more subject${_combo.length == 2 ? '' : 's'}',
          busy: _busy,
          onPressed: ready && !_busy ? _startUtme : null,
        ),
      ],
    );
  }

  Widget _chooserStep() {
    final data = _chooser;
    if (data == null) return const SizedBox.shrink();
    final c = context.lip;

    final sources =
        <({_Source s, IconData icon, String title, String sub, bool on})>[
          (
            s: _Source.random,
            icon: Icons.shuffle_rounded,
            title: 'Random mix',
            sub: 'A spread across every year',
            on: data.past > 0,
          ),
          (
            s: _Source.year,
            icon: Icons.calendar_month_rounded,
            title: 'By year',
            sub: 'One real past paper year',
            on: data.years.isNotEmpty,
          ),
          (
            s: _Source.topic,
            icon: Icons.category_rounded,
            title: 'By topic',
            sub: 'Drill one topic until it yields',
            on: data.topics.isNotEmpty,
          ),
          if (data.tutorial > 0)
            (
              s: _Source.tutorial,
              icon: Icons.school_rounded,
              title: 'Tutorial questions',
              sub: 'Teaching material, no exam year',
              on: true,
            ),
        ];

    final ready = switch (_source) {
      _Source.year => _year != null,
      _Source.topic => _topic != null,
      _ => true,
    };

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        for (final (i, src) in sources.indexed) ...[
          Entrance(
            index: i,
            child: LipChoiceCard(
              icon: src.icon,
              title: src.title,
              subtitle: src.sub,
              selected: _source == src.s,
              enabled: src.on,
              onTap: () => setState(() {
                _source = src.s;
                if (src.s != _Source.year) _year = null;
                if (src.s != _Source.topic) _topic = null;
              }),
            ),
          ),
          const SizedBox(height: Gap.md),
        ],
        if (_source == _Source.year) ...[
          const LipLabel('Pick the year'),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final y in data.years)
                LipChip(
                  '${y.year}',
                  count: y.n,
                  selected: _year == y.year,
                  onTap: () => setState(() => _year = y.year),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
        ],
        if (_source == _Source.topic) ...[
          const LipLabel('Pick the topic'),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final t in data.topics)
                LipChip(
                  t.name,
                  count: _source == _Source.tutorial ? t.nTutorial : t.n,
                  selected: _topic?.id == t.id,
                  onTap: () => setState(() => _topic = t),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
        ],
        /* THE DOWNLOAD BUTTON, FINALLY MOUNTED. It was built, tested at the
           repository level, promised by the vault's empty state ("open a
           subject in Practice and download it") — and placed on no screen at
           all, so no student could ever put a pack on their phone. This is
           that screen. */
        Row(
          children: [
            Expanded(
              child: Text(
                'Keep ${_subject?.name ?? 'this subject'} on your phone',
                style: LipType.small.copyWith(color: context.lip.text2),
              ),
            ),
            if (_subject != null)
              DownloadPackButton(
                subjectId: _subject!.id,
                subjectName: _subject!.name,
              ),
          ],
        ),
        const SizedBox(height: Gap.lg),

        const LipLabel('How many questions'),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final n in const [10, 20, 40, 60, 100])
              LipChip(
                '$n',
                selected: _count == n,
                onTap: () => setState(() => _count = n),
              ),
            /* A CHIP IS A SHORTCUT, NOT A LIMIT. Three fixed sizes meant a
               student revising one weak topic could not sit five questions,
               and one grinding before an exam could not sit 150. The chips
               stay because most people want one of them; the field is for
               everyone else. */
            LipChip(
              const [10, 20, 40, 60, 100].contains(_count)
                  ? 'Other'
                  : '$_count',
              selected: !const [10, 20, 40, 60, 100].contains(_count),
              onTap: _askCount,
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),

        // ---- the room: untimed practice, or a timed CBT ------------------
        const LipLabel('How do you want to sit it'),
        const SizedBox(height: Gap.sm),
        LipChoiceCard(
          icon: Icons.self_improvement_rounded,
          title: 'Practice',
          subtitle: 'No clock. See the answer and the why after each question',
          selected: !_timed,
          onTap: () => setState(() => _timed = false),
        ),
        const SizedBox(height: Gap.md),
        LipChoiceCard(
          icon: Icons.timer_rounded,
          title: 'CBT',
          subtitle:
              'A clock, no answers until you submit, exactly like the hall',
          selected: _timed,
          onTap: () => setState(() => _timed = true),
        ),
        if (_timed) ...[
          const SizedBox(height: Gap.md),
          const LipLabel('How long'),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final m in const [10, 20, 30, 45, 60, 120])
                LipChip(
                  '$m min',
                  selected: _minutes == m,
                  onTap: () => setState(() => _minutes = m),
                ),
              LipChip(
                const [10, 20, 30, 45, 60, 120].contains(_minutes)
                    ? 'Other'
                    : '$_minutes min',
                selected: !const [10, 20, 30, 45, 60, 120].contains(_minutes),
                onTap: _askMinutes,
              ),
            ],
          ),
        ],
        const SizedBox(height: Gap.lg),
        GlassSurface(
          tier: GlassTier.deep,
          padding: const EdgeInsets.all(Gap.md),
          child: Text(
            _label,
            style: LipType.smallStrong.copyWith(color: c.text2),
          ),
        ),
        const SizedBox(height: Gap.md),
        LipButton(
          label: _timed ? 'Start the clock' : 'Start practising',
          icon: _timed ? Icons.timer_rounded : Icons.play_arrow_rounded,
          // Gold marks the serious action, as it does on the website.
          gold: _timed,
          busy: _busy,
          onPressed: ready ? _start : null,
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }
}
