/// The off-web half of `tomOpenBrowserMedium`'s conditional import.
///
/// Reached only where there is no browser: a test on the VM. An in-memory medium is the honest stand-in — not a degraded version
/// of IndexedDB but the accurate answer to "what durable browser storage
/// does this process have", which is none.
library;

import '../bundle_medium.dart';

TomBundleMedium openBrowserMediumImpl(String namespace) =>
    TomMemoryBundleMedium();
