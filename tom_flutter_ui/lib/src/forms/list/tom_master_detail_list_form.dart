import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../widget_base/tom_construction_helpers.dart';
import '../../widget_base/tom_family_base.dart';
import '../tom_form.dart';
import '../tom_form_labels.dart';
import '../widgets/tom_unsaved_changes_guard.dart';
import 'tom_list_form.dart';

// ---------------------------------------------------------------------------
// TomMasterDetailListForm
// ---------------------------------------------------------------------------

/// Two-pane master-detail layout that consumes a [TomListForm] directly —
/// no separate "detail form" instance is needed.
///
/// This is the no-sibling-form architecture of [TomInlineListForm] and
/// [TomExpandableListForm] applied to the master-detail UX: when the
/// user picks row N in the master pane, the detail builder is handed
/// `listForm[N]` (the [TForm] the list itself owns). Because there is
/// no second form bound to the same [TomClass], dirty state and value
/// changes propagate cleanly through the standard child-container
/// chain — the detail's `isDirty` rolls into the master list-form's
/// `isDirty`, which rolls into the parent form's `isDirty`, and so on.
///
/// The widget is layout-agnostic: callers supply [masterBuilder] for
/// the left pane and [detailBuilder] for the right pane. The master
/// builder receives the current selection + a `selectIndex` callback
/// that runs the unsaved-changes guard (when [guardUnsavedSelectionChange]
/// is true) before rebuilding.
///
/// Example:
///
/// ```dart
/// TomMasterDetailListForm<ShippingAddress, ShippingAddressForm>(
///   listForm: form.shippingAddresses,
///   masterPaneWidth: 220,
///   masterBuilder: (ctx, list, selected, selectIndex) => AddressMasterPane(
///     listForm: list, selectedIndex: selected, selectIndex: selectIndex,
///   ),
///   detailBuilder: (ctx, index, rowForm) => AddressDetailPane(form: rowForm),
/// )
/// ```
///
/// Multiple [TomMasterDetailListForm] instances may share the same
/// [TomListForm] — each maintains its own selection observable, so
/// scaffold A may be looking at row 0 while scaffold B is looking at
/// row 2.
///
/// **Resource resolution.** When [tomId] is set, the following keys are
/// consulted (each falls back to the constructor argument or a hard-
/// coded default if no resource exists):
///
/// | Key                            | Type        | Default                     |
/// |--------------------------------|-------------|-----------------------------|
/// | `<basePath>.padding`           | EdgeInsets  | (no padding)                |
/// | `<basePath>.empty`             | string      | the built-in italic hint    |
/// | `<basePath>.masterPaneWidth`   | double      | `280`                       |
/// | `<basePath>.gap`               | double      | `16`                        |
/// | `<basePath>.minMasterPaneWidth`| double      | `120`                       |
/// | `<basePath>.maxMasterPaneWidth`| double      | (half of viewport)          |
///
/// **Draggable splitter.** Pass [draggableSplitter]: true to make the
/// gap between the master and detail panes a horizontal-resize handle.
/// The user can then drag the splitter to widen or shrink the master
/// pane between [minMasterPaneWidth] and [maxMasterPaneWidth] (or, when
/// [maxMasterPaneWidth] is null, half the available width). The starting
/// width is [masterPaneWidth] (or its resource fallback).
///
/// **Authorization.** The whole widget passes through the standard
/// [TomPolicyNodeBase] gate at `<basePath>` — `none` hides the entire
/// scaffold (both panes), `disabled` greys it out and absorbs pointers,
/// `read` applies the readonly visual treatment. Per-row authorization is
/// **not** supported by design — every row of a list shares the list's
/// auth state. Authorize the *fields* of the row sub-form via the field
/// widgets themselves; the same field auth applies to every row.
class TomMasterDetailListForm<
  TItem extends TomClass,
  TForm extends TomForm<TItem>
>
    extends TomListBase {
  TomMasterDetailListForm({
    super.key,
    super.tomId,
    super.tomGroup,
    super.scope,
    super.authorizer,
    super.uiStateController,
    required this.listForm,
    required this.masterBuilder,
    required this.detailBuilder,
    this.emptyDetailBuilder,
    double? masterPaneWidth,
    double? gap,
    EdgeInsetsGeometry? padding,
    this.guardUnsavedSelectionChange = true,
    this.initialSelectedIndex,
    this.draggableSplitter = false,
    double? minMasterPaneWidth,
    double? maxMasterPaneWidth,
  }) : _masterPaneWidth = masterPaneWidth,
       _gap = gap,
       _padding = padding,
       _minMasterPaneWidth = minMasterPaneWidth,
       _maxMasterPaneWidth = maxMasterPaneWidth {
    _resolvedMasterPaneWidth =
        _masterPaneWidth ??
        TomCtr.doubleVal(basePath, 'masterPaneWidth') ??
        280.0;
    _resolvedGap = _gap ?? TomCtr.doubleVal(basePath, 'gap') ?? 16.0;
    _resolvedPadding = _padding ?? TomCtr.edgeInsets(basePath, 'padding');
    _resolvedEmptyText = TomCtr.textOrNull(basePath, 'empty');
    _resolvedMinMasterPaneWidth =
        _minMasterPaneWidth ??
        TomCtr.doubleVal(basePath, 'minMasterPaneWidth') ??
        120.0;
    _resolvedMaxMasterPaneWidth =
        _maxMasterPaneWidth ?? TomCtr.doubleVal(basePath, 'maxMasterPaneWidth');
  }

  /// The list whose rows feed both panes.
  final TomListForm<TItem, TForm> listForm;

  /// Optional initial selection. When non-null, the widget runs
  /// `selectIndex(initialSelectedIndex)` on the first frame so the detail
  /// pane comes up already showing that row.
  ///
  /// The value is consulted only on the very first build; subsequent
  /// changes are ignored (selection becomes user-driven from then on).
  final int? initialSelectedIndex;

  /// Builds the master pane (typically a list of summaries plus an
  /// add/remove/reorder toolbar). The provided callback re-runs the
  /// unsaved-changes guard, applies the selection, and rebuilds the
  /// scaffold.
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
    int? selectedIndex,
    Future<void> Function(int? index) selectIndex,
  )
  masterBuilder;

  /// Builds the detail pane. The provided [rowForm] is the row's own
  /// sub-form (`listForm[selectedIndex]`) — bind any field widgets,
  /// Save/Discard buttons, error views directly to it.
  ///
  /// When nothing is selected (or the index is out of range) this
  /// builder is NOT called — [emptyDetailBuilder] runs instead.
  final Widget Function(BuildContext context, int selectedIndex, TForm rowForm)
  detailBuilder;

  /// Optional widget shown when nothing is selected. Defaults to a
  /// centred italic hint (resolved from `<basePath>.empty` if set,
  /// otherwise the built-in fallback).
  final WidgetBuilder? emptyDetailBuilder;

  final double? _masterPaneWidth;
  final double? _gap;
  final EdgeInsetsGeometry? _padding;
  final double? _minMasterPaneWidth;
  final double? _maxMasterPaneWidth;

  late final double _resolvedMasterPaneWidth;
  late final double _resolvedGap;
  late final EdgeInsetsGeometry? _resolvedPadding;
  late final String? _resolvedEmptyText;
  late final double _resolvedMinMasterPaneWidth;
  late final double? _resolvedMaxMasterPaneWidth;

  /// When `true` (default), selection changes prompt Save/Discard/Cancel
  /// if the currently-selected row's sub-form is dirty. Set to `false`
  /// to switch silently.
  final bool guardUnsavedSelectionChange;

  /// When `true`, the gap between the master pane and the detail pane
  /// becomes a draggable splitter handle that lets the user resize the
  /// master pane interactively. Defaults to `false` so existing
  /// scaffolds keep their fixed-width master pane.
  final bool draggableSplitter;

  @override
  Widget buildContent(BuildContext context) {
    return _TomMasterDetailListFormImpl<TItem, TForm>(
      listForm: listForm,
      masterBuilder: masterBuilder,
      detailBuilder: detailBuilder,
      emptyDetailBuilder: emptyDetailBuilder,
      emptyText: _resolvedEmptyText,
      masterPaneWidth: _resolvedMasterPaneWidth,
      gap: _resolvedGap,
      padding: _resolvedPadding,
      guardUnsavedSelectionChange: guardUnsavedSelectionChange,
      initialSelectedIndex: initialSelectedIndex,
      draggableSplitter: draggableSplitter,
      minMasterPaneWidth: _resolvedMinMasterPaneWidth,
      maxMasterPaneWidth: _resolvedMaxMasterPaneWidth,
    );
  }
}

/// Internal stateful renderer that owns the selection observable and the
/// [TomListForm] subscription. The public [TomMasterDetailListForm]
/// resolves resources up-front and delegates to this widget so the auth
/// / resource pipeline (which is StatelessWidget-shaped) and the live
/// observer chain don't fight each other.
class _TomMasterDetailListFormImpl<
  TItem extends TomClass,
  TForm extends TomForm<TItem>
>
    extends StatefulWidget {
  const _TomMasterDetailListFormImpl({
    super.key,
    required this.listForm,
    required this.masterBuilder,
    required this.detailBuilder,
    required this.masterPaneWidth,
    required this.gap,
    required this.guardUnsavedSelectionChange,
    required this.draggableSplitter,
    required this.minMasterPaneWidth,
    this.emptyDetailBuilder,
    this.emptyText,
    this.padding,
    this.initialSelectedIndex,
    this.maxMasterPaneWidth,
  });

  final TomListForm<TItem, TForm> listForm;
  final Widget Function(
    BuildContext context,
    TomListForm<TItem, TForm> listForm,
    int? selectedIndex,
    Future<void> Function(int? index) selectIndex,
  )
  masterBuilder;
  final Widget Function(BuildContext, int, TForm) detailBuilder;
  final WidgetBuilder? emptyDetailBuilder;
  final String? emptyText;
  final double masterPaneWidth;
  final double gap;
  final EdgeInsetsGeometry? padding;
  final bool guardUnsavedSelectionChange;
  final int? initialSelectedIndex;
  final bool draggableSplitter;
  final double minMasterPaneWidth;
  final double? maxMasterPaneWidth;

  @override
  State<_TomMasterDetailListFormImpl<TItem, TForm>> createState() =>
      _TomMasterDetailListFormImplState<TItem, TForm>();
}

class _TomMasterDetailListFormImplState<
  TItem extends TomClass,
  TForm extends TomForm<TItem>
>
    extends State<_TomMasterDetailListFormImpl<TItem, TForm>>
    implements TomObserver {
  final TomNInt _selectedIndex = TomNInt(null);

  /// Live master pane width when the splitter is draggable. Initialised
  /// to the constructor / resource value and adjusted on horizontal
  /// drag. When the splitter is disabled this field is unused — the
  /// build path goes straight through `widget.masterPaneWidth`.
  late double _masterPaneWidth;

  @override
  void initState() {
    super.initState();
    widget.listForm.addObserver(this);
    _selectedIndex.addObserver(this);
    _masterPaneWidth = widget.masterPaneWidth;
    final initial = widget.initialSelectedIndex;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectIndex(initial);
      });
    }
  }

  @override
  void didUpdateWidget(
    covariant _TomMasterDetailListFormImpl<TItem, TForm> old,
  ) {
    super.didUpdateWidget(old);
    if (!identical(old.listForm, widget.listForm)) {
      old.listForm.removeObserver(this);
      widget.listForm.addObserver(this);
      // The previous selection may not point to a meaningful row in
      // the new list — clear it to avoid the detail pane flashing
      // stale content.
      _selectedIndex | null;
    }
    // Reset the live width when the host pushes a new starting width.
    // We only do so if the user hasn't yet dragged (dragged-from-start
    // is detected by the live width still equalling the previous
    // constructor value). This keeps user-driven drags sticky across
    // unrelated widget rebuilds.
    if (old.masterPaneWidth != widget.masterPaneWidth &&
        _masterPaneWidth == old.masterPaneWidth) {
      _masterPaneWidth = widget.masterPaneWidth;
    }
  }

  @override
  void dispose() {
    widget.listForm.removeObserver(this);
    _selectedIndex.removeObserver(this);
    super.dispose();
  }

  @override
  void onNotify(TomObservable observable) {
    if (!mounted) return;
    // Defensive: if the list shrinks past the current selection (e.g. a
    // remove from outside this widget), clear the selection so the
    // detail pane falls back to the empty builder instead of trying to
    // render an out-of-range row.
    final cur = ~_selectedIndex;
    if (cur != null && cur >= widget.listForm.length) {
      _selectedIndex | null;
    }
    setState(() {});
  }

  Future<void> _selectIndex(int? index) async {
    final current = ~_selectedIndex;
    if (current == index) return;

    Future<void> apply() async {
      _selectedIndex | index;
    }

    if (widget.guardUnsavedSelectionChange &&
        current != null &&
        current >= 0 &&
        current < widget.listForm.length) {
      final rowForm = widget.listForm[current];
      await guardUnsavedChanges(context: context, form: rowForm, action: apply);
    } else {
      await apply();
    }
  }

  Widget _buildEmptyDetail(BuildContext context) {
    final builder = widget.emptyDetailBuilder;
    if (builder != null) return builder(context);
    final text = widget.emptyText;
    if (text != null && text.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    // Resolved globally: a master-detail view is a form-level surface with no
    // field scope of its own, and an application words this invitation once.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          TomFormLabels.masterDetailEmpty(null),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  /// Clamps a candidate master pane width into the [min, max] range,
  /// where `max` defaults to half of the available width when not
  /// supplied by the host.
  double _clampWidth(double candidate, double availableWidth) {
    final min = widget.minMasterPaneWidth;
    final max = widget.maxMasterPaneWidth ?? availableWidth / 2;
    final effectiveMax = max < min ? min : max;
    if (candidate < min) return min;
    if (candidate > effectiveMax) return effectiveMax;
    return candidate;
  }

  /// Minimum mouse-friendly hit target around the visual splitter line.
  /// The visual line stays at 2px in the centre of the gap; we widen the
  /// gesture region to at least this many logical pixels so the user
  /// doesn't have to land the cursor on the 2px stripe to start a drag.
  static const double _minHandleHitWidth = 12.0;

  Widget _buildSplitterHandle(BuildContext context, double availableWidth) {
    // Make the gesture-active region at least [_minHandleHitWidth] wide
    // even when the host's `gap` is small. We render the handle inside
    // a fixed-width SizedBox(widget.gap) but use Stack + Positioned so
    // the GestureDetector overflows on either side when needed — that
    // way the visible layout still respects `gap` while the drag area
    // is comfortable to hit.
    final gap = widget.gap;
    final hitWidth = gap >= _minHandleHitWidth ? gap : _minHandleHitWidth;
    final overflow = ((hitWidth - gap) / 2).clamp(0.0, double.infinity);
    final dividerColor = Theme.of(context).dividerColor;

    return SizedBox(
      width: gap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Visible handle — thin centred line.
          Center(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: dividerColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          // Hit target — wider invisible region with the resize cursor
          // and the drag handler. May overflow the gap on either side
          // (Stack(clipBehavior: none)) when `gap` is narrow.
          Positioned(
            left: -overflow,
            right: -overflow,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _masterPaneWidth = _clampWidth(
                      _masterPaneWidth + details.delta.dx,
                      availableWidth,
                    );
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ~_selectedIndex;
    final master = widget.masterBuilder(
      context,
      widget.listForm,
      selected,
      _selectIndex,
    );

    Widget detail;
    if (selected == null ||
        selected < 0 ||
        selected >= widget.listForm.length) {
      detail = _buildEmptyDetail(context);
    } else {
      detail = widget.detailBuilder(
        context,
        selected,
        widget.listForm[selected],
      );
    }

    Widget rowFor(double availableWidth) {
      final separator = widget.draggableSplitter
          ? _buildSplitterHandle(context, availableWidth)
          : SizedBox(width: widget.gap);
      // When the splitter is draggable, also clamp the live width on
      // every build so a viewport that shrinks below our current width
      // doesn't leave the master pane bleeding into the detail.
      final effectiveWidth = widget.draggableSplitter
          ? _clampWidth(_masterPaneWidth, availableWidth)
          : widget.masterPaneWidth;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: effectiveWidth, child: master),
          separator,
          Expanded(child: detail),
        ],
      );
    }

    Widget body;
    if (widget.draggableSplitter) {
      // LayoutBuilder gives us the actual content-area width every
      // frame — far more reliable than reaching into the State's own
      // RenderObject (which previously only surfaced *after* the first
      // layout pass and missed any padding the host applied above us).
      body = LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : double.infinity;
          return rowFor(available);
        },
      );
    } else {
      body = rowFor(double.infinity);
    }

    return widget.padding != null
        ? Padding(padding: widget.padding!, child: body)
        : body;
  }
}
