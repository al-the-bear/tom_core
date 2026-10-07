/// The application-owned blob-store backend the file-storage example
/// registers, kept apart from the example so the reflection root can reach it.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A backend a deployment writes itself: an in-memory store that remembers
/// which shelf it was configured for.
///
/// Its one setting, [shelf], is a field — that is how the registry knows the
/// key a configuration may give it, and refuses one it does not declare.
@tomReflector
class ExampleShelfBlobStoreBackend extends TomBlobStoreBackend {
  /// The shelf this store stands for; only a label, here.
  String shelf = 'unnamed';

  /// The [shelf] of the most recent store built, so the example can show the
  /// setting arrived.
  static String? lastShelf;

  @override
  TomBlobStore build(String name) {
    lastShelf = shelf;
    return TomMemoryBlobStore();
  }
}
