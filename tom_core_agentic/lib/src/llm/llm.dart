// The LLM provider contract + the Anthropic Agent SDK provider.
//
// Migrated into `tom_core_agentic` from the tom_brain substrate / run layers so
// the provider seam and the Agent-SDK-backed provider are reusable outside the
// brain (the TomSpecs editor consumes them through the VS Code bridge).
//
// **One provider ships here, and that is deliberate.** The brain's other three
// — an Ollama HTTP provider, an OpenAI passthrough, and a deterministic stub —
// stayed where they were, because each depends on brain-domain packages that
// sit *above* this layer, and moving one would invert the dependency this
// package exists to keep pointing one way. They are not missing from the
// contract: `AgentSdkLlmProvider` is one implementation of a seam that is
// complete without them, and `example/llm/llm_example.dart` implements a second
// in sixty lines to show that it is.
library;

export 'agent_sdk_llm_provider.dart';
export 'agent_sdk_session.dart';
export 'captured_wire.dart';
export 'llm_call_report.dart';
export 'llm_options.dart';
export 'llm_provider.dart';
export 'llm_stream_event.dart';
export 'wire_prompt.dart';
