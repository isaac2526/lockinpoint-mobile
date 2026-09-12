import '../../core/json.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// COMPETITION ROUNDS · the UTME Challenge and every one after it.
///
/// The leaderboard ranks everybody since the beginning of time, which is a
/// scoreboard rather than a competition: a student who joined in March can
/// never catch one who joined in January. A ROUND is a window with a prize —
/// only sittings inside its dates count, so everyone starts level on the day
/// it opens.
///
/// /api/mobile/rounds has served this all along and the app has never asked.
/// A null round is a NORMAL answer: most of the year no competition is
/// running, and the screen says so plainly rather than showing an empty
/// scoreboard that looks broken.
/// ===========================================================================

class Prize {
  const Prize(this.position, this.prize, this.note);
  final int position;
  final String prize;
  final String note;
}

class Round {
  const Round({
    required this.id,
    required this.name,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.prizes,
  });

  factory Round.from(Map<dynamic, dynamic> m) => Round(
    id: asText(m['id']),
    name: asText(m['name'], 'Challenge'),
    description: asText(m['description']),
    startsAt: DateTime.tryParse('${m['startsAt'] ?? ''}'),
    endsAt: DateTime.tryParse('${m['endsAt'] ?? ''}'),
    prizes: (asList(m['prizes']))
        .whereType<Map>()
        .map(
          (p) => Prize(
            (asIntOrNull(p['position'])) ?? 0,
            asText(p['prize']),
            asText(p['note']),
          ),
        )
        .toList(),
  );

  final String id;
  final String name;
  final String description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<Prize> prizes;

  /// Whole days until it closes. Null when there is no end date; negative
  /// only in the moments between closing and the backend noticing.
  int? get daysLeft {
    final e = endsAt;
    if (e == null) return null;
    final now = DateTime.now();
    return DateTime(
      e.year,
      e.month,
      e.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

class Winner {
  const Winner(this.round, this.position, this.name, this.prize, this.state);
  final String round;
  final int position;

  /// A username, never an email. A winners board is public, and publishing
  /// the addresses of the students who did best is how they get targeted.
  final String name;
  final String prize;
  final String state;
}

class RoundsView {
  const RoundsView({required this.round, required this.winners});
  final Round? round;
  final List<Winner> winners;
}

final roundsProvider = FutureProvider<RoundsView>((ref) async {
  final res = await ref.read(apiProvider).get('/api/mobile/rounds');
  final r = res['round'];
  return RoundsView(
    round: r is Map ? Round.from(r) : null,
    winners: (asList(res['winners']))
        .whereType<Map>()
        .map(
          (w) => Winner(
            asText(w['round']),
            (asIntOrNull(w['position'])) ?? 0,
            asText(w['name'], 'A student'),
            asText(w['prize']),
            asText(w['state']),
          ),
        )
        .toList(),
  );
});
