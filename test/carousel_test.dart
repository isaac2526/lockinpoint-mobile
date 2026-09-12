import 'package:flutter_test/flutter_test.dart';
import 'package:lockinpoint/features/home/home_carousel.dart';

/// ===========================================================================
/// A SLIDE THAT DID NOTHING WHEN YOU TAPPED IT
///
/// The rule was `if (uri.hasScheme) launchUrl(...)` and nothing else. So a
/// slide whose target was anything an admin would naturally type — the name
/// of a room, or a domain with the https:// left off — did NOTHING AT ALL
/// when tapped. No navigation, no browser, no message. A dead card that looks
/// exactly like a live one, which is the hardest kind of bug for an owner to
/// report: "the carousel does not work" is all there is to say about it.
/// ===========================================================================
void main() {
  test('a room name opens the room, here in the app', () {
    for (final key in ['practice', 'vault', 'theory', 'tutor', 'games']) {
      final t = resolveSlideTarget(key);
      expect(t.roomKey, key, reason: '"$key" should open the $key room');
      expect(t.url, isNull, reason: '"$key" must not open a browser');
    }
  });

  test('a room name survives a leading slash and capitals', () {
    expect(resolveSlideTarget('/practice').roomKey, 'practice');
    expect(resolveSlideTarget('Practice').roomKey, 'practice');
    expect(resolveSlideTarget('  /Vault  ').roomKey, 'vault');
  });

  test('a domain without https:// is still a link', () {
    // Nobody types the scheme. This used to be a dead card.
    expect(
      resolveSlideTarget('lockinpoint.com/careers').url.toString(),
      'https://lockinpoint.com/careers',
    );
    expect(resolveSlideTarget('wa.me/2348012345678').url?.host, 'wa.me');
  });

  test('a full link is left exactly as written', () {
    final u = resolveSlideTarget('https://wa.me/2348012345678?text=hi').url!;
    expect(u.toString(), 'https://wa.me/2348012345678?text=hi');
  });

  test('a bad row opens nothing, and is not an error', () {
    /* All of these parse as a Uri perfectly well and lead nowhere. A bad row
       must cost that row, not the home screen. */
    for (final bad in [
      '',
      '   ',
      'https://',
      '://',
      'not a room',
      '/nowhere',
      'practise', // the British spelling is not a feature key
    ]) {
      expect(
        resolveSlideTarget(bad).isNothing,
        isTrue,
        reason: '"$bad" should resolve to nothing',
      );
    }
  });
}
