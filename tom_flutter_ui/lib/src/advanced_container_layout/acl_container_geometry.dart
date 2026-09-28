/// The geometry pass: the convergence loop, one row's computed layout, the
/// size estimates it rests on, and the anchor arithmetic behind `alignX*` and
/// `alignY*`.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclGeometry on _AclContainerState {
  /// Runs the iterative pre-calculation loop and returns one [_AclRowLayout]
  /// per content row (gap rows are skipped).
  ///
  /// Uses only [_naturalSizeCache] as external input (no render-tree reads).
  /// Iterates up to [_maxPreCalcIterations] times until all values converge
  /// within [_geometryEpsilon].
  List<_AclRowLayout> _runPreCalcLoop({
    required double? effectiveMaxW,
    List<AclRow>? overrideRows,
  }) {
    final rows = overrideRows ?? widget.rows;
    final contentRows = rows.where((r) => !r.isGapRow).toList(growable: false);

    List<_AclRowLayout>? prev;

    for (int iter = 0; iter < _maxPreCalcIterations; iter++) {
      // Cross-row virtual rects accumulated as we process rows in order.
      final crossRowVirtualRects = <Key, Rect>{};
      // For Y-alignment we also need the virtual rects of same-row components
      // that were placed earlier in the row. These are local to each row pass
      // and built up inside _computeRowLayout.

      final current = <_AclRowLayout>[];
      for (final row in contentRows) {
        final layout = _computeRowLayout(
          row: row,
          availableWidth: effectiveMaxW,
          crossRowVirtualRects: crossRowVirtualRects,
        );
        // Publish this row's virtual rects for subsequent rows.
        crossRowVirtualRects.addAll(layout.virtualRects);
        current.add(layout);
      }

      if (prev != null && _hasConverged(prev, current)) {
        return current;
      }
      prev = current;
    }

    return prev!;
  }

  bool _hasConverged(List<_AclRowLayout> a, List<_AclRowLayout> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final ra = a[i];
      final rb = b[i];
      if ((ra.estimatedHeight - rb.estimatedHeight).abs() >= _geometryEpsilon) {
        return false;
      }
      for (final entry in rb.fittedWidths.entries) {
        final prev = ra.fittedWidths[entry.key];
        if (prev == null || (prev - entry.value).abs() >= _geometryEpsilon) {
          return false;
        }
      }
      for (final entry in rb.horizontalDeltas.entries) {
        final prev = ra.horizontalDeltas[entry.key];
        if (prev == null || (prev - entry.value).abs() >= _geometryEpsilon) {
          return false;
        }
      }
      for (final entry in rb.verticalDeltas.entries) {
        final prev = ra.verticalDeltas[entry.key];
        if (prev == null || (prev - entry.value).abs() >= _geometryEpsilon) {
          return false;
        }
      }
    }
    return true;
  }

  /// Pure-Dart computation of layout values for one content row.
  _AclRowLayout _computeRowLayout({
    required AclRow row,
    required double? availableWidth,
    required Map<Key, Rect> crossRowVirtualRects,
  }) {
    final fittedWidths = <int, double>{};
    final horizontalDeltas = <int, double>{};
    final verticalDeltas = <int, double>{};
    final linkedWidths = <int, double>{};
    final linkedHeights = <int, double>{};
    final gapSlotWidths = <int, double>{};
    final virtualRects = <Key, Rect>{};

    // ── Step 0: resolve linked sizes from sameWidthAs / sameHeightAs ─────
    final hasGapSlots = row.components.any((c) => c.isGap);
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (comp.useOtherDimX && comp.referenceKey != null) {
        final refRect = crossRowVirtualRects[comp.referenceKey];
        if (refRect != null) linkedWidths[i] = refRect.width;
      }
      if (comp.useOtherDimY && comp.referenceKey != null) {
        final refRect = crossRowVirtualRects[comp.referenceKey];
        if (refRect != null) linkedHeights[i] = refRect.height;
      }
    }

    // ── Steps 1/2/3: compute fitted widths ───────────────────────────────
    if (availableWidth != null && availableWidth.isFinite) {
      final fw = _computeFittedWidths(
        row: row,
        availableWidth: availableWidth,
        crossRowVirtualRects: crossRowVirtualRects,
        linkedWidths: linkedWidths,
      );
      if (fw != null) fittedWidths.addAll(fw);
    }

    // ── Gap slot widths ───────────────────────────────────────────────────
    if (hasGapSlots && availableWidth != null && availableWidth.isFinite) {
      double totalFitted = 0;
      for (int i = 0; i < row.components.length; i++) {
        final comp = row.components[i];
        if (comp.isGap) continue;
        totalFitted +=
            fittedWidths[i] ??
            linkedWidths[i] ??
            comp.preferredSize?.width ??
            _naturalWidth(comp) ??
            0;
      }
      final gapRemaining = math.max(0.0, availableWidth - totalFitted);
      final gapWeightSum = row.components
          .where((c) => c.isGap)
          .fold(0.0, (s, c) => s + c.gapWeight);
      if (gapWeightSum > 0 && !widget.scrollableX) {
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (!comp.isGap) continue;
          gapSlotWidths[i] = (gapRemaining * comp.gapWeight / gapWeightSum)
              .clamp(0.0, double.infinity);
        }
      }
    }

    // ── Build virtual rects and compute alignment deltas ──────────────────

    // Pre-compute expandX allocations so that virtual rects for non-expandX
    // components positioned AFTER an expandX component use the correct X
    // offsets.  Without this, cross-row alignRightToRight references to
    // components on the right of an expandX field would see the preferred
    // width instead of the actual expanded width, producing wrong deltas.
    //
    // Skip the expandX surplus-distribution entirely when the shrink phase
    // has already produced fitted widths for expandX components (row is
    // narrower than natural) — they're shrinking proportionally toward
    // their minimum via `fittedWidths`, not growing.
    final rowIsShrinking = row.components.any(
      (c) =>
          c.expandX &&
          !c.isGap &&
          fittedWidths.containsKey(row.components.indexOf(c)),
    );
    final expandXWidths = <int, double>{};
    if (!rowIsShrinking && availableWidth != null && availableWidth.isFinite) {
      double fixedWidth = 0;
      double totalExpandXFlex = 0;
      final expandXCompIndices = <int>[];
      final expandXFlexes = <int, double>{};
      for (int i = 0; i < row.components.length; i++) {
        final comp = row.components[i];
        if (comp.isGap) {
          fixedWidth += gapSlotWidths[i] ?? 0;
          continue;
        }
        if (comp.expandX && !comp.isGap) {
          // expandX components share the surplus left over after every
          // non-expandX component has taken its preferred width. Their
          // flex weight mirrors the non-expandX grow phase: (P/M − 1)
          // when both M and P are explicitly set with min < pref, or a
          // small positive fallback so callers who just mark expandX
          // without also configuring M/P still participate in the row.
          final minW = (comp.minimumSize?.width ?? linkedWidths[i] ?? 0).clamp(
            0.0,
            double.maxFinite,
          );
          final prefW = (fittedWidths[i] ?? comp.preferredSize?.width ?? minW)
              .clamp(minW, double.maxFinite);
          double flex;
          if (minW > 0 && prefW > minW) {
            flex = prefW / minW - 1.0;
          } else {
            // Symmetric fallback: when M is unset or M >= P the caller
            // hasn't asked for proportional growth, so every expandX
            // component takes an equal share of whatever surplus exists.
            flex = 1.0;
          }
          flex = (flex.isFinite ? flex : 1.0).clamp(1e-3, 10000.0);
          expandXFlexes[i] = flex;
          expandXCompIndices.add(i);
          totalExpandXFlex += flex;
          // Count the preferred width as the minimum allocation.
          fixedWidth += aclEffectiveGapBefore(comp, row, availableWidth);
        } else {
          final w =
              fittedWidths[i] ??
              linkedWidths[i] ??
              comp.preferredSize?.width ??
              _naturalWidth(comp) ??
              0;
          fixedWidth += w + aclEffectiveGapBefore(comp, row, availableWidth);
        }
      }
      if (expandXCompIndices.isNotEmpty && totalExpandXFlex > 0) {
        final expandPool = math.max(0.0, availableWidth - fixedWidth);
        for (final i in expandXCompIndices) {
          final share = expandPool * (expandXFlexes[i]! / totalExpandXFlex);
          expandXWidths[i] = share.clamp(0.0, double.maxFinite);
        }
      }
    }

    double plannedX = 0;
    double maxHorizontalX = 0;
    double minHorizontalX = 0;
    double rowEstimatedHeight = 0;
    // Same-row virtual rects needed for Y-alignment back-references.
    final sameRowVirtualRects = <Key, Rect>{};

    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];

      if (comp.isGap) {
        plannedX += gapSlotWidths[i] ?? 0;
        maxHorizontalX = math.max(maxHorizontalX, plannedX);
        continue;
      }

      final isFlexNative =
          comp.child is Flexible ||
          comp.child is Expanded ||
          comp.child is Spacer;

      final hasExplicitXAlignment = comp.alignXToKey != null;

      // Check collapseToVisual BEFORE advancing by gapBefore so that explicit
      // gaps (dist:) are never cancelled. When collapsing, the component ends
      // up at (maxHX + gapBefore) — flush with the previous component's visual
      // right edge, plus the requested gap. Both pre-calc and _buildRow emit
      // SizedBox(gapBefore) first, then apply hDelta as a spacer or Transform,
      // so they remain in sync.
      double hDelta = 0;
      final priorPlannedX = plannedX;
      final compEffectiveGap = aclEffectiveGapBefore(comp, row, availableWidth);
      if (compEffectiveGap > 0) {
        plannedX += compEffectiveGap;
      }

      final linkedW = linkedWidths[i];
      final linkedH = linkedHeights[i];

      // Horizontal alignment delta
      if (!isFlexNative &&
          !hasExplicitXAlignment &&
          maxHorizontalX < priorPlannedX) {
        // collapseToVisual: maxHX lags behind the natural planned position.
        // Place component at maxHX + gapBefore by using priorPlannedX as base.
        hDelta = maxHorizontalX - priorPlannedX;
      } else if (hasExplicitXAlignment) {
        // For components with explicit X alignment in rows that do not fill
        // the available width, _buildRow wraps every child with
        // ConstrainedBox(maxWidth: constraints.maxWidth). The actual rendered
        // width is therefore min(preferredWidth, containerWidth). Feed the same
        // effective width into _calcHorizontalDelta so the centre point is right.
        final rowFillsWidth = row.components.any(
          (c) => (c.expandX && !c.isGap) || c.isGap,
        );
        double? alignLinkedW = linkedW;
        if (!rowFillsWidth &&
            alignLinkedW == null &&
            availableWidth != null &&
            availableWidth.isFinite) {
          final pref = comp.preferredSize?.width;
          if (pref != null && pref > availableWidth) {
            alignLinkedW = availableWidth;
          }
        }
        hDelta = _calcHorizontalDelta(
          comp: comp,
          plannedX: plannedX,
          linkedWidth: alignLinkedW,
          virtualRects: sameRowVirtualRects,
          crossRowVirtualRects: crossRowVirtualRects,
          fittedWidths: fittedWidths,
        );
      }
      horizontalDeltas[i] = hDelta;

      // For expandX components, use the pre-computed expanded width so that
      // subsequent components (and cross-row references) see correct offsets.
      final estimatedW =
          expandXWidths[i] ?? _estimateW(comp, linkedW, fittedWidths[i]);
      final estimatedH = _estimateH(comp, linkedH);

      rowEstimatedHeight = math.max(rowEstimatedHeight, estimatedH);

      final shiftedLeft = plannedX + (hDelta < 0 ? hDelta : 0);
      final shiftedRight = shiftedLeft + estimatedW;
      minHorizontalX = math.min(minHorizontalX, shiftedLeft);
      maxHorizontalX = math.max(maxHorizontalX, shiftedRight);

      final key = comp.componentKey;
      if (key != null) {
        final vRect = Rect.fromLTWH(shiftedLeft, 0, estimatedW, estimatedH);
        virtualRects[key] = vRect;
        sameRowVirtualRects[key] = vRect;
      }

      plannedX += (hDelta > 0 ? hDelta : 0) + estimatedW;
    }

    // ── Vertical alignment deltas (same-row) ─────────────────────────────
    // Requires virtual rects to be built first; update them with Y offsets.
    //
    // Virtual rects all have top=0. _buildRow places each non-expandY
    // component at a baseTopInRow that depends on the Row's actual
    // crossAxisAlignment — which in turn comes from
    // row.defaultRowCrossAlignment (top / center / bottom). Adjust the
    // virtual rect Y by that default offset so the delta reflects a
    // shift from the component's rendered position, not from
    // an artificial top=0 or a hardcoded centering assumption.
    final hasRowExpandY = row.components.any((c) => !c.isGap && c.expandY);
    // Per-component rowCrossAlignment lookup: only meaningful when the
    // row is stretched (hasRowExpandY), otherwise every child ends up
    // aligned by the Row's single crossAxisAlignment regardless of the
    // component's own setting — see _wrapWithRowCrossAlignment.
    final keyToComp = <Key, AclComponent>{};
    for (final c in row.components) {
      if (c.componentKey != null) keyToComp[c.componentKey!] = c;
    }
    double defaultTopFor(Rect r, AclComponent? c) {
      if (hasRowExpandY) {
        // Stretch row: the Align wrapper fills row height and the
        // component sits at its own rowCrossAlignment inside that.
        final align = c?.rowCrossAlignment ?? AclRowCrossAlignment.top;
        return switch (align) {
          AclRowCrossAlignment.top => 0.0,
          AclRowCrossAlignment.center => (rowEstimatedHeight - r.height) / 2,
          AclRowCrossAlignment.bottom => rowEstimatedHeight - r.height,
        };
      }
      // Fixed-crossAxis row: Row.crossAxisAlignment dictates placement,
      // not the component's own alignment.
      return switch (row.defaultRowCrossAlignment) {
        AclRowCrossAlignment.top => 0.0,
        AclRowCrossAlignment.center => (rowEstimatedHeight - r.height) / 2,
        AclRowCrossAlignment.bottom => rowEstimatedHeight - r.height,
      };
    }

    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (comp.alignYToKey == null ||
          comp.alignYFrom == null ||
          comp.alignYTo == null ||
          comp.componentKey == null) {
        continue;
      }

      final selfRect = virtualRects[comp.componentKey];
      final refRect =
          sameRowVirtualRects[comp.alignYToKey] ??
          virtualRects[comp.alignYToKey];
      if (selfRect == null || refRect == null) continue;

      final refComp = keyToComp[comp.alignYToKey];

      final adjSelfRect = selfRect.translate(0, defaultTopFor(selfRect, comp));
      final adjRefRect = refRect.translate(0, defaultTopFor(refRect, refComp));

      final selfPoint = _verticalPoint(adjSelfRect, comp.alignYFrom!);
      final refPoint = _verticalPoint(adjRefRect, comp.alignYTo!);
      // Gap convention: positive gap always pushes self further AWAY from
      // the reference edge; negative gap pulls it in (overlap). The sign
      // therefore depends on which side of the reference self lands on.
      //   self.top  → ref.bottom : self is below → +gap pushes down
      //   self.bottom → ref.top : self is above → +gap pushes up
      //   same-ordinal alignments (e.g. TopToTop) preserve the historical
      //   -gap convention so existing call-sites keep behaving the same.
      final signedGap =
          _gapSignY(comp.alignYFrom!, comp.alignYTo!) * comp.alignYGap;
      final delta = (refPoint + signedGap) - selfPoint;
      verticalDeltas[i] = delta;
    }

    return _AclRowLayout(
      fittedWidths: fittedWidths,
      horizontalDeltas: horizontalDeltas,
      verticalDeltas: verticalDeltas,
      linkedWidths: linkedWidths,
      linkedHeights: linkedHeights,
      gapSlotWidths: gapSlotWidths,
      virtualRects: virtualRects,
      estimatedHeight: rowEstimatedHeight,
      minHorizontalX: minHorizontalX,
    );
  }

  // ── Natural size helpers ──────────────────────────────────────────────────

  double? _naturalWidth(AclComponent comp) {
    final key = comp.componentKey;
    if (key == null) return null;
    return _naturalSizeCache[key]?.width ??
        (comp.child is SizedBox ? (comp.child as SizedBox).width : null);
  }

  double? _naturalHeight(AclComponent comp) {
    final key = comp.componentKey;
    if (key == null) return null;
    return _naturalSizeCache[key]?.height;
  }

  double _estimateW(
    AclComponent comp,
    double? linkedWidth,
    double? fittedWidth,
  ) {
    if (fittedWidth != null) return fittedWidth.clamp(0, double.infinity);
    if (linkedWidth != null) return linkedWidth.clamp(0, double.infinity);
    return (comp.preferredSize?.width ??
            comp.minimumSize?.width ??
            _naturalWidth(comp) ??
            0)
        .clamp(0, double.infinity);
  }

  double _estimateH(AclComponent comp, double? linkedHeight) {
    if (linkedHeight != null && linkedHeight > 0) {
      return linkedHeight.clamp(0, double.infinity);
    }
    // Treat preferredSize.height == 0 as "no preference" so the natural
    // height is used.  The auto-default Size(150, 0) must not suppress
    // intrinsic height for labels and other unsized components.
    final prefH = comp.preferredSize?.height;
    if (prefH != null && prefH > 0) return prefH;
    return (comp.minimumSize?.height ?? _naturalHeight(comp) ?? 0).clamp(
      0,
      double.infinity,
    );
  }

  // ── Horizontal delta (pure Dart) ──────────────────────────────────────────

  double _calcHorizontalDelta({
    required AclComponent comp,
    required double plannedX,
    required double? linkedWidth,
    required Map<Key, Rect> virtualRects,
    required Map<Key, Rect> crossRowVirtualRects,
    required Map<int, double> fittedWidths,
  }) {
    if (comp.alignXToKey == null ||
        comp.alignXFrom == null ||
        comp.alignXTo == null) {
      return 0;
    }

    final key = comp.alignXToKey!;
    final refRect = crossRowVirtualRects[key] ?? virtualRects[key];
    if (refRect == null) return 0;

    final widthEstimate =
        linkedWidth ??
        (comp.preferredSize?.width ??
            comp.minimumSize?.width ??
            _naturalWidth(comp) ??
            0);
    final selfPoint =
        plannedX + _horizontalOffset(comp.alignXFrom!, widthEstimate);
    final targetPoint = _horizontalPoint(refRect, comp.alignXTo!);
    // See _gapSignY for the convention — mirrored on the X axis:
    //   self.left → ref.right : self is right of ref → +gap pushes right
    //   self.right → ref.left : self is left of ref → +gap pushes left
    //   same-ordinal alignments keep the historical -gap convention.
    final signedGap =
        _gapSignX(comp.alignXFrom!, comp.alignXTo!) * comp.alignXGap;
    return (targetPoint + signedGap) - selfPoint;
  }

  double _horizontalPoint(Rect rect, AclAxisPointX point) => switch (point) {
    AclAxisPointX.left => rect.left,
    AclAxisPointX.center => rect.center.dx,
    AclAxisPointX.right => rect.right,
  };

  double _verticalPoint(Rect rect, AclAxisPointY point) => switch (point) {
    AclAxisPointY.top => rect.top,
    AclAxisPointY.center => rect.center.dy,
    AclAxisPointY.bottom => rect.bottom,
  };

  int _ordinalY(AclAxisPointY p) => switch (p) {
    AclAxisPointY.top => 0,
    AclAxisPointY.center => 1,
    AclAxisPointY.bottom => 2,
  };

  int _ordinalX(AclAxisPointX p) => switch (p) {
    AclAxisPointX.left => 0,
    AclAxisPointX.center => 1,
    AclAxisPointX.right => 2,
  };

  /// Direction multiplier for `gap` on Y-axis alignments.
  /// +1 when self lands below ref (e.g. TopToBottom) — positive gap pushes down.
  /// -1 when self lands above ref (e.g. BottomToTop) — positive gap pushes up.
  /// -1 (preserving legacy behaviour) for same-ordinal alignments where no
  ///   obvious "away" direction exists (TopToTop, CenterToCenter, BottomToBottom).
  double _gapSignY(AclAxisPointY self, AclAxisPointY ref) {
    final s = _ordinalY(self);
    final r = _ordinalY(ref);
    if (s < r) return 1.0;
    if (s > r) return -1.0;
    return -1.0;
  }

  /// Direction multiplier for `gap` on X-axis alignments — mirror of _gapSignY.
  double _gapSignX(AclAxisPointX self, AclAxisPointX ref) {
    final s = _ordinalX(self);
    final r = _ordinalX(ref);
    if (s < r) return 1.0;
    if (s > r) return -1.0;
    return -1.0;
  }

  double _horizontalOffset(AclAxisPointX point, double width) =>
      switch (point) {
        AclAxisPointX.left => 0,
        AclAxisPointX.center => width / 2,
        AclAxisPointX.right => width,
      };
}
