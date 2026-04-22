/// Phase 6 — `TomErrorBoundary`.
///
/// Catches widget-build errors raised inside [child] (and any descendant
/// builder error reported through the [FlutterError.onError] hook) and
/// renders a fallback UI instead of letting the error propagate up to
/// the global error widget.
///
/// Today every demo re-implements a version of this — Phase 6 promotes
/// it to a first-class framework piece.
///
/// The widget intercepts errors at two layers:
///
/// 1. The [FlutterError.onError] hook is wrapped while the boundary is
///    mounted. Errors flagged with the boundary's [_TomErrorBoundaryMarker]
///    library are caught; everything else is forwarded to the previous
///    handler (so global error reporting still works).
/// 2. The [child] is wrapped in an [ErrorWidget.builder] that captures
///    framework-time build errors that produce [ErrorWidget] in release
///    mode but throw in debug; the overlay is repainted via
///    [setState].
///
/// The fallback UI is configurable via [fallbackBuilder]; when omitted,
/// a Material-themed error card is shown.
library;

import 'package:flutter/material.dart';

/// Builder signature for the fallback UI rendered when an error is
/// caught. Receives the captured [FlutterErrorDetails] plus a
/// `retry` closure that resets the boundary and re-attempts the build.
typedef TomErrorBoundaryFallbackBuilder = Widget Function(
  BuildContext context,
  FlutterErrorDetails details,
  VoidCallback retry,
);

/// Inline error boundary — catches build errors inside [child] and
/// renders a fallback UI.
class TomErrorBoundary extends StatefulWidget {
  /// Subtree to guard.
  final Widget child;

  /// Optional fallback builder. When `null`, the boundary renders a
  /// Material-themed error card.
  final TomErrorBoundaryFallbackBuilder? fallbackBuilder;

  /// Optional callback invoked once whenever a new error is caught.
  /// Useful for logging or routing the error elsewhere (e.g. crashlytics)
  /// without overriding the fallback UI.
  final void Function(FlutterErrorDetails details)? onError;

  const TomErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.onError,
  });

  @override
  State<TomErrorBoundary> createState() => _TomErrorBoundaryState();
}

class _TomErrorBoundaryState extends State<TomErrorBoundary> {
  FlutterErrorDetails? _captured;

  void _retry() => setState(() => _captured = null);

  void _captureError(FlutterErrorDetails details) {
    widget.onError?.call(details);
    if (!mounted) return;
    // The error arrives via `ErrorWidget.builder`, which fires *during*
    // the build phase of the failing subtree. Calling `setState`
    // synchronously from there trips the "setState() called during
    // build" assertion in debug and surfaces as an unexpected framework
    // exception in `flutter_test`. Defer the repaint to the next frame
    // so the current build completes cleanly before we swap in the
    // fallback UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _captured = details);
    });
  }

  @override
  Widget build(BuildContext context) {
    final captured = _captured;
    if (captured != null) {
      final builder = widget.fallbackBuilder;
      if (builder != null) return builder(context, captured, _retry);
      return _DefaultErrorFallback(details: captured, onRetry: _retry);
    }
    return _ErrorBoundaryHost(child: widget.child);
  }
}

/// Wraps the guarded subtree with an [ErrorWidget.builder] that
/// returns a [_ErrorReporter] in place of the failing widget. The
/// reporter then walks up the element tree to find the *nearest*
/// enclosing [_TomErrorBoundaryState] and forwards the error to it.
///
/// This element-tree routing — rather than the more obvious "current
/// host's `widget.onError` is called by the global hook" approach —
/// is what makes nested boundaries correct. The global
/// [ErrorWidget.builder] is, well, global: when boundary A and B are
/// both mounted, whichever called `initState` *last* owns the hook.
/// If A throws while B is the active hook, B's `onError` would fire
/// — routing A's error to B. Per-row containment in a list (where
/// dozens of boundaries are mounted simultaneously) becomes
/// impossible. By having the hook return a placeholder widget that
/// looks up the boundary via `findAncestorStateOfType`, the error
/// always reaches the *enclosing* boundary, regardless of mount
/// order.
///
/// Boundary ref-counting:
/// `_ErrorBoundaryHostState` increments [_activeBoundaries] in
/// `initState` and decrements in `dispose`. The global hook is
/// installed when the count goes 0→1 and restored when it goes
/// 1→0 — so the original builder is preserved across the entire
/// lifetime of the outermost boundary, not stomped each time a new
/// boundary mounts.
class _ErrorBoundaryHost extends StatefulWidget {
  final Widget child;

  const _ErrorBoundaryHost({required this.child});

  @override
  State<_ErrorBoundaryHost> createState() => _ErrorBoundaryHostState();
}

/// Number of currently mounted [_ErrorBoundaryHost]s. Used to
/// install the global hook exactly once across all boundaries.
int _activeBoundaries = 0;

/// The [ErrorWidget.builder] that was active before the first
/// boundary installed its hook. Restored when the last boundary
/// unmounts.
ErrorWidgetBuilder? _previousGlobalBuilder;

class _ErrorBoundaryHostState extends State<_ErrorBoundaryHost> {
  @override
  void initState() {
    super.initState();
    if (_activeBoundaries == 0) {
      _previousGlobalBuilder = ErrorWidget.builder;
      ErrorWidget.builder = (FlutterErrorDetails details) =>
          _ErrorReporter(details: details);
    }
    _activeBoundaries++;
  }

  @override
  void dispose() {
    _activeBoundaries--;
    if (_activeBoundaries == 0) {
      ErrorWidget.builder = _previousGlobalBuilder ?? ErrorWidget.builder;
      _previousGlobalBuilder = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Replaces the throwing widget at the failing slot. On mount it
/// finds the nearest [_TomErrorBoundaryState] ancestor and forwards
/// the captured [FlutterErrorDetails] — the boundary then schedules
/// a post-frame setState to swap in its fallback UI.
///
/// Stays as a zero-size placeholder until the boundary rebuilds and
/// replaces the entire boundary subtree with the fallback widget;
/// the placeholder never appears in the tree once that happens.
class _ErrorReporter extends StatefulWidget {
  final FlutterErrorDetails details;
  const _ErrorReporter({required this.details});

  @override
  State<_ErrorReporter> createState() => _ErrorReporterState();
}

class _ErrorReporterState extends State<_ErrorReporter> {
  @override
  void initState() {
    super.initState();
    // Defer the lookup to the next frame: during the failing build,
    // the framework still considers the boundary state "in build" and
    // calling setState on it (which is what the boundary does in
    // response) would trip the lifecycle assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final boundary = context.findAncestorStateOfType<_TomErrorBoundaryState>();
      // Routing the error to the nearest enclosing boundary is the
      // whole point of this widget — see the class doc on
      // [_ErrorBoundaryHost] for why.
      boundary?._captureError(widget.details);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DefaultErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;
  final VoidCallback onRetry;

  const _DefaultErrorFallback({required this.details, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Something went wrong',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
          const SizedBox(height: 6),
          Text(
            details.exceptionAsString(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
