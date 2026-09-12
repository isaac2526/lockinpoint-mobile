import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ===========================================================================
/// THE CAST THE OWNER READ ON HIS OWN PHONE
///
///     Type int is not a subtype of type string in type cast
///
/// One screen showed it; three hundred and thirty-two casts could have. They
/// are all gone now, replaced by the total coercions in lib/core/json.dart.
///
/// This test is the only thing standing between "gone" and "gone until the
/// next feature". It reads the source of the app itself and fails the build
/// the moment somebody writes a hard cast on JSON again — including me, in
/// six months, in a hurry.
/// ===========================================================================
void main() {
  test('no screen in this app casts JSON with `as`', () {
    // These are the casts that crash on a value the server changed. A cast to
    // a widget, a controller or a sealed type is a different thing entirely
    // and is left alone.
    final risky = RegExp(
      r'\bas (?:String|int|num|double|bool|List|Map)\b',
    );

    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // The coercion helpers themselves are where the type tests live.
      if (f.path.endsWith('core/json.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (risky.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use the helpers in lib/core/json.dart instead — asText, asInt, '
          'asDouble, asBool, asMap, asMapList, asList, asTextList, asTime. '
          'A cast is a bet that the server will never change.\n'
          '${offenders.join('\n')}',
    );
  });
}
