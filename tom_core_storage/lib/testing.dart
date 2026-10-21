/// Test support for code that stores through [TomStorage]: an in-memory
/// compare-and-swap remote ([TomMemoryRemote]) and per-device views onto it
/// ([TomMemoryStorage]) whose reads, writes, quota, key and replica lag can
/// each be made to fail on their own.
///
/// A test double, kept beside the port it stands in for so any caller of the
/// port can test against it. Nothing a product links imports this library.
library;

import 'tom_core_storage.dart';

export 'src/testing/memory_remote.dart';
