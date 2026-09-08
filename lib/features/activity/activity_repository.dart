import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// ACTIVITY HISTORY
///
/// Fifteen places on the backend call logActivity(), and until now the only
/// thing that ever read those rows back was the admin control room. A student
/// could see their results and nothing else — not when they activated, not
/// which question they flagged, not the payout they requested, not the day
/// they started a sitting and walked away from it.
/// ===========================================================================

class ActivityRow {
  const ActivityRow({
    required this.id,
    required this.title,
    required this.detail,
    required this.icon,
    required this.at,
  });

  factory ActivityRow.from(Map<dynamic, dynamic> m) => ActivityRow(
    id: m['id'] as String? ?? '',
    title: m['title'] as String? ?? 'Activity',
    detail: m['detail'] as String? ?? '',
    icon: m['icon'] as String? ?? 'dot',
    at: DateTime.tryParse('${m['at'] ?? ''}'),
  );

  final String id;
  final String title;
  final String detail;
  final String icon;
  final DateTime? at;
}

class ActivityPage {
  const ActivityPage({
    required this.rows,
    required this.total,
    required this.hasMore,
  });

  final List<ActivityRow> rows;
  final int total;
  final bool hasMore;
}

final activityProvider = FutureProvider.family<ActivityPage, int>((
  ref,
  page,
) async {
  final res = await ref
      .read(apiProvider)
      .get('/api/mobile/activity', query: {'page': page});
  return ActivityPage(
    rows: ((res['rows'] as List?) ?? const [])
        .whereType<Map>()
        .map(ActivityRow.from)
        .toList(),
    total: (res['total'] as int?) ?? 0,
    hasMore: res['hasMore'] == true,
  );
});
