import '../../core/json.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';

/// ===========================================================================
/// THE QUESTION HARVEST
///
/// /harvest on the website, which the app never had. It is the one screen
/// where the student gives rather than takes: a candidate walks out of a Post
/// UTME hall with questions still fresh, and types them in while they are.
/// That is where the Post UTME bank actually comes from — no publisher sells
/// it, and no scraper finds it.
///
/// The school request rides on the same screen, because it is the same
/// instinct three minutes later: "my school is not on your list". Two forms,
/// one door, both already answered by routes that had never been called from
/// a phone: /api/harvest and /api/schools/request.
/// ===========================================================================
class HarvestScreen extends ConsumerStatefulWidget {
  const HarvestScreen({super.key});

  @override
  ConsumerState<HarvestScreen> createState() => _HarvestScreenState();
}

class _HarvestScreenState extends ConsumerState<HarvestScreen> {
  final _school = TextEditingController();
  final _question = TextEditingController();
  final _options = TextEditingController();
  final _answer = TextEditingController();
  final _requestSchool = TextEditingController();

  bool _sending = false;
  bool _requesting = false;
  String _error = '';
  String _thanks = '';
  String _requestSaid = '';

  /// How many this student has contributed in this sitting. A counter that
  /// climbs is the whole reward for a screen with nothing to take.
  int _given = 0;

  @override
  void dispose() {
    _school.dispose();
    _question.dispose();
    _options.dispose();
    _answer.dispose();
    _requestSchool.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final school = _school.text.trim();
    final question = _question.text.trim();
    if (school.isEmpty || question.isEmpty) {
      setState(
        () => _error = 'The school and the question are the two must-haves.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = '';
      _thanks = '';
    });
    try {
      final res = await ref
          .read(apiProvider)
          .post(
            '/api/harvest',
            body: {
              'school_name': school,
              'question': question,
              'options_text': _options.text.trim(),
              'answer': _answer.text.trim(),
            },
          );
      if (!mounted) return;
      if (res['ok'] == false) {
        setState(() {
          _sending = false;
          _error = asText(res['message'], 'That did not send.');
        });
        return;
      }
      setState(() {
        _sending = false;
        _given += 1;
        _thanks =
            asTextOrNull(res['message']) ??
            'Received — thank you for feeding the harvest!';
        /* THE SCHOOL STAYS, EVERYTHING ELSE CLEARS. A student remembering
           six questions from one exam should type the school once. */
        _question.clear();
        _options.clear();
        _answer.clear();
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  Future<void> _request() async {
    final name = _requestSchool.text.trim();
    if (name.length < 3) {
      setState(() => _requestSaid = "Type your school's full name.");
      return;
    }
    setState(() {
      _requesting = true;
      _requestSaid = '';
    });
    try {
      final res = await ref
          .read(apiProvider)
          .post('/api/schools/request', body: {'school': name});
      if (!mounted) return;
      final count = asInt(res['count']);
      setState(() {
        _requesting = false;
        if (res['ok'] == false) {
          _requestSaid = asText(res['message'], 'That did not send.');
        } else {
          _requestSaid = count > 1
              ? 'Noted — $count students have asked for this school.'
              : 'Noted. You are the first to ask for this one.';
          _requestSchool.clear();
        }
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _requestSaid = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Scaffold(
      appBar: AppBar(title: const Text('Question harvest')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.huge),
          children: [
            Entrance(
              child: GlassSurface(
                tier: GlassTier.raised,
                seam: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Just wrote your Post UTME?',
                      style: LipType.subheading.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'While it is still fresh, drop the questions you '
                      'remember. Real students remembering real questions is '
                      'how the Post UTME bank grows — and how the students '
                      'after you get exactly what you wished you had.',
                      style: LipType.small.copyWith(color: c.text2),
                    ),
                    if (_given > 0) ...[
                      const SizedBox(height: Gap.md),
                      LipChip(
                        _given == 1
                            ? 'One question given today'
                            : '$_given questions given today',
                        tone: ChipTone.gold,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),

            Entrance(
              index: 1,
              child: GlassSurface(
                tier: GlassTier.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _school,
                      enabled: !_sending,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: "Which school's exam?",
                        hintText: 'e.g. UNILAG',
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    TextField(
                      controller: _question,
                      enabled: !_sending,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'The question, as you remember it',
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    TextField(
                      controller: _options,
                      enabled: !_sending,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'The options, as many as you remember',
                        helperText: 'One per line is easiest.',
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    TextField(
                      controller: _answer,
                      enabled: !_sending,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'The answer, if you are sure',
                        hintText: 'A, B, C or D',
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      LipFormError(message: _error),
                    ],
                    if (_thanks.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      Text(
                        _thanks,
                        style: LipType.small.copyWith(color: c.success),
                      ),
                    ],
                    const SizedBox(height: Gap.md),
                    LipButton(
                      label: 'Send it in',
                      icon: Icons.volunteer_activism_rounded,
                      expand: true,
                      busy: _sending,
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),

            // ---- my school is not on your list --------------------------
            const LipLabel('Your school missing?'),
            const SizedBox(height: Gap.sm),
            Entrance(
              index: 2,
              child: GlassSurface(
                tier: GlassTier.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask for it. The more students ask for the same school, '
                      'the sooner its papers are added.',
                      style: LipType.small.copyWith(color: c.text2),
                    ),
                    const SizedBox(height: Gap.md),
                    TextField(
                      controller: _requestSchool,
                      enabled: !_requesting,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: "Your school's full name",
                      ),
                    ),
                    if (_requestSaid.isNotEmpty) ...[
                      const SizedBox(height: Gap.sm),
                      Text(
                        _requestSaid,
                        style: LipType.small.copyWith(color: c.text2),
                      ),
                    ],
                    const SizedBox(height: Gap.md),
                    LipButton(
                      label: 'Ask for this school',
                      icon: Icons.school_rounded,
                      expand: true,
                      busy: _requesting,
                      onPressed: _request,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
