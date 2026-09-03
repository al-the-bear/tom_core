import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'acl_container.dart';

// ── Variant-related enums ────────────────────────────────────────────────────

/// Input mode for variant detection.
enum AclInputMode { touch, pointer }

/// Derived form factor for variant detection.
enum AclFormFactor { phone, tablet, desktop }

/// Visual density category for variant detection.
enum AclDensity { compact, comfortable, standard }

// ── AclVariantDetector ───────────────────────────────────────────────────────

/// Determines whether an inline variant block should be active.
///
/// Returns `true` when the variant should be shown for the current context.
/// The [acl] parameter is the nearest ancestor [Acl] widget, or `null` if
/// the layout was created via [AclLayout] directly.
typedef AclVariantDetector =
    bool Function(
      AclDeviceContext deviceContext,
      Acl? acl,
      BuildContext context,
    );

// ── AclDeviceContext ─────────────────────────────────────────────────────────

/// Snapshot of the current device and layout environment used by
/// [AclVariantDetector] to decide which inline variant is active.
class AclDeviceContext {
  /// Available container width in logical pixels.
  final double width;

  /// Available container height in logical pixels, or `null` if unbounded.
  final double? height;

  /// Current input mode (touch or pointer).
  final AclInputMode inputMode;

  /// Derived form factor based on available width.
  final AclFormFactor formFactor;

  /// Current device orientation.
  final Orientation orientation;

  /// Target platform.
  final TargetPlatform platform;

  /// Whether the app is running on the web.
  final bool isWeb;

  /// Visual density category.
  final AclDensity density;

  /// Text direction (LTR or RTL).
  final TextDirection textDirection;

  /// Current text scale factor for accessibility.
  final double accessibilityScale;

  const AclDeviceContext({
    required this.width,
    this.height,
    required this.inputMode,
    required this.formFactor,
    required this.orientation,
    required this.platform,
    required this.isWeb,
    required this.density,
    required this.textDirection,
    required this.accessibilityScale,
  });

  /// Creates an [AclDeviceContext] from the current Flutter [BuildContext]
  /// and the available layout dimensions.
  factory AclDeviceContext.of(
    BuildContext context, {
    required double width,
    double? height,
  }) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);
    final platform = theme.platform;
    final scale = mq.textScaler.scale(1.0);

    return AclDeviceContext(
      width: width,
      height: height,
      inputMode: resolveInputMode(platform),
      formFactor: resolveFormFactor(width),
      orientation: mq.orientation,
      platform: platform,
      isWeb: kIsWeb,
      density: resolveDensity(theme.visualDensity),
      textDirection: Directionality.of(context),
      accessibilityScale: scale,
    );
  }

  /// Determines input mode from platform.
  ///
  /// Mobile platforms (iOS, Android) default to [AclInputMode.touch].
  /// Desktop platforms and web default to [AclInputMode.pointer].
  static AclInputMode resolveInputMode(TargetPlatform platform) {
    if (kIsWeb) return AclInputMode.pointer;
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return AclInputMode.touch;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return AclInputMode.pointer;
    }
  }

  /// Determines form factor from available width.
  ///
  /// - < 600 px → [AclFormFactor.phone]
  /// - < 1024 px → [AclFormFactor.tablet]
  /// - ≥ 1024 px → [AclFormFactor.desktop]
  static AclFormFactor resolveFormFactor(double width) {
    if (width < 600) return AclFormFactor.phone;
    if (width < 1024) return AclFormFactor.tablet;
    return AclFormFactor.desktop;
  }

  /// Determines density category from [VisualDensity].
  ///
  /// Averages horizontal and vertical density values:
  /// - avg ≤ −1.5 → [AclDensity.compact]
  /// - avg ≤ −0.5 → [AclDensity.comfortable]
  /// - otherwise  → [AclDensity.standard]
  static AclDensity resolveDensity(VisualDensity visualDensity) {
    final avg = (visualDensity.horizontal + visualDensity.vertical) / 2;
    if (avg <= -1.5) return AclDensity.compact;
    if (avg <= -0.5) return AclDensity.comfortable;
    return AclDensity.standard;
  }

  /// Builds a convenience [AclVariantDetector] from named parameters.
  ///
  /// All specified parameters combine with AND logic — every condition must be
  /// true for the detector to return true.  Returns `null` when no parameters
  /// are specified (indicating a default variant).
  ///
  /// The two size facets are **exclusive upper bounds**: [width] and [height]
  /// match a device strictly *narrower* / *shorter* than the value given, so a
  /// bound of `500` does not match a device of exactly `500`.
  /// [minAccessibilityScale] points the other way and is an **inclusive lower
  /// bound** — the parameter names are the only hint that the numeric facets
  /// disagree about direction.
  ///
  /// ## An unknown device height never matches
  ///
  /// [AclDeviceContext.height] is nullable, and the container leaves it `null`
  /// whenever the incoming constraints have unbounded height — that is,
  /// whenever it shrink-wraps its content, which is the ordinary case inside a
  /// `Column`, a `ListView`, or any scrollable.
  ///
  /// A [height] facet asked of such a context returns `false`. `null` is *not*
  /// read as "no constraint on this axis" and does not fall back to a default
  /// height: it fails the facet outright, and because the facets are ANDed it
  /// vetoes the whole detector however well every other facet fits.
  ///
  /// This is the intended degradation — an unbounded height is not a *short*
  /// one, so a spec meaning "activate when the viewport is short" should not
  /// fire when the viewport has no height to speak of. But the consequence is
  /// worth stating plainly, because it is invisible at the call site: **a
  /// variant gated on [height] can never activate in a shrink-wrapping
  /// container**, and the row falls back to its default variant instead. An
  /// author who wants a height-gated variant must give the container a bounded
  /// height — an enclosing `SizedBox`, `Expanded` or `Flexible`.
  ///
  /// [width] has no equivalent hazard: `width` is non-nullable, and the
  /// container only builds a device context at all when the horizontal axis is
  /// bounded.
  ///
  /// The behaviour is pinned by
  /// `test/advanced_container_layout/acl_variant_detector_test.dart`.
  static AclVariantDetector? buildConvenienceDetector({
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
  }) {
    final hasAny =
        width != null ||
        height != null ||
        input != null ||
        formFactor != null ||
        orientation != null ||
        platforms != null ||
        isWeb != null ||
        density != null ||
        textDirection != null ||
        minAccessibilityScale != null;

    if (!hasAny) return null;

    return (AclDeviceContext dc, Acl? acl, BuildContext context) {
      if (width != null && dc.width >= width) return false;
      if (height != null && (dc.height == null || dc.height! >= height)) {
        return false;
      }
      if (input != null && dc.inputMode != input) return false;
      if (formFactor != null && dc.formFactor != formFactor) return false;
      if (orientation != null && dc.orientation != orientation) return false;
      if (platforms != null && !platforms.contains(dc.platform)) return false;
      if (isWeb != null && dc.isWeb != isWeb) return false;
      if (density != null && dc.density != density) return false;
      if (textDirection != null && dc.textDirection != textDirection) {
        return false;
      }
      if (minAccessibilityScale != null &&
          dc.accessibilityScale < minAccessibilityScale) {
        return false;
      }
      return true;
    };
  }
}
