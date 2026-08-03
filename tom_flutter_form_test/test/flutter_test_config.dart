// Tolerant golden comparator — absorbs sub-pixel font / anti-aliasing drift
// that differs across hosts and Flutter engine revisions, so pixel goldens do
// not oscillate red when the same suite runs on a different machine.
//
// Why: Flutter's default `LocalFileComparator` is exact-match. The screenshots
// in this package render real text (Roboto + Material icons); font hinting and
// anti-aliasing produce tiny per-pixel differences between the host/engine that
// generated the goldens and any other host/engine. A percentage threshold lets
// that sub-pixel noise pass while genuine visual regressions (layout shifts,
// colour/theme changes) still fail, because those move far more than the
// threshold's worth of pixels.
//
// Drift scales with text density, not with severity. Measured against the
// pre-2026-08-04 baselines, the ten example screens drifted 1.08%–1.63% while
// `example_list_screen` — the same drift per glyph, but far more glyphs — hit
// 3.89% and failed. All eleven were pure anti-aliasing: not one differing pixel
// sat in a flat region, and every dominant area colour was byte-identical. So a
// single global percentage is inherently a compromise across screens of
// differing density, and the earlier "observed <1.5%, so 3% has margin" reading
// was an artefact of the densest screen never having been measured.
//
// The threshold is therefore a coarse gate, not the real discriminator. When a
// golden does fail, decide with the flat-region and dominant-colour checks
// documented in `example_screenshot_test.dart` rather than with the percentage;
// those separate rasterisation from regression directly.
//
// `flutter test` auto-discovers this file (one per package test root) and runs
// `testExecutable` before the suite, installing the comparator. See quest todo
// RCJ17.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fraction (0.0–1.0) of pixel difference tolerated before a golden fails.
///
/// 5%, raised from 3% once the drift on the densest screen was measured at
/// 3.89% and shown to be pure anti-aliasing (see the header). A threshold has
/// to sit above the noise floor it exists to absorb, or it reports that noise
/// as failure — which is precisely what 3% did.
///
/// Raising it costs little detection power, because the power was never in the
/// percentage: a regression confined to one field or label moves well under 1%
/// of a 1280×800 frame and was already invisible at 3%. What this gate catches
/// is the broad kind — a palette, typography or layout change — and those move
/// tens of percent. On this suite a card-fill colour change alone would repaint
/// the 56% of the frame that the fill occupies.
const double _goldenTolerance = 0.05;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final defaultComparator = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantGoldenComparator(
    // Append a filename so LocalFileComparator's internal dirname() recovers the
    // exact original basedir (the running test file's directory).
    Uri.parse('${defaultComparator.basedir}flutter_test_config.dart'),
    tolerance: _goldenTolerance,
  );
  await testMain();
}

/// [LocalFileComparator] that passes when the pixel difference is within
/// [tolerance]; otherwise it fails exactly like the default comparator
/// (writing the failure PNGs and throwing).
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}
