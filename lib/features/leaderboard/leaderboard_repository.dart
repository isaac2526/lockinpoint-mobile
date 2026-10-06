import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

/// ===========================================================================
/// THE ROUND THAT IS OPEN
///
/// The leaderboard ranks everyone since the beginning of time, which is a
/// scoreboard rather than a competition: a student who joined in March can
/// never catch one who joined in January. A ROUND is a window with a prize,
/// so everybody starts level on the day it opens.
///
/// A null round is a NORMAL answer, not an error. Most of the year there is
/// no competition running, and the screen shows nothing rather than an empty
/// trophy card that looks broken.
/// ===========================================================================
class CompetitionRound {
  const CompetitionRound({
    required this.name,
    required this.description,
    required this.endsAt,
    required this.prizes,
  });

  final String name;
  final String description;
  final DateTime endsAt;
  final List<({int position, String prize})> prizes;

  /// Whole days left, floored — "2 days left" on the last afternoon is a lie
  /// a student will not forgive.
  int get daysLeft {
    final d = endsAt.difference(DateTime.now()).inHours;
    return d <= 0 ? 0 : (d / 24).floor();
  }

  String get closing {
    final h = endsAt.difference(DateTime.now()).inHours;
    if (h <= 0) return 'closing now';
    if (h < 24) return 'closes in $h hours';
    return 'closes in $daysLeft days';
  }

  static CompetitionRound? from(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return CompetitionRound(
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      endsAt: DateTime.tryParse('${j['endsAt']}') ?? DateTime.now(),
      prizes: ((j['prizes'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (p) => (
              position: (p['position'] as num?)?.toInt() ?? 0,
              prize: p['prize'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }
}

class RoundsView {
  const RoundsView({required this.round, required this.winners});
  final CompetitionRound? round;
  final List<({String name, String round, int position, String prize})> winners;
}

final roundsProvider = FutureProvider<RoundsView>((ref) async {
  final res = await ref.read(apiProvider).get('/api/mobile/rounds');
  return RoundsView(
    round: CompetitionRound.from(res['round']),
    winners: ((res['winners'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (w) => (
            name: w['name'] as String? ?? '',
            round: w['round'] as String? ?? '',
            position: (w['position'] as num?)?.toInt() ?? 0,
            prize: w['prize'] as String? ?? '',
          ),
        )
        .toList(),
  );
});
