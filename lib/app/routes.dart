import 'package:flutter/material.dart';

import '../core/open.dart';
import '../features/activation/activation_screen.dart';
import '../features/career/career_screen.dart';
import '../features/classroom/classroom_screen.dart';
import '../features/games/climb_screen.dart';
import '../features/games/games_screen.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/practice/practice_flow_screen.dart';
import '../features/progress/analysis_screen.dart';
import '../features/progress/results_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/search/search_screen.dart';
import '../features/tutor/tutor_screen.dart';
import '../features/vault/vault_screen.dart';

/// ===========================================================================
/// WHERE AN ADMIN'S TARGET STRING ACTUALLY GOES
///
/// Notices and carousel slides carry a target typed into the admin panel:
/// `/games`, `/practice`, a full URL, a bare host. The app used to show a
/// toast SAYING "Opening /games" — narrating the action instead of doing it.
/// One table, used by every surface that holds an admin target, so a route
/// that works from a notice cannot be dead on a slide.
///
/// An unknown route says so instead of doing nothing: an admin who typos
/// `/gmaes` should hear about it from the first student, not never.
/// ===========================================================================
Future<void> openAppTarget(BuildContext context, String target) async {
  final (kind, uri) = classifyTarget(target);
  switch (kind) {
    case TargetKind.none:
      return;
    case TargetKind.url:
      return openOutside(context, uri!);
    case TargetKind.route:
      final path = target.trim().toLowerCase();
      // First segment decides the room; anything after it is ignored rather
      // than guessed at.
      final head = path.split('/').where((s) => s.isNotEmpty).firstOrNull;
      final Widget? screen = switch (head) {
        'practice' || 'exams' || 'cbt' => const PracticeFlowScreen(),
        'games' || 'arena' => const GamesScreen(),
        'climb' || 'challenge' => const ClimbSetupScreen(),
        'leaderboard' || 'ranking' => const LeaderboardScreen(),
        'activate' || 'activation' || 'pricing' => const ActivationScreen(),
        'classroom' || 'materials' || 'notes' => const ClassroomScreen(),
        'career' || 'institutions' || 'aggregate' => const CareerScreen(),
        'saved' || 'bookmarks' => const SavedScreen(),
        'vault' || 'offline' => const VaultScreen(),
        'plan' || 'study-plan' => const PlanScreen(),
        'search' => const SearchScreen(),
        'tutor' || 'lumi' || 'ai' => const TutorScreen(),
        'history' || 'results' => const ResultsScreen(),
        'analysis' => const AnalysisScreen(),
        _ => null,
      };
      if (screen != null) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));
        return;
      }
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('This build has no screen at $target yet.')),
        );
  }
}
