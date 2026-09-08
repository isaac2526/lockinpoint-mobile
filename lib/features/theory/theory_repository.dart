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

class TheorySubject {
  const TheorySubject({
    required this.id,
    required this.name,
    required this.exam,
    required this.questions,
  });

  final String id;
  final String name;
  final String exam;
  final int questions;
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
final theorySubjectsProvider =
    FutureProvider.family<List<TheorySubject>, String>((ref, kind) async {
      final res = await ref
          .read(apiProvider)
          .get('/api/mobile/theory', query: {'kind': kind});
      return ((res['subjects'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => TheorySubject(
              id: m['id'] as String? ?? '',
              name: m['name'] as String? ?? '',
              exam: m['exam'] as String? ?? '',
              questions: (m['questions'] as int?) ?? 0,
            ),
          )
          .toList();
    });

final theoryYearsProvider =
    FutureProvider.family<
      List<({int year, int n})>,
      ({String subject, String kind})
    >((ref, key) async {
      final res = await ref
          .read(apiProvider)
          .get(
            '/api/mobile/theory',
            query: {'subject': key.subject, 'kind': key.kind},
          );
      return ((res['years'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => (year: (m['year'] as int?) ?? 0, n: (m['n'] as int?) ?? 0),
          )
          .toList();
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
