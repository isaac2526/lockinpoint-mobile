import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/design/theme.dart';
import 'package:lockinpoint/features/tutor/tutor_screen.dart';

/// ===========================================================================
/// LUMI, THINKING
///
/// A grey loading rectangle sat where her reply was going to be. It is what
/// every list in this app shows while a row loads, and inside a conversation
/// it says the wrong thing entirely: a student cannot tell "she is working on
/// it" from "this screen has broken".
/// ===========================================================================
class _Slow extends Fake implements Api {
  _Slow(this.gate);
  final Completer<void> gate;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async => {'ok': true, 'chats': const []};

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    await gate.future;
    return {'ok': true, 'answer': 'Because momentum is conserved.'};
  }
}

void main() {
  testWidgets('Lumi says she is thinking, and keeps saying it', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_Slow(gate))],
        child: MaterialApp(theme: LipTheme.light(), home: const TutorScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'why is that?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    // Not a grey box. Her name, and what she is doing.
    expect(find.text('Lumi is thinking…'), findsOneWidget);

    /* AND IT CHANGES. A still line after fifteen seconds looks stuck, and a
       student who thinks the screen has frozen taps back. */
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Working through it…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('This one needs a moment. Still going.'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    /* The thinking bubble is gone once the answer lands. The answer itself
       is drawn as rich text, whose spans find.text cannot see — that is what
       lumi_markdown_test.dart is for. */
    expect(find.text('Lumi is thinking…'), findsNothing);
    expect(find.text('Working through it…'), findsNothing);
    expect(find.text('This one needs a moment. Still going.'), findsNothing);
  });
}
