import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'classroom_repository.dart';

/// ===========================================================================
/// THE CLASSROOM
///
/// Exam, then subject, then the shelf: notes to read, videos to watch, files
/// to keep. Violet throughout, because the classroom owns violet the way
/// practice owns blue — a student should know which room they are in before
/// they read a single word.
/// ===========================================================================
class ClassroomScreen extends ConsumerStatefulWidget {
  const ClassroomScreen({super.key});

  @override
  ConsumerState<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends ConsumerState<ClassroomScreen> {
  String _exam = '';

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(classroomExamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classroom')),
      body: SafeArea(
        child: exams.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Column(
              children: [
                LipSkeleton(height: 44),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 120),
              ],
            ),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(classroomExamsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const LipEmpty(
                icon: Icons.auto_stories_rounded,
                title: 'No exams yet',
                message: 'The tutors have not opened a room yet.',
              );
            }
            final exam = _exam.isEmpty ? list.first.slug : _exam;
            return Column(
              children: [
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
                    itemBuilder: (_, i) => Center(
                      child: LipChip(
                        list[i].name,
                        selected: list[i].slug == exam,
                        onTap: () => setState(() => _exam = list[i].slug),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _Subjects(examSlug: exam)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Subjects extends ConsumerWidget {
  const _Subjects({required this.examSlug});
  final String examSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final subjects = ref.watch(classroomSubjectsProvider(examSlug));

    return subjects.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: LipSkeleton(height: 200),
      ),
      error: (e, _) => LipError(
        message: '$e',
        onRetry: () => ref.invalidate(classroomSubjectsProvider(examSlug)),
      ),
      data: (list) => list.isEmpty
          ? const LipEmpty(
              icon: Icons.auto_stories_rounded,
              title: 'Nothing in this room yet',
              message:
                  'Notes and videos appear here as the tutors upload them.',
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.huge,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Gap.md,
                crossAxisSpacing: Gap.md,
                childAspectRatio: 2.1,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => GlassSurface(
                hue: c.hues.violet,
                padding: const EdgeInsets.all(Gap.md),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ShelfScreen(subject: list[i]),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    list[i].name,
                    style: LipType.subheading.copyWith(color: c.text1),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ShelfScreen extends ConsumerWidget {
  const _ShelfScreen({required this.subject});
  final SubjectRef subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final shelf = ref.watch(subjectShelfProvider(subject.id));

    return Scaffold(
      appBar: AppBar(title: Text(subject.name)),
      body: SafeArea(
        child: shelf.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 220),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(subjectShelfProvider(subject.id)),
          ),
          data: (s) => s.isEmpty
              ? const LipEmpty(
                  icon: Icons.auto_stories_rounded,
                  title: 'This shelf is empty',
                  message:
                      'No notes, videos or files for this subject yet. Practice '
                      'is open in the meantime.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    if (s.notes.isNotEmpty) ...[
                      const LipLabel('Notes to read'),
                      const SizedBox(height: Gap.sm),
                      ...s.notes.map(
                        (m) => _Row(
                          icon: Icons.article_rounded,
                          hue: c.hues.teal,
                          title: m.title,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _NoteScreen(id: m.id, title: m.title),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                    ],
                    if (s.videos.isNotEmpty) ...[
                      const LipLabel('Video lessons'),
                      const SizedBox(height: Gap.sm),
                      ...s.videos.map(
                        (m) => _Row(
                          icon: Icons.play_circle_rounded,
                          hue: c.hues.rose,
                          title: m.title,
                          onTap: m.url.isEmpty
                              ? null
                              : () => launchUrl(
                                  Uri.parse(m.url),
                                  mode: LaunchMode.externalApplication,
                                ),
                        ),
                      ),
                      const SizedBox(height: Gap.lg),
                    ],
                    if (s.documents.isNotEmpty) ...[
                      const LipLabel('Files to keep'),
                      const SizedBox(height: Gap.sm),
                      ...s.documents.map(
                        (m) => _Row(
                          icon: Icons.description_rounded,
                          hue: c.hues.amber,
                          title: m.title,
                          onTap: m.url.isEmpty
                              ? null
                              : () => launchUrl(
                                  Uri.parse(m.url),
                                  mode: LaunchMode.externalApplication,
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.hue,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final LipHue hue;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: GlassSurface(
        tier: GlassTier.raised,
        padding: const EdgeInsets.all(Gap.md),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: hue.ink),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                title.isEmpty ? 'Untitled' : title,
                style: LipType.body.copyWith(color: c.text1),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _NoteScreen extends ConsumerWidget {
  const _NoteScreen({required this.id, required this.title});
  final String id;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final note = ref.watch(noteProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: note.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 300),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(noteProvider(id)),
          ),
          data: (n) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Gap.lg,
              Gap.lg,
              Gap.lg,
              Gap.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n['title'] ?? '',
                  style: LipType.title.copyWith(color: c.text1),
                ),
                const SizedBox(height: Gap.md),
                /* The body is stored as HTML by the admin editor. Rendering it
                   as rich text needs a renderer the app does not ship; showing
                   the tags would be worse than showing none. Stripped, spaced
                   and set at reading size — honest plain text beats a broken
                   attempt at formatting. */
                Text(
                  _readable(n['body'] ?? ''),
                  style: LipType.body.copyWith(color: c.text2, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _readable(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n\n')
    .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
