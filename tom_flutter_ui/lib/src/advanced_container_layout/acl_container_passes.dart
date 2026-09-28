/// The three passes that decide *which rows* exist at this width: a whole
/// variant row set, a row split by breakpoint, and the inline variants that
/// select components within a row.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclRowSelection on _AclContainerState {
  /// Selects the appropriate variant rows based on [availableWidth], or
  /// returns the default [widget.rows] if no variant matches.
  List<AclRow> _selectVariantRows(double? availableWidth) {
    if (widget.variants.isEmpty || availableWidth == null) return widget.rows;
    // Variants are sorted by atWidth ascending. Pick the first (narrowest)
    // whose threshold exceeds availableWidth — this is the most specific match.
    for (final variant in widget.variants) {
      if (availableWidth < variant.atWidth) {
        return variant.rows;
      }
    }
    return widget.rows;
  }

  /// Applies row breakpoints: splits a row into multiple rows when
  /// [availableWidth] drops below the breakpoint threshold.
  List<AclRow> _applyRowBreakpoints(List<AclRow> rows, double? availableWidth) {
    if (availableWidth == null) return rows;
    final result = <AclRow>[];
    for (final row in rows) {
      if (row.isGapRow || row.breakpoints.isEmpty) {
        result.add(row);
        continue;
      }
      // Collect active breakpoints (sorted smallest atWidth first).
      final active =
          row.breakpoints.where((bp) => availableWidth < bp.atWidth).toList()
            ..sort((a, b) => a.splitAfter.compareTo(b.splitAfter));
      if (active.isEmpty) {
        result.add(row);
        continue;
      }
      // Build split indices (1-based → 0-based boundary).
      final splitIndices = <int>{};
      for (final bp in active) {
        splitIndices.add(bp.splitAfter.clamp(1, row.components.length));
      }
      final sorted = splitIndices.toList()..sort();
      int start = 0;
      for (int i = 0; i < sorted.length; i++) {
        final end = sorted[i];
        if (end <= start || end > row.components.length) continue;
        final dist = i == 0
            ? row.gapBefore
            : active
                  .firstWhere(
                    (b) => b.splitAfter == end,
                    orElse: () => active.first,
                  )
                  .splitRowDist;
        // Every fragment keeps everything the row had, including its id: a
        // split is a visual wrap of one logical row, so all fragments resolve
        // the same row policy and contribute the same path segment. Only the
        // components, the leading gap and the now-spent breakpoints differ.
        result.add(
          row.copyWith(
            components: row.components.sublist(start, end),
            gapBefore: i == 0 ? row.gapBefore : dist,
            breakpoints: const [],
          ),
        );
        start = end;
      }
      if (start < row.components.length) {
        result.add(
          row.copyWith(
            components: row.components.sublist(start),
            gapBefore: active.last.splitRowDist,
            breakpoints: const [],
          ),
        );
      }
    }
    return result;
  }

  /// Filters components within each row based on inline variant detectors.
  /// Components not in any variant block are always kept. Components in a
  /// variant block are kept only when their detector is the active one.
  ///
  /// See "Inline Component Variants" (§29) in
  /// `doc/acl_design_specification.md`.
  List<AclRow> _applyInlineVariants(
    List<AclRow> rows,
    AclDeviceContext? deviceContext,
    Acl? acl,
    BuildContext buildContext,
  ) {
    final result = <AclRow>[];
    for (final row in rows) {
      if (row.isGapRow) {
        result.add(row);
        continue;
      }
      final hasInline = row.components.any((c) => c.inlineVariant);
      if (!hasInline) {
        result.add(row);
        continue;
      }

      // Collect unique detectors in declaration order (by identity).
      final detectorOrder = <AclVariantDetector?>[];
      final seen = <AclVariantDetector?>{};
      for (final c in row.components) {
        if (!c.inlineVariant) continue;
        if (seen.add(c.variantDetector)) {
          detectorOrder.add(c.variantDetector);
        }
      }

      // Evaluate non-default detectors in declaration order.
      // First detector returning true wins.
      AclVariantDetector? activeDetector;
      bool matched = false;
      if (deviceContext != null) {
        for (final detector in detectorOrder) {
          if (detector == null) continue; // skip default for now
          if (detector(deviceContext, acl, buildContext)) {
            activeDetector = detector;
            matched = true;
            break;
          }
        }
      }

      // Filter: non-variant components always kept.
      // If a detector matched: keep variant components with that detector.
      // If no detector matched: keep default variant components (null).
      final filtered = row.components.where((c) {
        if (!c.inlineVariant) return true;
        if (matched) return identical(c.variantDetector, activeDetector);
        return c.variantDetector == null;
      }).toList();

      if (filtered.isEmpty) continue;
      result.add(
        // Only the component list changes; everything else is the row's.
        row.copyWith(components: filtered),
      );
    }
    return result;
  }
}
