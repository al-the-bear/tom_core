# Changelog

## 0.1.0

### Added

- **Transports.** `AgentSdkServerTransport` with the hosted VS Code CLI server
  transport (port scan, identity handshake, workspace pin) and the standalone
  Node child transport (credential isolation, ready line, stderr on death).
- **The channel.** `CliServerAiChannel` with the stall bound as a gap and
  401-retry detection, and `SdkTrailTranslator` from Agent SDK messages to
  `tom_core_llm` run events.
- **Selection.** `AgentSdkTransportSelector` and the availability gate with a
  reason a program can branch on.
- **Sessions.** `AgentSdkSessionProvider` and one isolate per session.
- **The server.** `agent_sdk_server.js`, its on-demand install
  (`install_agent_sdk_server`) and payload verification.
- **Live probe.** `live_probe.dart`; test doubles in `testing.dart`.
