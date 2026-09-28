/// Subscriptions and the two measurement caches: the natural-size cache the
/// container remaps across rebuilds, and the widths an auto-defaulted
/// component reports back after its first layout.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclStateLifecycle on _AclContainerState {
  void _subscribeVisibilityControllers([
    Map<String, AclGroupVisibilityController>? controllers,
  ]) {
    for (final ctrl
        in (controllers ?? widget.groupVisibilityControllers).values) {
      ctrl.modeNotifier.addListener(_onVisibilityChanged);
    }
  }

  void _unsubscribeVisibilityControllers([
    Map<String, AclGroupVisibilityController>? controllers,
  ]) {
    for (final ctrl
        in (controllers ?? widget.groupVisibilityControllers).values) {
      ctrl.modeNotifier.removeListener(_onVisibilityChanged);
    }
  }

  void _onVisibilityChanged() {
    _rebuild();
  }

  void _remapNaturalSizeCacheByPosition(
    List<AclRow> oldRows,
    List<AclRow> newRows,
  ) {
    final newCache = <Key, Size>{};
    final newMeasured = <Key, double>{};
    final minRows = math.min(oldRows.length, newRows.length);
    for (int ri = 0; ri < minRows; ri++) {
      final oldComps = oldRows[ri].components;
      final newComps = newRows[ri].components;
      final len = math.min(oldComps.length, newComps.length);
      for (int ci = 0; ci < len; ci++) {
        final oldKey = oldComps[ci].componentKey;
        final newKey = newComps[ci].componentKey;
        if (newKey == null) continue;
        final sz = oldKey != null ? _naturalSizeCache[oldKey] : null;
        if (sz != null) newCache[newKey] = sz;
        final measured = oldKey != null ? _measuredDefaultWidths[oldKey] : null;
        if (measured != null) newMeasured[newKey] = measured;
      }
    }
    _naturalSizeCache
      ..clear()
      ..addAll(newCache);
    _measuredDefaultWidths
      ..clear()
      ..addAll(newMeasured);
  }

  // ── Auto-defaulted preferred widths ───────────────────────────────────────

  /// Records the minimum width [key]'s child needs, reported from layout by
  /// [_AclFloorWidthBox].
  ///
  /// Called during layout, so the rebuild it may need is deferred to the next
  /// frame — the same post-frame discipline the natural-size cache uses.
  void _reportMeasuredDefaultWidth(Key key, double minWidth) {
    if (!minWidth.isFinite || minWidth < 0) return;
    final previous = _measuredDefaultWidths[key];
    if (previous != null && (previous - minWidth).abs() < _geometryEpsilon) {
      return;
    }
    _measuredDefaultWidths[key] = minWidth;
    if (_measuredDefaultWidthRebuildScheduled) return;
    _measuredDefaultWidthRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuredDefaultWidthRebuildScheduled = false;
      _rebuild();
    });
  }

  /// Widens components whose preferred width was auto-defaulted and whose
  /// content has been measured as needing more than the default.
  ///
  /// This is the point at which the default stops being a cap: the widened
  /// value flows into the *whole* pre-calculation — planned X positions, row
  /// estimates, the fit/shrink distribution and `getRect()` — so the geometry
  /// the engine computes in pure Dart stays the geometry that is rendered.
  /// Widening here rather than at the individual read sites is what keeps that
  /// true: a component is one declared width to everything downstream.
  ///
  /// The first frame has no measurement and uses the plain default; the
  /// measurement arrives from that frame's layout and the container rebuilds
  /// once. Until it does — and whenever the row is too tight for the widened
  /// width — [_AclFloorWidthBox] clips rather than overflows.
  List<AclRow> _applyMeasuredDefaultWidths(List<AclRow> rows) {
    if (_measuredDefaultWidths.isEmpty) return rows;
    List<AclRow>? rewritten;
    for (int ri = 0; ri < rows.length; ri++) {
      final row = rows[ri];
      List<AclComponent>? components;
      for (int ci = 0; ci < row.components.length; ci++) {
        final widened = _widenedByMeasurement(row.components[ci]);
        if (widened == null) continue;
        components ??= List<AclComponent>.of(row.components);
        components[ci] = widened;
      }
      if (components == null) continue;
      rewritten ??= List<AclRow>.of(rows);
      rewritten[ri] = row.copyWith(components: components);
    }
    return rewritten ?? rows;
  }

  /// The component with its auto-defaulted preferred width raised to the
  /// measured minimum, or `null` when nothing needs to change.
  AclComponent? _widenedByMeasurement(AclComponent component) {
    if (!component.preferredWidthIsDefault) return null;
    final key = component.componentKey;
    final declared = component.preferredSize?.width;
    if (key == null || declared == null) return null;
    final measured = _measuredDefaultWidths[key];
    if (measured == null) return null;
    // An author-declared maximum still caps the widening — the auto-applied
    // default is the only thing this pass is allowed to overrule.
    final cap = component.maximumSize?.width;
    final width = (cap != null && cap.isFinite)
        ? math.min(measured, cap)
        : measured;
    if (width <= declared + _geometryEpsilon) return null;
    return component.copyWith(
      preferredSize: Size(width, component.preferredSize!.height),
    );
  }

  void _scheduleNaturalSizeCacheRefresh() {
    if (_naturalSizeCacheRefreshScheduled) return;
    _naturalSizeCacheRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _naturalSizeCacheRefreshScheduled = false;
      if (!mounted) return;

      bool changed = false;
      for (final row in widget.rows) {
        for (final comp in row.components) {
          final key = comp.componentKey;
          if (key is! GlobalKey) continue;
          // Only refresh entries for natural-sized components (no ACL hints).
          // Explicitly-sized components never enter the cache.
          if (comp.preferredSize != null ||
              comp.minimumSize != null ||
              comp.maximumSize != null ||
              comp.useOtherDimX ||
              comp.useOtherDimY) {
            continue;
          }

          final ctx = key.currentContext;
          final ro = ctx?.findRenderObject();
          if (ro is! RenderBox || !ro.hasSize) continue;
          final size = ro.size;
          final cached = _naturalSizeCache[key];
          if (cached == null ||
              (cached.width - size.width).abs() >= _geometryEpsilon ||
              (cached.height - size.height).abs() >= _geometryEpsilon) {
            _naturalSizeCache[key] = size;
            changed = true;
          }
        }
      }

      if (changed) _rebuild();
    });
  }

  // ── Fitted width calculation (pure Dart — no render tree reads) ─────────────
}
