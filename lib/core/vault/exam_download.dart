import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../json.dart';
import 'vault_repository.dart';

/// ===========================================================================
/// DOWNLOADING AN EXAMINATION
///
/// The vault could be FILLED, subject by subject, and that was the whole of
/// it. A student sitting WAEC had to find and tap Download on each of their
/// nine subjects, one at a time, with no idea how much of their bundle the
/// nine would cost until they had spent it.
///
/// What this adds is the thing a student actually wants: "give me WAEC".
/// One button per examination, and while it runs, four honest numbers —
/// per cent, megabytes so far, megabytes in total, and the name of the
/// subject being fetched right now.
///
/// PAUSE IS BETWEEN SUBJECTS, AND THAT IS SAID OUT LOUD.
/// One subject's pack is one request. Stopping in the middle of it would
/// throw away what had already arrived, so Pause finishes the subject in
/// flight and stops before the next one. On a nine-subject exam that is a
/// wait of seconds, and it means a pause never costs a student data they
/// have already paid for.
///
/// IT RESUMES ACROSS A RESTART, and not by remembering a byte offset — by
/// asking the vault what it already holds. A pack is written in one
/// transaction, so a pack is either fully on the phone or not there at all;
/// there is no such thing as a half-written subject to recover from. A phone
/// killed at subject six comes back holding five and fetches four.
///
/// AND IT KNOWS WHEN THERE IS MORE. The manifest says how many questions a
/// subject has; the vault knows how many it holds. The difference is "12 new
/// questions", which is what an update button should say instead of just
/// "Update".
/// ===========================================================================

/// One subject in the queue.
class VaultSubjectPlan {
  const VaultSubjectPlan({
    required this.subjectId,
    required this.subject,
    required this.examSlug,
    required this.examName,
    required this.questions,
    required this.bytes,
    required this.held,
  });

  final String subjectId;
  final String subject;
  final String examSlug;
  final String examName;

  /// What the server has.
  final int questions;
  final int bytes;

  /// What this phone has. Zero means never downloaded.
  final int held;

  bool get isHeld => held > 0;

  /// Questions on the server that are not on this phone yet. Negative would
  /// mean the bank shrank — that is not an update, so it floors at zero.
  int get behind => questions - held < 0 ? 0 : questions - held;

  bool get needsUpdate => isHeld && behind > 0;
  bool get needsFirstDownload => !isHeld;
}

/// One examination, and everything under it.
class ExamPlan {
  const ExamPlan({
    required this.slug,
    required this.name,
    required this.subjects,
  });

  final String slug;
  final String name;
  final List<VaultSubjectPlan> subjects;

  int get questions => subjects.fold(0, (a, s) => a + s.questions);
  int get bytes => subjects.fold(0, (a, s) => a + s.bytes);

  int get heldSubjects => subjects.where((s) => s.isHeld).length;
  int get heldBytes =>
      subjects.where((s) => s.isHeld).fold(0, (a, s) => a + s.bytes);

  /// New questions across the whole examination — what the button says.
  int get behind => subjects.fold(0, (a, s) => a + s.behind);

  bool get complete => subjects.isNotEmpty && subjects.every((s) => s.isHeld);
  bool get anyUpdate => subjects.any((s) => s.needsUpdate);

  List<VaultSubjectPlan> get outstanding =>
      subjects.where((s) => s.needsFirstDownload || s.needsUpdate).toList();
}

enum VaultRunPhase { idle, running, paused, done, failed }

class VaultDownloadState {
  const VaultDownloadState({
    this.loading = false,
    this.exams = const [],
    this.phase = VaultRunPhase.idle,
    this.runningExam = '',
    this.current = '',
    this.doneBytes = 0,
    this.totalBytes = 0,
    this.doneSubjects = 0,
    this.totalSubjects = 0,
    this.problem = '',
    this.listProblem = '',
  });

  final bool loading;
  final List<ExamPlan> exams;

  final VaultRunPhase phase;

  /// The examination a run belongs to. Empty when nothing is running — and
  /// still set while paused, which is what makes Resume possible.
  final String runningExam;

  /// The subject being fetched right now, for the line under the bar.
  final String current;

  final int doneBytes;
  final int totalBytes;
  final int doneSubjects;
  final int totalSubjects;

  /// A failure inside a run. Never a raw exception.
  final String problem;

  /// A failure reading the list itself, which is a different thing — the
  /// difference between "your download broke" and "we could not even ask".
  final String listProblem;

  bool get isBusy =>
      phase == VaultRunPhase.running || phase == VaultRunPhase.paused;

  double get fraction =>
      totalBytes <= 0 ? 0 : (doneBytes / totalBytes).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();

  ExamPlan? examFor(String slug) {
    for (final e in exams) {
      if (e.slug == slug) return e;
    }
    return null;
  }

  /// "12.4 MB of about 31.8 MB". "About", because the server's byte figure
  /// is an estimate and says so; a number presented as exact and then 30%
  /// out costs more trust than one presented as an estimate.
  String get sizeLine => '${mb(doneBytes)} of about ${mb(totalBytes)}';

  static String mb(int bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  VaultDownloadState copyWith({
    bool? loading,
    List<ExamPlan>? exams,
    VaultRunPhase? phase,
    String? runningExam,
    String? current,
    int? doneBytes,
    int? totalBytes,
    int? doneSubjects,
    int? totalSubjects,
    String? problem,
    String? listProblem,
  }) => VaultDownloadState(
    loading: loading ?? this.loading,
    exams: exams ?? this.exams,
    phase: phase ?? this.phase,
    runningExam: runningExam ?? this.runningExam,
    current: current ?? this.current,
    doneBytes: doneBytes ?? this.doneBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    doneSubjects: doneSubjects ?? this.doneSubjects,
    totalSubjects: totalSubjects ?? this.totalSubjects,
    problem: problem ?? this.problem,
    listProblem: listProblem ?? this.listProblem,
  );
}

/// Which examination a run was on when the app last closed. Only so the
/// screen can OFFER to carry on; the vault itself is the record of what is
/// actually held, and this is never trusted for that.
const _kRunKey = 'lip-vault-exam-run';

class VaultDownloader extends Notifier<VaultDownloadState> {
  @override
  VaultDownloadState build() => const VaultDownloadState();

  bool _stopRequested = false;
  bool _running = false;

  /// Reads the manifest and the vault and works out, per examination, what is
  /// held, what is missing and what is out of date.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, listProblem: '');
    try {
      final res = await ref.read(apiProvider).get('/api/mobile/vault');
      final text = asMap(res['text']);

      /* WHAT THE PHONE ALREADY HOLDS, by subject, with its count — so
         "behind" is a real subtraction and not a guess. */
      final held = <String, int>{};
      for (final p in await ref.read(vaultDbProvider).allPacks()) {
        held[p.subjectId] = p.count;
      }

      final byExam = <String, List<VaultSubjectPlan>>{};
      final names = <String, String>{};
      for (final m in asMapList(text['packs'])) {
        final slug = asText(m['examSlug']);
        final id = asText(m['subjectId']);
        if (slug.isEmpty || id.isEmpty) continue;
        names[slug] = asText(m['exam'], slug.toUpperCase());
        (byExam[slug] ??= []).add(
          VaultSubjectPlan(
            subjectId: id,
            subject: asText(m['subject']),
            examSlug: slug,
            examName: names[slug]!,
            questions: asInt(m['questions']),
            bytes: asInt(m['bytes']),
            held: held[id] ?? 0,
          ),
        );
      }

      final exams =
          byExam.entries
              .map(
                (e) => ExamPlan(
                  slug: e.key,
                  name: names[e.key] ?? e.key.toUpperCase(),
                  subjects: e.value
                    ..sort((a, b) => a.subject.compareTo(b.subject)),
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      state = state.copyWith(loading: false, exams: exams);
    } catch (e, st) {
      /* CATCHES EVERYTHING, not just ApiFailure.
         It caught only ApiFailure, and anything else — a shape the manifest
         had never returned before, a database that would not open, a plain
         TypeError — left `loading` true forever. The student was then looking
         at a loading skeleton that would never resolve, on a screen whose
         whole job is to tell them what they can use without a network. A
         spinner that never stops is the worst failure state there is,
         because it does not even look like one. */
      debugPrint('[lockinpoint] vault manifest: ${describeFailure(e, st)}');
      state = state.copyWith(
        loading: false,
        listProblem: humanError(e, doing: 'load the list of examinations'),
      );
    }
  }

  /// Which examination, if any, was mid-run when the app last closed.
  Future<String> interruptedRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kRunKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _remember(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (slug.isEmpty) {
        await prefs.remove(_kRunKey);
      } else {
        await prefs.setString(_kRunKey, slug);
      }
    } catch (_) {
      // The vault is the real record. Losing this costs one offered resume.
    }
  }

  /// Fetch everything outstanding under one examination.
  ///
  /// ONE SUBJECT AT A TIME, on purpose. Six parallel downloads finish
  /// marginally sooner on a good connection, fall over on a bad one, and on a
  /// phone with 1GB of RAM holding six responses at once they get the app
  /// killed mid-download.
  Future<void> start(String examSlug) async {
    if (_running) return;
    final plan = state.examFor(examSlug);
    if (plan == null) return;

    final todo = plan.outstanding;
    if (todo.isEmpty) {
      state = state.copyWith(phase: VaultRunPhase.done, runningExam: '');
      return;
    }

    _running = true;
    _stopRequested = false;
    await _remember(examSlug);

    state = state.copyWith(
      phase: VaultRunPhase.running,
      runningExam: examSlug,
      problem: '',
      current: '',
      doneBytes: 0,
      totalBytes: todo.fold<int>(0, (a, s) => a + s.bytes),
      doneSubjects: 0,
      totalSubjects: todo.length,
    );

    final repo = VaultRepository(
      ref.read(apiProvider),
      ref.read(vaultDbProvider),
    );

    var bytes = 0;
    var done = 0;
    var lastProblem = '';

    try {
      for (final sub in todo) {
        /* PAUSE IS CHECKED HERE, between subjects, so nothing already
           fetched is thrown away. */
        if (_stopRequested) {
          state = state.copyWith(phase: VaultRunPhase.paused, current: '');
          return;
        }

        state = state.copyWith(current: sub.subject);
        try {
          await repo.download(sub.subjectId, limit: 500);
          done += 1;
          bytes += sub.bytes;
          state = state.copyWith(doneSubjects: done, doneBytes: bytes);
        } catch (e, st) {
          /* One subject failing does not sink the run — the other eight are
             still worth having — but it is NOT silent, and the run ends
             saying so rather than reporting a success it did not have.

             CATCHES EVERYTHING for the same reason refresh() does: a
             malformed pack that threw a TypeError used to escape this loop
             and leave the bar frozen at whatever per cent it had reached,
             running forever, with no Retry because nothing had failed. */
          lastProblem = humanError(e, doing: 'download ${sub.subject}');
          debugPrint(
            '[lockinpoint] pack ${sub.subjectId}: '
            '${describeFailure(e, st)}',
          );
        }
      }

      await _remember('');
      if (lastProblem.isEmpty) {
        state = state.copyWith(
          phase: VaultRunPhase.done,
          current: '',
          problem: '',
          runningExam: '',
        );
      } else {
        // Retry is offered on exactly this: some subjects are missing and we
        // know why.
        state = state.copyWith(
          phase: VaultRunPhase.failed,
          current: '',
          problem: lastProblem,
        );
      }
    } finally {
      _running = false;
      // The held counts have changed; the buttons must change with them.
      await refresh();
      ref.invalidate(vaultPacksProvider);
      ref.invalidate(hasVaultProvider);
    }
  }

  /// Stops before the next subject. The one in flight is allowed to land.
  void pause() {
    if (state.phase != VaultRunPhase.running) return;
    _stopRequested = true;
  }

  /// Carries on with whatever is still outstanding. Because "outstanding" is
  /// recomputed from the vault, this is also what a resume after a restart
  /// does — there is no separate path to get wrong.
  Future<void> resume() async {
    final slug = state.runningExam;
    if (slug.isEmpty) return;
    await start(slug);
  }

  /// After a failure. Identical to resume, named for what the student is
  /// doing, because "Resume" on a red bar reads like a lie.
  Future<void> retry() => resume();

  /// Throws the whole examination away. The manifest is reread so the button
  /// goes back to "Download" rather than staying on "Downloaded".
  Future<void> removeExam(String examSlug) async {
    final plan = state.examFor(examSlug);
    if (plan == null) return;
    final repo = VaultRepository(
      ref.read(apiProvider),
      ref.read(vaultDbProvider),
    );
    for (final sub in plan.subjects.where((s) => s.isHeld)) {
      await repo.remove(sub.subjectId);
    }
    await refresh();
    ref.invalidate(vaultPacksProvider);
    ref.invalidate(hasVaultProvider);
  }
}

final vaultDownloadProvider =
    NotifierProvider<VaultDownloader, VaultDownloadState>(VaultDownloader.new);
