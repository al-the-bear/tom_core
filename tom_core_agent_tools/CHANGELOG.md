# Changelog

## 0.1.0

### Added

- **Tools.** `AgentTool` with a validated argument schema, `AgentToolRegistry`
  with `where`, and `AgentToolContext` with the guard and the transaction
  hooks an application implements.
- **Scope and consent.** `AgentScope` and the five-gate `agentGuard`;
  `AgentInvocation` with execution granted only against an
  `AgentExecutionGrant` statement.
- **Audit.** `AgentAuditEntry`, `AgentAuditLog`, `AgentMemoryAuditLog` and
  `AgentFileAuditLog` over an `AgentAuditStore`; the per-call
  `AgentAuditRecording`.
- **Presentations.** `AgentToolBinding` (an `LlmToolBinding`) and
  `AgentInProcessMcpServer`.
- **Runs.** `AgentRun` with its dry run, and `AgentPreviewThenApply`.
