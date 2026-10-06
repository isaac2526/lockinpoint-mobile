import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ===========================================================================
/// OPENING THINGS, HONESTLY
///
/// Half the "dead buttons" in the installed build traced to one habit:
/// calling launchUrl and ignoring what it returns. On Android with a browser
/// that is usually fine; on a desktop without xdg-open, on web popup-blocked
/// tabs, on a phone with no email app, launchUrl returns FALSE — no throw,
/// no browser, no anything. The student taps, the button animates, nothing
/// happens, and the app has just taught them not to trust it.
///
/// Every outward tap now goes through here: the result is checked, and a
/// failure SAYS SO, showing the address so the student can reach it by hand.
/// A button that cannot do its job must say so out loud — silence is the one
/// unacceptable outcome.
/// ===========================================================================
/// The launcher itself, swappable so the "it must SAY so" rule can be
/// tested. Production never passes this; a test passes one that refuses.
typedef UrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> openOutside(
  BuildContext context,
  Uri uri, {
  UrlLauncher launcher = _defaultLauncher,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    ok = await launcher(uri);
  } catch (_) {
    ok = false;
  }
  if (ok) return;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Could not open $uri on this device.'),
        // Long enough to read an address; a copy affordance would be better
        // still, but a visible truth beats a silent lie today.
        duration: const Duration(seconds: 5),
      ),
    );
}

/// Where an admin-configured target actually goes.
///
/// Notices and carousel slides carry a `target` string typed into the admin
/// panel: sometimes a full URL, sometimes an app route like `/games`, and
/// sometimes a bare host. The app used to show a toast SAYING "Opening
/// /games" and then not open it — a button that narrates the action instead
/// of performing it. The route table lives with the caller (it knows its
/// screens); this decides which KIND of target it is holding.
enum TargetKind { route, url, none }

(TargetKind, Uri?) classifyTarget(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return (TargetKind.none, null);
  if (t.startsWith('/')) return (TargetKind.route, null);
  final hasScheme = t.contains('://');
  /* A BARE WORD IS NOT A HOST. Without this, an admin's typo ("gmaes")
     becomes https://gmaes and the app opens a browser at a domain that does
     not exist — worse than saying the target is unusable. A scheme-less
     address still works when it looks like one: www.lockinpoint.com/x. */
  if (!hasScheme && !t.contains('.')) return (TargetKind.none, null);
  final uri = Uri.tryParse(hasScheme ? t : 'https://$t');
  if (uri == null || uri.host.isEmpty) return (TargetKind.none, null);
  return (TargetKind.url, uri);
}
