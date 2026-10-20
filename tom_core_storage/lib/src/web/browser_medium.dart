/// The browser-local [TomBundleMedium] — durable state for an origin, such as
/// a commit journal — selected at compile time.
///
/// IndexedDB (`TomIndexedDbBundleMedium`): bytes stored as they are, a quota
/// that is a share of the disk rather than a few megabytes, and a refused
/// write that surfaces as an error a caller can report instead of a commit
/// that disappears.
///
/// The conditional import is what lets a web application be tested. A library
/// that imports `package:web` does not compile on the VM, so a test on the VM
/// would fail to load before asserting anything; off-web the stub supplies an
/// in-memory medium instead, which is the truthful stand-in because off-web
/// there is no browser storage to be durable in.
library;

import '../bundle_medium.dart';

import 'browser_medium_stub.dart'
    if (dart.library.js_interop) 'browser_medium_web.dart';

/// The medium holding [namespace]'s durable state for this origin. Each
/// namespace is its own IndexedDB database, named [namespace]; prefix it with
/// the application's name (`myapp.journal`) so two applications on one origin
/// cannot meet.
TomBundleMedium tomOpenBrowserMedium(String namespace) =>
    openBrowserMediumImpl(namespace);

/// What the browser said when it refused a read or a write.
///
/// Its own type, carrying the DOM exception's **name**, because the one
/// refusal a caller has to recognise — `QuotaExceededError` — is a name and not
/// a class, and the sentence it renders is what an application can show.
class TomBrowserStorageException implements Exception {
  /// The DOM exception's name (`QuotaExceededError`, `AbortError`, …).
  final String name;
  final String message;

  const TomBrowserStorageException(this.name, this.message);

  bool get isQuotaExceeded => name == 'QuotaExceededError';

  @override
  String toString() => isQuotaExceeded
      ? "the browser's storage for this site is full"
      : 'the browser refused to store it ($name: $message)';
}
