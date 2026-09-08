import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/vault/materials.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/rich_text.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'classroom_repository.dart';

/// ===========================================================================
/// THE CLASSROOM · one question per screen.
///
/// This was a single page: a horizontal strip of exam chips at the top and
/// every subject in the exam below it, so choosing WAEC and choosing Chemistry
/// happened in the same breath and the room you were in was a chip you might
/// have scrolled past. On a phone that reads as one undifferentiated wall.
///
/// It is now the walk the rest of the platform uses, and the walk a student
/// actually takes:
///
///     which examination  →  which subject  →  what is on the shelf
///
/// Each on its own screen, each with the back button that gets you to the
/// previous decision. Violet throughout, because the classroom owns violet
/// the way practice owns blue — a student should know which room they are in
/// before they read a single word.
/// ===========================================================================
class ClassroomScreen extends ConsumerWidget {
  const ClassroomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final exams = ref.watch(classroomExamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classroom')),
      body: SafeArea(
        child: exams.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Column(
              children: [
                LipSkeleton(height: 78),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 78),
                SizedBox(height: Gap.md),
                LipSkeleton(height: 78),
              ],
            ),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(classroomExamsProvider),
          ),
          data: (list) => list.isEmpty
              ? const LipEmpty(
                  icon: Icons.auto_stories_rounded,
                  title: 'No examination room is open yet',
                  message: 'The tutors have not opened a room yet.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    Text(
                      'Which examination room?',
                      style: LipType.title.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Notes to read, video lessons, and files to keep — '
                      'filed the way the papers are.',
                      style: LipType.small.copyWith(color: c.text3),
                    ),
                    const SizedBox(height: Gap.lg),
                    for (final e in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: _BigRow(
                          icon: Icons.auto_stories_rounded,
                          hue: c.hues.violet,
                          title: e.name,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ClassroomSubjectsScreen(exam: e),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Step two: which subject, inside the examination already chosen.
class ClassroomSubjectsScreen extends ConsumerWidget {
  const ClassroomSubjectsScreen({super.key, required this.exam});
  final ExamRef exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final subjects = ref.watch(classroomSubjectsProvider(exam.slug));

    return Scaffold(
      appBar: AppBar(title: Text(exam.name)),
      body: SafeArea(
        child: subjects.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: LipSkeleton(height: 220),
          ),
          error: (e, _) => LipError(
            message: '$e',
            onRetry: () => ref.invalidate(classroomSubjectsProvider(exam.slug)),
          ),
          data: (list) => list.isEmpty
              ? const LipEmpty(
                  icon: Icons.auto_stories_rounded,
                  title: 'Nothing in this room yet',
                  message:
                      'Notes and videos appear here as the tutors upload them.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.huge,
                  ),
                  children: [
                    Text(
                      'Which subject?',
                      style: LipType.title.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: Gap.lg),
                    for (final s in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: _BigRow(
                          icon: Icons.menu_book_rounded,
                          hue: c.hues.violet,
                          title: s.name,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ClassroomShelfScreen(subject: s),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Step three: the shelf itself — notes, videos and files for one subject.
class ClassroomShelfScreen extends ConsumerWidget {
  const ClassroomShelfScreen({super.key, required this.subject});
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
                          keep: _Keep(
                            id: m.id,
                            subjectId: subject.id,
                            title: m.title,
                            kind: 'note',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ClassroomNoteScreen(id: m.id, title: m.title),
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
                          icon: m.kind == 'slides'
                              ? Icons.slideshow_rounded
                              : Icons.description_rounded,
                          hue: c.hues.amber,
                          title: m.title,
                          keep: _Keep(
                            id: m.id,
                            subjectId: subject.id,
                            title: m.title,
                            kind: 'document',
                            url: m.url,
                          ),
                          subtitle: 'Opens with your name on every page',
                          onTap: m.url.isEmpty
                              ? null
                              : () => launchUrl(
                                  /* The server hands back a path on its own
                                     domain — /api/doc/<id> — because that is
                                     the gate that checks activation and burns
                                     the reader's name across the pages. It
                                     used to hand back a public storage URL
                                     for a bucket that does not exist, so
                                     every file 404'd. */
                                  Uri.parse(
                                    m.url.startsWith('http')
                                        ? m.url
                                        : '${AppConfig.apiBase}${m.url}',
                                  ),
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

/// One note, read inside the app.
class ClassroomNoteScreen extends ConsumerWidget {
  const ClassroomNoteScreen({super.key, required this.id, required this.title});
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
                /* THE BODY IS HTML, AND IT IS NOW DRAWN AS HTML.
                   It used to go through a regex that deleted every tag: which
                   turns H<sub>2</sub>O into H2O and x<sup>2</sup> into x2 —
                   wrong in chemistry, wrong in every index — and threw away
                   bold, underline, lists, tables and every formula. The
                   renderer for exactly this content already existed for
                   practice questions; it now lives in the design system where
                   any screen can use it. */
                LipHtml(
                  n['body'] ?? '',
                  baseStyle: LipType.body.copyWith(color: c.text2, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tall row for a decision: examination, subject. Big enough to be the only
/// thing on the screen worth tapping.
class _BigRow extends StatelessWidget {
  const _BigRow({
    required this.icon,
    required this.hue,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final LipHue hue;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return GlassSurface(
      hue: hue,
      padding: const EdgeInsets.all(Gap.lg),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hue.tint,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, size: 22, color: hue.ink),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              title,
              style: LipType.subheading.copyWith(color: c.text1),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.hue,
    required this.title,
    this.subtitle,
    this.onTap,
    this.keep,
  });

  final IconData icon;
  final LipHue hue;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// The per-item download button. TIER TWO of the offline vault: questions
  /// are fetched once for everybody, but a note or a PDF is kept only when
  /// this particular student asks for this particular file.
  final Widget? keep;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled' : title,
                    style: LipType.body.copyWith(color: c.text1),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: LipType.caption.copyWith(color: c.text3),
                    ),
                ],
              ),
            ),
            ?keep,
            Icon(Icons.chevron_right_rounded, size: 18, color: c.text3),
          ],
        ),
      ),
    );
  }
}

/// ===========================================================================
/// KEEP THIS ONE · the second tier's button, per file.
///
/// Three states and each says something different: not here, working, here.
/// A button that looks the same before and after a 30MB download is a button
/// a student presses twice.
/// ===========================================================================
class _Keep extends ConsumerWidget {
  const _Keep({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.kind,
    this.url = '',
  });

  final String id;
  final String subjectId;
  final String title;
  final String kind;
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lip;
    final saved = ref.watch(materialSavedProvider(id)).value ?? false;

    Future<void> act() async {
      final vault = ref.read(materialVaultProvider);
      final messenger = ScaffoldMessenger.of(context);
      try {
        if (saved) {
          await vault.forget(id);
          messenger.showSnackBar(
            const SnackBar(content: Text('Removed from this phone')),
          );
        } else {
          messenger.showSnackBar(SnackBar(content: Text('Keeping "$title"…')));
          if (kind == 'note') {
            await vault.saveNote(id: id, subjectId: subjectId, title: title);
          } else {
            await vault.saveDocument(
              id: id,
              subjectId: subjectId,
              title: title,
              url: url,
            );
          }
          messenger.showSnackBar(
            const SnackBar(content: Text('Kept. It opens with no signal now.')),
          );
        }
      } on ApiFailure catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      } finally {
        ref.invalidate(materialSavedProvider(id));
        ref.invalidate(savedMaterialsProvider);
      }
    }

    return IconButton(
      tooltip: saved ? 'On this phone · tap to remove' : 'Keep on this phone',
      onPressed: act,
      icon: Icon(
        saved ? Icons.offline_pin_rounded : Icons.download_for_offline_outlined,
        size: 20,
        color: saved ? c.hues.green.ink : c.text3,
      ),
    );
  }
}
