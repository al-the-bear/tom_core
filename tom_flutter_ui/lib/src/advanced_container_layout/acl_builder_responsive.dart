part of 'acl_builder.dart';

/// Responding to the space available: alternative layouts, row breakpoints
/// and inline component variants.
extension AclBuilderResponsive on AclBuilder {
  // ── Responsive Variants ────────────────────────────────────────────────────

  /// Registers a replacement row tree used when the container's available
  /// width drops below [atWidth]. Variants are matched narrowest-first, so the
  /// most specific one wins.
  ///
  /// **The variant builder does not inherit this builder's defaults.** It is a
  /// fresh [AclBuilder], so every `setAclDefault*` value configured here —
  /// append gap, row gap, row height, row alignments, flags, unknown preferred
  /// and minimum sizes — is back at its framework default inside [builder].
  /// Restate the ones the variant needs:
  ///
  /// ```dart
  /// AclBuilder()
  ///     .setAclDefaultAppendGap(16)
  ///     .append(street).append(number)
  ///     .addVariant('narrow', atWidth: 480, builder: (b) => b
  ///         .setAclDefaultAppendGap(16)   // restate: not inherited
  ///         .append(street)
  ///         .newRow()
  ///         .append(number));
  /// ```
  ///
  /// The container's *chrome* — border, padding, background, title — is
  /// unaffected by which variant is active, because it belongs to the
  /// container rather than to any row tree. A variant supplies rows and
  /// nothing else.
  ///
  /// `test/advanced_container_layout/acl_variant_inheritance_test.dart` pins
  /// both halves of this.
  /// Copies every builder-wide **row-level** default onto [target].
  ///
  /// Used by [addVariant] so a variant's rows are built against the same
  /// defaults as the container's own. Each field here is one a row or a
  /// component reads while it is being appended; a field the container reads at
  /// [build] time is deliberately absent, and
  /// `test/advanced_container_layout/acl_variant_inheritance_test.dart`
  /// classifies every `_default*` field one way or the other, so a new one
  /// cannot quietly be neither.
  ///
  /// [target] must be freshly constructed and untouched: the row alignment is
  /// stamped onto a row when the row is *created*, and the constructor has
  /// already created the first one, so this restamps it. A target that had
  /// rows appended would have them silently realigned.
  void _copyRowDefaultsTo(AclBuilder target) {
    target._defaultFlags = _defaultFlags;
    target._defaultAppendGap = _defaultAppendGap;
    target._defaultAppendGapBpOverrides = _defaultAppendGapBpOverrides;
    target._defaultRowHeight = _defaultRowHeight;
    target._defaultRowHeightBpOverrides = _defaultRowHeightBpOverrides;
    target._defaultRowGap = _defaultRowGap;
    target._defaultUnknownMinimumSize = _defaultUnknownMinimumSize;
    target._defaultUnknownPreferredSize = _defaultUnknownPreferredSize;
    target._defaultRowVerticalAlignment = _defaultRowVerticalAlignment;
    target._defaultRowHorizontalAlignment = _defaultRowHorizontalAlignment;
    // The alignment is applied at row *creation*, and the target's first row
    // was created by its constructor — before these defaults arrived. Later
    // rows pick it up from `newRow`; this one has to be told.
    target._currentRow.alignment = _defaultRowHorizontalAlignment;
  }

  AclBuilder addVariant(
    String name, {
    required double atWidth,
    required void Function(AclBuilder) builder,
  }) {
    // The variant restates its rows; it does not restate the defaults those
    // rows are built against. Copying them across *before* the callback runs
    // is what makes that true: `append` and `newRow` read these as they go, so
    // a default set afterwards would not reach the rows already built. An
    // explicit setting inside the variant still wins — it simply overwrites
    // the inherited value on the way past.
    //
    // Only row-level defaults travel. The container's own settings — chrome,
    // `aclId`, `idScope`, `aclGroup`, `defaultHideUnauthorized` — are read
    // from *this* builder when `build()` runs and land on the container
    // widget, which a variant never replaces: `_selectVariantRows` swaps the
    // row list and nothing else. They already apply to variant rows, so
    // copying them here would be a second channel to the same place.
    final variantBuilder = AclBuilder();
    _copyRowDefaultsTo(variantBuilder);
    builder(variantBuilder);
    // Why: the variant's rows are harvested straight out of the throwaway
    // builder, so nothing else ever calls the finalization `build()` performs.
    // Without it the last component appended inside the variant keeps a null
    // preferred size and never carries `preferredWidthIsDefault` — which is the
    // flag that puts it inside the measure/clip box. It would then lay out
    // unclipped on the first frame, before any measurement exists, and overflow
    // for exactly that frame.
    variantBuilder._finalizeCurrentComponent();
    _variants.add(
      AclVariant(
        name: name,
        atWidth: atWidth,
        rows: variantBuilder._rows
            .map(
              (r) => r.toRow(
                defaultAppendGap: variantBuilder._defaultAppendGap,
                defaultAppendGapBpOverrides:
                    variantBuilder._defaultAppendGapBpOverrides,
                fallbackHeight: variantBuilder._defaultRowHeight,
                fallbackHeightBpOverrides:
                    variantBuilder._defaultRowHeightBpOverrides,
                defaultRowCrossAlignment:
                    variantBuilder._defaultRowVerticalAlignment,
              ),
            )
            .toList(),
      ),
    );
    return this;
  }

  // ── Row Breakpoints ────────────────────────────────────────────────────────

  /// Adds a row breakpoint at the current position in the builder chain.
  ///
  /// The split index is calculated from the number of components appended so
  /// far. Call this **between** `append()` calls to indicate where the row
  /// should break when the container width drops below [atWidth].
  AclBuilder addRowBreakpoint({
    required double atWidth,
    double splitRowDist = 0,
  }) {
    _currentRow.breakpoints.add(
      AclRowBreakpoint(
        atWidth: atWidth,
        splitAfter: _currentRow.components.length,
        splitRowDist: splitRowDist,
      ),
    );
    return this;
  }

  // ── Inline Component Variants ──────────────────────────────────────────────

  /// Opens a block whose appended components belong to one device variant.
  ///
  /// Everything appended until the matching [endVariant] is tagged with a
  /// single detector. At layout time the container evaluates each row's
  /// variants **in declaration order and keeps the first that matches**;
  /// components of the losing variants are dropped from that row entirely.
  ///
  /// A `startVariant()` with no arguments builds no detector and marks its
  /// components as the **default variant**. It is not part of that ordered
  /// race — it is the fallback taken when no gated variant matched, so it may
  /// be declared anywhere in the row. It is also what shows when the container
  /// has no device context to test against at all, which happens whenever the
  /// incoming constraints have unbounded *width*.
  ///
  /// The named facets are forwarded to
  /// [AclDeviceContext.buildConvenienceDetector] and combine with AND. Read its
  /// documentation before gating on [height] in particular: an unbounded
  /// container reports an unknown height, which **fails** the facet, so a
  /// height-gated variant never activates while the container shrink-wraps.
  ///
  /// Passing [detector] supplies the predicate directly and ignores every named
  /// facet — use it for conditions the convenience parameters cannot express.
  ///
  /// Throws [StateError] when a variant block is already open.
  AclBuilder startVariant({
    double? width,
    double? height,
    AclInputMode? input,
    AclFormFactor? formFactor,
    Orientation? orientation,
    Set<TargetPlatform>? platforms,
    bool? isWeb,
    AclDensity? density,
    TextDirection? textDirection,
    double? minAccessibilityScale,
    AclVariantDetector? detector,
  }) {
    if (_inVariantBlock) {
      throw StateError(
        'AclBuilder.startVariant(): already inside a variant block. '
        'Call endVariant() before starting a new one.',
      );
    }
    _inVariantBlock = true;
    _currentVariantDetector =
        detector ??
        AclDeviceContext.buildConvenienceDetector(
          width: width,
          height: height,
          input: input,
          formFactor: formFactor,
          orientation: orientation,
          platforms: platforms,
          isWeb: isWeb,
          density: density,
          textDirection: textDirection,
          minAccessibilityScale: minAccessibilityScale,
        );
    return this;
  }

  /// Closes the block opened by [startVariant].
  ///
  /// Components appended after this call are untagged again, and untagged
  /// components survive variant filtering unconditionally — they appear
  /// whichever variant wins.
  ///
  /// Throws [StateError] when no variant block is open.
  AclBuilder endVariant() {
    if (!_inVariantBlock) {
      throw StateError(
        'AclBuilder.endVariant(): not inside a variant block. '
        'Call startVariant() first.',
      );
    }
    _inVariantBlock = false;
    _currentVariantDetector = null;
    return this;
  }
}
