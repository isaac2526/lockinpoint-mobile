import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'practice_repository.dart';
import '../../design/rich_text.dart';

/// ===========================================================================
/// THE REVIEW · where the learning actually happens
///
/// A score tells a student nothing they can act on. This screen shows every
/// question the server marked: what they chose, what was right, and the
/// explanation. It opens on the ones they missed, because that is what a
/// student came back for, and the whole paper is one tap away.
///
/// Every letter here comes from the server's marking, never from the phone's:
/// the app does not decide what was correct.
/// ===========================================================================
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.result, required this.label});

  final SubmitResult result;
  final String label;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late bool _missedOnly = widget.result.missed.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final all = widget.result.corrections;
    final shown = _missedOnly ? widget.result.missed : all;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review', style: LipType.subheading.copyWith(color: c.text1)),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LipType.caption.copyWith(color: c.text3),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
              child: Row(
                children: [
                  LipChip(
                    'Missed ${widget.result.missed.length}',
                    tone: ChipTone.danger,
                    selected: _missedOnly,
                    onTap: widget.result.missed.isEmpty
                        ? null
                        : () => setState(() => _missedOnly = true),
                  ),
                  const SizedBox(width: Gap.sm),
                  LipChip(
                    'All ${all.length}',
                    selected: !_missedOnly,
                    onTap: () => setState(() => _missedOnly = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const LipEmpty(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Nothing missed',
                      message: 'A clean paper. Take the next one.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(Gap.md),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Gap.md),
                      itemBuilder: (context, i) => _CorrectionCard(
                        correction: shown[i],
                        number: all.indexOf(shown[i]) + 1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction, required this.number});

  final Correction correction;
  final int number;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final k = correction;

    return GlassSurface(
      tier: GlassTier.raised,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question $number',
                style: LipType.label.copyWith(color: c.text3),
              ),
              const Spacer(),
              LipChip(
                k.isRight
                    ? 'Correct'
                    : k.skipped
                    ? 'Left blank'
                    : 'Wrong',
                tone: k.isRight
                    ? ChipTone.success
                    : k.skipped
                    ? ChipTone.warning
                    : ChipTone.danger,
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          LipHtml(k.question, baseStyle: LipType.body.copyWith(color: c.text1)),
          if (k.mediaUrl('question') != null) ...[
            const SizedBox(height: Gap.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: CachedNetworkImage(
                imageUrl: k.mediaUrl('question')!,
                placeholder: (_, _) => const LipSkeleton(height: 120),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: Gap.md),
          for (final (i, opt) in k.options.indexed) ...[
            _ReviewOption(
              letter: k.letterAt(i),
              html: opt,
              right: k.letterAt(i) == k.right,
              chosen: k.letterAt(i) == k.chosen,
            ),
            const SizedBox(height: 6),
          ],
          if (k.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: c.glassDeep,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LipLabel('Why'),
                  const SizedBox(height: Gap.sm),
                  LipHtml(
                    k.explanation,
                    baseStyle: LipType.small.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewOption extends StatelessWidget {
  const _ReviewOption({
    required this.letter,
    required this.html,
    required this.right,
    required this.chosen,
  });

  final String letter;
  final String html;
  final bool right;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final wrongPick = chosen && !right;
    final (bg, fg) = right
        ? (c.successSoft, c.success)
        : wrongPick
        ? (c.dangerSoft, c.danger)
        : (Colors.transparent, c.text2);

    return Semantics(
      label: right
          ? 'Option $letter, the correct answer'
          : wrongPick
          ? 'Option $letter, your answer, wrong'
          : 'Option $letter',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: Text(
                letter,
                style: LipType.smallStrong.copyWith(color: fg),
              ),
            ),
            Expanded(
              child: LipHtml(
                html,
                baseStyle: LipType.option.copyWith(color: fg),
              ),
            ),
            if (right)
              Icon(Icons.check_rounded, size: 16, color: c.success)
            else if (wrongPick)
              Icon(Icons.close_rounded, size: 16, color: c.danger),
          ],
        ),
      ),
    );
  }
}
