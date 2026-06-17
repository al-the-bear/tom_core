// Editor-facing agent data models.
//
// The TomSpecs editor's persisted domain objects — profiles, the prompt
// queue, chat / trail messages, reminder templates, timed requests — plus
// the YAML codec they round-trip through and the editor placeholder binder.
// Migrated into `tom_core_agentic` (§20 step 2 of
// `tom_specs_editor_specification.md`) so the editor and any future agent
// runtime share one model layer. All models are domain-neutral and depend
// only on `tom_basics`, `yaml` / `yaml_edit`, and the in-package placeholder
// engine.
library;

export 'agent_profile.dart';
export 'agent_send.dart';
export 'agent_yaml.dart';
export 'bridge_connection.dart';
export 'chat_message.dart';
export 'editor_placeholder_bindings.dart';
export 'prompt_queue.dart';
export 'reconnect.dart';
export 'reminder_template.dart';
export 'timed_request.dart';
