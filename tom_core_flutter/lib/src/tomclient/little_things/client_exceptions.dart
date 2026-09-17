import 'package:tom_core_kernel/tom_core_kernel.dart';

/// An exception originating on the client side of a Tom application.
///
/// `TomClientException` is a thin semantic subtype of the kernel
/// [TomException]: it carries the kernel's payload unchanged but lets client
/// code distinguish failures raised in the Flutter client from those surfaced
/// by lower layers (server, kernel) via a simple `is TomClientException` check.
///
/// **The kernel's whole parameter list is forwarded**, including the three that
/// identify a failure rather than describe it — [TomException.uuid],
/// [TomBaseException.requestUuid] and [TomException.serverCallError]. Every
/// client-side exception type chains through here, so a parameter missing from
/// this list is missing from all of them; the three were, and each had a case
/// the client could not express:
///
///  * `uuid` is generated when omitted, which is right for a failure raised
///    here and wrong for one *reconstructed* from a server's error envelope —
///    a fresh identity cannot be matched to the log line written on the far
///    side, which is the one place the failure was actually recorded.
///  * `requestUuid` is the correlation id, and the client is the side that
///    *issues* requests. The one exception type whose purpose is to say "this
///    came from the client" could not say which request it came from.
///  * `serverCallError` is the kernel's slot for "this came from an HTTP
///    call", and a client is where HTTP calls originate.
///    `TomUserPreferencesClientException` is the first to fill it.
///
/// The three are deliberately constructor arguments rather than fields assigned
/// afterwards. Two of them — `uuid` and `requestUuid` — are writable on a kernel
/// exception, so that much of the payload was always *reachable*; but a report
/// edited between the throw and the catch describes a failure the code in
/// between decided on, and everything these three carry is known where the
/// exception is raised. [TomException.serverCallError] is `final`, so for it the
/// constructor is the only route there has ever been.
///
/// ## The message is not resolved here
///
/// `key` is what a UI resolves against the text resources; `defaultUserMessage`
/// is the fallback for when no resource exists. **Neither is performed by this
/// class**, and that is the design rather than an omission: an exception is
/// raised in places a resource tree may not exist yet — early start-up, a
/// worker isolate, a unit test — and `TomTextResourceProvider.getAppResources`
/// *throws* where none is installed. A type that resolved on construction would
/// carry that failure into precisely the situations where reporting a failure
/// matters most.
///
/// So the lookup belongs to the one layer that already knows a resource tree is
/// installed — the code that displays the error:
///
/// ```dart
/// String messageFor(TomException failure) =>
///     TomTextResourceProvider.getAppResources().getTextOrNull(failure.key) ??
///     failure.defaultUserMessage;
/// ```
///
/// `getTextOrNull`, never `getText`: the latter echoes the key when the bundle
/// has no entry, which would put `login.failed` in front of a user and discard
/// the fallback this message exists to be. Both branches, and that trap, are
/// executed by `example/little_things/little_things_example.dart`.
class TomClientException extends TomException {
  /// Creates a client-side exception. See [TomException] for the meaning of
  /// each argument.
  TomClientException(
    super.key,
    super.defaultUserMessage, {
    super.uuid,
    super.requestUuid,
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.serverCallError,
  });
}

/// A client exception that is meant to be shown to the user in the UI.
///
/// `TomClientUIException` narrows [TomClientException] to errors whose
/// `defaultUserMessage` is safe and intended for display. Consumers commonly
/// branch on its type — e.g. `if (e is TomClientUIException) rethrow;` to let a
/// presentable error bubble up to the UI while wrapping non-presentable ones —
/// so the distinct type, not just the message, is the contract.
///
/// It forwards the same list as [TomClientException], for the same reason: a
/// presentable failure is no less in need of the request it belongs to.
class TomClientUIException extends TomClientException {
  /// Creates a user-facing client exception. See [TomException] for the meaning
  /// of each argument.
  TomClientUIException(
    super.key,
    super.defaultUserMessage, {
    super.uuid,
    super.requestUuid,
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.serverCallError,
  });
}
