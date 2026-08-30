/// The one way a test in this package is allowed to tolerate a render error.
///
/// Several tests pin a preview to a fixed width — that is the whole point of a
/// responsiveness gallery — and a width pinned narrower than its content
/// overflows inside the narrower harness column. That is an artifact of the
/// harness, not a defect in the mechanism under test, so it has to be
/// tolerated.
///
/// The tolerance must be *narrow*, and this file exists because it is easy to
/// write one that is not. `FlutterError.onError = (_) {}` reads like "ignore
/// the overflow" and means "ignore everything": a failed assertion in a build
/// method, a bad state, a `RenderBox` layout error all vanish, and the test
/// goes on to pass on whatever it happens to find in the tree. Three test files
/// in this folder did exactly that, and stayed green while every build reported
/// a `StateError`.
///
/// So the tolerance lives here, once, and is expressed as a filter rather than
/// a silence. Nothing in this folder installs `FlutterError.onError` directly.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [details] is the benign preview overflow described above.
///
/// Matched on the message rather than the exception type because Flutter
/// reports overflow as a plain `FlutterError` whose text carries the
/// "A RenderFlex overflowed by N pixels" wording — there is no distinct type to
/// match on.
bool isOverflowError(FlutterErrorDetails details) =>
    details.exception.toString().contains('overflowed');

/// Drops preview overflow reports for the rest of the current test and forwards
/// every other error to the handler already in place.
///
/// That handler is `flutter_test`'s own, so a non-overflow error still fails the
/// test with its real message. Forwarding rather than silencing is also what
/// keeps an ordinary `expect` failure legible: with reporting disabled a plain
/// mismatch surfaces as an opaque `_pendingExceptionDetails != null` binding
/// assertion instead of the actual difference.
///
/// Restores the previous handler via `addTearDown`, so a caller cannot leak the
/// filter into the next test by forgetting to undo it.
void tolerateOverflowErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (isOverflowError(details)) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}
