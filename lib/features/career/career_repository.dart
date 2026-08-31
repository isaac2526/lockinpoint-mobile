import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// CAREERS, COURSES AND WHERE TO STUDY THEM
///
/// The question a candidate actually has is "who offers Medicine, and at what
/// cut-off?" — and until now it could not be asked. Departments were only ever
/// queryable one institution at a time, so answering it meant five hundred
/// requests. One indexed search answers it in one.
/// ===========================================================================

class CareerRef {
  const CareerRef({
    required this.name,
    required this.slug,
    required this.summary,
    required this.stream,
  });

  final String name;
  final String slug;
  final String summary;
  final String stream;

  static CareerRef from(Map<String, dynamic> j) => CareerRef(
    name: j['name'] as String? ?? '',
    slug: j['slug'] as String? ?? '',
    summary: j['summary'] as String? ?? '',
    stream: j['stream'] as String? ?? '',
  );
}

class InstitutionRef {
  const InstitutionRef({
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.state,
  });

  final String id;
  final String name;
  final String shortName;
  final String type;
  final String state;

  static InstitutionRef from(Map<String, dynamic> j) => InstitutionRef(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    shortName: j['shortName'] as String? ?? '',
    type: j['type'] as String? ?? '',
    state: j['state'] as String? ?? '',
  );
}

/// One school offering one course, with whatever the tutors published about
/// its cut-off. This is the row the whole feature exists to produce.
class CourseOffer {
  const CourseOffer({
    required this.course,
    required this.institution,
    required this.shortName,
    required this.cutoff,
    required this.note,
    required this.state,
    required this.type,
  });

  final String course;
  final String institution;
  final String shortName;
  final String cutoff;
  final String note;
  final String state;
  final String type;

  static CourseOffer from(Map<String, dynamic> j) => CourseOffer(
    course: j['course'] as String? ?? '',
    institution: j['institution'] as String? ?? '',
    shortName: j['shortName'] as String? ?? '',
    cutoff: j['cutoff'] as String? ?? '',
    note: j['note'] as String? ?? '',
    state: j['state'] as String? ?? '',
    type: j['type'] as String? ?? '',
  );
}

class CareerShelf {
  const CareerShelf({required this.careers, required this.institutions});
  final List<CareerRef> careers;
  final List<InstitutionRef> institutions;
}

final careerShelfProvider = FutureProvider.family<CareerShelf, String>((
  ref,
  query,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/career', query: {if (query.isNotEmpty) 'q': query});
  return CareerShelf(
    careers: ((res['careers'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => CareerRef.from(m.cast<String, dynamic>()))
        .toList(),
    institutions: ((res['institutions'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => InstitutionRef.from(m.cast<String, dynamic>()))
        .toList(),
  );
});

/// WHO OFFERS THIS COURSE. Three letters minimum, matching the server, so a
/// single keystroke does not sweep every department in the country.
final courseOffersProvider = FutureProvider.family<List<CourseOffer>, String>((
  ref,
  course,
) async {
  if (course.trim().length < 3) return const [];
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/career', query: {'course': course.trim()});
  return ((res['offers'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => CourseOffer.from(m.cast<String, dynamic>()))
      .toList();
});

class InstitutionDetail {
  const InstitutionDetail({
    required this.name,
    required this.about,
    required this.aggregate,
    required this.state,
    required this.departments,
  });

  final String name;
  final String about;

  /// How this school turns a UTME score into an aggregate. Stored as prose by
  /// the tutors, so the app strips the markup it cannot render.
  final String aggregate;
  final String state;
  final List<({String name, String cutoff, String note})> departments;
}

final institutionProvider = FutureProvider.family<InstitutionDetail, String>((
  ref,
  id,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/career', query: {'inst': id});
  final i = (res['institution'] as Map?)?.cast<String, dynamic>() ?? const {};
  return InstitutionDetail(
    name: i['name'] as String? ?? '',
    about: i['about'] as String? ?? '',
    aggregate: i['aggregate'] as String? ?? '',
    state: i['state'] as String? ?? '',
    departments: ((res['departments'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (d) => (
            name: d['name'] as String? ?? '',
            cutoff: d['cutoff'] as String? ?? '',
            note: d['note'] as String? ?? '',
          ),
        )
        .toList(),
  );
});

final careerProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  slug,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/career', query: {'career': slug});
  return (res['career'] as Map?)?.cast<String, dynamic>() ?? const {};
});

/// The admin editor stores prose as HTML. The app ships no renderer for it,
/// and showing the tags would be worse than showing none.
String readableHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n\n')
    .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
