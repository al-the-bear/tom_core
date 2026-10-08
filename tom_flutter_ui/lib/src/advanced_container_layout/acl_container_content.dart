/// Assembling the container's content: the rows that survive every pass, laid
/// out and stacked.
///
/// See `acl_container.dart` for why these are parts rather than libraries.
part of 'acl_container.dart';

extension _AclContent on _AclContainerState {
  Widget _buildContent(BuildContext context) {
    final minContW =
        (widget.minimumContainerSize?.width ??
                widget.preferredContainerSize?.width ??
                0.0)
            .clamp(0.0, double.maxFinite);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawMaxW = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 0.0;
        final effectiveMaxW = math.max(rawMaxW, minContW);
        final canExpandHorizontally = effectiveMaxW > 0;
        final canExpandVertically = constraints.hasBoundedHeight;

        // ── Resolve effective rows (variants → inline → breakpoints) ────
        final variantRows = _selectVariantRows(
          canExpandHorizontally ? effectiveMaxW : null,
        );

        // Only resolve DeviceContext when inline variants exist (avoids
        // unnecessary MediaQuery/Theme subscriptions).
        final hasInlineVariants = variantRows.any(
          (r) => !r.isGapRow && r.components.any((c) => c.inlineVariant),
        );
        AclDeviceContext? deviceCtx;
        Acl? parentAcl;
        if (hasInlineVariants && canExpandHorizontally) {
          deviceCtx = AclDeviceContext.of(
            context,
            width: effectiveMaxW,
            height: canExpandVertically ? constraints.maxHeight : null,
          );
          parentAcl = context.findAncestorWidgetOfExactType<Acl>();
        }
        final inlineFilteredRows = _applyInlineVariants(
          variantRows,
          deviceCtx,
          parentAcl,
          context,
        );
        final breakpointedRows = _applyRowBreakpoints(
          inlineFilteredRows,
          canExpandHorizontally ? effectiveMaxW : null,
        );
        final effectiveRows = _resolvePreferredWidths(
          _applyAuthHiding(breakpointedRows),
        );

        final hasExpandY = effectiveRows.any(
          (row) => !row.isGapRow && row.components.any((c) => c.expandY),
        );
        final hasGapRows =
            effectiveRows.any((row) => row.isGapRow) && !widget.scrollableY;

        final useMaxVertical =
            (hasExpandY || hasGapRows) && canExpandVertically;
        final needsHorizontalScroll =
            !widget.scrollableX &&
            minContW > 0 &&
            constraints.hasBoundedWidth &&
            rawMaxW < minContW;

        // ── Pre-calculation loop ─────────────────────────────────────────
        final rowLayouts = _runPreCalcLoop(
          effectiveMaxW: canExpandHorizontally ? effectiveMaxW : null,
          overrideRows: effectiveRows,
        );

        // ── Global left overflow: uniform visual shift (Transform, not
        //    Padding) keeping everything inside the container without
        //    consuming layout space. ──────────────────────────────────────
        final globalMinHX = rowLayouts.isEmpty
            ? 0.0
            : rowLayouts.map((l) => l.minHorizontalX).reduce(math.min);
        final globalExtraLeft = globalMinHX < 0 ? -globalMinHX : 0.0;

        // ── Assemble Flutter widget tree from pre-computed values ────────
        final List<Widget> rowWidgets = [];
        int contentRowIndex = 0;
        final rowCanExpandVertically =
            canExpandVertically && !widget.scrollableY;

        for (final row in effectiveRows) {
          if (row.isGapRow) {
            if (!widget.scrollableY && canExpandVertically) {
              if (!hasExpandY) {
                // No expandY rows in layout: gap rows expand proportionally.
                final weight = (row.gapRowWeight * 1000).round().clamp(
                  1,
                  1000000,
                );
                final gapContent = row.separator != null
                    ? _buildSeparatorWidget(row.separator!)
                    : const SizedBox.expand();
                rowWidgets.add(
                  Flexible(flex: weight, fit: FlexFit.tight, child: gapContent),
                );
              } else {
                // expandY rows are present: gap rows do NOT compete for the
                // extra vertical space.
                if (row.separator != null) {
                  // Separator: at least 9px (4px pad + line + 4px pad),
                  // or the caller-specified minSize if larger.
                  final sepHeight = math.max(9.0, row.gapRowMinSize);
                  rowWidgets.add(
                    SizedBox(
                      height: sepHeight,
                      child: _buildSeparatorWidget(row.separator!),
                    ),
                  );
                } else if (row.gapRowMinSize > 0) {
                  // Pure spacing gap: collapse unless a minimum was specified.
                  rowWidgets.add(SizedBox(height: row.gapRowMinSize));
                }
              }
            } else {
              // Unbounded or scrollable context: gap rows cannot expand, but
              // still honour minSize as fixed spacing and render separators.
              if (row.separator != null) {
                final sepHeight = math.max(9.0, row.gapRowMinSize);
                rowWidgets.add(
                  SizedBox(
                    height: sepHeight,
                    child: _buildSeparatorWidget(row.separator!),
                  ),
                );
              } else if (row.gapRowMinSize > 0) {
                rowWidgets.add(SizedBox(height: row.gapRowMinSize));
              }
            }
            continue;
          }

          // Row policy gate. Independent of `hideUnauthorized`, which gates
          // `_applyAuthHiding` above — this one fires for any id'd row.
          // Because the `continue` precedes the gapBefore emission below, a
          // denied row takes its own gap with it and the next row keeps its
          // own; `_applyAuthHiding` does the opposite. See
          // `test/advanced_container_layout/acl_auth_visibility_test.dart`.
          TomAuthState? rowAuthState;
          if (row.id != null && row.id!.isNotEmpty) {
            final rowPath = _buildRowPolicyPath(
              rowId: row.id!,
              groupName: _rowGroup(row),
            );
            rowAuthState = TomAuthorization.resolveAuth(rowPath);
            if (!rowAuthState.isVisible) {
              contentRowIndex++;
              continue;
            }
          }

          if (row.gapBefore > 0) {
            rowWidgets.add(SizedBox(height: row.gapBefore));
          }

          final layout = rowLayouts[contentRowIndex++];
          Widget builtRow = _buildRow(
            row: row,
            layout: layout,
            canExpandHorizontally: canExpandHorizontally,
            canExpandVertically: rowCanExpandVertically,
            availableWidth: canExpandHorizontally ? effectiveMaxW : null,
            rowAuthState: rowAuthState,
          );

          // Row IDs do not create new scopes - scoping is external to containers

          final resolvedRowHeight = aclResolveRowHeight(
            row,
            canExpandHorizontally ? effectiveMaxW : null,
          );
          if (resolvedRowHeight != null) {
            builtRow = SizedBox(height: resolvedRowHeight, child: builtRow);
          }

          rowWidgets.add(builtRow);
        }

        final columnMainAxisSize = widget.scrollableY || !useMaxVertical
            ? MainAxisSize.min
            : MainAxisSize.max;

        Widget column = Column(
          mainAxisSize: columnMainAxisSize,
          crossAxisAlignment: canExpandHorizontally
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: rowWidgets,
        );

        // Uniformly shift ALL rows right when any row overflows to the
        // left.  Transform.translate doesn't consume layout space, so
        // expandX / constraints stay correct.
        if (globalExtraLeft > 0) {
          column = Transform.translate(
            offset: Offset(globalExtraLeft, 0),
            child: column,
          );
        }

        if (!canExpandHorizontally) {
          column = UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: column,
          );
        }

        if (needsHorizontalScroll) {
          column = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(width: minContW, child: column),
          );
        }

        if (widget.scrollableY) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: column,
          );
        }

        return column;
      },
    );
  }

  // ── Pre-calculation loop ──────────────────────────────────────────────────
}
