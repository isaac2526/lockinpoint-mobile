import '../../app/shell.dart';

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

/// WHICH ROAD OUT OF JAMB. The website forks here and the app never did: a
/// student who chose JAMB was walked straight into one subject, with no way to
/// reach the four-subject paper the welcome screen promises them.
enum _Road { subject, mock, mini }

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

  /// Null until a JAMB student has chosen between one subject and the paper.
  /// Every other examination has one road, so it is set the moment they pick.
  _Road? _road;

  /// The three subjects beside Use of English. Never four: the compulsory one
  /// is not a choice, and a student who could deselect it would be sitting a
  /// paper JAMB does not set.
  final List<SubjectOption> _picked = [];

  /// Questions per subject in a mini mock. The full mock does not ask — the
  /// server sets 60 for the compulsory subject and 40 for each of the rest.
  int _per = 10;

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

  /// JAMB is the only examination with two roads, and it is not hardcoded by
  /// name: an exam forks when the server marks one of its subjects compulsory,
  /// which is exactly what makes a four-subject paper possible. The same
  /// property drives the website's own fork.
  bool get _forks => (_subjects ?? const []).any((s) => s.compulsory);

  SubjectOption? get _compulsory {
    for (final s in _subjects ?? const <SubjectOption>[]) {
      if (s.compulsory) return s;
    }
    return null;
  }

  Future<void> _pickExam(ExamOption exam) => _guard(() async {
    final list = await _repo.subjects(exam.slug);
    setState(() {
      _exam = exam;
      _subjects = list;
      _subject = null;
      _chooser = null;
      _picked.clear();
      // An exam with no compulsory subject has one road, so do not ask.
      _road = list.any((s) => s.compulsory) ? null : _Road.subject;
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

  /// What the student is about to sit, named on the button and on the paper.
  String get _jambLabel {
    final names = [
      if (_compulsory != null) _compulsory!.name,
      ..._picked.map((s) => s.name),
    ].join(' + ');
    return _road == _Road.mini
        ? 'JAMB Mini Mock · $names'
        : 'JAMB Full Mock · $names';
  }

  Future<void> _startJamb() => _guard(() async {
    final english = _compulsory;
    if (english == null || _picked.length != 3) return;
    final sitting = await _repo.startJamb(
      // English first, then the three in the order the student chose them.
      subjectIds: [english.id, ..._picked.map((s) => s.id)],
      label: _jambLabel,
      perSubject: _road == _Road.mini ? _per : null,
    );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PracticeSessionScreen(sitting: sitting),
      ),
    );
  });

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
    } else if (_step == 1 && _forks && _road != null) {
      // Inside the JAMB fork, Back returns to the fork rather than all the
      // way out to the exam list — the student chose JAMB on purpose.
      setState(() {
        _road = null;
        _picked.clear();
        _error = null;
      });
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
                  // At the top of a tab the arrow would point nowhere, so it
                  // becomes the way into the drawer instead.
                  if (widget.embedded && _step == 0)
                    IconButton(
                      // See dashboard_screen.dart: Scaffold.of() finds this
                      // screen's own drawer-less Scaffold, not the shell's.
                      onPressed: openAppMenu,
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Menu',
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
                          1 =>
                            _road == null || _road == _Road.subject
                                ? _exam?.shortName ?? 'Choose your subject'
                                : 'Your JAMB combination',
                          _ => _chooser?.subjectName ?? 'Set up your session',
                        }, style: LipType.heading.copyWith(color: c.text1)),
                        Text(
                          // The paper is two steps, not three: exam, then the
                          // combination. Saying "of 3" would leave a student
                          // waiting for a step that never comes.
                          _road == _Road.mock || _road == _Road.mini
                              ? 'Step 2 of 2'
                              : 'Step ${_step + 1} of 3',
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
      1 when _forks && _road == null => _forkStep(),
      1 when _road == _Road.mock || _road == _Road.mini => _combinationStep(),
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

  /// ========================================================================
  /// THE FORK · one subject, or the paper.
  ///
  /// The app's welcome screen promises "a complete JAMB mock of 180 questions
  /// scored over 400" and prints 180 as a headline figure. Until this screen
  /// existed there was no way to reach one from inside the app: choosing JAMB
  /// walked straight into a single-subject chooser, and /api/attempts had
  /// accepted `jamb_mock` and `jamb_mini` the whole time. The website has
  /// forked here since it was written; this is the same fork, same order.
  /// ========================================================================
  Widget _forkStep() {
    final c = context.lip;
    final english = _compulsory?.name ?? 'Use of English';
    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(
          'Two ways to sit ${_exam?.shortName ?? 'this exam'}. Both draw from '
          'the same bank of real past questions.',
          style: LipType.small.copyWith(color: c.text2),
        ),
        const SizedBox(height: Gap.lg),
        Entrance(
          index: 0,
          child: LipChoiceCard(
            icon: Icons.auto_stories_rounded,
            title: 'Practise one subject',
            subtitle: 'Pick a subject, then a year, a topic or a random mix',
            selected: false,
            onTap: _busy ? null : () => setState(() => _road = _Road.subject),
          ),
        ),
        const SizedBox(height: Gap.md),
        Entrance(
          index: 1,
          child: LipChoiceCard(
            icon: Icons.workspace_premium_rounded,
            title: 'Full UTME mock - 4 subjects',
            // The counts are the server's. Naming them here is a description
            // of what it does, not a second opinion about it.
            subtitle:
                '$english plus three you choose · 180 questions on one two '
                'hour clock, scored over 400',
            selected: false,
            onTap: _busy ? null : () => setState(() => _road = _Road.mock),
          ),
        ),
        const SizedBox(height: Gap.md),
        Entrance(
          index: 2,
          child: LipChoiceCard(
            icon: Icons.speed_rounded,
            title: 'Mini mock',
            subtitle:
                'The same four subjects, fewer questions each · for a warm up '
                'rather than a full sitting',
            selected: false,
            onTap: _busy ? null : () => setState(() => _road = _Road.mini),
          ),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  /// ========================================================================
  /// THE COMBINATION · English is in, and exactly three more.
  ///
  /// A FOURTH PICK IS REFUSED RATHER THAN SILENTLY SWAPPED. Quietly dropping
  /// the first subject to make room for a fourth is the kind of helpfulness
  /// that loses a student the subject they meant to sit and tells them
  /// nothing. Tapping a chosen subject again unpicks it, which is the only
  /// unsurprising way to change your mind.
  /// ========================================================================
  Widget _combinationStep() {
    final c = context.lip;
    final english = _compulsory;
    final rest = (_subjects ?? const <SubjectOption>[])
        .where((s) => !s.compulsory)
        .toList();
    final ready = _picked.length == 3;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        if (english != null) ...[
          LipChip(
            '${english.name} - always in',
            selected: true,
            tone: ChipTone.gold,
          ),
          const SizedBox(height: Gap.md),
        ],
        LipLabel(
          ready ? '3 of 3 chosen' : 'Pick 3 more · ${_picked.length} of 3',
        ),
        const SizedBox(height: Gap.sm),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final s in rest)
              LipChip(
                s.name,
                selected: _picked.any((p) => p.id == s.id),
                onTap: _busy
                    ? null
                    : () => setState(() {
                        final at = _picked.indexWhere((p) => p.id == s.id);
                        if (at >= 0) {
                          _picked.removeAt(at);
                        } else if (_picked.length < 3) {
                          _picked.add(s);
                        }
                      }),
              ),
          ],
        ),
        if (_road == _Road.mini) ...[
          const SizedBox(height: Gap.lg),
          const LipLabel('How many questions per subject'),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            children: [
              for (final n in const [10, 20, 40, 60])
                LipChip(
                  '$n',
                  selected: _per == n,
                  onTap: () => setState(() => _per = n),
                ),
            ],
          ),
        ],
        const SizedBox(height: Gap.lg),
        GlassSurface(
          tier: GlassTier.deep,
          padding: const EdgeInsets.all(Gap.md),
          child: Text(
            ready
                ? _jambLabel
                : 'Choose three subjects beside '
                      '${english?.name ?? 'the compulsory one'}.',
            style: LipType.smallStrong.copyWith(color: c.text2),
          ),
        ),
        const SizedBox(height: Gap.md),
        LipButton(
          // Named, so the student knows exactly what they are about to sit
          // before the clock starts rather than after it.
          label: ready
              ? 'Start: ${english?.name ?? 'English'} + 3 subjects'
              : 'Pick three subjects',
          icon: Icons.timer_rounded,
          gold: true,
          busy: _busy,
          onPressed: ready ? _startJamb : null,
        ),
        const SizedBox(height: Gap.xl),
      ],
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
