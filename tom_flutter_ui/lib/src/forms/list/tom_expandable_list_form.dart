import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../tom_form.dart';
import 'tom_list_form.dart';
import 'tom_reorder_handle.dart';

// ---------------------------------------------------------------------------
// TomExpandableListForm — Phase 2a §16
// ---------------------------------------------------------------------------

/// Expansion policy for [TomExpandableListForm].
enum TomExpansionPolicy {
  /// Opening a row collapses any other open row. The default — picks
  /// the spec's "no two dirty rows competing for attention" default for
  /// list editing.
  singleOpen,

  /// Multiple rows may be expanded at once. Useful when rows are
  /// independent and the user wants to compare or edit several in
  /// parallel.
  multipleOpen,
}

/// Controls expansion state from outside the widget. The widget creates
/// an internal controller when none is provided; pass your own when you
/// need to react to or drive expansion (e.g. collapse all on save
/// success, programmatically open the newly-added row).
///
/// All methods are async because an attached [TomExpandableListForm] may
/// have an `onBeforeChange` veto that runs validation or shows
/// confirmation dialogs.
class TomExpandableListFormController extends ChangeNotifier {
  TomExpandableListFormController({
    Set<int>? initialExpanded,
  }) : _expanded = {...?initialExpanded};

  final Set<int> _expanded;

  /// Read-only view of the currently expanded indices.
  Set<int> get expanded => Set.unmodifiable(_expanded);

  /// Whether [index] is currently expanded.
  bool isExpanded(int index) => _expanded.contains(index);

  /// Programmatically expand [index] under [policy]. Does NOT consult
  /// the attached widget's `onBeforeChange` veto — use this for code-
  /// driven flows ("after save, open the new row") where bypassing the
  /// veto is the intended behaviour. For user-driven toggles, let the
  /// widget call its internal toggle so the veto runs.
  void expand(int index,
      {TomExpansionPolicy policy = TomExpansionPolicy.singleOpen}) {
    _applyExpand(index, policy);
  }

  /// Programmatically collapse [index]. Does NOT consult any veto.
  void collapse(int index) {
    _applyCollapse(index);
  }

  /// Programmatically collapse every row. Does NOT consult any veto.
  /// The canonical use is "after a successful save, collapse the open
  /// row(s) to return the user to the read-only summary view".
  void collapseAll() {
    _applyCollapseAll();
  }

  /// Internal: apply a state change without consulting any veto. Called
  /// by the widget after a veto check has passed (or when no veto is
  /// configured).
  void _applyExpand(int index, TomExpansionPolicy policy) {
    if (policy == TomExpansionPolicy.singleOpen) {
      _expanded
        ..clear()
        ..add(index);
    } else {
      _expanded.add(index);
    }
    notifyListeners();
  }

  void _applyCollapse(int index) {
    if (_expanded.remove(index)) notifyListeners();
  }

  void _applyCollapseAll() {
    if (_expanded.isEmpty) return;
    _expanded.clear();
    notifyListeners();
  }
}

/// Renders a [TomListForm] as a vertical sequence of expandable rows —
/// each row collapsed shows a builder-supplied summary, expanded shows a
/// builder-supplied editor for the row's [TForm].
///
/// This is the right component when rows are individually heavy (many
/// fields, validation panels, sub-tables) and the natural UX is "browse
/// the list, drill into one row at a time". Each row sees the same
/// [TForm] instance the [TomListForm] owns — there is no sibling form
/// bound to the same [TomClass], so structural mutations and dirty
/// state propagate cleanly through the standard child-container chain.
///
/// Expansion policy:
///   * [TomExpansionPolicy.singleOpen] (default) — opening a row
///     collapses any other open row.
///   * [TomExpansionPolicy.multipleOpen] — multiple rows may be open
///     concurrently.
///
/// Vetoing a state change: pass [onBeforeChange] to gate expansion
/// toggles. Receives the row whose state would change and the desired
/// new open state. Returning `false` cancels the toggle (the row stays
/// in its current state). Useful for "validate before switching away"
/// patterns.
///
/// External control: pass a [TomExpandableListFormController] to drive
/// or observe expansion from outside (e.g. `controller.collapseAll()`
/// after a successful save).
///
/// **Resource resolution.** When [tomId] is set, the following keys are
/// consulted (each falls back to the constructor argument or a hard-
/// coded default if no resource exists):
///
/// | Key                         | Type        | Default                     |
/// |-----------------------------|-------------|-----------------------------|
/// | `<basePath>.padding`        | EdgeInsets  | (no padding)                |
/// | `<basePath>.empty`          | string      | (no auto-empty widget)      |
/// | `<basePath>.policy`         | string      | `'singleOpen'`              |
///
/// The resource value `singleOpen` / `multipleOpen` resolves to the
/// matching [TomExpansionPolicy]; an explicit [policy] argument always
/// wins over the resource.
///
/// **Authorization.** The whole widget passes through the standard
/// [TomPolicyNodeBase] gate at `<basePath>` — `none` hides the entire
/// list, `disabled` greys it out and absorbs pointers, `read` applies
/// the readonly visual treatment. Per-row authorization is **not**
/// supported by design — every row of a list shares the list's auth
/// state. Authorize the *fields* of the row sub-form via the field
/// widgets themselves; the same field auth applies to every row.
class TomExpandableListForm<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends TomListBase {
  TomExpandableListForm({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.authorizerStrategy,
    super.uiStateController,
    required this.listForm,
    required this.summaryBuilder,
    required this.bodyBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.toolbarBuilder,
    this.emptyBuilder,
    this.rowSeparatorBuilder,
    TomExpansionPolicy? policy,
    this.controller,
    this.initialExpanded,
    this.onBeforeChange,
    this.onExpansionChanged,
    EdgeInsetsGeometry? padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.reorderable = false,
    this.onReorder,
    this.proxyDecorator,
  })  : _policy = policy,
        _padding = padding {
    _resolvedPadding = _padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedEmptyText = TomCtr.textOrNull(basePath, 'empty');
    _resolvedPolicy = _policy ?? _resolvePolicyResource(basePath);
  }

  /// The list whose rows are rendered as expandable tiles.
  final TomListForm<TItem, TForm> listForm;

  /// Builds the always-visible row summary (collapsed and expanded
  /// states both render this). The whole row reacts to taps on the
  /// summary to toggle expansion.
  final Widget Function(BuildContext context, int index, TForm rowForm)
      summaryBuilder;

  /// Builds the editor body shown when the row is expanded. The
  /// provided [rowForm] is the same instance reachable via
  /// `listForm[index]`.
  final Widget Function(BuildContext context, int index, TForm rowForm)
      bodyBuilder;

  /// Optional header rendered above all rows. Use for column titles,
  /// dirty chips, totals.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
  )? headerBuilder;

  /// Optional footer rendered below all rows.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
  )? footerBuilder;

  /// Optional toolbar rendered after [footerBuilder]. Conventionally
  /// hosts Add / Bulk-action buttons.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
  )? toolbarBuilder;

  /// Optional widget shown in place of any rows when the list is empty.
  /// Header / footer / toolbar still render around it. When omitted,
  /// the resource `<basePath>.empty` (if any) is shown as plain text;
  /// otherwise nothing is shown.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Optional separator between consecutive rows.
  final Widget Function(BuildContext context, int index)? rowSeparatorBuilder;

  final TomExpansionPolicy? _policy;
  late final TomExpansionPolicy _resolvedPolicy;

  /// Optional external controller. If null, one is created internally
  /// (seeded from [initialExpanded] if supplied).
  final TomExpandableListFormController? controller;

  /// Initial expanded indices. Only consulted when [controller] is null.
  final Set<int>? initialExpanded;

  /// Optional veto for an expansion state change. Receives the row that
  /// would change, its [TForm], and the desired new open state. Return
  /// `false` to cancel the toggle.
  ///
  /// Common pattern (validate-before-switch):
  /// ```dart
  /// onBeforeChange: (index, form, willOpen) async {
  ///   if (willOpen) return true;          // collapsing — always allow
  ///   final errors = await form.validate();
  ///   if (errors.isEmpty) return true;
  ///   showSnackbar(context, 'Fix errors first');
  ///   return false;
  /// }
  /// ```
  final Future<bool> Function(int index, TForm rowForm, bool willOpen)?
      onBeforeChange;

  /// Notified after every expansion state change. Receives the
  /// post-change set of expanded indices.
  final void Function(Set<int> expanded)? onExpansionChanged;

  final EdgeInsetsGeometry? _padding;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final String? _resolvedEmptyText;

  /// Cross-axis alignment of the inner [Column]. Defaults to
  /// [CrossAxisAlignment.stretch] so rows fill the available width.
  final CrossAxisAlignment crossAxisAlignment;

  /// When `true`, rows are wrapped in a [ReorderableListView] so the
  /// user can drag them into a new order via [TomReorderHandle]
  /// instances embedded inside [summaryBuilder]. Reorder events forward
  /// to [TomListForm.reorder] (and [onReorder] if supplied). The
  /// [rowSeparatorBuilder] is ignored in reorderable mode (place
  /// separator chrome inside the row body instead).
  final bool reorderable;

  /// Optional reorder hook fired *after* [TomListForm.reorder] runs.
  /// Arguments use [TomListForm] semantics — `to` is the destination
  /// index AFTER the reorder (NOT the pre-removal index that
  /// [ReorderableListView] reports natively).
  final void Function(int from, int to)? onReorder;

  /// Custom proxy decorator forwarded to [ReorderableListView] when
  /// [reorderable] is true. Use to style the floating row that follows
  /// the user's pointer during a drag.
  final Widget Function(Widget child, int index, Animation<double> animation)?
      proxyDecorator;

  static TomExpansionPolicy _resolvePolicyResource(String? basePath) {
    final raw = TomCtr.textOrNull(basePath, 'policy');
    switch (raw) {
      case 'multipleOpen':
        return TomExpansionPolicy.multipleOpen;
      case 'singleOpen':
      default:
        return TomExpansionPolicy.singleOpen;
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return _TomExpandableListFormImpl<TItem, TForm>(
      listForm: listForm,
      summaryBuilder: summaryBuilder,
      bodyBuilder: bodyBuilder,
      headerBuilder: headerBuilder,
      footerBuilder: footerBuilder,
      toolbarBuilder: toolbarBuilder,
      emptyBuilder: emptyBuilder,
      emptyText: _resolvedEmptyText,
      rowSeparatorBuilder: rowSeparatorBuilder,
      policy: _resolvedPolicy,
      controller: controller,
      initialExpanded: initialExpanded,
      onBeforeChange: onBeforeChange,
      onExpansionChanged: onExpansionChanged,
      padding: _resolvedPadding,
      crossAxisAlignment: crossAxisAlignment,
      reorderable: reorderable,
      onReorder: onReorder,
      proxyDecorator: proxyDecorator,
    );
  }
}

/// Internal stateful renderer that owns the [TomListForm] subscription,
/// the expansion controller, and the toggle/veto pipeline. The public
/// [TomExpandableListForm] resolves resources up-front and delegates to
/// this widget so the auth / resource pipeline (StatelessWidget-shaped)
/// and the live observer / controller chain don't fight each other.
class _TomExpandableListFormImpl<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends StatefulWidget {
  const _TomExpandableListFormImpl({
    super.key,
    required this.listForm,
    required this.summaryBuilder,
    required this.bodyBuilder,
    required this.policy,
    required this.crossAxisAlignment,
    required this.reorderable,
    this.headerBuilder,
    this.footerBuilder,
    this.toolbarBuilder,
    this.emptyBuilder,
    this.emptyText,
    this.rowSeparatorBuilder,
    this.controller,
    this.initialExpanded,
    this.onBeforeChange,
    this.onExpansionChanged,
    this.padding,
    this.onReorder,
    this.proxyDecorator,
  });

  final TomListForm<TItem, TForm> listForm;
  final Widget Function(BuildContext, int, TForm) summaryBuilder;
  final Widget Function(BuildContext, int, TForm) bodyBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? headerBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)? footerBuilder;
  final Widget Function(BuildContext, TomListForm<TItem, TForm>)?
      toolbarBuilder;
  final Widget Function(BuildContext)? emptyBuilder;
  final String? emptyText;
  final Widget Function(BuildContext, int)? rowSeparatorBuilder;
  final TomExpansionPolicy policy;
  final TomExpandableListFormController? controller;
  final Set<int>? initialExpanded;
  final Future<bool> Function(int, TForm, bool)? onBeforeChange;
  final void Function(Set<int>)? onExpansionChanged;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;
  final bool reorderable;
  final void Function(int, int)? onReorder;
  final Widget Function(Widget, int, Animation<double>)? proxyDecorator;

  @override
  State<_TomExpandableListFormImpl<TItem, TForm>> createState() =>
      _TomExpandableListFormImplState<TItem, TForm>();
}

class _TomExpandableListFormImplState<TItem extends TomClass,
        TForm extends TomForm<TItem>>
    extends State<_TomExpandableListFormImpl<TItem, TForm>>
    implements TomObserver {
  late TomExpandableListFormController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller ??
        TomExpandableListFormController(initialExpanded: widget.initialExpanded));
    _ownsController = widget.controller == null;
    widget.listForm.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _TomExpandableListFormImpl<TItem, TForm> old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      _detachController();
      if (widget.controller != null) {
        _attachController(widget.controller!);
        _ownsController = false;
      } else {
        _attachController(TomExpandableListFormController(
            initialExpanded: widget.initialExpanded));
        _ownsController = true;
      }
    }
    if (!identical(old.listForm, widget.listForm)) {
      old.listForm.removeObserver(this);
      widget.listForm.addObserver(this);
    }
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    _detachController();
    super.dispose();
  }

  void _attachController(TomExpandableListFormController c) {
    _controller = c;
    _controller.addListener(_onControllerChanged);
  }

  void _detachController() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    widget.onExpansionChanged?.call(_controller.expanded);
  }

  @override
  void onNotify(TomObservable _) {
    if (mounted) setState(() {});
  }

  /// Compute the post-move index of a row that was at [original] before
  /// a move that took the row at [from] to position [to]. Used to keep
  /// the controller's expanded-set aligned after a drag-reorder.
  int _remapIndexAfterMove(int original, int from, int to) {
    if (original == from) return to;
    if (from < to) {
      // Moving downward: rows in [from+1 .. to] shift up by one.
      if (original > from && original <= to) return original - 1;
      return original;
    } else {
      // Moving upward: rows in [to .. from-1] shift down by one.
      if (original >= to && original < from) return original + 1;
      return original;
    }
  }

  Future<void> _toggle(int index) async {
    final form = widget.listForm[index];
    final isOpen = _controller.isExpanded(index);
    final willOpen = !isOpen;

    final veto = widget.onBeforeChange;
    if (veto != null) {
      // For singleOpen: opening row N also collapses any currently-open
      // row M. Run the veto on M *before* opening N so a dirty M can
      // refuse the implicit collapse.
      if (willOpen && widget.policy == TomExpansionPolicy.singleOpen) {
        for (final other in _controller.expanded.toList()) {
          if (other == index) continue;
          if (other < 0 || other >= widget.listForm.length) continue;
          final ok = await veto(other, widget.listForm[other], false);
          if (!ok) return;
        }
      }
      final ok = await veto(index, form, willOpen);
      if (!ok) return;
    }

    if (willOpen) {
      _controller._applyExpand(index, widget.policy);
    } else {
      _controller._applyCollapse(index);
    }
  }

  Widget? _buildEmpty(BuildContext context) {
    final builder = widget.emptyBuilder;
    if (builder != null) return builder(context);
    final text = widget.emptyText;
    if (text != null && text.isNotEmpty) return Text(text);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.listForm;
    final children = <Widget>[];

    final header = widget.headerBuilder?.call(context, list);
    if (header != null) children.add(header);

    if (list.isEmpty) {
      final empty = _buildEmpty(context);
      if (empty != null) children.add(empty);
    } else if (widget.reorderable) {
      children.add(ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        proxyDecorator: widget.proxyDecorator,
        onReorderItem: (from, to) {
          // onReorderItem already delivers `to` adjusted for the removed
          // item, so it is the final destination index directly.
          final adjusted = to;
          if (adjusted == from) return;
          // Recompute expansion state after the move so the dragged
          // row stays in its previous open/closed state at the new
          // index.
          final wasExpanded = _controller.isExpanded(from);
          // Build a new expansion set with each index remapped to its
          // post-reorder position. (singleOpen vs multipleOpen treated
          // identically — we're moving rows, not toggling them.)
          final remapped = <int>{};
          for (final idx in _controller.expanded) {
            remapped.add(_remapIndexAfterMove(idx, from, adjusted));
          }
          _controller._expanded
            ..clear()
            ..addAll(remapped);
          // Make sure the dragged row's state is preserved at its new
          // index in case the remap ate it (e.g. drag from collapsed
          // sibling).
          if (wasExpanded) {
            _controller._expanded.add(adjusted);
          }
          list.reorder(from, adjusted);
          widget.onReorder?.call(from, adjusted);
        },
        itemBuilder: (context, i) {
          return _TomExpandableRow<TItem, TForm>(
            key: ValueKey('tom-expandable-row-${list[i].hashCode}-$i-'
                '${_controller.isExpanded(i) ? 'open' : 'closed'}'),
            index: i,
            rowForm: list[i],
            isExpanded: _controller.isExpanded(i),
            summaryBuilder: widget.summaryBuilder,
            bodyBuilder: widget.bodyBuilder,
            onTap: () => _toggle(i),
          );
        },
      ));
    } else {
      for (var i = 0; i < list.length; i++) {
        if (i > 0 && widget.rowSeparatorBuilder != null) {
          children.add(widget.rowSeparatorBuilder!(context, i - 1));
        }
        children.add(_TomExpandableRow<TItem, TForm>(
          // The key embeds the row's expansion state so the row's State
          // is rebuilt cleanly when controller-driven changes flip the
          // open flag from outside (avoids stale Material InkWell etc.).
          key: ValueKey('tom-expandable-row-$i-'
              '${_controller.isExpanded(i) ? 'open' : 'closed'}'),
          index: i,
          rowForm: list[i],
          isExpanded: _controller.isExpanded(i),
          summaryBuilder: widget.summaryBuilder,
          bodyBuilder: widget.bodyBuilder,
          onTap: () => _toggle(i),
        ));
      }
    }

    final footer = widget.footerBuilder?.call(context, list);
    if (footer != null) children.add(footer);

    final toolbar = widget.toolbarBuilder?.call(context, list);
    if (toolbar != null) children.add(toolbar);

    final column = Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    return widget.padding != null
        ? Padding(padding: widget.padding!, child: column)
        : column;
  }
}

/// Internal row widget — lays out summary + body with no Material
/// dependency so the component works in Cupertino contexts too.
class _TomExpandableRow<TItem extends TomClass, TForm extends TomForm<TItem>>
    extends StatelessWidget {
  const _TomExpandableRow({
    super.key,
    required this.index,
    required this.rowForm,
    required this.isExpanded,
    required this.summaryBuilder,
    required this.bodyBuilder,
    required this.onTap,
  });

  final int index;
  final TForm rowForm;
  final bool isExpanded;
  final Widget Function(BuildContext, int, TForm) summaryBuilder;
  final Widget Function(BuildContext, int, TForm) bodyBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: summaryBuilder(context, index, rowForm),
        ),
        if (isExpanded) bodyBuilder(context, index, rowForm),
      ],
    );
  }
}
