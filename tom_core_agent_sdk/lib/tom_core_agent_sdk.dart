/// Anthropic's Claude Agent SDK as a `tom_core_llm` provider.
///
/// [AgentSdkSessionProvider] serves every request from a session over the
/// transport an [AgentSdkTransportSelector] chose: [HostedCliServerAiTransport]
/// (a running VS Code with the Tom extension's CLI server) or
/// [StandaloneNodeAiTransport] (a Node server the app starts and owns). The
/// run streams `tom_core_llm` events; a request's tools are relayed back to the
/// app through an in-process MCP server.
library;

export 'src/server_payload.dart';
export 'src/session_provider.dart';
export 'src/sessions/session_manager.dart';
export 'src/stall_bound.dart';
export 'src/transport/cli_server_channel.dart';
export 'src/transport/hosted_transport.dart';
export 'src/transport/standalone_transport.dart';
export 'src/transport/transport.dart';
export 'src/transport_selector.dart';
