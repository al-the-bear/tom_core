/// Catches widget-build errors raised anywhere in the guarded subtree and
/// renders a fallback UI instead of letting them reach the global error
/// widget.
///
/// Interception is one mechanism, and the indirection in it is what makes
/// *nested* boundaries correct. [ErrorWidget.builder] is global, so it cannot
/// belong to a boundary: with several mounted, whichever installed last would
/// own the hook and would receive every subtree's errors. Instead the builder
/// is installed once — ref-counted across all mounted boundaries, so the
/// original is preserved for as long as any boundary is in the tree, whether
/// or not it is currently showing a fallback — and it returns a reporter
/// widget at the failing slot. That reporter is built *in
/// the failing subtree*, so it can walk up the element tree to the nearest
/// enclosing boundary and hand the error to that one. Mount order stops
/// mattering, and a list of dozens of boundaries contains each row's failure
/// to its own row.
///
/// A boundary guards its own subtree and nothing else. The global slot has one
/// occupant, so while any boundary is mounted its hook also sees errors raised
/// outside every boundary; those are handed to the builder that was in the
/// slot beforehand — Flutter's red box in debug, the application's own widget
/// in release — so mounting a boundary changes nothing outside it. Anything
/// else would turn one guarded row into a process-wide suppression of error
/// reporting.
///
/// The fallback UI is configurable via
/// [TomErrorBoundary.fallbackBuilder]; when omitted, a Material-themed
/// error card is shown.
library;

import 'package:flutter/material.dart';

/// Builder signature for the fallback UI rendered when an error is
/// caught. Receives the captured [FlutterErrorDetails] plus a
/// `retry` closure that resets the boundary and re-attempts the build.
typedef TomErrorBoundaryFallbackBuilder =
    Widget Function(
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

  /// Releases the global [ErrorWidget.builder] hook and forgets every mounted
  /// boundary.
  ///
  /// The hook is process-wide, and so is the count that owns it: a boundary
  /// whose `dispose` never runs leaves the slot held for the rest of the
  /// process, and everything after it inherits an error widget belonging to a
  /// widget that is gone. A test that tears down its binding, or that pumps a
  /// boundary and then abandons the tree, has no other way back.
  ///
  /// Nothing in an application should need this: there, boundaries are
  /// disposed by the framework and the count returns to zero on its own.
  @visibleForTesting
  static void debugReleaseGlobalHook() => _GlobalHook.reset();
}

class _TomErrorBoundaryState extends State<TomErrorBoundary> {
  FlutterErrorDetails? _captured;

  /// The hook is owned by the **boundary**, for its whole lifetime.
  ///
  /// The tempting alternative — owning it on a host widget the boundary
  /// renders only while it has caught nothing — makes a boundary stop
  /// guarding the moment it captures: the capture unmounts the host, drops
  /// the count, and, if this is the last boundary, puts the previous builder
  /// back. What it stops guarding includes its own `fallbackBuilder`, which is
  /// caller code and can throw. In a list of guarded rows the count would fall
  /// with each row that failed, and when the last healthy row failed the order
  /// of the remaining captures would decide whether the final error was caught
  /// or dropped.
  ///
  /// Tying the install and the release to the boundary being in the tree is
  /// what "this subtree is guarded" means.
  /// Which run of the global hook this boundary's share belongs to.
  ///
  /// A reset starts a new run, so a boundary that acquired before it releases
  /// nothing: its share was already written off. Without this, a leaked
  /// boundary disposing later would decrement a count it no longer has a claim
  /// on, and hand back the slot from under whichever boundary holds it now.
  late final int _hookRun;

  @override
  void initState() {
    super.initState();
    _hookRun = _GlobalHook.acquire();
  }

  @override
  void dispose() {
    _GlobalHook.release(_hookRun);
    super.dispose();
  }

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
    return widget.child;
  }
}

/// The process-wide state behind [ErrorWidget.builder], in one place that can
/// be put back.
///
/// It is process-wide because the slot it manages is: there is one
/// [ErrorWidget.builder] per isolate, and the count is what lets several
/// boundaries share it without the second one stomping what the first found.
///
/// Holding it as two bare library variables made it unrecoverable. A boundary
/// whose `dispose` never runs — a test that tears down its binding, say —
/// pins the count above zero for the rest of the process, so the slot is never
/// handed back and everything that runs afterwards inherits a hook belonging
/// to a widget that no longer exists. That is the failure that shows up
/// somewhere else entirely, and there was no way back from it.
class _GlobalHook {
  _GlobalHook._();

  /// Mounted boundaries. The hook is installed on 0→1 and released on 1→0.
  static int _active = 0;

  /// Which run of the hook [_active] is counting.
  ///
  /// Bumped by [reset], so shares taken out before it can be recognised and
  /// ignored when they are handed back.
  static int _run = 0;

  /// What held the slot before the first boundary took it.
  ///
  /// Non-null exactly while [_active] is above zero — set on the way up,
  /// cleared on the way down. [_ErrorReporter] reads it for every error raised
  /// outside all boundaries.
  static ErrorWidgetBuilder? _saved;

  static ErrorWidgetBuilder? get saved => _saved;

  /// Takes a share of the hook, and returns the run it belongs to.
  static int acquire() {
    if (_active == 0) {
      _saved = ErrorWidget.builder;
      ErrorWidget.builder = (FlutterErrorDetails details) =>
          _ErrorReporter(details: details);
    }
    _active++;
    return _run;
  }

  /// Hands back a share taken out in [run].
  ///
  /// A share from an earlier run was written off by the [reset] that ended it,
  /// so returning it would take the slot away from whoever holds it now.
  static void release(int run) {
    if (run != _run) return;
    _active--;
    if (_active > 0) return;
    ErrorWidget.builder = _saved!;
    _saved = null;
  }

  /// Puts the slot back and forgets every mounted boundary.
  ///
  /// For a test that cannot rely on `dispose` having run — the count is
  /// process-wide, so one leak would otherwise be inherited by every test
  /// after it in the same process.
  static void reset() {
    final saved = _saved;
    if (saved != null) ErrorWidget.builder = saved;
    _saved = null;
    _active = 0;
    _run++;
  }
}

/// Replaces the throwing widget at the failing slot, and decides whose error
/// it is.
///
/// The hook returns a widget rather than calling a boundary directly, and that
/// indirection is what makes nested boundaries correct. [ErrorWidget.builder]
/// is global: with boundaries A and B both mounted, one of them owns the slot,
/// and a hook that called its owner would route A's error to B. Per-row
/// containment in a list of dozens of boundaries would be impossible. Because
/// this widget is built *in the failing subtree*, it can walk up to the
/// nearest enclosing boundary, and mount order stops mattering.
///
/// Inside a boundary, it forwards the captured [FlutterErrorDetails] to the
/// nearest enclosing one — which then schedules a post-frame setState to swap
/// in its fallback UI — and stays a zero-size placeholder until that happens.
///
/// **Outside every boundary, it renders what the error would have rendered had
/// no boundary been mounted**: the builder [_GlobalHook] saved, which is
/// Flutter's
/// red box in debug and whatever the application installed in release. The
/// global slot has one occupant, so the boundary that took it also receives
/// errors it has no business handling; returning a blank for those would make
/// mounting a single boundary anywhere — one row of one list — silently
/// disable error reporting for the whole process.
///
/// That is why the ancestor lookup happens in [build] rather than in a
/// post-frame callback. Whose error it is has to be answered *while the
/// failing slot is being built*, because the answer decides what that slot
/// renders. Only the boundary's `setState` still has to wait for the frame to
/// finish, and only when there is a boundary to call it on.
class _ErrorReporter extends StatefulWidget {
  final FlutterErrorDetails details;
  const _ErrorReporter({required this.details});

  @override
  State<_ErrorReporter> createState() => _ErrorReporterState();
}

class _ErrorReporterState extends State<_ErrorReporter> {
  @override
  Widget build(BuildContext context) {
    // Routing to the *nearest enclosing* boundary is the whole point of this
    // widget — see the class doc on [_ErrorBoundaryHost] for why the hook
    // returns a widget instead of calling a boundary directly.
    final boundary = context.findAncestorStateOfType<_TomErrorBoundaryState>();
    if (boundary == null) {
      return _GlobalHook.saved?.call(widget.details) ?? const SizedBox.shrink();
    }

    // Deferred because the error arrives during the failing subtree's build:
    // calling setState on the boundary now would trip the lifecycle assertion
    // in debug and surface as a framework exception under `flutter_test`.
    // `mounted` is the ordinary guard for a callback that can outlive the
    // State that registered it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      boundary._captureError(widget.details);
    });
    return const SizedBox.shrink();
  }
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
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Something went wrong',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            details.exceptionAsString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}
