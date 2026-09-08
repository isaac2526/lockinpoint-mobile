import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../design/components.dart';
import '../../design/glass.dart';
import '../../design/motion_widgets.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../design/rich_text.dart';

/// One hit from /api/search. The answer and explanation come with it, because
/// search is a study tool for a signed in student, not a question feed.
class SearchHit {
  const SearchHit({
    required this.id,
    required this.question,
    required this.answer,
    required this.explanation,
    required this.exam,
    required this.subject,
  });

  final String id;
  final String question;
  final String answer;
  final String explanation;
  final String exam;
  final String subject;

  static SearchHit fromJson(Map<String, dynamic> j) => SearchHit(
    id: j['id'] as String? ?? '',
    question: j['question'] as String? ?? '',
    answer: (j['answer'] as String? ?? '').toUpperCase(),
    explanation: j['explanation'] as String? ?? '',
    exam: j['exam'] as String? ?? '',
    subject: j['subject'] as String? ?? '',
  );
}

class SearchResults {
  const SearchResults({required this.rows, required this.total});
  final List<SearchHit> rows;
  final int total;
}

class SearchRepository {
  SearchRepository(this._api);
  final Api _api;

  /// The server refuses anything under three characters, so the phone does
  /// too: a one letter query would ask the database to read the whole bank.
  static const minChars = 3;
  static const perPage = 10;

  Future<SearchResults> find(String query, {int page = 1}) async {
    final res = await _api.get(
      '/api/search',
      query: {'q': query.trim(), 'p': '$page'},
    );
    return SearchResults(
      rows: ((res['rows'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(SearchHit.fromJson)
          .toList(),
      total: (res['total'] as num?)?.toInt() ?? 0,
    );
  }
}

final searchRepositoryProvider = Provider(
  (ref) => SearchRepository(ref.watch(apiProvider)),
);

/// ===========================================================================
/// QUESTION SEARCH
///
/// Type a phrase you half remember from a past paper and find it. Results
/// hide their answer behind a tap, deliberately: seeing the answer with the
/// question teaches nothing, and a student searching for a question they are
/// stuck on should get the chance to think first.
/// ===========================================================================
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  SearchResults? _results;
  String _ran = '';
  int _page = 1;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Typing does not fire a request per keystroke. Half a second of quiet
  /// does, which on mobile data is the difference between one round trip and
  /// twenty.
  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < SearchRepository.minChars) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _run(1));
  }

  Future<void> _run(int page) async {
    final q = _controller.text.trim();
    if (q.length < SearchRepository.minChars) return;
    setState(() {
      _busy = true;
      _error = null;
      _page = page;
    });
    try {
      final res = await ref.read(searchRepositoryProvider).find(q, page: page);
      if (!mounted) return;
      setState(() {
        _results = res;
        _ran = q;
      });
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _pages => _results == null
      ? 1
      : (_results!.total / SearchRepository.perPage).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    return Scaffold(
      appBar: AppBar(title: const Text('Question search')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                onSubmitted: (_) => _run(1),
                textInputAction: TextInputAction.search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Type any phrase from a question',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ),
            if (_results != null && _results!.total > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_results!.total} '
                    '${_results!.total == 1 ? "match" : "matches"} for "$_ran"',
                    style: LipType.caption.copyWith(color: c.text3),
                  ),
                ),
              ),
            Expanded(child: _body()),
            if (_pages > 1) _pager(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return LipError(message: _error!, onRetry: () => _run(_page));
    }
    final res = _results;
    if (res == null) {
      return const LipEmpty(
        icon: Icons.search_rounded,
        title: 'Find any past question',
        message:
            'Type at least three letters of anything you remember from it, '
            'and every matching question in the bank comes back.',
      );
    }
    if (res.rows.isEmpty) {
      return LipEmpty(
        icon: Icons.manage_search_rounded,
        title: 'Nothing matched "$_ran"',
        message:
            'Try fewer words, or a phrase from the middle of the question.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.md),
      itemCount: res.rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (context, i) => Entrance.inList(
        index: i,
        child: _HitCard(hit: res.rows[i]),
      ),
    );
  }

  Widget _pager() {
    final c = context.lip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _page <= 1 || _busy ? null : () => _run(_page - 1),
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Back'),
          ),
          Text(
            'Page $_page of $_pages',
            style: LipType.caption.copyWith(color: c.text3),
          ),
          TextButton.icon(
            onPressed: _page >= _pages || _busy ? null : () => _run(_page + 1),
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Next'),
            iconAlignment: IconAlignment.end,
          ),
        ],
      ),
    );
  }
}

class _HitCard extends StatefulWidget {
  const _HitCard({required this.hit});
  final SearchHit hit;

  @override
  State<_HitCard> createState() => _HitCardState();
}

class _HitCardState extends State<_HitCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.lip;
    final h = widget.hit;
    return GlassSurface(
      tier: GlassTier.raised,
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (h.exam.isNotEmpty || h.subject.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(
                [h.exam, h.subject].where((s) => s.isNotEmpty).join(' · '),
                style: LipType.label.copyWith(color: c.text3),
              ),
            ),
          LipHtml(h.question, baseStyle: LipType.body.copyWith(color: c.text1)),
          const SizedBox(height: Gap.md),
          if (!_open)
            LipChip(
              'Show answer',
              tone: ChipTone.brand,
              onTap: () => setState(() => _open = true),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: c.successSoft,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Answer: ${h.answer}',
                    style: LipType.bodyStrong.copyWith(color: c.success),
                  ),
                  if (h.explanation.trim().isNotEmpty) ...[
                    const SizedBox(height: Gap.sm),
                    LipHtml(
                      h.explanation,
                      baseStyle: LipType.small.copyWith(color: c.text2),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
