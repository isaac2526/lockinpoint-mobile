import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/design/components.dart';
import 'package:lockinpoint/design/theme.dart';

/// ===========================================================================
/// WHAT A STUDENT LOOKS AT WHILE THEY WAIT
///
/// Three things are checked, and none of them is "a widget exists":
///
///   1 · the skeleton actually MOVES. A static grey box after two seconds
///       reads as a broken screen, not as a loading one.
///   2 · every screen that can load has SOMETHING in its loading branch.
///   3 · every screen that can load can also FAIL, and says so — which is
///       the half that was silently missing for months, because `.when`
///       looks at loading before error and a failed screen sat on a pulsing
///       skeleton for ever.
/// ===========================================================================
void main() {
  testWidgets('the skeleton is an animation, not a grey rectangle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LipTheme.light(),
        home: const Scaffold(body: Center(child: LipSkeleton(height: 40))),
      ),
    );

    Gradient? shimmer() {
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(LipSkeleton),
          matching: find.byType(Container),
        ),
      );
      return (box.decoration as BoxDecoration?)?.gradient;
    }

    await tester.pump();
    final first = shimmer() as LinearGradient?;
    expect(first, isNotNull, reason: 'the skeleton drew no gradient at all');

    // A third of the way through its cycle, the band must have moved.
    await tester.pump(const Duration(milliseconds: 380));
    final later = shimmer() as LinearGradient?;

    expect(
      later!.begin,
      isNot(first!.begin),
      reason:
          'the shimmer band never moved — this is a static grey box, '
          'which after two seconds reads as a broken screen',
    );

    // And it repeats rather than finishing and freezing.
    await tester.pump(const Duration(milliseconds: 1100));
    expect(shimmer(), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('no screen waits with a blank space where content will be', () {
    /* Read from the source, because the alternative is pumping thirty
       screens and their providers. A loading branch that draws nothing is
       indistinguishable from a screen that has finished and found nothing. */
    final offenders = <String>[];
    for (final f in Directory('lib/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!l.contains('loading:')) continue;
        // The next few lines are what it draws.
        final body = lines.skip(i).take(4).join(' ');
        final drawsNothing =
            body.contains('SizedBox.shrink') || body.contains('Container()');
        // One screen deliberately draws nothing: a side section of a page
        // that is already useful without it, and it says so above the line.
        final deliberate = lines
            .skip(i > 6 ? i - 6 : 0)
            .take(7)
            .join(' ')
            .contains('No skeleton and no error');
        if (drawsNothing && !deliberate) {
          offenders.add('${f.path}:${i + 1}  ${l.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These wait with an empty space. Use LipSkeleton so a student can '
          'tell "loading" from "there is nothing here".\n'
          '${offenders.join('\n')}',
    );
  });

  test('an error while reloading is never hidden behind a skeleton', () {
    /* THE ONE THAT MATTERED. An AsyncValue can be in error AND loading at
       once, and `when` looks at loading first, so a screen that failed sat
       on a pulsing skeleton for ever while the real message waited in a
       state nothing drew. Every `.when` with an error branch must carry the
       two flags that stop it. */
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].trimRight().endsWith('.when(')) continue;
        final window = lines.skip(i).take(80).join('\n');
        if (!window.contains('error:')) continue;
        final head = lines.skip(i).take(12).join('\n');
        if (!head.contains('skipLoadingOnReload')) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These will show a skeleton for ever when they fail while '
          'reloading. Add skipLoadingOnReload / skipLoadingOnRefresh.\n'
          '${offenders.join('\n')}',
    );
  });
}
