import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
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
  const PracticeFlowScreen({super.key});

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
    });
    try {
      await work();
    } on ApiFailure catch (e) {
      setState(() => _error = e.message);
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
      Navigator.of(context).pop();
    } else {
      setState(() {
        _step -= 1;
        _error = null;
      });
    }
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
                  child: LipError(
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
        return Entrance(
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
        const LipLabel('How many questions'),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          children: [
            for (final n in const [10, 20, 40])
              LipChip(
                '$n',
                selected: _count == n,
                onTap: () => setState(() => _count = n),
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
            children: [
              for (final m in const [10, 20, 30, 45])
                LipChip(
                  '$m min',
                  selected: _minutes == m,
                  onTap: () => setState(() => _minutes = m),
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
