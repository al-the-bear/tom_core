import 'package:tom_core_kernel/tom_core_kernel.dart';

/// An exception originating on the client side of a Tom application.
///
/// `TomClientException` is a thin semantic subtype of the kernel
/// [TomException]: it carries the same `key` / `defaultUserMessage` /
/// `parameters` / `stack` / `rootException` / `autoLog` payload but lets client
/// code distinguish failures raised in the Flutter client from those surfaced
/// by lower layers (server, kernel) via a simple `is TomClientException` check.
class TomClientException extends TomException {
  /// Creates a client-side exception. See [TomException] for the meaning of
  /// each argument.
  TomClientException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// A client exception that is meant to be shown to the user in the UI.
///
/// `TomClientUIException` narrows [TomClientException] to errors whose
/// `defaultUserMessage` is safe and intended for display. Consumers commonly
/// branch on its type — e.g. `if (e is TomClientUIException) rethrow;` to let a
/// presentable error bubble up to the UI while wrapping non-presentable ones —
/// so the distinct type, not just the message, is the contract.
class TomClientUIException extends TomClientException {
  /// Creates a user-facing client exception. See [TomException] for the meaning
  /// of each argument.
  TomClientUIException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}
