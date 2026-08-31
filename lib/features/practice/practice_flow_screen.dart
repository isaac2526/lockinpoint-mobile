import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../core/vault/vault_repository.dart';
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
      _step = 1;
    });
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
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PracticeSessionScreen(sitting: sitting),
      ),
    );
  });

  void _back() {
    if (_step == 0) {
      /* Embedded, step zero IS the top of a tab — there is nothing behind it
         to pop, and popping would tear the shell out from under the student. */
      if (widget.embedded) return;
      Navigator.of(context).pop();
    } else {
      setState(() {
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
                        onPressed: () => Scaffold.of(context).openDrawer(),
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
                          _ => _chooser?.subjectName ?? 'Set up your session',
                        }, style: LipType.heading.copyWith(color: c.text1)),
                        Text(
                          'Step ${_step + 1} of 3',
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
