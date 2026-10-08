/// Building one row.
///
/// The largest single piece of the container, and the one that touches the
/// most: gaps, alignment deltas, authorization treatment, measurement
/// wrappers, size constraints and the flex-native children that must reach
/// the `Row` unwrapped.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclRowBuild on _AclContainerState {
  Widget _buildRow({
    required AclRow row,
    required _AclRowLayout layout,
    required bool canExpandHorizontally,
    required bool canExpandVertically,
    double? availableWidth,
    TomAuthState? rowAuthState,
  }) {
    final isRtl =
        (widget.direction ??
            AclDirectionScope.maybeOf(context) ??
            AclDirection.ltr) ==
        AclDirection.rtl;
    final mainAxisAlignment = switch (row.alignment) {
      AclRowAlignment.left => MainAxisAlignment.start,
      AclRowAlignment.center => MainAxisAlignment.center,
      AclRowAlignment.right => MainAxisAlignment.end,
    };

    final hasExpandX = row.components.any((c) => c.expandX && !c.isGap);
    final hasExpandY = row.components.any((c) => c.expandY);
    final hasGapSlots = row.components.any((c) => c.isGap);
    final rowFillsWidth = hasExpandX || hasGapSlots;

    final gapWeightSum = hasGapSlots
        ? row.components
              .where((c) => c.isGap)
              .fold(0.0, (s, c) => s + c.gapWeight)
        : 0.0;

    final children = <Widget>[];
    double plannedX = 0;
    double minHorizontalX = 0;
    double maxHorizontalX = 0;
    double rowEstimatedWidth = 0;
    double minVerticalOffset = 0;
    double maxVerticalExtent = 0;
    final rowEstimatedHeight = layout.estimatedHeight;
    int componentIndex = -1;

    for (final component in row.components) {
      componentIndex++;

      // ── Gap slot ──────────────────────────────────────────────────────────
      if (component.isGap) {
        if (!widget.scrollableX && gapWeightSum > 0) {
          if (rowFillsWidth) {
            final totalExpandXFlex = hasExpandX
                ? row.components.where((c) => c.expandX && !c.isGap).fold(0.0, (
                    s,
                    c,
                  ) {
                    final pref = c.preferredSize?.width ?? 0.0;
                    final min = c.minimumSize?.width ?? 0.0;
                    final diff = pref - min;
                    return s + (diff > 0 && diff.isFinite ? diff : 1000.0);
                  })
                : 0.0;
            final int flex;
            if (totalExpandXFlex > 0) {
              flex = ((component.gapWeight / gapWeightSum) * totalExpandXFlex)
                  .round()
                  .clamp(1, 100000);
            } else {
              flex = (component.gapWeight / gapWeightSum * 10000).round().clamp(
                1,
                10000,
              );
            }
            children.add(Spacer(flex: flex));
          } else {
            final gapWidth = (layout.gapSlotWidths[componentIndex] ?? 0).clamp(
              0.0,
              double.infinity,
            );
            if (gapWidth > 0) children.add(SizedBox(width: gapWidth));
            plannedX += gapWidth;
            maxHorizontalX = math.max(maxHorizontalX, plannedX);
          }
        }
        continue;
      }

      // ── Regular component ─────────────────────────────────────────────────
      final isFlexNativeChild =
          component.child is Flexible ||
          component.child is Expanded ||
          component.child is Spacer;

      final alignmentDelta = layout.horizontalDeltas[componentIndex] ?? 0.0;
      final verticalAlignmentOffset =
          layout.verticalDeltas[componentIndex] ?? 0.0;

      // Always emit gapBefore — the pre-calc always accounts for it in plannedX
      // so the alignmentDelta is always measured from after the gap.
      final renderGap = aclEffectiveGapBefore(component, row, availableWidth);
      if (renderGap > 0) {
        children.add(SizedBox(width: renderGap));
        plannedX += renderGap;
      }

      if (alignmentDelta > 0) {
        children.add(SizedBox(width: alignmentDelta));
        plannedX += alignmentDelta;
      }

      Widget child = component.child;

      // ── Group visibility ──────────────────────────────────────────────────
      final compGroup = _componentGroup(component, row);
      final visMode = _groupMode(compGroup);
      if (visMode == AclGroupVisibilityMode.hidden) {
        // Hidden: zero size, skip the component entirely.
        children.add(const SizedBox.shrink());
        continue;
      }

      // Component policy gate. Like the row gate, independent of
      // `hideUnauthorized`. `renderGap` above has already been emitted by the
      // time we get here, and the next component emits its own, so a denied
      // component reclaims its width and leaves *both* gaps — the mirror of
      // `_applyAuthHiding`, which forwards one gap and drops the other.
      String? componentPolicyPath;
      TomAuthState? authState;
      if (component.id != null && component.id!.isNotEmpty) {
        componentPolicyPath = _buildComponentPolicyPath(
          componentId: component.id!,
          groupName: compGroup,
          row: row,
        );
        authState = TomAuthorization.resolveAuth(componentPolicyPath);
        if (!authState.isVisible) {
          children.add(const SizedBox.shrink());
          continue;
        }
      }

      // Wrap with AclScope to provide ID/group metadata — but not around a
      // flex-native child. `Flexible`, `Expanded` and `Spacer` are
      // `ParentDataWidget`s that must be the Row's direct child; anything
      // between them and the Row makes applying their parent data an
      // assertion. That is why every sizing and alignment wrapper below is
      // guarded the same way.
      if (!isFlexNativeChild) {
        child = _wrapWithScope(
          child,
          component,
          row,
          groupName: compGroup,
          fullPath: componentPolicyPath,
        );
      }

      // ── Withheld treatment, decided once and applied once ────────────────
      // Three inputs can withhold this component: the row's grant, its own
      // grant, and the runtime mode of its group. They are different *axes* —
      // two are policy, one is an application toggle — but they are not
      // different *looks*: a user cannot tell from the pixels why a control is
      // inert, and must not be shown two shades of "off" in one container.
      //
      // So they are folded into a single effective state with `narrow`, whose
      // ordering (none < disabled < read < full) makes the most restrictive
      // input win, and rendered through the theme. Folding first is what stops
      // a row and a component that both withhold from stacking their
      // treatments into a doubly-dimmed component.
      var effectiveAuth = (rowAuthState ?? TomAuthState.full).narrow(
        authState ?? TomAuthState.full,
      );
      if (visMode == AclGroupVisibilityMode.disabled) {
        effectiveAuth = effectiveAuth.narrow(TomAuthState.disabled);
      }
      // `none` is unreachable: both gates above already returned for it. The
      // local binding keeps the callback from closing over `child` while
      // `child` is the very thing being reassigned.
      final laidOut = child;
      child = TomThemeScope.applyAuthState(
        context,
        effectiveAuth,
        () => laidOut,
      );

      // ── Auto-defaulted width: measure, and never overflow ────────────────
      // Innermost wrapper, so it sees the component's own content and receives
      // whatever width the sizing wrappers below settle on. Only components
      // whose preferred width the builder invented get it; an author-declared
      // width is emitted unchanged.
      if (!isFlexNativeChild &&
          component.preferredWidthIsDefault &&
          component.componentKey != null) {
        final measureKey = component.componentKey!;
        child = _AclFloorWidthBox(
          onMinWidth: (minWidth) =>
              _reportMeasuredDefaultWidth(measureKey, minWidth),
          child: child,
        );
      }

      final linkedWidth = layout.linkedWidths[componentIndex];
      final linkedHeight = layout.linkedHeights[componentIndex];
      final fittedWidth = layout.fittedWidths[componentIndex];

      final minWidth = component.useOtherDimX
          ? (linkedWidth ??
                component.minimumSize?.width ??
                component.preferredSize?.width)
          : (component.minimumSize?.width ?? component.preferredSize?.width);
      final safePrefH =
          (component.preferredSize?.height != null &&
              component.preferredSize!.height > 0)
          ? component.preferredSize!.height
          : null;
      final minHeight = component.useOtherDimY
          ? ((linkedHeight != null && linkedHeight > 0 ? linkedHeight : null) ??
                component.minimumSize?.height ??
                safePrefH)
          : (component.minimumSize?.height ?? safePrefH);
      // For useOtherDimX components whose reference is not yet resolved (first frame),
      // fall back to availableWidth as maxWidth — prevents TextField/Dropdown
      // "unbounded width" assertion inside Row(mainAxisSize.max) rows.
      final maxWidth = component.useOtherDimX
          ? (linkedWidth ??
                component.maximumSize?.width ??
                (availableWidth?.isFinite == true ? availableWidth : null))
          : component.maximumSize?.width;
      // Skip linkedHeight of 0 for maxHeight — on the first frame the
      // reference component may have height 0 (auto-default Size(150,0))
      // and constraining sameHeightAs followers to maxHeight:0 would collapse
      // them.  After the natural-size cache populates, linkedHeight becomes
      // the real rendered height and the constraint is correct.
      final maxHeight = component.useOtherDimY
          ? ((linkedHeight != null && linkedHeight > 0 ? linkedHeight : null) ??
                component.maximumSize?.height)
          : component.maximumSize?.height;

      if (!isFlexNativeChild &&
          (minWidth != null ||
              minHeight != null ||
              maxWidth != null ||
              maxHeight != null)) {
        child = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth ?? 0,
            minHeight: minHeight ?? 0,
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: child,
        );
      }

      // ── Height wrapping (BEFORE width) ──────────────────────────────────
      // Height wrapping is applied first so that the width SizedBox ends up
      // on the outside.  This is critical for vertical centering: the inner
      // Column(CrossAxisAlignment.stretch) inherits the tight width
      // constraint from the outer SizedBox(width:), preserving correct
      // widths for both expandX and non-expandX components.
      if (!isFlexNativeChild && (!component.expandY || !canExpandVertically)) {
        // Treat preferredSize.height == 0 as "no height preference" so that
        // auto-defaulted components use intrinsic height instead of being
        // constrained to 0.
        final rawPrefH = component.preferredSize?.height;
        final effectiveHeight =
            (linkedHeight != null && linkedHeight > 0 ? linkedHeight : null) ??
            (rawPrefH != null && rawPrefH > 0 ? rawPrefH : null);
        if (effectiveHeight != null) {
          // For expandX components, do NOT wrap with Column(stretch) — it
          // would override the ConstrainedBox's maxWidth since the Align
          // layers above loosen the Flexible's tight constraint, and
          // Column(stretch) re-tightens to whatever its parent gives.
          // Non-expandX components have an outer SizedBox(width:) that
          // supplies the correct tight width for Column(stretch).
          if (component.expandX && canExpandHorizontally) {
            child = SizedBox(height: effectiveHeight, child: child);
          } else {
            // Vertically centre content inside the allocated height.
            // Column with CrossAxisAlignment.stretch preserves the parent's
            // tight width constraint from the outer SizedBox(width:).
            // Flexible(loose) prevents the child from exceeding the Column's
            // height when the inner ConstrainedBox has a larger maxHeight.
            final verticalAlign = switch (component.rowCrossAlignment) {
              AclRowCrossAlignment.top => MainAxisAlignment.start,
              AclRowCrossAlignment.center => MainAxisAlignment.center,
              AclRowCrossAlignment.bottom => MainAxisAlignment.end,
            };
            child = SizedBox(
              height: effectiveHeight,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: verticalAlign,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Flexible(child: child)],
              ),
            );
          }
        }
      }

      // ── Width wrapping (OUTSIDE height) ─────────────────────────────────
      // When fittedWidth is set for an expandX component, the shrink
      // phase has decided that component's width — we must respect it
      // (in particular the minimumSize floor) instead of handing the
      // rest of this method's expandX-only path over to Flexible, which
      // would pull the component below its minimum whenever the row is
      // tighter than the sum of shrunken widths.
      final expandXShrinking =
          component.expandX && canExpandHorizontally && fittedWidth != null;
      if (!isFlexNativeChild &&
          (!component.expandX || !canExpandHorizontally || expandXShrinking)) {
        final effectiveWidth =
            fittedWidth ?? linkedWidth ?? component.preferredSize?.width;
        if (effectiveWidth != null) {
          child = SizedBox(width: effectiveWidth, child: child);
        }
      }

      final hasFiniteMaxWidth =
          (component.maximumSize?.width ?? double.infinity).isFinite;
      if (!isFlexNativeChild &&
          component.expandX &&
          canExpandHorizontally &&
          !expandXShrinking &&
          !hasFiniteMaxWidth) {
        child = SizedBox(width: double.infinity, child: child);
      }

      final estimatedWidth = _estimateW(component, linkedWidth, fittedWidth);
      final estimatedHeight = _estimateH(component, linkedHeight);

      final shiftedLeftInRow =
          plannedX + (alignmentDelta < 0 ? alignmentDelta : 0);
      final shiftedRightInRow = shiftedLeftInRow + estimatedWidth;
      minHorizontalX = math.min(minHorizontalX, shiftedLeftInRow);
      maxHorizontalX = math.max(maxHorizontalX, shiftedRightInRow);
      rowEstimatedWidth = math.max(
        rowEstimatedWidth,
        plannedX + estimatedWidth,
      );

      // NOTE: componentKey wrapping is now done AFTER transforms to ensure
      // getRect() returns the visually transformed position.

      // Skip cross-alignment wrapping for expandY components — they are
      // stretched by CrossAxisAlignment.stretch and must not have their
      // height constraints loosened by an Align(heightFactor:1) wrapper.
      if (!isFlexNativeChild && !(component.expandY && canExpandVertically)) {
        child = _wrapWithRowCrossAlignment(child, component.rowCrossAlignment);
      }

      if (!isFlexNativeChild && alignmentDelta < 0) {
        child = Transform.translate(
          offset: Offset(alignmentDelta, 0),
          child: child,
        );
      }

      // baseTopInRow must match where the Row widget actually places the
      // component cross-axis. With CrossAxisAlignment.stretch (hasExpandY
      // path), every child starts at y=0 and fills the row height. Without
      // expandY, the Row's crossAxisAlignment is driven by the row's
      // configured defaultRowCrossAlignment (top/center/bottom) — NOT a
      // hardcoded centering — otherwise the min/maxVerticalExtent that
      // drive Padding(top/bottom) over-/under-estimate the space needed
      // around translated components.
      final double baseTopInRow;
      if (hasExpandY && canExpandVertically) {
        baseTopInRow = 0.0;
      } else {
        baseTopInRow = switch (row.defaultRowCrossAlignment) {
          AclRowCrossAlignment.top => 0.0,
          AclRowCrossAlignment.center =>
            (rowEstimatedHeight - estimatedHeight) / 2,
          AclRowCrossAlignment.bottom => rowEstimatedHeight - estimatedHeight,
        };
      }
      final shiftedTopInRow = baseTopInRow + verticalAlignmentOffset;
      final shiftedBottomInRow = shiftedTopInRow + estimatedHeight;

      minVerticalOffset = math.min(minVerticalOffset, shiftedTopInRow);
      maxVerticalExtent = math.max(maxVerticalExtent, shiftedBottomInRow);

      if (!isFlexNativeChild && verticalAlignmentOffset != 0) {
        child = Transform.translate(
          offset: Offset(0, verticalAlignmentOffset),
          child: child,
        );
      }

      // Wrap with componentKey AFTER transforms so getRect() sees final position.
      if (!isFlexNativeChild && component.componentKey != null) {
        if (component.expandY && canExpandVertically) {
          // expandY: use a transparent SizedBox to carry the key without
          // loosening the cross-axis (height) constraints that allow this
          // component to fill the row.
          child = SizedBox(key: component.componentKey, child: child);
        } else {
          child = Align(
            key: component.componentKey,
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          );
        }
      }

      if (component.expandX && canExpandHorizontally && !expandXShrinking) {
        // Use isFlexNativeChild (checked on component.child) since `child`
        // may have been wrapped with AclScope and other widgets by now.
        if (!isFlexNativeChild) {
          final minW = (component.minimumSize?.width ?? linkedWidth ?? 0).clamp(
            0.0,
            double.maxFinite,
          );
          final prefW = (fittedWidth ?? component.preferredSize?.width ?? minW)
              .clamp(minW, double.maxFinite);
          final diff = prefW - minW;
          final flexWeight = (diff.isFinite ? diff.round() : 1000).clamp(
            1,
            10000,
          );
          child = Flexible(flex: flexWeight, fit: FlexFit.tight, child: child);
        }
      }

      children.add(child);
      plannedX += estimatedWidth;
    }

    // ── Row widget assembly ───────────────────────────────────────────────────

    Widget rowWidget;
    // No per-row horizontal compensation — cross-row alignment requires
    // all rows to share the same coordinate origin.  A global
    // Transform.translate on the containing Column handles left overflow.
    final double extraLeft = 0.0;

    if (!rowFillsWidth && canExpandHorizontally) {
      rowWidget = LayoutBuilder(
        builder: (context, constraints) {
          final boundedChildren = children
              .map(
                (child) => child is Flexible || child is Spacer
                    ? child
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: child,
                      ),
              )
              .toList();

          final rowContent = Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: _resolveRowCrossAxis(
              row.defaultRowCrossAlignment,
              hasExpandY: hasExpandY,
              canExpandVertically: canExpandVertically,
            ),
            mainAxisSize: MainAxisSize.min,
            children: boundedChildren,
          );

          final alignment = switch (mainAxisAlignment) {
            MainAxisAlignment.end ||
            MainAxisAlignment.spaceBetween ||
            MainAxisAlignment.spaceAround ||
            MainAxisAlignment.spaceEvenly => AlignmentDirectional.centerEnd,
            MainAxisAlignment.center => Alignment.center,
            _ => AlignmentDirectional.centerStart,
          };

          return widget.scrollableX
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: rowContent,
                )
              : Align(alignment: alignment, child: rowContent);
        },
      );
    } else {
      rowWidget = Row(
        mainAxisAlignment: hasGapSlots
            ? MainAxisAlignment.start
            : mainAxisAlignment,
        crossAxisAlignment: _resolveRowCrossAxis(
          row.defaultRowCrossAlignment,
          hasExpandY: hasExpandY,
          canExpandVertically: canExpandVertically,
        ),
        mainAxisSize: rowFillsWidth && canExpandHorizontally
            ? MainAxisSize.max
            : MainAxisSize.min,
        children: children,
      );
    }

    final double extraTop = minVerticalOffset < 0 ? -minVerticalOffset : 0.0;
    final extraBottom = math.max(0.0, maxVerticalExtent - rowEstimatedHeight);
    final extraRight = rowFillsWidth && canExpandHorizontally
        ? 0.0
        : math.max(0.0, maxHorizontalX - rowEstimatedWidth);
    if (extraTop > 0 || extraBottom > 0 || extraLeft > 0 || extraRight > 0) {
      rowWidget = Padding(
        padding: EdgeInsets.only(
          left: extraLeft,
          right: extraRight,
          top: extraTop,
          bottom: extraBottom,
        ),
        child: rowWidget,
      );
    }

    if (!rowFillsWidth && canExpandHorizontally && extraLeft > 0) {
      rowWidget = ClipRect(child: rowWidget);
    }

    // Wrap with an explicit Directionality rather than inheriting the
    // ambient one, so the resolved AclDirection controls component flow even
    // when it opposes the surrounding app.
    rowWidget = Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: rowWidget,
    );

    if (hasExpandY && canExpandVertically) {
      int rowFlex = 1;
      for (final component in row.components) {
        if (!component.expandY) continue;
        final linkedH = layout.linkedHeights[row.components.indexOf(component)];
        final minH = (component.minimumSize?.height ?? linkedH ?? 0).clamp(
          0,
          double.infinity,
        );
        final prefH = (component.preferredSize?.height ?? minH).clamp(
          minH,
          double.infinity,
        );
        rowFlex = (rowFlex + (prefH - minH).round()).clamp(1, 10000);
      }
      return Flexible(flex: rowFlex, fit: FlexFit.tight, child: rowWidget);
    }

    return rowWidget;
  }
}
