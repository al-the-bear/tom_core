import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../tom_form.dart';
import 'tom_list_form.dart';

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
class TomExpandableListForm<TItem extends TomClass,
    TForm extends TomForm<TItem>> extends StatefulWidget {
  const TomExpandableListForm({
    super.key,
    required this.listForm,
    required this.summaryBuilder,
    required this.bodyBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.toolbarBuilder,
    this.emptyBuilder,
    this.rowSeparatorBuilder,
    this.policy = TomExpansionPolicy.singleOpen,
    this.controller,
    this.initialExpanded,
    this.onBeforeChange,
    this.onExpansionChanged,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

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
  /// Header / footer / toolbar still render around it.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Optional separator between consecutive rows.
  final Widget Function(BuildContext context, int index)? rowSeparatorBuilder;

  /// Single-open vs multi-open. Defaults to [TomExpansionPolicy.singleOpen].
  final TomExpansionPolicy policy;

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

  /// Outer padding applied to the entire stack.
  final EdgeInsetsGeometry? padding;

  /// Cross-axis alignment of the inner [Column]. Defaults to
  /// [CrossAxisAlignment.stretch] so rows fill the available width.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<TomExpandableListForm<TItem, TForm>> createState() =>
      _TomExpandableListFormState<TItem, TForm>();
}

class _TomExpandableListFormState<TItem extends TomClass,
        TForm extends TomForm<TItem>>
    extends State<TomExpandableListForm<TItem, TForm>>
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
  void didUpdateWidget(covariant TomExpandableListForm<TItem, TForm> old) {
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

  @override
  Widget build(BuildContext context) {
    final list = widget.listForm;
    final children = <Widget>[];

    final header = widget.headerBuilder?.call(context, list);
    if (header != null) children.add(header);

    if (list.isEmpty) {
      final empty = widget.emptyBuilder?.call(context);
      if (empty != null) children.add(empty);
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
