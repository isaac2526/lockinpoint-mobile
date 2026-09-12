import '../../core/json.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import 'vault_repository.dart';

/// ===========================================================================
/// THE FIRST-LAUNCH DOWNLOAD · the text, and only the text.
///
/// TWO TIERS, and the split is the whole point.
///
///   TEXT — every subject's questions, and the institution list. A few
///     megabytes, and the thing that makes this app work in a place with no
///     signal at all. Fetched once, on first launch.
///
///   MATERIALS — PDFs, slides, notes. Tens of megabytes each, and only some
///     are ever wanted. Opt in, per subject and per file. Never automatic:
///     nobody's data bundle should be spent on a PDF they did not ask for.
///
/// IT CAN BE BACKGROUNDED. IT CANNOT BE SKIPPED. Those are different things
/// and the difference matters. A student who needs the app right now can
/// carry on using it while this runs — the bar moves to the top of the screen
/// and stays there. What there is no button for is "no thanks", because an
/// app that lets someone decline its offline data and then fails them on a
/// bus with no network has not respected their choice; it has moved the
/// failure to a worse moment and made it look like a bug.
///
/// EVERY NUMBER IS REAL. The megabytes come from the server's own count of
/// what is there, and are labelled an estimate because they are one. A bar
/// that reaches 90% and stops, or says 4 MB and downloads 40, costs more
/// trust than no bar — a student on a metered bundle is watching that figure
/// decide whether they can afford to finish.
///
/// IT RESUMES. Progress is per subject and each finished pack is already in
/// the vault, so a phone that dies at 60% picks up at 60% rather than
/// starting again — which on a metered bundle is not a small courtesy.
/// ===========================================================================

/// One subject waiting to be fetched.
class VaultPackPlan {
  const VaultPackPlan({
    required this.subjectId,
    required this.subject,
    required this.exam,
    required this.questions,
    required this.bytes,
  });

  final String subjectId;
  final String subject;
  final String exam;
  final int questions;
  final int bytes;
}

enum EssentialPhase { unknown, needed, running, paused, done, failed }

class EssentialState {
  const EssentialState({
    required this.phase,
    this.plans = const [],
    this.doneSubjects = const {},
    this.totalBytes = 0,
    this.doneBytes = 0,
    this.current = '',
    this.problem = '',
  });

  final EssentialPhase phase;
  final List<VaultPackPlan> plans;
  final Set<String> doneSubjects;
  final int totalBytes;
  final int doneBytes;
  final String current;
  final String problem;

  double get fraction =>
      totalBytes <= 0 ? 0 : (doneBytes / totalBytes).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();

  static String mb(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String get sizeLine => '${mb(doneBytes)} of about ${mb(totalBytes)}';

  EssentialState copyWith({
    EssentialPhase? phase,
    List<VaultPackPlan>? plans,
    Set<String>? doneSubjects,
    int? totalBytes,
    int? doneBytes,
    String? current,
    String? problem,
  }) => EssentialState(
    phase: phase ?? this.phase,
    plans: plans ?? this.plans,
    doneSubjects: doneSubjects ?? this.doneSubjects,
    totalBytes: totalBytes ?? this.totalBytes,
    doneBytes: doneBytes ?? this.doneBytes,
    current: current ?? this.current,
    problem: problem ?? this.problem,
  );
}

/// Remembers that the text pack is complete, so the second launch does not
/// ask again. The VAULT is the real record — this is only the fast answer, so
/// a student is not made to wait for a database walk on every cold start.
const _kDoneFlag = 'lip-vault-text-done';

class EssentialDownloader extends Notifier<EssentialState> {
  @override
  EssentialState build() => const EssentialState(phase: EssentialPhase.unknown);

  bool _running = false;

  /// Works out whether anything is needed. Cheap, and safe to call on every
  /// launch: one preference read, and one request only when it might be.
  Future<void> check() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kDoneFlag) == true) {
        state = const EssentialState(phase: EssentialPhase.done);
        return;
      }
    } catch (_) {
      // A phone whose preferences will not open still gets its download.
    }

    try {
      final res = await ref.read(apiProvider).get('/api/mobile/vault');
      final text = (res['text'] as Map?) ?? const {};
      final plans = ((text['packs'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (m) => VaultPackPlan(
              subjectId: asText(m['subjectId']),
              subject: asText(m['subject']),
              exam: asText(m['exam']),
              questions: (asIntOrNull(m['questions'])) ?? 0,
              bytes: (asIntOrNull(m['bytes'])) ?? 0,
            ),
          )
          .where((p) => p.subjectId.isNotEmpty)
          .toList();

      /* An unactivated student cannot fetch packs — /api/mobile/pack gates on
         activation, and finding that out one subject at a time through a
         progress bar would be a cruel way to learn it. */
      if (res['activated'] != true || plans.isEmpty) {
        state = const EssentialState(phase: EssentialPhase.done);
        return;
      }

      /* Already-held subjects are not re-fetched. This is what makes a phone
         that died at 60% pick up at 60%. */
      final held = (await ref.read(vaultDbProvider).allPacks())
          .map((p) => p.subjectId)
          .toSet();
      final remaining = plans
          .where((p) => !held.contains(p.subjectId))
          .toList();

      final total = plans.fold<int>(0, (a, p) => a + p.bytes);
      final already = plans
          .where((p) => held.contains(p.subjectId))
          .fold<int>(0, (a, p) => a + p.bytes);

      if (remaining.isEmpty) {
        await _markDone();
        state = EssentialState(
          phase: EssentialPhase.done,
          totalBytes: total,
          doneBytes: total,
        );
        return;
      }

      state = EssentialState(
        phase: EssentialPhase.needed,
        plans: plans,
        doneSubjects: held,
        totalBytes: total,
        doneBytes: already,
      );
    } on ApiFailure catch (e) {
      /* NOT a failure of the app. A student who opens LockInPoint on a bus
         with no signal must reach their dashboard; the download is offered
         again the next time they open it with a connection. */
      state = EssentialState(phase: EssentialPhase.failed, problem: e.message);
    }
  }

  /// Fetches every remaining pack, one at a time.
  ///
  /// ONE AT A TIME on purpose. Six parallel downloads finish marginally
  /// sooner on a good connection and fall over on a bad one, and a phone with
  /// 1GB of RAM holding six responses at once is a phone that gets killed
  /// mid-download.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    state = state.copyWith(phase: EssentialPhase.running, problem: '');

    final repo = VaultRepository(
      ref.read(apiProvider),
      ref.read(vaultDbProvider),
    );
    final done = {...state.doneSubjects};
    var bytes = state.doneBytes;

    try {
      for (final plan in state.plans) {
        if (done.contains(plan.subjectId)) continue;
        state = state.copyWith(current: plan.subject);
        try {
          await repo.download(plan.subjectId, limit: 500);
          done.add(plan.subjectId);
          bytes += plan.bytes;
          state = state.copyWith(doneSubjects: done, doneBytes: bytes);
        } on ApiFailure catch (e) {
          /* One subject failing does not sink the run: the other forty are
             still worth having, and this one is retried on the next launch
             because it never enters `done`. */
          state = state.copyWith(problem: e.message);
        }
      }

      if (done.length >= state.plans.length) {
        await _markDone();
        state = state.copyWith(
          phase: EssentialPhase.done,
          doneBytes: state.totalBytes,
          current: '',
          problem: '',
        );
      } else {
        // Stopped short. Say so, and leave it resumable.
        state = state.copyWith(phase: EssentialPhase.paused, current: '');
      }
    } finally {
      _running = false;
    }
  }

  /// Lets a student use the app while the rest arrives. NOT a skip: the run
  /// keeps going and the bar stays on screen.
  void moveToBackground() {
    if (state.phase == EssentialPhase.running) {
      state = state.copyWith(phase: EssentialPhase.running);
    }
  }

  Future<void> _markDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDoneFlag, true);
    } catch (_) {
      /* The vault itself is the real record; this flag only saves a database
         walk on the next cold start. Losing it costs one extra check. */
    }
  }
}

final essentialDownloadProvider =
    NotifierProvider<EssentialDownloader, EssentialState>(
      EssentialDownloader.new,
    );
