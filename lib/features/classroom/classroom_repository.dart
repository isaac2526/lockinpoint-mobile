import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// THE CLASSROOM
///
/// The same three tables the website's /materials page reads — notes, videos
/// and documents — through one endpoint that applies the same published
/// filters. Two classrooms that disagreed about what a subject contains would
/// be worse than one.
/// ===========================================================================

class ExamRef {
  const ExamRef(this.slug, this.name);
  final String slug;
  final String name;
}

class SubjectRef {
  const SubjectRef(this.id, this.name);
  final String id;
  final String name;
}

class Material {
  const Material({
    required this.id,
    required this.title,
    this.url = '',
    this.kind = '',
  });

  final String id;
  final String title;

  /// Empty for a note — a note is read inside the app, not opened elsewhere.
  final String url;
  final String kind;
}

class SubjectShelf {
  const SubjectShelf({
    required this.notes,
    required this.videos,
    required this.documents,
  });

  final List<Material> notes;
  final List<Material> videos;
  final List<Material> documents;

  bool get isEmpty => notes.isEmpty && videos.isEmpty && documents.isEmpty;
  int get total => notes.length + videos.length + documents.length;
}

List<Material> _materials(Object? raw, {String titleKey = 'title'}) =>
    ((raw as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) => Material(
            id: asText(m['id']),
            title: asText(m[titleKey]),
            url: asText(m['url']),
            kind: asText(m['kind']),
          ),
        )
        .toList();

final classroomExamsProvider = FutureProvider<List<ExamRef>>((ref) async {
  final res = await ref.read(apiProvider).get('/api/mobile/classroom');
  return ((res['exams'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => ExamRef(asText(m['slug']), asText(m['name'])))
      .toList();
});

final classroomSubjectsProvider =
    FutureProvider.family<List<SubjectRef>, String>((ref, examSlug) async {
      final res = await ref
          .read(apiProvider)
          .get('/api/mobile/classroom', query: {'exam': examSlug});
      return ((res['subjects'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SubjectRef(asText(m['id']), asText(m['name'])))
          .toList();
    });

final subjectShelfProvider = FutureProvider.family<SubjectShelf, String>((
  ref,
  subjectId,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/classroom', query: {'subject': subjectId});
  return SubjectShelf(
    notes: _materials(res['notes']),
    videos: _materials(res['videos']),
    documents: _materials(res['documents']),
  );
});

final noteProvider = FutureProvider.family<Map<String, String>, String>((
  ref,
  noteId,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/classroom', query: {'note': noteId});
  final n = res['note'];
  if (n is! Map) throw ApiFailure('That note is not available.');
  return {'title': asText(n['title']), 'body': asText(n['body'])};
});
