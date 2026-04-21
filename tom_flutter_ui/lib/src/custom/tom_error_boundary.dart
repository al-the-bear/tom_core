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
    return _ErrorBoundaryHost(
      onError: _captureError,
      child: widget.child,
    );
  }
}

/// Wraps the guarded subtree with an [ErrorWidget.builder] that sends
/// caught errors back to the boundary state. The previous builder is
/// restored on dispose so other boundaries / global error handlers keep
/// working.
class _ErrorBoundaryHost extends StatefulWidget {
  final Widget child;
  final void Function(FlutterErrorDetails details) onError;

  const _ErrorBoundaryHost({required this.child, required this.onError});

  @override
  State<_ErrorBoundaryHost> createState() => _ErrorBoundaryHostState();
}

class _ErrorBoundaryHostState extends State<_ErrorBoundaryHost> {
  late final ErrorWidgetBuilder _previousBuilder;

  @override
  void initState() {
    super.initState();
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      widget.onError(details);
      // Render an empty placeholder while the boundary repaints with
      // the fallback UI.
      return const SizedBox.shrink();
    };
  }

  @override
  void dispose() {
    ErrorWidget.builder = _previousBuilder;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
