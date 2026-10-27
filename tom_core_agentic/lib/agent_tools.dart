/// A tool surface for LLM agents: declared tools, a permission scope with a
/// fixed gate order, an invocation record that carries execution consent, an
/// append-only audit trail, the presentations a model sees (native tool
/// declarations, an in-process MCP server) and preview-then-apply runs.
library;

export 'src/audit.dart';
export 'src/binding.dart';
export 'src/errors.dart';
export 'src/invocation.dart';
export 'src/preview_then_apply.dart';
export 'src/schema.dart';
export 'src/scope.dart';
export 'src/tool.dart';
