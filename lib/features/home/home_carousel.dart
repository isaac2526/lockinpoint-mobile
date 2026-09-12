import '../../core/json.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../content/content_repository.dart';
import 'feature_grid.dart' show destinationForFeatureKey;

/// ===========================================================================
/// THE PROMO STRIP
///
/// Whatever the team wants a student to see first: a results announcement, a
/// campaign, a deadline. Every slide is a row in `carousel_slides`, so it
/// changes without a release.
///
/// IT SHIPS EMPTY, AND THAT IS CORRECT. With no slides configured there is no
/// strip at all — a carousel of invented content would be worse than nothing,
/// and a placeholder that says "your promo here" is worse still.
///
/// The next card PEEKS past the right edge, which is the whole reason anyone
/// discovers a horizontal list on a phone.
/// ===========================================================================
class HomeCarousel extends ConsumerWidget {
  const HomeCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slides = ref.watch(carouselProvider).value ?? const [];
    if (slides.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Builder(
        builder: (context) {
          /* SQUARE. It was a fixed 150 high against a card roughly 330 wide —
             better than 2:1 — so every square picture an admin uploaded was
             cropped to a letterbox and the top and bottom of it were simply
             not on the phone. A poster with the date at the bottom lost the
             date. The card now matches the shape of the images being put
             into it. */
          final width = MediaQuery.sizeOf(context).width - (Gap.lg * 2) - 34;
          return SizedBox(
            height: width,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: slides.length,
              separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
              // One card, plus a sliver of the next — which is the whole
              // reason anyone discovers a horizontal list on a phone.
              itemBuilder: (context, i) =>
                  _Slide(slide: slides[i], width: width),
            ),
          );
        },
      ),
    );
  }
}

/// ===========================================================================
/// WHERE A SLIDE GOES
///
/// The old rule was `if (uri.hasScheme) launchUrl(...)` and nothing else, so
/// a slide whose target was anything an admin would naturally type did
/// NOTHING AT ALL when tapped — no navigation, no browser, no message. A dead
/// card that looks exactly like a live one.
///
/// Three things an admin actually types, all of them now work:
///
///   "practice", "theory", "vault"     a room in this app. Opens it here,
///                                     which is what a promo for a feature
///                                     should do.
///   "lockinpoint.com/careers"         a web address with the https:// left
///                                     off, because nobody types that.
///   "https://wa.me/234…"              a full link. Opens outside, as before.
///
/// And a target that matches none of them opens nothing rather than throwing
/// — a bad row must not crash the home screen.
/// ===========================================================================
/// What a slide's target actually means. Pure, so the decision can be tested
/// without a navigator, a browser or a network — and the decision is the part
/// that was wrong.
class SlideTarget {
  const SlideTarget({this.roomKey, this.url});

  /// A room in this app, as [destinationForFeatureKey] names them.
  final String? roomKey;

  /// A web address to open outside the app.
  final Uri? url;

  bool get isNothing => roomKey == null && url == null;
}

SlideTarget resolveSlideTarget(String target) {
  final t = target.trim();
  if (t.isEmpty) return const SlideTarget();

  // A room in the app, written with or without a leading slash.
  final key = (t.startsWith('/') ? t.substring(1) : t).toLowerCase();
  if (destinationForFeatureKey(key) != null) return SlideTarget(roomKey: key);

  final uri = Uri.tryParse(t.contains('://') ? t : 'https://$t');
  /* A REAL HOST IS REQUIRED. "https://" on its own parses perfectly well and
     opens nothing; so does "https://practice" for a room that does not
     exist. A dot in the host is the cheapest honest test for "this is a web
     address and not a word somebody typed". */
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
    return const SlideTarget();
  }
  return SlideTarget(url: uri);
}

Future<void> openSlideTarget(BuildContext context, String target) async {
  final where = resolveSlideTarget(target);

  final key = where.roomKey;
  if (key != null) {
    final room = destinationForFeatureKey(key);
    if (room != null) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => room));
    }
    return;
  }

  final url = where.url;
  if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide, required this.width});
  final Map<String, dynamic> slide;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final image = (asText(slide['image_url'])).trim();
    final target = (asText(slide['target'])).trim();
    final subtext = (asText(slide['subtext'])).trim();

    return SizedBox(
      width: width,
      child: GlassSurface(
        tier: GlassTier.raised,
        padding: EdgeInsets.zero,
        onTap: target.isEmpty ? null : () => openSlideTarget(context, target),
        semanticLabel: '${slide['headline'] ?? ''}. $subtext',
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                // A slide whose image is still arriving shows its colour, not
                // a spinner: the text below is the point anyway.
                placeholder: (_, _) => ColoredBox(color: c.hues.blue.tint),
                errorWidget: (_, _, _) => ColoredBox(color: c.hues.blue.tint),
              ),
            // Enough scrim for white text to survive any photograph.
            if (image.isNotEmpty)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                    stops: [0.35, 1],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asText(slide['headline']),
                    style: LipType.subheading.copyWith(
                      color: image.isEmpty ? c.text1 : Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtext.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtext,
                      style: LipType.small.copyWith(
                        color: image.isEmpty ? c.text2 : Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
