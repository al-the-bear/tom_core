/// Width fitting: how a row's surplus or shortfall is distributed across its
/// components, honouring minimums, maximums, expand flags and gap weights.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclFitting on _AclContainerState {
  /// Returns fitted widths for components that need shrinking or growing to fit
  /// [availableWidth]. Returns `null` if no adjustment is needed.
  ///
  /// [linkedWidths] — pre-resolved sameWidthAs / sameSize widths (index → width).
  Map<int, double>? _computeFittedWidths({
    required AclRow row,
    required double availableWidth,
    required Map<Key, Rect> crossRowVirtualRects,
    Map<int, double> linkedWidths = const {},
  }) {
    double plannedX = 0;
    double minHX = 0;
    double maxHX = 0;
    final vRects = <Key, Rect>{};
    final prefWidths = <int, double>{};

    bool skip(AclComponent c) =>
        c.isGap ||
        c.child is Flexible ||
        c.child is Expanded ||
        c.child is Spacer ||
        c.expandX ||
        c.alignXToKey != null;

    // For the SHRINK phase we include expandX components so they shrink
    // alongside everyone else toward their minimum. In the grow phase
    // they stay out (expandXWidths handles surplus) but once the row is
    // tighter than natural width, treating expandX the same as any other
    // component avoids it collapsing to 0 before the non-expandX
    // neighbours start shrinking.
    bool skipForShrink(AclComponent c) =>
        c.isGap ||
        c.child is Flexible ||
        c.child is Expanded ||
        c.child is Spacer ||
        c.alignXToKey != null;

    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skip(comp)) continue;

      final linkedW =
          linkedWidths[i] ??
          (comp.useOtherDimX
              ? crossRowVirtualRects[comp.referenceKey]?.width
              : null);

      final bool collapseToVisual =
          comp.alignXToKey == null && maxHX < plannedX;
      final effectiveGap = aclEffectiveGapBefore(comp, row, availableWidth);
      if (effectiveGap > 0 && !collapseToVisual) plannedX += effectiveGap;

      final delta = collapseToVisual
          ? (maxHX + effectiveGap - plannedX)
          : _calcHorizontalDelta(
              comp: comp,
              plannedX: plannedX,
              linkedWidth: linkedW,
              virtualRects: vRects,
              crossRowVirtualRects: crossRowVirtualRects,
              fittedWidths: const {},
            );

      if (delta > 0) plannedX += delta;

      final pref =
          (linkedW ?? comp.preferredSize?.width ?? comp.minimumSize?.width ?? 0)
              .clamp(0.0, double.infinity);
      prefWidths[i] = pref;

      // Use non-zero preferredSize.height when set explicitly; otherwise
      // fall through to minimumSize or natural height.  The auto-default
      // Size(150, 0) sets height to 0 which must NOT suppress intrinsic height.
      final prefH = comp.preferredSize?.height;
      final h =
          (prefH != null && prefH > 0
                  ? prefH
                  : (comp.minimumSize?.height ?? _naturalHeight(comp) ?? 0))
              .clamp(0.0, double.infinity);
      final shiftedLeft = plannedX + (delta < 0 ? delta : 0);
      minHX = math.min(minHX, shiftedLeft);
      maxHX = math.max(maxHX, shiftedLeft + pref);

      final key = comp.componentKey;
      if (key != null) vRects[key] = Rect.fromLTWH(shiftedLeft, 0, pref, h);
      plannedX += pref;
    }

    final extraLeft = minHX < 0 ? -minHX : 0.0;
    final naturalWidth = maxHX + extraLeft;

    // Extend natural width to include expandX components' preferred widths
    // (+ the gap before each). The top loop skips expandX so the row is
    // considered to "fit" even when the expandX preferred widths wouldn't.
    // Including them here makes the grow/shrink split respect the
    // caller's preferred widths for every component, not just the
    // non-expandX subset — so shrinking kicks in at the right threshold
    // and expandX joins the shrink distribution from the first pixel of
    // deficit.
    double naturalWithExpandX = naturalWidth;
    final expandXPrefs = <int, double>{};
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (!comp.expandX || comp.isGap) continue;
      if (comp.child is Flexible ||
          comp.child is Expanded ||
          comp.child is Spacer) {
        continue;
      }
      final pref =
          comp.preferredSize?.width ??
          comp.minimumSize?.width ??
          _naturalWidth(comp) ??
          0.0;
      expandXPrefs[i] = pref;
      naturalWithExpandX +=
          pref + aclEffectiveGapBefore(comp, row, availableWidth);
    }

    if (naturalWithExpandX <= availableWidth) {
      // ── Grow phase ─────────────────────────────────────────────────────
      // When there is an expandX (or gap) in the row, non-expandX components
      // stay pinned at their preferred size — surplus flows to the expandX
      // components via `expandXWidths` in _computeRowLayout. When there is
      // no expandX/gap, non-expandX components themselves absorb the surplus
      // so the row always fills the available width.
      //
      // Surplus distribution weight per component is (P/M − 1): components
      // with a larger ratio between preferred and minimum size take a larger
      // share. A component with M=0 (no explicit minimum) falls back to
      // weight 1 so it still participates. Each component is clamped at its
      // maximumSize (if set); any unused growth from clamped components is
      // redistributed by the same rule until no component can absorb more.
      final hasRowFiller = row.components.any(
        (c) => (c.expandX && !c.isGap) || c.isGap,
      );
      if (!hasRowFiller) {
        double naturalExcludedWidth = 0;
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (skip(comp)) continue;
          if (comp.preferredSize != null ||
              comp.minimumSize != null ||
              comp.maximumSize != null ||
              comp.useOtherDimX) {
            continue;
          }
          // Use cached natural width as seed; falls back to 0 on first frame.
          naturalExcludedWidth +=
              _naturalWidth(comp) ??
              (comp.child is SizedBox
                  ? ((comp.child as SizedBox).width ?? 0.0)
                  : 0.0);
        }

        // alignX*-positioned components were excluded from `naturalWidth`
        // (they're placed by cross-row alignment, not sequentially) but
        // they still occupy horizontal space in the row. Count their
        // preferred widths + the gap that precedes them, otherwise the
        // non-aligned growable components would over-grow and push the
        // row past `availableWidth`, producing a visible RenderFlex
        // overflow on layouts like reference_constraints /
        // comprehensive_form.
        double alignedOccupiedWidth = 0;
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (comp.alignXToKey == null) continue;
          if (comp.isGap) continue;
          if (comp.child is Flexible ||
              comp.child is Expanded ||
              comp.child is Spacer) {
            continue;
          }
          final pref =
              comp.preferredSize?.width ??
              comp.minimumSize?.width ??
              _naturalWidth(comp) ??
              0.0;
          alignedOccupiedWidth +=
              pref + aclEffectiveGapBefore(comp, row, availableWidth);
        }

        double surplus = math.max(
          0.0,
          availableWidth -
              naturalWidth -
              naturalExcludedWidth -
              alignedOccupiedWidth,
        );
        if (surplus < 1) return null;

        // Collect growable components and their (P/M − 1) weights. A
        // component participates in horizontal growth only when BOTH a
        // minimum and a preferred width are set with min < pref — that
        // is what defines the growth direction and magnitude in the
        // caller's model. Components without an explicit minimum
        // (setMSize not called) stay pinned at their preferred width;
        // components with min == pref (no growth room) also stay put.
        final growable = <int>[];
        final weights = <int, double>{};
        final currentWidths = <int, double>{};
        for (int i = 0; i < row.components.length; i++) {
          final comp = row.components[i];
          if (skip(comp)) continue;
          if (comp.useOtherDimX) continue;
          final minW = comp.minimumSize?.width;
          final prefW = comp.preferredSize?.width;
          if (minW == null || prefW == null) continue;
          if (!minW.isFinite || minW <= 0) continue;
          if (prefW <= minW) continue;
          final weight = prefW / minW - 1.0;
          if (!weight.isFinite || weight <= 0) continue;
          growable.add(i);
          weights[i] = weight;
          currentWidths[i] = prefWidths[i] ?? prefW;
        }
        if (growable.isEmpty) return null;

        // Iteratively grow. A component that hits its maximumSize drops out
        // of the weighted pool; the remainder keeps sharing the leftover.
        final unclamped = {...growable};
        while (surplus >= 1 && unclamped.isNotEmpty) {
          final weightSum = unclamped.fold<double>(
            0.0,
            (s, i) => s + weights[i]!,
          );
          if (weightSum <= 0) break;
          var distributedThisRound = 0.0;
          // Snapshot to avoid mutating during iteration.
          for (final i in unclamped.toList()) {
            final share = surplus * (weights[i]! / weightSum);
            final max = row.components[i].maximumSize?.width;
            final current = currentWidths[i]!;
            double grown = current + share;
            double actualGrowth = share;
            if (max != null && max.isFinite && grown > max) {
              actualGrowth = math.max(0.0, max - current);
              grown = max;
              unclamped.remove(i);
            }
            currentWidths[i] = grown;
            distributedThisRound += actualGrowth;
          }
          surplus -= distributedThisRound;
          if (distributedThisRound < 0.5) break; // avoid infinite churn
        }
        return currentWidths;
      }
      return null;
    }

    // ── Shrink phase ────────────────────────────────────────────────────────
    // Components shrink from preferred towards minimum. When no explicit
    // minimumSize is set the floor is 0 — NOT preferredSize — so that
    // auto-defaulted components (150×0) can still participate in shrinking.
    //
    // expandX components participate in the shrink phase too: once the
    // row is tighter than natural width they shrink alongside everyone
    // else, proportionally to (pref − min). Otherwise expandX would
    // collapse to 0 (via _computeRowLayout's expandPool clamp) long
    // before the non-expandX neighbours start giving up space.
    final deficit = naturalWithExpandX - availableWidth;
    if (deficit < 1) return null;

    double shrinkCap = 0;
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skipForShrink(comp)) continue;
      if (comp.useOtherDimX) continue;
      final pref = expandXPrefs[i] ?? prefWidths[i] ?? 0.0;
      shrinkCap += math.max(0.0, pref - (comp.minimumSize?.width ?? 0));
    }
    if (shrinkCap < 1) return null;

    final ratio = (deficit / shrinkCap).clamp(0.0, 1.0);
    final fitted = <int, double>{};
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (skipForShrink(comp)) continue;
      if (comp.useOtherDimX) continue;
      if (comp.preferredSize == null && comp.minimumSize == null) continue;
      final pref = expandXPrefs[i] ?? prefWidths[i] ?? 0.0;
      final min = comp.minimumSize?.width ?? 0.0;
      fitted[i] = pref - math.max(0.0, pref - min) * ratio;
    }
    return fitted;
  }

  // ── Border rendering ───────────────────────────────────────────────────────

  /// The width every expandX component takes when the row is not shrinking,
  /// and the width every gap slot takes beside them
  /// (`doc/acl_design_specification.md` §6 Step 3).
  ///
  /// Each expanding component first gets its **floor**: its fitted or linked
  /// width when the layout decided one, otherwise its preferred width, never
  /// below its minimum — a minimum is a floor, and a preferred width with no
  /// minimum doubles as one (`doc/acl_design_specification.md` §5). Only what
  /// is left once every component has its width (the **surplus**) is shared
  /// out:
  ///
  /// - by the growth weight `(preferred / minimum) − 1` when both are
  ///   declared and the minimum is below the preferred width, and by an equal
  ///   weight of 1 otherwise — a component that asked for no proportional
  ///   growth still takes part;
  /// - capped by each component's maximum, the excess going on to the others;
  /// - half of it to the row's gap slots, by slot weight, when there are any.
  ///
  /// When the floors do not fit the shrink phase normally runs instead; if it
  /// did not (its estimate of the neighbours was smaller than the render), the
  /// floors are scaled down proportionally so the row still fits.
  ///
  /// Returns null when the row has no expandX component the layout can size.
  ({Map<int, double> widths, Map<int, double> gapWidths})? _expandXTargets({
    required AclRow row,
    required double availableWidth,
    required Map<int, double> fittedWidths,
    required Map<int, double> linkedWidths,
  }) {
    double fixed = 0;
    final floors = <int, double>{};
    final weights = <int, double>{};
    final caps = <int, double>{};
    final gapIndices = <int>[];
    for (int i = 0; i < row.components.length; i++) {
      final comp = row.components[i];
      if (comp.isGap) {
        gapIndices.add(i);
        continue;
      }
      fixed += aclEffectiveGapBefore(comp, row, availableWidth);
      final flexNative =
          comp.child is Flexible ||
          comp.child is Expanded ||
          comp.child is Spacer;
      if (flexNative) continue;
      if (!comp.expandX) {
        fixed +=
            fittedWidths[i] ??
            linkedWidths[i] ??
            comp.preferredSize?.width ??
            _naturalWidth(comp) ??
            0;
        continue;
      }
      final minW = comp.minimumSize?.width ?? 0;
      final prefW = comp.preferredSize?.width ?? 0;
      final maxW = comp.maximumSize?.width ?? double.infinity;
      final floor = math.min(
        fittedWidths[i] ?? linkedWidths[i] ?? math.max(prefW, minW),
        maxW,
      );
      floors[i] = math.max(0.0, floor);
      caps[i] = maxW;
      final ratio = (minW > 0 && prefW > minW) ? prefW / minW - 1.0 : 1.0;
      weights[i] = ratio.isFinite && ratio > 0 ? ratio : 1.0;
    }
    if (floors.isEmpty) return null;

    final room = math.max(0.0, availableWidth - fixed);
    final floorSum = floors.values.fold(0.0, (s, w) => s + w);
    final widths = <int, double>{};
    final gapWidths = <int, double>{};

    if (floorSum > room) {
      for (final entry in floors.entries) {
        widths[entry.key] = floorSum > 0 ? entry.value * room / floorSum : 0;
      }
      for (final i in gapIndices) {
        gapWidths[i] = 0;
      }
      return (widths: widths, gapWidths: gapWidths);
    }

    var surplus = room - floorSum;
    var gapPool = 0.0;
    if (gapIndices.isNotEmpty && !widget.scrollableX) {
      gapPool = surplus / 2;
      surplus -= gapPool;
    }

    // Water-fill the surplus: share it by weight, cap anyone it would take
    // past their maximum, and share what the caps leave over among the rest.
    widths.addAll(floors);
    final open = floors.keys.toSet();
    while (surplus > 1e-9 && open.isNotEmpty) {
      final total = open.fold(0.0, (s, i) => s + weights[i]!);
      final capped = <int>[];
      for (final i in open) {
        final share = surplus * weights[i]! / total;
        if (widths[i]! + share >= caps[i]!) capped.add(i);
      }
      if (capped.isEmpty) {
        for (final i in open) {
          widths[i] = widths[i]! + surplus * weights[i]! / total;
        }
        surplus = 0;
        break;
      }
      for (final i in capped) {
        surplus -= caps[i]! - widths[i]!;
        widths[i] = caps[i]!;
        open.remove(i);
      }
    }
    // Whatever every capped component left over belongs to the gap slots.
    gapPool += math.max(0.0, surplus);

    if (gapIndices.isNotEmpty) {
      final gapWeightSum = gapIndices.fold(
        0.0,
        (s, i) => s + row.components[i].gapWeight,
      );
      for (final i in gapIndices) {
        gapWidths[i] = gapWeightSum > 0
            ? gapPool * row.components[i].gapWeight / gapWeightSum
            : 0;
      }
    }
    return (widths: widths, gapWidths: gapWidths);
  }
}
