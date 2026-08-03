// The LLM provider contract + the Anthropic Agent SDK provider.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate / run layers so
// the provider seam and the Agent-SDK-backed provider are reusable outside the
// brain (the TomSpecs editor consumes them through the VS Code bridge). The
// substrate-coupled HTTP / stub providers (Ollama, OpenAI passthrough, Stub) are
// intentionally NOT migrated here — they depend on brain-domain packages that
// sit above this layer; see `deferred.tom_specs.md`.
library;

export 'agent_sdk_llm_provider.dart';
export 'agent_sdk_session.dart';
export 'captured_wire.dart';
export 'llm_call_report.dart';
export 'llm_options.dart';
export 'llm_provider.dart';
export 'llm_stream_event.dart';
export 'wire_prompt.dart';
