import '../../core/json.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../home/dashboard_screen.dart';
import '../leaderboard/leaderboard_screen.dart';

/// ===========================================================================
/// WHERE YOU SIT ON THE BOARD
///
/// The leaderboard ranks by state and by school. Neither number could ever
/// reach a phone, because the app had no way to SET either one: the profile
/// screen printed "State ·" for a student with no state and offered nothing
/// to do about it, and /api/profile/complete — the route written precisely
/// for this — had never been called from here.
///
/// The list of states is the SERVER'S, fetched per student for their own
/// country. Compiling Nigeria's thirty-seven divisions into the app would be
/// a third copy of a list that already exists twice, and a student in Ghana
/// would be offered Nigerian states. The route also refuses a value that is
/// not one of its own, so a stray spelling cannot become a phantom region on
/// the board.
/// ===========================================================================

/// What this student still owes, and the choices they may make.
class PlaceAsk {
  const PlaceAsk({
    required this.complete,
    required this.missing,
    required this.countryCode,
    required this.states,
  });

  final bool complete;
  final List<String> missing;
  final String countryCode;

  /// Empty for a country that has no state boards — a family in Toronto is
  /// never asked for a Nigerian state.
  final List<String> states;

  bool get needsState => missing.contains('state');

  static const unknown = PlaceAsk(
    complete: true,
    missing: [],
    countryCode: '',
    states: [],
  );

  static PlaceAsk fromJson(Map<String, dynamic> j) => PlaceAsk(
    complete: j['complete'] != false,
    missing: ((j['missing'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    countryCode: asText(j['country_code']),
    states: ((j['states'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

final placeAskProvider = FutureProvider<PlaceAsk>((ref) async {
  try {
    final res = await ref.read(apiProvider).get('/api/profile/complete');
    if (res['ok'] == false) return PlaceAsk.unknown;
    return PlaceAsk.fromJson(res);
  } on ApiFailure {
    /* A profile screen that fails to load because ONE optional card could
       not be fetched has turned a missing dropdown into a missing page. */
    return PlaceAsk.unknown;
  }
});

/// The card on the profile screen. Quiet when the state is already set,
/// prominent when it is not — because the missing state is the reason a whole
/// board is closed to this student.
class PlaceCard extends ConsumerStatefulWidget {
  const PlaceCard({super.key, this.state, this.institution});

  /// What the dashboard snapshot already knows, so the card can render its
  /// settled state without waiting for its own request.
  final String? state;
  final String? institution;

  @override
  ConsumerState<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends ConsumerState<PlaceCard> {
  bool _open = false;
  bool _saving = false;
  String? _chosenState;
  String _error = '';
  late final TextEditingController _school = TextEditingController(
    text: widget.institution ?? '',
  );

  @override
  void dispose() {
    _school.dispose();
    super.dispose();
  }

  Future<void> _save(PlaceAsk ask) async {
    final state = _chosenState ?? widget.state ?? '';
    if (ask.states.isNotEmpty && state.trim().isEmpty) {
      setState(() => _error = 'Choose your state.');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final res = await ref
          .read(apiProvider)
          .post(
            '/api/profile/complete',
            body: {
              if (state.trim().isNotEmpty) 'state': state.trim(),
              if (_school.text.trim().isNotEmpty)
                'institution': _school.text.trim(),
            },
          );
      if (!mounted) return;
      if (res['ok'] == false) {
        setState(() {
          _saving = false;
          _error = asText(res['message'], 'That did not save.');
        });
        return;
      }
      setState(() {
        _saving = false;
        _open = false;
      });
      /* Three screens are now stale at once, and all three are cheap to
         rebuild: the profile's own record, the ask itself, and the board —
         whose state and school tabs have just become available. */
      ref.invalidate(placeAskProvider);
      ref.invalidate(leaderboardProvider);
      await ref.read(dashboardProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Your state board is open now.')),
      );
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final ask = ref.watch(placeAskProvider).value ?? PlaceAsk.unknown;
    final hasState = (widget.state ?? '').trim().isNotEmpty;

    // Nothing to ask and nothing to change: no card at all.
    if (ask.states.isEmpty && !hasState) return const SizedBox.shrink();

    if (!_open) {
      return GlassSurface(
        tier: hasState ? GlassTier.card : GlassTier.raised,
        seam: !hasState,
        onTap: () => setState(() => _open = true),
        semanticLabel: hasState
            ? 'Your state is ${widget.state}. Tap to change it.'
            : 'Add your state to appear on your state leaderboard.',
        child: Row(
          children: [
            Icon(
              hasState ? Icons.place_rounded : Icons.add_location_alt_rounded,
              color: hasState ? c.text3 : c.brand,
              size: 22,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasState ? 'Your place on the board' : 'Add your state',
                    style: LipType.bodyStrong.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasState
                        ? [
                            widget.state,
                            if ((widget.institution ?? '').trim().isNotEmpty)
                              widget.institution,
                          ].whereType<String>().join(' · ')
                        : 'The state and school boards rank by this. Without '
                              'it you only appear on the national one.',
                    style: LipType.small.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.text3, size: 20),
          ],
        ),
      );
    }

    return GlassSurface(
      tier: GlassTier.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LipLabel('Your place on the board'),
          const SizedBox(height: Gap.md),
          if (ask.states.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: ask.states.contains(_chosenState ?? widget.state)
                  ? (_chosenState ?? widget.state)
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'State'),
              items: [
                for (final s in ask.states)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                      _chosenState = v;
                      _error = '';
                    }),
            ),
            const SizedBox(height: Gap.md),
          ],
          TextField(
            controller: _school,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'School (optional)',
              helperText: 'Opens your school board when others type the same.',
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            LipFormError(message: _error),
          ],
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: LipButton(
                  label: 'Save',
                  busy: _saving,
                  onPressed: () => _save(ask),
                ),
              ),
              const SizedBox(width: Gap.md),
              TextButton(
                onPressed: _saving ? null : () => setState(() => _open = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
