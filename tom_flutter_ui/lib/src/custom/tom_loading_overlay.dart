/// Full-surface loading indicator with optional message. Layers a
/// translucent scrim + centred [CircularProgressIndicator] (+ optional
/// label) over the [TomLoadingOverlay.child] subtree when
/// [TomLoadingOverlay.isLoading] is true.
///
/// Suits any operation that suspends a whole surface rather than one
/// control — a `SlowValidator` round-trip or a save action, for example.
/// Backticked rather than linked: `SlowValidator` belongs to this
/// package's `forms/validation` library, which `custom/` does not import
/// and must not import for the sake of a doc reference.
///
/// Designed to wrap an entire screen body or a card-sized panel; the
/// scrim sizes itself to the child via a [Stack] so callers don't need
/// to thread a `Size` through.
library;

import 'package:flutter/material.dart';

/// Full-surface loading indicator overlay.
class TomLoadingOverlay extends StatelessWidget {
  /// Subtree to overlay.
  final Widget child;

  /// When `true`, the scrim + spinner are rendered on top of [child].
  /// When `false`, only [child] is rendered (no extra widgets).
  final bool isLoading;

  /// Optional message shown beneath the spinner. When `null`, only the
  /// spinner is shown.
  final String? message;

  /// Scrim colour. Defaults to a 40 % opacity black overlay.
  final Color scrimColor;

  /// Optional explicit progress value (0..1). When `null`, the spinner
  /// is indeterminate.
  final double? progress;

  /// Whether the scrim should block pointer events under it. Defaults
  /// to `true`.
  final bool blocksPointerEvents;

  const TomLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.scrimColor = const Color(0x66000000),
    this.progress,
    this.blocksPointerEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    final theme = Theme.of(context);
    final overlay = Positioned.fill(
      // `IgnorePointer`, not `AbsorbPointer(absorbing: blocksPointerEvents)`.
      // The scrim is a `ColoredBox`, whose hit-test behaviour is opaque, so it
      // swallows a tap on its own — an `AbsorbPointer` that had stopped
      // absorbing changed nothing, and `blocksPointerEvents: false` left the
      // content exactly as unreachable as the default. Taking the whole
      // overlay out of hit testing is what actually hands the pointer back;
      // nothing in it is interactive.
      child: IgnorePointer(
        ignoring: !blocksPointerEvents,
        child: ColoredBox(
          color: scrimColor,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: progress),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  DefaultTextStyle.merge(
                    style:
                        theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ) ??
                        const TextStyle(color: Colors.white),
                    child: Text(message!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(children: [child, overlay]);
  }
}
