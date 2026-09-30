import 'dart:math' as math;

import 'package:flutter/material.dart';
// `_AclFloorWidthBox` drops to the render layer: measuring a child's minimum
// intrinsic width and clipping instead of overflowing are both below what the
// widget layer exposes.
import 'package:flutter/rendering.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../theme/tom_theme.dart';
import 'acl_flags.dart';
import 'acl_device_context.dart';
import 'acl_group_visibility.dart';
import 'acl_responsive.dart';
import 'acl_scope.dart';
import 'row_alignment.dart';

// ── Border enums / types ─────────────────────────────────────────────────────

part 'acl_container_values.dart';
part 'acl_container_model.dart';
part 'acl_container_widgets.dart';
part 'acl_container_state_lifecycle.dart';
part 'acl_container_passes.dart';
part 'acl_container_identity.dart';
part 'acl_container_fitting.dart';
part 'acl_container_geometry.dart';
part 'acl_container_chrome.dart';
part 'acl_container_content.dart';
part 'acl_container_row.dart';

/// Pre-computed layout values for a single content row, produced by the
/// pre-calculation loop. These values are handed directly to [_buildRow] so
/// that Flutter layout is performed in a single pass with all sizes fixed.
class _AclRowLayout {
  /// Fitted (steps 1/2/3) widths by component index. null → natural size.
  final Map<int, double> fittedWidths;

  /// Computed horizontal translation delta for each component index.
  /// 0.0 for components that have no alignXToKey.
  final Map<int, double> horizontalDeltas;

  /// Computed vertical translation delta for each component index.
  /// 0.0 for components that have no alignYToKey.
  final Map<int, double> verticalDeltas;

  /// Resolved linked widths (from sameWidthAs / sameSize) by component index.
  final Map<int, double> linkedWidths;

  /// Resolved linked heights (from sameHeightAs / sameSize) by component index.
  final Map<int, double> linkedHeights;

  /// Width assigned to each gap slot by component index (0 when scrollableX).
  final Map<int, double> gapSlotWidths;

  /// Virtual rect for every component (by componentKey). Published for
  /// cross-row constraint resolution in subsequent rows.
  final Map<Key, Rect> virtualRects;

  /// Estimated row height from the pre-calc pass.
  final double estimatedHeight;

  /// Minimum horizontal X position (may be negative for shifted components).
  final double minHorizontalX;

  _AclRowLayout({
    required this.fittedWidths,
    required this.horizontalDeltas,
    required this.verticalDeltas,
    required this.linkedWidths,
    required this.linkedHeights,
    required this.gapSlotWidths,
    required this.virtualRects,
    required this.estimatedHeight,
    this.minHorizontalX = 0.0,
  });
}

// ── AclContainer ─────────────────────────────────────────────────────────────

class AclContainer extends StatefulWidget {
  final List<AclRow> rows;
  final AclBorderStyle borderStyle;
  final AclBorderStyle? focusedBorderStyle;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  /// Enables horizontal scrolling; gap slots collapse to 0 on the X axis.
  final bool scrollableX;

  /// Enables vertical scrolling; gap rows collapse to 0 on the Y axis.
  final bool scrollableY;

  /// Optional preferred container size. Acts as the minimum when no explicit
  /// minimum is set. Maximum is unlimited unless [maximumContainerSize] is set.
  final Size? preferredContainerSize;

  /// Optional minimum container size.
  final Size? minimumContainerSize;

  /// Optional maximum container size.
  final Size? maximumContainerSize;

  /// Optional identifier for this container. Whether it reaches descendant
  /// paths depends on [idScope].
  ///
  /// See "Container IDs" (§24) in `doc/acl_design_specification.md`.
  final String? aclId;

  /// Whether this container contributes its ID to descendant paths.
  ///
  /// - `true` — identity container: ID appears in descendant paths.
  /// - `false` — layout container (default): ID is for own resources only.
  final bool idScope;

  /// Optional group name for the entire container, letting a
  /// [AclGroupVisibilityController] act on everything it holds at once.
  ///
  /// The outermost default of the group chain: a component belongs to its own
  /// group, else its row's, else this one. So a row or component that names a
  /// group keeps it, and everything else joins this one — for its visibility
  /// mode, its policy path, and the group [AclScope] reports.
  ///
  /// See "Groups" (§25) in `doc/acl_design_specification.md`.
  final String? aclGroup;

  /// Group visibility controllers keyed by group name. Only groups with an
  /// entry here can be shown, hidden or disabled; membership alone does
  /// nothing.
  ///
  /// See "Group Visibility Control" (§26) in
  /// `doc/acl_design_specification.md`.
  final Map<String, AclGroupVisibilityController> groupVisibilityControllers;

  /// Responsive variants sorted by atWidth descending. A variant supplies
  /// replacement [rows] and nothing else — the container's chrome does not
  /// change with the active variant.
  ///
  /// See "Responsive Variants" (§27) in `doc/acl_design_specification.md`.
  final List<AclVariant> variants;

  /// Layout direction: LTR (default) or RTL.
  /// If null, falls back to the nearest [AclDirectionScope], then [AclDirection.ltr].
  ///
  /// See "Layout Direction (RTL/LTR)" (§30) in
  /// `doc/acl_design_specification.md`.
  final AclDirection? direction;

  /// Default for per-component `hideUnauthorized`. When `true`, any
  /// component whose child implements [TomAuthorizable] and currently
  /// resolves to [TomAuthState.none] is **removed from its row before
  /// layout**, together with the `gapBefore` of the component that
  /// follows it in the same row. If a row ends up with no components it
  /// is dropped in turn, along with the `gapBefore` of the next row.
  ///
  /// Components can opt in or out individually via
  /// [AclComponent.hideUnauthorized] (typically set through the builder's
  /// `setHideUnauthorized(bool)` fluent call).
  final bool defaultHideUnauthorized;

  const AclContainer({
    super.key,
    required this.rows,
    this.borderStyle = const AclBorderStyle.none(),
    this.focusedBorderStyle,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.scrollableX = false,
    this.scrollableY = false,
    this.preferredContainerSize,
    this.minimumContainerSize,
    this.maximumContainerSize,
    this.aclId,
    this.idScope = false,
    this.aclGroup,
    this.groupVisibilityControllers = const {},
    this.variants = const [],
    this.direction,
    this.defaultHideUnauthorized = false,
  });

  @override
  State<AclContainer> createState() => _AclContainerState();
}

/// How close two geometry passes must be to count as converged.
///
/// Library-level rather than a class static so the parts that do the
/// arithmetic can name it without qualifying it through the state class,
/// which is not where the number belongs anyway.
const double _geometryEpsilon = 0.5;

/// The cap on convergence iterations, after which the last pass is taken.
const int _maxPreCalcIterations = 20;

class _AclContainerState extends State<AclContainer> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocusWithin = false;
  bool _naturalSizeCacheRefreshScheduled = false;

  /// Cache of measured natural sizes for components with no explicit ACL size
  /// hints. Populated by the post-frame callback; used as the seed for the
  /// pre-calculation loop. Keys are the component's [AclComponent.componentKey].
  final Map<Key, Size> _naturalSizeCache = {};

  /// Measured minimum widths of components whose preferred width was *not*
  /// declared by the author but auto-applied by `AclBuilder`
  /// ([AclComponent.preferredWidthIsDefault]).
  ///
  /// The value is the narrowest width at which the child can be painted without
  /// overflowing — its minimum intrinsic width — reported from layout by
  /// [_AclFloorWidthBox]. Kept apart from [_naturalSizeCache] on purpose: that
  /// cache holds *rendered* sizes of components carrying no ACL hints at all,
  /// and mixing a lower bound into it would change how those are estimated.
  /// Keys are the component's [AclComponent.componentKey].
  final Map<Key, double> _measuredDefaultWidths = {};
  bool _measuredDefaultWidthRebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    _subscribeVisibilityControllers();
  }

  @override
  void dispose() {
    _unsubscribeVisibilityControllers();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AclContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-subscribe if controllers changed.
    if (!identical(
      oldWidget.groupVisibilityControllers,
      widget.groupVisibilityControllers,
    )) {
      _unsubscribeVisibilityControllers(oldWidget.groupVisibilityControllers);
      _subscribeVisibilityControllers();
    }
    // AclBuilder generates new GlobalKeys on every build() call. Transfer
    // cached natural sizes from old keys to new keys by structural position
    // (row index × component index) so there is no one-frame cache-miss lag
    // after a parent rebuild.
    _remapNaturalSizeCacheByPosition(oldWidget.rows, widget.rows);
  }

  /// Rebuilds, for the parts.
  ///
  /// `setState` is `@protected`, which an extension is not entitled to call
  /// even in the same library. One forwarder on the class is the whole cost
  /// of the split, and it names the three places that schedule a rebuild.
  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _buildContent(context);

    // Clip overflow when the available space is smaller than content needs.
    // This prevents visual overflow (paint outside bounds) and replaces the
    // yellow/black striped overflow indicator with a clean clip.
    content = ClipRect(child: content);

    // Container-level height/width constraints. minContW is handled inside
    // _buildContent (inside LayoutBuilder) so expandX/gap use the correct width.
    final minContH =
        widget.minimumContainerSize?.height ??
        widget.preferredContainerSize?.height;
    final maxContW = widget.maximumContainerSize?.width;
    final maxContH = widget.maximumContainerSize?.height;
    if (minContH != null || maxContW != null || maxContH != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minContH ?? 0,
          maxWidth: maxContW ?? double.infinity,
          maxHeight: maxContH ?? double.infinity,
        ),
        child: content,
      );
    }

    // Post-frame: re-measure natural-sized components. If any size changed,
    // trigger one rebuild. This is the ONLY path that reads the render tree.
    _scheduleNaturalSizeCacheRefresh();

    final activeBorderStyle =
        _hasFocusWithin && widget.focusedBorderStyle != null
        ? widget.focusedBorderStyle!
        : widget.borderStyle;

    final hasExplicitPadding = widget.padding != EdgeInsets.zero;
    if (hasExplicitPadding) {
      content = Padding(padding: widget.padding, child: content);
    }

    content = _wrapWithBorder(
      content,
      activeBorderStyle,
      suppressDefaultInsets: hasExplicitPadding,
    );

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (_hasFocusWithin == hasFocus || !mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hasFocusWithin == hasFocus) return;
          setState(() {
            _hasFocusWithin = hasFocus;
          });
        });
      },
      child: content,
    );
  }
}
