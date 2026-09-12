import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// SAVED QUESTIONS
///
/// A saved question is one a student got wrong or found hard. So the answer
/// and the working travel with it — a list that shows the stem and withholds
/// the explanation is a list of unfinished arguments.
/// ===========================================================================

class SavedQuestion {
  const SavedQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.subject,
    this.year,
  });

  final String id;
  final String question;
  final List<String> options;

  /// 'A'…'E'. Empty when the bank has no answer recorded, which happens and
  /// must not crash a list.
  final String answer;
  final String explanation;
  final String subject;
  final int? year;

  /// The index the answer letter points at, or null if it points nowhere.
  int? get answerIndex {
    if (answer.isEmpty) return null;
    final i = answer.codeUnitAt(0) - 65;
    return i >= 0 && i < options.length ? i : null;
  }

  static SavedQuestion from(Map<String, dynamic> j) => SavedQuestion(
    id: asText(j['id']),
    question: asText(j['question']),
    options: ((j['options'] as List?) ?? const []).map((o) => '$o').toList(),
    answer: (asText(j['answer'])).toUpperCase(),
    explanation: asText(j['explanation']),
    subject: asText(j['subject']),
    year: j['year'] is int ? j['year'] as int : null,
  );
}

class SavedPage {
  const SavedPage({required this.questions, required this.total});
  final List<SavedQuestion> questions;
  final int total;
}

final savedQuestionsProvider = FutureProvider.family<SavedPage, int>((
  ref,
  page,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/saved', query: {'page': '$page'});
  return SavedPage(
    questions: ((res['questions'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => SavedQuestion.from(m.cast<String, dynamic>()))
        .toList(),
    total: asInt(res['total']),
  );
});

/// Unsave. Takes the Api rather than a ref so it is resolved before the gap.
Future<void> unsaveQuestion(Api api, String questionId) =>
    api.post('/api/qmark', body: {'op': 'unsave', 'questionId': questionId});
