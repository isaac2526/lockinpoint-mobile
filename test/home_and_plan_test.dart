import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/core/api.dart';
import 'package:lockinpoint/features/content/content_repository.dart';
import 'package:lockinpoint/features/plan/plan_repository.dart';

/// ===========================================================================
/// THREE THINGS THE OWNER NAMED, EACH PROVEN RATHER THAN ASSERTED.
///
///   "Quotes are missing from the app"      — the table, the admin desk and
///                                            the route all existed; nothing
///                                            in the app had ever read them.
///   "WhatsApp channel button in the footer" — and no email clutter.
///   "Allow up to about 15 hours, not 2"     — and drop the requirement to
///                                            have sat a few papers first.
/// ===========================================================================
class _Contacts extends Fake implements Api {
  _Contacts(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path.contains('quote')) {
      return {
        'ok': true,
        'quote': {'text': 'Do the hard thing first.', 'author': 'Tutor Bello'},
      };
    }
    return {'ok': true, 'contacts': rows};
  }
}

void main() {
  test('the app finally reads the quote of the day', () async {
    final container = ProviderContainer(
      overrides: [apiProvider.overrideWithValue(_Contacts(const []))],
    );
    addTearDown(container.dispose);

    final q = await container.read(quoteOfTheDayProvider.future);
    expect(q, isNotNull);
    expect(q!['text'], 'Do the hard thing first.');
    expect(q['author'], 'Tutor Bello');
  });

  test('a WhatsApp contact becomes a wa.me link the backend controls', () {
    // The admin types a phone number; the scheme is the app's business.
    final number = SupportContact.from(const {
      'kind': 'whatsapp',
      'label': 'Our channel',
      'value': '+234 801 234 5678',
    });
    expect(number.uri.toString(), 'https://wa.me/2348012345678');

    // A real channel INVITE is a link, and must survive untouched — a
    // chat.whatsapp.com invite mangled into wa.me/<digits> opens nothing.
    final invite = SupportContact.from(const {
      'kind': 'whatsapp',
      'label': 'Our channel',
      'value': 'https://whatsapp.com/channel/ABC123',
    });
    expect(invite.uri.toString(), 'https://whatsapp.com/channel/ABC123');
  });

  test('the plan offers a real day, not a two-hour ceiling', () {
    // Read from the screen's own source, so the test cannot pass by agreeing
    // with a copy of the list typed into the test.
    final src = File('lib/features/plan/plan_screen.dart').readAsStringSync();
    final chips = RegExp(r'for \(final m in const \[([^\]]*)\]')
        .firstMatch(src)!
        .group(1)!
        .split(',')
        .map((x) => int.tryParse(x.trim()))
        .whereType<int>()
        .toList();

    expect(chips, isNotEmpty);
    expect(
      chips.reduce((a, b) => a > b ? a : b),
      900,
      reason: 'fifteen hours, which is the day of somebody two weeks out',
    );
    expect(chips, contains(15), reason: 'a short honest day still fits');
  });

  test('building a plan carries the subjects, so day one is not refused', () {
    final body = planBuildBody(
      targetDate: DateTime(2026, 5, 1, 23, 30),
      minutesPerDay: 900,
      subjectIds: const ['s1', 's2'],
    );
    expect(body['subjectIds'], ['s1', 's2']);
    expect(body['minutesPerDay'], 900);
    // A day, not a moment: 23:30 in Lagos must not become the 2nd.
    expect(body['targetDate'], '2026-05-01');

    // No subjects is not an error — a student with a history needs none.
    expect(
      planBuildBody(targetDate: DateTime(2026, 5, 1), minutesPerDay: 30),
      isNot(contains('subjectIds')),
    );

    // And the clamp holds on both ends.
    expect(
      planBuildBody(
        targetDate: DateTime(2026, 5, 1),
        minutesPerDay: 5000,
      )['minutesPerDay'],
      900,
    );
    expect(
      planBuildBody(
        targetDate: DateTime(2026, 5, 1),
        minutesPerDay: 0,
      )['minutesPerDay'],
      10,
    );
  });

  test('ticking one day off never rebuilds the fortnight', () {
    // `op` decides which of the route's two jobs runs. Left off, the request
    // does not fail — it rebuilds everything under the student.
    expect(planTickBody('i1', done: true)['op'], 'done');
  });
}
