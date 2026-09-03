// AgentProfile — the editor's persona / behaviour model.
//
// Ported from the VS Code extension's `AnthropicProfile`
// (`tom_vscode_extension/src/handlers/anthropic-handler.ts`) for the
// TomSpecs editor's Profiles editor (§11.4 / §12). Persisted as YAML in
// the spec workspace.
//
// Beyond the VS Code field set this gains one editor-specific field:
// [interruptRetryPrefix] (N10) — the prefix prepended to an
// auto-resent interrupted prompt during the reconnect protocol (§6.1).
library;

/// Approval gate for write tool calls.
enum ToolApprovalMode {
  always('always'),
  never('never');

  const ToolApprovalMode(this.value);

  final String value;

  static ToolApprovalMode fromValue(String? value) =>
      ToolApprovalMode.values.firstWhere(
        (m) => m.value == value,
        orElse: () => ToolApprovalMode.always,
      );
}

/// A named persona that supplies the system prompt and per-send behaviour.
final class AgentProfile {
  const AgentProfile({
    required this.id,
    required this.name,
    this.description = '',
    this.systemPrompt = '',
    this.configurationId,
    this.toolsEnabled,
    this.enabledTools,
    this.maxRounds,
    this.historyMode,
    this.maxTokens,
    this.retryMaxTotalWaitMinutes,
    this.isDefault,
    this.thinkingEnabled,
    this.thinkingBudgetTokens,
    this.promptCachingEnabled,
    this.toolApprovalMode,
    this.useBuiltInTools,
    this.allowInteractiveQuestions,
    this.interactiveQuestionsTemplateId,
    this.autoInjectMemory,
    this.userPromptWrapper,
    this.interruptRetryPrefix = defaultInterruptRetryPrefix,
  });

  /// Default [interruptRetryPrefix] seeded when a VS Code profile is copied
  /// into the editor (N10).
  static const String defaultInterruptRetryPrefix =
      'This was interrupted due to a technical error.';

  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String? configurationId;
  final bool? toolsEnabled;
  final List<String>? enabledTools;
  final int? maxRounds;
  final String? historyMode;
  final int? maxTokens;
  final int? retryMaxTotalWaitMinutes;
  final bool? isDefault;
  final bool? thinkingEnabled;
  final int? thinkingBudgetTokens;
  final bool? promptCachingEnabled;
  final ToolApprovalMode? toolApprovalMode;
  final bool? useBuiltInTools;
  final bool? allowInteractiveQuestions;
  final String? interactiveQuestionsTemplateId;
  final bool? autoInjectMemory;
  final String? userPromptWrapper;

  /// Editor-specific (N10): prefix for an auto-resent interrupted prompt.
  final String interruptRetryPrefix;

  factory AgentProfile.fromYaml(Map<String, dynamic> yaml) => AgentProfile(
    id: yaml['id'] as String,
    name: yaml['name'] as String? ?? '',
    description: yaml['description'] as String? ?? '',
    systemPrompt: yaml['systemPrompt'] as String? ?? '',
    configurationId: yaml['configurationId'] as String?,
    toolsEnabled: yaml['toolsEnabled'] as bool?,
    enabledTools: (yaml['enabledTools'] as List?)?.whereType<String>().toList(),
    maxRounds: yaml['maxRounds'] as int?,
    historyMode: yaml['historyMode'] as String?,
    maxTokens: yaml['maxTokens'] as int?,
    retryMaxTotalWaitMinutes: yaml['retryMaxTotalWaitMinutes'] as int?,
    isDefault: yaml['isDefault'] as bool?,
    thinkingEnabled: yaml['thinkingEnabled'] as bool?,
    thinkingBudgetTokens: yaml['thinkingBudgetTokens'] as int?,
    promptCachingEnabled: yaml['promptCachingEnabled'] as bool?,
    toolApprovalMode: yaml['toolApprovalMode'] == null
        ? null
        : ToolApprovalMode.fromValue(yaml['toolApprovalMode'] as String?),
    useBuiltInTools: yaml['useBuiltInTools'] as bool?,
    allowInteractiveQuestions: yaml['allowInteractiveQuestions'] as bool?,
    interactiveQuestionsTemplateId:
        yaml['interactiveQuestionsTemplateId'] as String?,
    autoInjectMemory: yaml['autoInjectMemory'] as bool?,
    userPromptWrapper: yaml['userPromptWrapper'] as String?,
    interruptRetryPrefix:
        yaml['interruptRetryPrefix'] as String? ?? defaultInterruptRetryPrefix,
  );

  Map<String, dynamic> toYaml() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'systemPrompt': systemPrompt,
    if (configurationId != null) 'configurationId': configurationId,
    if (toolsEnabled != null) 'toolsEnabled': toolsEnabled,
    if (enabledTools != null) 'enabledTools': enabledTools,
    if (maxRounds != null) 'maxRounds': maxRounds,
    if (historyMode != null) 'historyMode': historyMode,
    if (maxTokens != null) 'maxTokens': maxTokens,
    if (retryMaxTotalWaitMinutes != null)
      'retryMaxTotalWaitMinutes': retryMaxTotalWaitMinutes,
    if (isDefault != null) 'isDefault': isDefault,
    if (thinkingEnabled != null) 'thinkingEnabled': thinkingEnabled,
    if (thinkingBudgetTokens != null)
      'thinkingBudgetTokens': thinkingBudgetTokens,
    if (promptCachingEnabled != null)
      'promptCachingEnabled': promptCachingEnabled,
    if (toolApprovalMode != null) 'toolApprovalMode': toolApprovalMode!.value,
    if (useBuiltInTools != null) 'useBuiltInTools': useBuiltInTools,
    if (allowInteractiveQuestions != null)
      'allowInteractiveQuestions': allowInteractiveQuestions,
    if (interactiveQuestionsTemplateId != null)
      'interactiveQuestionsTemplateId': interactiveQuestionsTemplateId,
    if (autoInjectMemory != null) 'autoInjectMemory': autoInjectMemory,
    if (userPromptWrapper != null) 'userPromptWrapper': userPromptWrapper,
    'interruptRetryPrefix': interruptRetryPrefix,
  };
}
