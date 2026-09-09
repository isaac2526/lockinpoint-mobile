import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// THEORY AND PRACTICAL
///
/// Every WAEC, NECO and NABTEB paper has a second half that is not multiple
/// choice, and until now a student preparing here practised half of it.
///
/// THE MODEL ANSWER IS NOT FETCHED WITH THE QUESTION. It arrives only when
/// the student asks, one at a time — a theory question whose marking scheme
/// is already on the screen is a passage to read, not a question to attempt,
/// and the whole value of theory practice is writing your own answer first
/// and then finding out.
/// ===========================================================================

/// An examination that has theory or practical under it.
///
/// The app had no notion of one. Every subject from every board arrived in a
/// single flat list, which is exactly the "everything moded together" the
/// owner objected to — his words were "which examination classroom did you
/// want to enter, then which topic, on different pages".
class TheoryExam {
  const TheoryExam({
    required this.slug,
    required this.name,
    required this.full,
    required this.subjects,
  });

  final String slug;
  final String name;
  final String full;
  final int subjects;

  static TheoryExam from(Map<String, dynamic> j) => TheoryExam(
    slug: j['slug'] as String? ?? '',
    name: j['name'] as String? ?? '',
    full: j['full'] as String? ?? '',
    subjects: (j['subjects'] as num?)?.toInt() ?? 0,
  );
}

/// A written session — what Tutor Bello types in Admin → Theory / Practical.
///
/// THESE WERE INVISIBLE ON THE PHONE. Admin writes them into `notes`; the
/// app's Theory room read `theory_questions`, which only the PDF importer
/// ever writes. Two tables that never met, so every session he wrote was
/// live on the website and absent here — and every imported past paper was
/// the exact reverse.
class TheorySession {
  const TheorySession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime? updatedAt;

  static TheorySession from(Map<String, dynamic> j) => TheorySession(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? 'Untitled session',
    updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}'),
  );
}

/// What one subject holds: the tutor's sessions, and the imported papers.
class TheoryShelf {
  const TheoryShelf({required this.sessions, required this.years});

  final List<TheorySession> sessions;
  final List<({int year, int n})> years;

  bool get isEmpty => sessions.isEmpty && years.isEmpty;
}

class TheorySubject {
  const TheorySubject({
    required this.id,
    required this.name,
    required this.exam,
    required this.questions,
    required this.sessions,
  });

  final String id;
  final String name;
  final String exam;

  /// Imported past-paper questions.
  final int questions;

  /// Sessions the tutor wrote by hand. Counted separately because a subject
  /// may have one kind and not the other, and both must bring it onto the
  /// list.
  final int sessions;

  int get total => questions + sessions;
}

class TheoryQuestion {
  const TheoryQuestion({
    required this.id,
    required this.number,
    required this.html,
    this.marks,
  });

  final String id;
  final String number;
  final String html;
  final int? marks;
}

class TheoryAnswer {
  const TheoryAnswer({required this.html, required this.hasAnswer, this.marks});
  final String html;

  /// False when this paper was imported without its marking scheme. Said
  /// plainly rather than shown as an empty box that looks like a bug.
  final bool hasAnswer;
  final int? marks;
}

/// 'theory' or 'practical' — two different papers with different
/// conventions, and a student revising one is not revising the other.
///
/// Step one of the walk: WHICH EXAMINATION.
final theoryExamsProvider = FutureProvider.family<List<TheoryExam>, String>((
  ref,
  kind,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/theory', query: {'kind': kind});
  return ((res['exams'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => TheoryExam.from(m.cast<String, dynamic>()))
      .toList();
});

/// Step two: which subject, under the examination just chosen.
final theorySubjectsProvider =
    FutureProvider.family<List<TheorySubject>, ({String kind, String exam})>((
      ref,
      key,
    ) async {
      final res = await ref
          .read(apiProvider)
          .get(
            '/api/mobile/theory',
            query: {
              'kind': key.kind,
              if (key.exam.isNotEmpty) 'exam': key.exam,
            },
          );
      return ((res['subjects'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => TheorySubject(
              id: m['id'] as String? ?? '',
              name: m['name'] as String? ?? '',
              exam: m['exam'] as String? ?? '',
              questions: (m['questions'] as num?)?.toInt() ?? 0,
              sessions: (m['sessions'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
    });

/// Step three: what this subject holds — the tutor's written sessions AND
/// the imported papers, on one shelf, each opening its own page.
final theoryShelfProvider =
    FutureProvider.family<TheoryShelf, ({String subject, String kind})>((
      ref,
      key,
    ) async {
      final res = await ref
          .read(apiProvider)
          .get(
            '/api/mobile/theory',
            query: {'subject': key.subject, 'kind': key.kind},
          );
      return TheoryShelf(
        sessions: ((res['sessions'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => TheorySession.from(m.cast<String, dynamic>()))
            .toList(),
        years: ((res['years'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (m) => (
                year: (m['year'] as num?)?.toInt() ?? 0,
                n: (m['n'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(),
      );
    });

/// One written session, opened.
final theorySessionProvider =
    FutureProvider.family<({String title, String html}), String>((
      ref,
      id,
    ) async {
      final res = await ref
          .read(apiProvider)
          .get('/api/mobile/theory', query: {'session': id});
      final n = (res['session'] as Map?)?.cast<String, dynamic>() ?? const {};
      return (
        title: n['title'] as String? ?? 'Session',
        html: n['body_html'] as String? ?? n['body'] as String? ?? '',
      );
    });

final theoryPaperProvider =
    FutureProvider.family<
      List<TheoryQuestion>,
      ({String subject, String kind, int year})
    >((ref, key) async {
      final res = await ref
          .read(apiProvider)
          .get(
            '/api/mobile/theory',
            query: {
              'subject': key.subject,
              'kind': key.kind,
              'year': '${key.year}',
            },
          );
      return ((res['questions'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => TheoryQuestion(
              id: m['id'] as String? ?? '',
              number: m['number'] as String? ?? '',
              html:
                  m['question_html'] as String? ??
                  m['question'] as String? ??
                  '',
              marks: m['marks'] as int?,
            ),
          )
          .toList();
    });

/// Asked for deliberately, one question at a time.
Future<TheoryAnswer> revealAnswer(Api api, String questionId) async {
  final res = await api.get(
    '/api/mobile/theory',
    query: {'answer': questionId},
  );
  return TheoryAnswer(
    html: res['answer_html'] as String? ?? res['answer'] as String? ?? '',
    hasAnswer: res['hasAnswer'] == true,
    marks: res['marks'] as int?,
  );
}
