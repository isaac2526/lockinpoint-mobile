import '../../core/json.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'career_repository.dart';

/// ===========================================================================
/// CAREER & INSTITUTIONS
///
/// Three tabs, orange throughout — the palette's career hue.
///
///   WHO OFFERS IT  the question every candidate actually has, and the one
///                  the product could not answer until now
///   CAREERS        what the work is, and which courses reach it
///   SCHOOLS        one institution's departments and its aggregate formula
/// ===========================================================================
class CareerScreen extends ConsumerStatefulWidget {
  const CareerScreen({super.key});

  @override
  ConsumerState<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends ConsumerState<CareerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Scaffold(
      appBar: AppBar(title: const Text('Career & institutions')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.sm,
              ),
              child: Row(
                children: [
                  for (final (i, label) in [
                    'Who offers it',
                    'Careers',
                    'Schools',
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: Gap.sm),
                    LipChip(
                      label,
                      selected: _tab == i,
                      onTap: () => setState(() => _tab = i),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                0 => const _CourseSearch(),
                1 => const _Careers(),
                _ => const _Schools(),
              },
            ),
          ],
        ),
      ),
      backgroundColor: c.bgBase,
    );
  }
}

// ---------------------------------------------------------- who offers it --

class _CourseSearch extends ConsumerStatefulWidget {
  const _CourseSearch();

  @override
  ConsumerState<_CourseSearch> createState() => _CourseSearchState();
}

class _CourseSearchState extends ConsumerState<_CourseSearch> {
  final _input = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  /// One request per settle, not one per keystroke. Nigerian mobile data is
  /// not free and a department search is not cheap.
  void _typed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final offers = ref.watch(courseOffersProvider(_query));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          child: TextField(
            controller: _input,
            onChanged: _typed,
            style: LipType.body.copyWith(color: c.text1),
            decoration: const InputDecoration(
              hintText: 'Medicine, Law, Computer Science…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
        Expanded(
          child: _query.length < 3
              ? const LipEmpty(
                  icon: Icons.school_rounded,
                  title: 'Which course?',
                  message:
                      'Type three letters or more and every school offering '
                      'it appears, with whatever cut-off the tutors have '
                      'published.',
                )
              : offers.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Gap.lg),
                    child: LipSkeleton(height: 200),
                  ),
                  error: (e, _) => LipError(
                    message: humanError(e, doing: 'load the schools'),
                    onRetry: () => ref.invalidate(courseOffersProvider(_query)),
                  ),
                  data: (list) => list.isEmpty
                      ? LipEmpty(
                          icon: Icons.search_off_rounded,
                          title: 'Nothing matched "$_query"',
                          message:
                              'Try the course as a school writes it — '
                              '"Medicine and Surgery" rather than "doctor".',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            Gap.lg,
                            Gap.md,
                            Gap.lg,
                            Gap.huge,
                          ),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final o = list[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: Gap.sm),
                              child: GlassSurface(
                                hue: c.hues.orange,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            o.institution,
                                            style: LipType.subheading.copyWith(
                                              color: c.text1,
                                            ),
                                          ),
                                        ),
                                        if (o.cutoff.isNotEmpty)
                                          LipChip(
                                            o.cutoff,
                                            tone: ChipTone.brand,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      o.course,
                                      style: LipType.body.copyWith(
                                        color: c.text2,
                                      ),
                                    ),
                                    if (o.state.isNotEmpty ||
                                        o.type.isNotEmpty) ...[
                                      const SizedBox(height: Gap.xs),
                                      Text(
                                        [o.state, o.type]
                                            .where((s) => s.isNotEmpty)
                                            .join(' · '),
                                        style: LipType.caption.copyWith(
                                          color: c.text3,
                                        ),
                                      ),
                                    ],
                                    if (o.note.isNotEmpty) ...[
                                      const SizedBox(height: Gap.xs),
                                      Text(
                                        o.note,
                                        style: LipType.caption.copyWith(
                                          color: c.text3,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- careers --

class _Careers extends ConsumerWidget {
  const _Careers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final shelf = ref.watch(careerShelfProvider(''));

    return shelf.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: LipSkeleton(height: 220),
      ),
      error: (e, _) => LipError(
        message: humanError(e, doing: 'load the schools'),
        onRetry: () => ref.invalidate(careerShelfProvider('')),
      ),
      data: (s) => s.careers.isEmpty
          ? const LipEmpty(
              icon: Icons.work_rounded,
              title: 'No careers published yet',
              message:
                  'The tutors add these in the admin panel. Course search and '
                  'schools work in the meantime.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.lg,
                Gap.huge,
              ),
              itemCount: s.careers.length,
              itemBuilder: (_, i) {
                final k = s.careers[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: GlassSurface(
                    hue: c.hues.orange,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            _CareerDetail(slug: k.slug, title: k.name),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                k.name,
                                style: LipType.subheading.copyWith(
                                  color: c.text1,
                                ),
                              ),
                            ),
                            if (k.stream.isNotEmpty)
                              LipChip(k.stream, tone: ChipTone.neutral),
                          ],
                        ),
                        if (k.summary.isNotEmpty) ...[
                          const SizedBox(height: Gap.xs),
                          Text(
                            k.summary,
                            style: LipType.small.copyWith(
                              color: c.text2,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CareerDetail extends ConsumerWidget {
  const _CareerDetail({required this.slug, required this.title});
  final String slug;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final career = ref.watch(careerProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: career.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 280),
          ),
          error: (e, _) => LipError(
            message: humanError(e, doing: 'load the schools'),
            onRetry: () => ref.invalidate(careerProvider(slug)),
          ),
          data: (k) {
            final courses = (asList(k['courses'])).whereType<Map>().toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.lg,
                Gap.lg,
                Gap.huge,
              ),
              children: [
                if ((asText(k['summary'])).isNotEmpty)
                  GlassSurface(
                    hue: c.hues.orange,
                    child: Text(
                      asText(k['summary']),
                      style: LipType.body.copyWith(color: c.text1, height: 1.5),
                    ),
                  ),
                if ((asText(k['body'])).isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  Text(
                    readableHtml(asText(k['body'])),
                    style: LipType.body.copyWith(color: c.text2, height: 1.6),
                  ),
                ],
                if (courses.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  const LipLabel('Courses that lead here'),
                  const SizedBox(height: Gap.sm),
                  ...courses.map(
                    (co) => Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: GlassSurface(
                        tier: GlassTier.raised,
                        padding: const EdgeInsets.all(Gap.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${co['name']}',
                              style: LipType.body.copyWith(color: c.text1),
                            ),
                            if ('${co['note']}'.isNotEmpty)
                              Text(
                                '${co['note']}',
                                style: LipType.caption.copyWith(color: c.text3),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- schools --

class _Schools extends ConsumerWidget {
  const _Schools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final shelf = ref.watch(careerShelfProvider(''));

    return shelf.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: LipSkeleton(height: 220),
      ),
      error: (e, _) => LipError(
        message: humanError(e, doing: 'load the schools'),
        onRetry: () => ref.invalidate(careerShelfProvider('')),
      ),
      data: (s) => s.institutions.isEmpty
          ? const LipEmpty(
              icon: Icons.account_balance_rounded,
              title: 'No institutions yet',
              message: 'The tutors add these in the admin panel.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.lg,
                Gap.huge,
              ),
              itemCount: s.institutions.length,
              itemBuilder: (_, i) {
                final inst = s.institutions[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: GlassSurface(
                    tier: GlassTier.raised,
                    padding: const EdgeInsets.all(Gap.md),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _InstitutionDetail(id: inst.id),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inst.name,
                                style: LipType.body.copyWith(color: c.text1),
                              ),
                              Text(
                                [
                                  inst.state,
                                  inst.type,
                                ].where((x) => x.isNotEmpty).join(' · '),
                                style: LipType.caption.copyWith(color: c.text3),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: c.text3,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _InstitutionDetail extends ConsumerWidget {
  const _InstitutionDetail({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final inst = ref.watch(institutionProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Institution')),
      body: SafeArea(
        child: inst.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 300),
          ),
          error: (e, _) => LipError(
            message: humanError(e, doing: 'load the schools'),
            onRetry: () => ref.invalidate(institutionProvider(id)),
          ),
          data: (d) => ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.lg,
              Gap.lg,
              Gap.lg,
              Gap.huge,
            ),
            children: [
              Text(d.name, style: LipType.title.copyWith(color: c.text1)),
              if (d.state.isNotEmpty)
                Text(d.state, style: LipType.small.copyWith(color: c.text3)),
              if (d.aggregate.isNotEmpty) ...[
                const SizedBox(height: Gap.lg),
                const LipLabel('How this school computes your aggregate'),
                const SizedBox(height: Gap.sm),
                GlassSurface(
                  hue: c.hues.indigo,
                  child: Text(
                    readableHtml(d.aggregate),
                    style: LipType.small.copyWith(color: c.text1, height: 1.6),
                  ),
                ),
              ],
              if (d.departments.isNotEmpty) ...[
                const SizedBox(height: Gap.lg),
                LipLabel('${d.departments.length} courses'),
                const SizedBox(height: Gap.sm),
                ...d.departments.map(
                  (dep) => Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: GlassSurface(
                      tier: GlassTier.raised,
                      padding: const EdgeInsets.all(Gap.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dep.name,
                                  style: LipType.body.copyWith(color: c.text1),
                                ),
                              ),
                              if (dep.cutoff.isNotEmpty)
                                LipChip(dep.cutoff, tone: ChipTone.brand),
                            ],
                          ),
                          if (dep.note.isNotEmpty) ...[
                            const SizedBox(height: Gap.xs),
                            Text(
                              dep.note,
                              style: LipType.caption.copyWith(
                                color: c.text3,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
