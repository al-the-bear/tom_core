/// Generic, domain-free building blocks for agentic systems.
///
/// Everything exported here depends only on `tom_basics` (plus `yaml`
/// for [YamlConfigReader]) and is safe to reuse across the brain, the
/// assistant, and any future agent runtime.
library;

export 'src/cancellation.dart';
export 'src/close_guard.dart';
export 'src/dedup_by_id.dart';
export 'src/http_date.dart';
export 'src/text_preview.dart';
