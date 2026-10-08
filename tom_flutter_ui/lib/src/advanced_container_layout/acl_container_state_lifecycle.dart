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

  /// Every component's preferred width as the whole pre-calculation reads it.
  ///
  /// Two corrections are applied here, once, rather than at the individual
  /// read sites:
  ///
  /// - **A preferred width is never below the minimum.** The specification
  ///   promises the invariant (`doc/acl_design_specification.md` §5b) and the
  ///   builder does not enforce it — `setMSize` stores the minimum and leaves
  ///   the preferred width where it was. A component preferring 150 with a
  ///   minimum of 734 then reads as 150 to the shrink check, which concludes
  ///   the row fits and never shrinks its neighbours toward their own floors.
  ///   Width only: a preferred height of 0 means "intrinsic", which raising it
  ///   would silently change.
  /// - **An auto-defaulted preferred width is widened to its measured
  ///   content.** This is the point at which the default stops being a cap:
  ///   the widened value flows into planned X positions, row estimates, the
  ///   fit/shrink distribution and `getRect()`, so the geometry the engine
  ///   computes in pure Dart stays the geometry that is rendered. The first
  ///   frame has no measurement and uses the plain default; the measurement
  ///   arrives from that frame's layout and the container rebuilds once.
  ///   Until it does — and whenever the row is too tight for the widened
  ///   width — [_AclFloorWidthBox] clips rather than overflows.
  List<AclRow> _resolvePreferredWidths(List<AclRow> rows) {
    List<AclRow>? rewritten;
    for (int ri = 0; ri < rows.length; ri++) {
      final row = rows[ri];
      List<AclComponent>? components;
      for (int ci = 0; ci < row.components.length; ci++) {
        final resolved = _resolvedPreferredWidth(row.components[ci]);
        if (resolved == null) continue;
        components ??= List<AclComponent>.of(row.components);
        components[ci] = resolved;
      }
      if (components == null) continue;
      rewritten ??= List<AclRow>.of(rows);
      rewritten[ri] = row.copyWith(components: components);
    }
    return rewritten ?? rows;
  }

  /// The component with its preferred width raised to its minimum and, when
  /// the width was auto-defaulted, to its measured content — or `null` when
  /// nothing needs to change.
  AclComponent? _resolvedPreferredWidth(AclComponent component) {
    final declared = component.preferredSize?.width;
    if (declared == null) return null;
    var width = math.max(declared, component.minimumSize?.width ?? 0);

    final key = component.componentKey;
    final measured = key == null ? null : _measuredDefaultWidths[key];
    if (component.preferredWidthIsDefault && measured != null) {
      // An author-declared maximum still caps the widening — the auto-applied
      // default is the only thing this pass is allowed to overrule.
      final cap = component.maximumSize?.width;
      width = math.max(
        width,
        (cap != null && cap.isFinite) ? math.min(measured, cap) : measured,
      );
    }
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
