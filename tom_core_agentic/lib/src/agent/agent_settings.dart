// Global agent settings (§7.1 Options surface + bridge host/port, §12).
//
// A single editor-configuration value (not a list): the bridge connection
// target and the global Agent SDK option defaults that overlay a profile when
// the profile leaves a field unset. Held in the spec workspace as a YAML file,
// out of the document `*.docspecs.yaml` pass.
library;

import 'agent_profile.dart';

/// Global agent settings: bridge target + the §7.1 `Options` defaults.
///
/// These defaults overlay the active [AgentProfile] — a profile field, when
/// set, wins; otherwise the value here applies. [defaultProfileId] names the
/// profile selected on launch.
final class AgentSettings {
  const AgentSettings({
    this.bridgeHost = 'localhost',
    this.portScanStart = 19900,
    this.portScanEnd = 19909,
    this.defaultProfileId,
    this.maxTokens,
    this.maxRounds,
    this.thinkingEnabled,
    this.promptCachingEnabled,
    this.toolApprovalMode,
  });

  /// Host the bridge port-scan connects to (§6).
  final String bridgeHost;

  /// First port of the §6 scan range (inclusive).
  final int portScanStart;

  /// Last port of the §6 scan range (inclusive).
  final int portScanEnd;

  /// Profile selected on launch; null = first available.
  final String? defaultProfileId;

  /// Global default for `Options.maxTokens` (overlaid by a profile when set).
  final int? maxTokens;

  /// Global default for the agent's max tool rounds.
  final int? maxRounds;

  /// Global default for extended thinking.
  final bool? thinkingEnabled;

  /// Global default for prompt caching.
  final bool? promptCachingEnabled;

  /// Global default tool-approval mode.
  final ToolApprovalMode? toolApprovalMode;

  factory AgentSettings.fromYaml(Map<String, dynamic> yaml) => AgentSettings(
        bridgeHost: yaml['bridgeHost'] as String? ?? 'localhost',
        portScanStart: yaml['portScanStart'] as int? ?? 19900,
        portScanEnd: yaml['portScanEnd'] as int? ?? 19909,
        defaultProfileId: yaml['defaultProfileId'] as String?,
        maxTokens: yaml['maxTokens'] as int?,
        maxRounds: yaml['maxRounds'] as int?,
        thinkingEnabled: yaml['thinkingEnabled'] as bool?,
        promptCachingEnabled: yaml['promptCachingEnabled'] as bool?,
        toolApprovalMode: yaml['toolApprovalMode'] == null
            ? null
            : ToolApprovalMode.fromValue(yaml['toolApprovalMode'] as String?),
      );

  Map<String, dynamic> toYaml() => <String, dynamic>{
        'bridgeHost': bridgeHost,
        'portScanStart': portScanStart,
        'portScanEnd': portScanEnd,
        if (defaultProfileId != null) 'defaultProfileId': defaultProfileId,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (maxRounds != null) 'maxRounds': maxRounds,
        if (thinkingEnabled != null) 'thinkingEnabled': thinkingEnabled,
        if (promptCachingEnabled != null)
          'promptCachingEnabled': promptCachingEnabled,
        if (toolApprovalMode != null)
          'toolApprovalMode': toolApprovalMode!.value,
      };

  AgentSettings copyWith({
    String? bridgeHost,
    int? portScanStart,
    int? portScanEnd,
    String? defaultProfileId,
    int? maxTokens,
    int? maxRounds,
    bool? thinkingEnabled,
    bool? promptCachingEnabled,
    ToolApprovalMode? toolApprovalMode,
  }) =>
      AgentSettings(
        bridgeHost: bridgeHost ?? this.bridgeHost,
        portScanStart: portScanStart ?? this.portScanStart,
        portScanEnd: portScanEnd ?? this.portScanEnd,
        defaultProfileId: defaultProfileId ?? this.defaultProfileId,
        maxTokens: maxTokens ?? this.maxTokens,
        maxRounds: maxRounds ?? this.maxRounds,
        thinkingEnabled: thinkingEnabled ?? this.thinkingEnabled,
        promptCachingEnabled: promptCachingEnabled ?? this.promptCachingEnabled,
        toolApprovalMode: toolApprovalMode ?? this.toolApprovalMode,
      );

  /// Whether the port-scan range is well-formed (start ≤ end, both positive).
  bool get hasValidPortRange =>
      portScanStart > 0 && portScanEnd > 0 && portScanStart <= portScanEnd;
}
