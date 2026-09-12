import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/smart_cache.dart';

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
    slug: asText(j['slug']),
    name: asText(j['name']),
    full: asText(j['full']),
    subjects: asInt(j['subjects']),
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
    id: asText(j['id']),
    title: asText(j['title'], 'Untitled session'),
    updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}'),
  );
}

/// What one subject holds: the tutor's sessions, and the imported papers.
/// A topic that ACTUALLY HOLDS THEORY QUESTIONS.
///
/// `theory_questions.topic_id` has existed since the table was created and
/// nothing had ever read it — so a student revising one topic before a class
/// test could only walk whole past papers, year by year, and pick the
/// relevant questions out by eye.
///
/// The list is built from the QUESTIONS, not from the syllabus, so a topic on
/// this shelf has at least one question behind it by construction. A shelf of
/// dead ends is worse than a short shelf.
class TheoryTopic {
  const TheoryTopic({required this.id, required this.name, required this.n});

  final String id;
  final String name;
  final int n;

  static TheoryTopic from(Map<String, dynamic> j) => TheoryTopic(
    id: asText(j['id']),
    name: asText(j['name']),
    n: asInt(j['n']),
  );
}

class TheoryShelf {
  const TheoryShelf({
    required this.sessions,
    required this.years,
    this.topics = const [],
  });

  final List<TheorySession> sessions;
  final List<({int year, int n})> years;
  final List<TheoryTopic> topics;

  bool get isEmpty => sessions.isEmpty && years.isEmpty && topics.isEmpty;
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
    this.year,
    this.series = '',
  });

  final String id;
  final String number;
  final String html;
  final int? marks;

  /// Set only when the questions came from a TOPIC rather than from one
  /// year's paper: across years, two questions numbered "3" are otherwise
  /// indistinguishable.
  final int? year;
  final String series;

  static TheoryQuestion from(Map<String, dynamic> m) => TheoryQuestion(
    id: asText(m['id']),
    number: asText(m['number']),
    html: asTextOrNull(m['question_html']) ?? asTextOrNull(m['question']) ?? '',
    marks: asIntOrNull(m['marks']),
    year: asIntOrNull(m['year']),
    series: asText(m['series']),
  );

  /// "2019 · 3", or just "3" inside a single year's paper.
  String get label {
    final n = number.isEmpty ? '' : number;
    if (year == null) return n;
    final y = series.isEmpty || series == 'main' ? '$year' : '$year $series';
    return n.isEmpty ? y : '$y · $n';
  }
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
  final res = (await readCached(
    ref,
    key: 'lip.theory.exams.$kind',
    path: '/api/mobile/theory',
    query: {'kind': kind},
  )).value;
  return (asList(res['exams']))
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
      final res = (await readCached(
        ref,
        key: 'lip.theory.subjects.${key.kind}.${key.exam}',
        path: '/api/mobile/theory',
        query: {'kind': key.kind, if (key.exam.isNotEmpty) 'exam': key.exam},
      )).value;
      return (asList(res['subjects']))
          .whereType<Map>()
          .map(
            (m) => TheorySubject(
              id: asText(m['id']),
              name: asText(m['name']),
              exam: asText(m['exam']),
              questions: asInt(m['questions']),
              sessions: asInt(m['sessions']),
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
      final res = (await readCached(
        ref,
        key: 'lip.theory.shelf.${key.kind}.${key.subject}',
        path: '/api/mobile/theory',
        query: {'subject': key.subject, 'kind': key.kind},
      )).value;
      return TheoryShelf(
        sessions: (asList(res['sessions']))
            .whereType<Map>()
            .map((m) => TheorySession.from(m.cast<String, dynamic>()))
            .toList(),
        years: (asList(res['years']))
            .whereType<Map>()
            .map((m) => (year: asInt(m['year']), n: asInt(m['n'])))
            .toList(),
        topics: asMapList(res['topics']).map(TheoryTopic.from).toList(),
      );
    });

/// One topic's questions, across every year the bank holds.
final theoryTopicProvider =
    FutureProvider.family<
      List<TheoryQuestion>,
      ({String subject, String kind, String topic})
    >((ref, key) async {
      final res = (await readCached(
        ref,
        key: 'lip.theory.topic.${key.kind}.${key.subject}.${key.topic}',
        path: '/api/mobile/theory',
        query: {'subject': key.subject, 'kind': key.kind, 'topic': key.topic},
      )).value;
      return asMapList(res['questions']).map(TheoryQuestion.from).toList();
    });

/// One written session, opened.
final theorySessionProvider =
    FutureProvider.family<({String title, String html}), String>((
      ref,
      id,
    ) async {
      /* A SESSION READ ONCE IS READABLE FOR EVER. This is the one that
         matters most on this screen: a student who opened Tutor Bello's
         walked solution last night on wifi should be able to revise from it
         on the bus, without having had to know in advance to keep it. */
      final res = (await readCached(
        ref,
        key: 'lip.theory.session.$id',
        path: '/api/mobile/theory',
        query: {'session': id},
      )).value;
      final n = asMap(res['session']);
      return (
        title: asText(n['title'], 'Session'),
        html: asTextOrNull(n['body_html']) ?? asText(n['body']),
      );
    });

final theoryPaperProvider =
    FutureProvider.family<
      List<TheoryQuestion>,
      ({String subject, String kind, int year})
    >((ref, key) async {
      final res = (await readCached(
        ref,
        key: 'lip.theory.paper.${key.kind}.${key.subject}.${key.year}',
        path: '/api/mobile/theory',
        query: {
          'subject': key.subject,
          'kind': key.kind,
          'year': '${key.year}',
        },
      )).value;
      return asMapList(res['questions']).map(TheoryQuestion.from).toList();
    });

/// Asked for deliberately, one question at a time.
Future<TheoryAnswer> revealAnswer(Api api, String questionId) async {
  final res = await api.get(
    '/api/mobile/theory',
    query: {'answer': questionId},
  );
  return TheoryAnswer(
    html: asTextOrNull(res['answer_html']) ?? asText(res['answer']),
    hasAnswer: res['hasAnswer'] == true,
    marks: asIntOrNull(res['marks']),
  );
}
