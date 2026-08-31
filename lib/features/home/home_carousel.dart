import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../content/content_repository.dart';

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
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: slides.length,
          separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
          itemBuilder: (context, i) => _Slide(
            slide: slides[i],
            // One card, plus a sliver of the next.
            width: MediaQuery.sizeOf(context).width - (Gap.lg * 2) - 34,
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide, required this.width});
  final Map<String, dynamic> slide;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final image = (slide['image_url'] as String? ?? '').trim();
    final target = (slide['target'] as String? ?? '').trim();
    final subtext = (slide['subtext'] as String? ?? '').trim();

    return SizedBox(
      width: width,
      child: GlassSurface(
        tier: GlassTier.raised,
        padding: EdgeInsets.zero,
        onTap: target.isEmpty
            ? null
            : () {
                final uri = Uri.tryParse(target);
                if (uri != null && uri.hasScheme) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
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
                    slide['headline'] as String? ?? '',
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
