import 'package:flutter/material.dart';

/// ===========================================================================
/// WHAT A STUDENT SEES IF A SCREEN FAILS TO BUILD AT ALL
///
/// Flutter's default answer to a build-time exception is the grey-on-red box
/// with the exception text printed inside it. In a release build it is a bare
/// grey rectangle — arguably worse, because it says nothing whatsoever.
///
/// Neither is acceptable in front of a student who is revising. This is the
/// last line of defence behind ErrorWidget.builder: it cannot recover the
/// screen, but it can tell the truth in one sentence and say what to do.
///
/// DELIBERATELY PLAIN. No colours read from a theme that may itself be what
/// failed, no provider lookups, no network, no images. It has to be able to
/// render when everything around it could not — so every value here is a
/// literal.
/// ===========================================================================
class SomethingBroke extends StatelessWidget {
  const SomethingBroke({super.key});

  @override
  Widget build(BuildContext context) => const Material(
    color: Color(0xFFEDF0F7),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 34, color: Color(0xFF6C7690)),
            SizedBox(height: 12),
            Text(
              'This part did not load',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0B1020),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Go back and open it again. If it keeps happening, tell Tutor '
              'Bello which screen it was.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF414B63)),
            ),
          ],
        ),
      ),
    ),
  );
}
