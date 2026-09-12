import '../../core/json.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';

/// ===========================================================================
/// CONTENT THE TEAM OWNS, READ BY THE APP
///
/// Support numbers, the quote of the day, the activation price, the promo
/// carousel, the home tiles and their badges — none of it is written in Dart,
/// because none of it should need a release to change. Isaac edits a row in
/// the admin panel and the next launch shows it.
///
/// EVERY ONE OF THESE CACHES. A support number is the same today as it was an
/// hour ago, and a student opening the app on a train should still be able to
/// find the WhatsApp line. So each read serves the last known answer instantly
/// and refreshes behind it; only a first-ever launch with no network shows
/// nothing at all.
/// ===========================================================================

class _Cached {
  const _Cached(this.key, this.path);
  final String key;
  final String path;
}

const _contacts = _Cached('lip.contacts', '/api/public/contacts?on=app');
const _quote = _Cached('lip.quote', '/api/public/quote');
const _price = _Cached('lip.price', '/api/public/price');
const _carousel = _Cached('lip.carousel', '/api/public/carousel');
const _tiles = _Cached('lip.tiles', '/api/public/tiles?on=app');

Future<Map<String, dynamic>> _read(Ref ref, _Cached what) async {
  final prefs = await SharedPreferences.getInstance();

  Future<Map<String, dynamic>?> fresh() async {
    try {
      final res = await ref.read(apiProvider).get(what.path);
      if (res['ok'] == true) {
        await prefs.setString(what.key, jsonEncode(res));
        return res;
      }
    } on ApiFailure {
      // The cache below is the answer. A support number does not expire.
    }
    return null;
  }

  final cached = prefs.getString(what.key);
  if (cached != null) {
    // Serve what we have, then quietly bring it up to date.
    Future.microtask(fresh);
    try {
      return jsonDecode(cached) as Map<String, dynamic>;
    } catch (_) {
      // A corrupt cache is thrown away, not fought with.
    }
  }
  return await fresh() ?? const {};
}

/// One support contact: a number, an address or a link, with its label.
class SupportContact {
  const SupportContact({
    required this.kind,
    required this.label,
    required this.value,
    this.description = '',
  });

  final String kind;
  final String label;
  final String value;
  final String description;

  static SupportContact from(Map<String, dynamic> j) => SupportContact(
    kind: asText(j['kind'], 'link'),
    label: asText(j['label']),
    value: asText(j['value']),
    description: asText(j['description']),
  );

  /// What tapping this should open. The backend stores the human-readable
  /// value; the scheme is decided here so a number stays readable in Admin.
  Uri get uri {
    final v = value.trim();
    switch (kind) {
      case 'phone':
        return Uri.parse('tel:${v.replaceAll(RegExp(r'[^\d+]'), '')}');
      case 'whatsapp':
        final digits = v.replaceAll(RegExp(r'[^\d]'), '');
        return Uri.parse(v.startsWith('http') ? v : 'https://wa.me/$digits');
      case 'email':
        return Uri.parse(v.startsWith('mailto:') ? v : 'mailto:$v');
      default:
        return Uri.parse(v);
    }
  }
}

/// Every support contact, grouped by channel — because a channel is a LIST.
/// The team runs more than one phone line, and the app shows all of them.
final supportContactsProvider = FutureProvider<List<SupportContact>>((
  ref,
) async {
  final j = await _read(ref, _contacts);
  final list = (j['contacts'] as List?) ?? const [];
  return list
      .whereType<Map>()
      .map((m) => SupportContact.from(m.cast<String, dynamic>()))
      .toList();
});

/// The quote of the day, from the `quotes` table an admin actually edits.
final quoteOfTheDayProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final j = await _read(ref, _quote);
  final q = j['quote'];
  return q is Map ? q.cast<String, dynamic>() : null;
});

/// WHAT ACTIVATION COSTS, decided by the server for this student's country.
/// The figure is never written in Dart: change it in Admin and the next
/// launch charges and displays the new one, with no APK.
final activationPriceProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  return await _read(ref, _price);
});

/// The promo strip. Empty until the team puts something in it.
final carouselProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final j = await _read(ref, _carousel);
  return ((j['slides'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => m.cast<String, dynamic>())
      .toList();
});

/// Admin overrides for the home grid: titles, colours, order and the NEW
/// badge. Empty means "use the app's own grid", so the home works before
/// anyone has configured a thing.
final featureTilesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final j = await _read(ref, _tiles);
  return ((j['tiles'] as List?) ?? const [])
      .whereType<Map>()
      .map((m) => m.cast<String, dynamic>())
      .toList();
});
