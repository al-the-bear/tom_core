import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../widget_base/tom_construction_helpers.dart';
import '../widget_base/tom_scope_path.dart';

/// Whether a [TomPrincipalCandidate] is one user or a group of users.
enum TomPrincipalKind {
  /// One user.
  user,

  /// A group of users.
  group,
}

/// One user or group a [TomPrincipalPicker] offers: what the search answered
/// with — an [id], a [displayName] to show, and its [kind]. Nothing else: a
/// directory that answers a picker discloses names, not e-mail addresses or
/// memberships.
@immutable
class TomPrincipalCandidate {
  /// Creates the candidate.
  const TomPrincipalCandidate({
    required this.id,
    required this.displayName,
    this.kind = TomPrincipalKind.user,
  });

  /// The user's or group's id, as the directory names it.
  final String id;

  /// The name shown in the list and on the chip.
  final String displayName;

  /// Whether this is a user or a group.
  final TomPrincipalKind kind;

  /// Equal by [id] and [kind]: a user and a group may share an id in two
  /// directories, and a renamed principal is still the one picked.
  @override
  bool operator ==(Object other) =>
      other is TomPrincipalCandidate && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'TomPrincipalCandidate(${kind.name} $id: $displayName)';
}

/// Answers the candidates whose name, username or e-mail starts with
/// [query]. The picker calls it only for queries of at least
/// [TomPrincipalPicker.minimumQueryLength] characters.
typedef TomPrincipalSearch =
    Future<List<TomPrincipalCandidate>> Function(String query);

/// A search field that finds users and groups through an injected [search]
/// and shows the picked ones as chips.
///
/// The picker owns no directory: [search] is whatever the application asks —
/// Tom UAM's subject search, a local list, a test fake. It asks once the query
/// is [minimumQueryLength] characters long and has rested for [debounce],
/// drops answers that a newer query has overtaken, shows at most
/// [maximumResults], and never offers what is already [selected].
///
/// The selection is the caller's: [selected] is shown, and [onChanged]
/// receives the new list when a candidate is picked or a chip removed. With
/// [multiple] `false` a pick replaces the selection.
///
/// **Authorization.** With a [tomId], the picker resolves its
/// [TomAuthState]: `none` hides it, `read` shows the chips without the field or
/// their delete buttons, `disabled` does the same dimmed.
///
/// **Accessibility.** The field carries [label] and [semanticsLabel]; each
/// result reads as its name and kind; the line under the field — searching,
/// how many matched, nothing matched, the search failed — is a live region, so
/// a screen reader announces it as it changes.
///
/// **Texts.** Every text resolves from resources first (keys `label`, `hint`,
/// `semanticsLabel`, `typeMore`, `searching`, `matches`, `noMatch`,
/// `searchFailed`, `retry`, `user`, `group`, `remove` under the [tomId]),
/// then from the explicit argument, then from an English default.
class TomPrincipalPicker extends StatefulWidget {
  /// Creates the picker.
  TomPrincipalPicker({
    super.key,
    this.tomId,
    this.scope,
    required this.search,
    this.selected = const [],
    this.onChanged,
    this.multiple = true,
    this.minimumQueryLength = defaultMinimumQueryLength,
    this.maximumResults = defaultMaximumResults,
    this.debounce = defaultDebounce,
    String? label,
    String? hint,
    String? semanticsLabel,
    this.disabledOpacity = 0.4,
    this.resultsMaxHeight = 280,
  }) {
    final basePath = TomCtr.resolvePath(tomId, scope);
    String text(String key, String? explicit, String fallback) =>
        TomCtr.textOrNull(basePath, key) ?? explicit ?? fallback;
    _texts = _PickerTexts(
      label: text('label', label, 'Share with'),
      hint: text('hint', hint, 'Name, username or e-mail'),
      semanticsLabel: text(
        'semanticsLabel',
        semanticsLabel,
        'Find users and groups',
      ),
      typeMore: text(
        'typeMore',
        null,
        'Type at least $minimumQueryLength characters',
      ),
      searching: text('searching', null, 'Searching'),
      matches: text('matches', null, '{count} found'),
      noMatch: text('noMatch', null, 'Nobody found'),
      searchFailed: text('searchFailed', null, 'The search failed'),
      retry: text('retry', null, 'Try again'),
      user: text('user', null, 'User'),
      group: text('group', null, 'Group'),
      remove: text('remove', null, 'Remove'),
    );
  }

  /// The shortest query the picker asks [search] for.
  static const int defaultMinimumQueryLength = 3;

  /// The most results the picker shows.
  static const int defaultMaximumResults = 20;

  /// How long a query must rest before the picker asks.
  static const Duration defaultDebounce = Duration(milliseconds: 300);

  /// Resource key path for the texts and the authorization. `null`: fully
  /// interactive, explicit texts or defaults.
  final String? tomId;

  /// Explicit scope override for [tomId]; [TomScope.current] when `null`.
  final TomScope? scope;

  /// Finds the candidates for a query.
  final TomPrincipalSearch search;

  /// The picked candidates, shown as chips.
  final List<TomPrincipalCandidate> selected;

  /// Receives the new selection. `null` makes the picker read-only.
  final ValueChanged<List<TomPrincipalCandidate>>? onChanged;

  /// Whether several candidates may be picked; when `false` a pick replaces
  /// the selection.
  final bool multiple;

  /// The shortest query asked for.
  final int minimumQueryLength;

  /// The most results shown.
  final int maximumResults;

  /// How long a query rests before it is asked.
  final Duration debounce;

  /// Opacity of the picker when its auth state is `disabled`.
  final double disabledOpacity;

  /// The tallest the result list grows before it scrolls.
  final double resultsMaxHeight;

  late final _PickerTexts _texts;

  @override
  State<TomPrincipalPicker> createState() => _TomPrincipalPickerState();
}

class _PickerTexts {
  const _PickerTexts({
    required this.label,
    required this.hint,
    required this.semanticsLabel,
    required this.typeMore,
    required this.searching,
    required this.matches,
    required this.noMatch,
    required this.searchFailed,
    required this.retry,
    required this.user,
    required this.group,
    required this.remove,
  });

  final String label;
  final String hint;
  final String semanticsLabel;
  final String typeMore;
  final String searching;
  final String matches;
  final String noMatch;
  final String searchFailed;
  final String retry;
  final String user;
  final String group;
  final String remove;
}

enum _Phase { idle, tooShort, searching, answered, failed }

class _TomPrincipalPickerState extends State<TomPrincipalPicker> {
  final TextEditingController _query = TextEditingController();
  Timer? _timer;
  int _generation = 0;
  _Phase _phase = _Phase.idle;
  List<TomPrincipalCandidate> _results = const [];

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  TomAuthState _auth() {
    final path = TomScopePath.resolve(widget.tomId, widget.scope);
    return path == null
        ? TomAuthState.full
        : TomAuthorization.resolveAuth(path);
  }

  void _queryChanged(String text) {
    _timer?.cancel();
    _generation++;
    final query = text.trim();
    if (query.isEmpty) {
      setState(() {
        _phase = _Phase.idle;
        _results = const [];
      });
      return;
    }
    if (query.length < widget.minimumQueryLength) {
      setState(() {
        _phase = _Phase.tooShort;
        _results = const [];
      });
      return;
    }
    setState(() => _phase = _Phase.searching);
    _timer = Timer(widget.debounce, () => _ask(query));
  }

  Future<void> _ask(String query) async {
    final generation = ++_generation;
    setState(() => _phase = _Phase.searching);
    try {
      final found = await widget.search(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = [
          for (final candidate in found)
            if (!widget.selected.contains(candidate)) candidate,
        ].take(widget.maximumResults).toList();
        _phase = _Phase.answered;
      });
    } on Object {
      // A failed search is shown, with a retry, rather than thrown: the
      // field stays usable and the user decides whether to ask again.
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = const [];
        _phase = _Phase.failed;
      });
    }
  }

  void _pick(TomPrincipalCandidate candidate) {
    final next = widget.multiple
        ? [...widget.selected, candidate]
        : [candidate];
    _timer?.cancel();
    _generation++;
    _query.clear();
    setState(() {
      _results = const [];
      _phase = _Phase.idle;
    });
    widget.onChanged?.call(next);
  }

  void _remove(TomPrincipalCandidate candidate) {
    widget.onChanged?.call([
      for (final picked in widget.selected)
        if (picked != candidate) picked,
    ]);
  }

  String _kindLabel(TomPrincipalKind kind) =>
      kind == TomPrincipalKind.user ? widget._texts.user : widget._texts.group;

  IconData _kindIcon(TomPrincipalKind kind) => kind == TomPrincipalKind.user
      ? Icons.person_outline
      : Icons.group_outlined;

  String? _status() {
    final texts = widget._texts;
    return switch (_phase) {
      _Phase.idle => null,
      _Phase.tooShort => texts.typeMore,
      _Phase.searching => texts.searching,
      _Phase.answered =>
        _results.isEmpty
            ? texts.noMatch
            : texts.matches.replaceAll('{count}', '${_results.length}'),
      _Phase.failed => texts.searchFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth();
    if (auth == TomAuthState.none) return const SizedBox.shrink();
    final editable = auth == TomAuthState.full && widget.onChanged != null;
    final texts = widget._texts;
    final theme = Theme.of(context);
    final status = _status();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.selected.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final picked in widget.selected)
                InputChip(
                  avatar: Icon(_kindIcon(picked.kind), size: 18),
                  label: Text(picked.displayName),
                  tooltip: '${picked.displayName}, ${_kindLabel(picked.kind)}',
                  onDeleted: editable ? () => _remove(picked) : null,
                  deleteButtonTooltipMessage:
                      '${texts.remove} ${picked.displayName}',
                ),
            ],
          ),
        if (editable) ...[
          const SizedBox(height: 8),
          Semantics(
            label: texts.semanticsLabel,
            textField: true,
            child: TextField(
              controller: _query,
              onChanged: _queryChanged,
              decoration: InputDecoration(
                labelText: texts.label,
                hintText: texts.hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _phase == _Phase.searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _phase == _Phase.failed
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (_phase == _Phase.failed)
                    TextButton(
                      onPressed: () => _ask(_query.text.trim()),
                      child: Text(texts.retry),
                    ),
                ],
              ),
            ),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.resultsMaxHeight),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final candidate in _results)
                    ListTile(
                      dense: true,
                      leading: Icon(_kindIcon(candidate.kind)),
                      title: Text(candidate.displayName),
                      subtitle: Text(_kindLabel(candidate.kind)),
                      onTap: () => _pick(candidate),
                    ),
                ],
              ),
            ),
        ],
      ],
    );

    if (auth == TomAuthState.disabled) {
      return Opacity(opacity: widget.disabledOpacity, child: content);
    }
    return content;
  }
}
