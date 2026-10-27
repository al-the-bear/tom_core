/// Feature flags: values a deployment switches without a release, evaluated
/// for the work at hand — its tenant, its principal's roles, or a stable
/// percentage of principals.
///
/// ## Reading a flag
///
/// ```dart
/// if (TomFeatureFlags.isEnabled('new-checkout')) { ... }
/// final limit = TomFeatureFlags.getInt('export-row-limit', defaultValue: 1000);
/// ```
///
/// A read never throws: an unknown flag, a value of another type or a failing
/// provider answer the default, and the `...Details` variants say why
/// ([TomFlagResolutionReason]). The context — who is asking — is taken from the
/// zone ([TomFlagContext.current]: the principal and the tenant of the request)
/// unless one is passed.
///
/// ## Providers
///
/// Values come from the installed [TomFlagProvider], shaped after the
/// OpenFeature provider contract, so a vendor or OpenFeature-compatible
/// service can be plugged in without changing a call site:
///
/// | Provider | Where |
/// | -------- | ----- |
/// | [TomRuleFlagProvider] | flags and their rules in configuration — the server's |
/// | [TomStaticFlagProvider] | values already evaluated — a client's, fetched from the server |
///
/// ## Rules
///
/// A [TomFlagDefinition] has a default value and rules, tried in order; the
/// first rule that matches gives the value. A rule matches when every condition
/// it states holds: the tenant is one of [TomFlagRule.tenants], the principal
/// holds one of [TomFlagRule.roles], and the principal falls in the first
/// [TomFlagRule.percentage] percent of the flag's buckets. The bucket is a
/// hash of the flag key and the principal's id, so a principal stays in or out
/// of a rollout across requests and processes, and raising the percentage only
/// adds principals.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../context/tenant_context.dart';
import '../little_things/little_things.dart';
import '../security/user_principal_aci.dart';

/// Who a flag is evaluated for — OpenFeature's evaluation context.
class TomFlagContext {
  /// A context for [targetingKey] (the principal's id) in [tenant], holding
  /// [roles], with free [attributes].
  const TomFlagContext({
    this.targetingKey,
    this.tenant,
    this.roles = const {},
    this.attributes = const {},
  });

  /// The id percentages are bucketed by, or `null` for no one in particular.
  final String? targetingKey;

  /// The tenant, or `null` for none.
  final String? tenant;

  /// The principal's roles.
  final Set<String> roles;

  /// Anything else a provider may target on.
  final Map<String, Object?> attributes;

  /// The context of the current zone: the authenticated principal's qualified
  /// id and roles, and the tenant.
  static TomFlagContext current() {
    final principal = getFromCurrentZone<TomPrincipal>();
    final known = principal != null && principal.authenticated;
    return TomFlagContext(
      targetingKey: known ? principal.qualifiedId : null,
      tenant: TomTenantContext.currentId,
      roles: known ? principal.aci.roles.toSet() : const {},
    );
  }

  @override
  String toString() =>
      'TomFlagContext($targetingKey, tenant: $tenant, roles: $roles)';
}

/// Why a flag resolved to the value it did — OpenFeature's resolution reasons.
enum TomFlagResolutionReason {
  /// The flag's own default: no rule matched.
  defaultValue,

  /// A rule targeting the tenant or the roles matched.
  targetingMatch,

  /// A percentage rule placed the principal in the rollout.
  split,

  /// The value is fixed, not evaluated per context.
  staticValue,

  /// The flag is unknown to the provider; the caller's default was used.
  flagNotFound,

  /// The flag's value is of another type; the caller's default was used.
  typeMismatch,

  /// The provider failed; the caller's default was used.
  error,
}

/// The outcome of evaluating one flag: its [value] and the [reason].
class TomFlagResolution<T> {
  /// A resolution to [value] for [reason], naming the [variant] (the matching
  /// rule's index) when a rule decided it.
  const TomFlagResolution(this.value, this.reason, {this.variant, this.error});

  /// The value the caller receives.
  final T value;

  /// Why it is this value.
  final TomFlagResolutionReason reason;

  /// Which rule decided it — `rule:<index>` — or `null`.
  final String? variant;

  /// What went wrong, for [TomFlagResolutionReason.error].
  final Object? error;

  /// Whether the caller's default was used for want of a value.
  bool get usedCallerDefault =>
      reason == TomFlagResolutionReason.flagNotFound ||
      reason == TomFlagResolutionReason.typeMismatch ||
      reason == TomFlagResolutionReason.error;

  @override
  String toString() => 'TomFlagResolution($value, ${reason.name})';
}

/// A source of flag values — the provider contract of OpenFeature, reduced to
/// one generic resolution.
///
/// [resolve] answers the raw value of [flagKey] for [context] with its reason,
/// or `null` when the flag is unknown; [TomFeatureFlags] checks the type and
/// falls back to the caller's default, so a provider never has to.
abstract class TomFlagProvider {
  /// Creates a provider.
  const TomFlagProvider();

  /// The value of [flagKey] for [context], or `null` when the flag is unknown.
  FutureOr<TomFlagResolution<Object?>?> resolve(
    String flagKey,
    TomFlagContext context,
  );

  /// Every flag this provider can answer for [context], by key — what a client
  /// fetches. A provider that cannot enumerate answers an empty map.
  FutureOr<Map<String, Object?>> evaluateAll(TomFlagContext context) =>
      const {};
}

/// The flag API — see the library documentation.
abstract final class TomFeatureFlags {
  /// The installed provider; without one every flag reads its default.
  static TomFlagProvider provider = const TomStaticFlagProvider({});

  /// Whether [flagKey] is on (its caller default [defaultValue]).
  static Future<bool> isEnabled(
    String flagKey, {
    bool defaultValue = false,
    TomFlagContext? context,
  }) async => (await details<bool>(flagKey, defaultValue, context)).value;

  /// The string value of [flagKey].
  static Future<String> getString(
    String flagKey, {
    required String defaultValue,
    TomFlagContext? context,
  }) async => (await details<String>(flagKey, defaultValue, context)).value;

  /// The whole-number value of [flagKey].
  static Future<int> getInt(
    String flagKey, {
    required int defaultValue,
    TomFlagContext? context,
  }) async => (await details<int>(flagKey, defaultValue, context)).value;

  /// The number value of [flagKey].
  static Future<double> getDouble(
    String flagKey, {
    required double defaultValue,
    TomFlagContext? context,
  }) async =>
      (await details<num>(flagKey, defaultValue, context)).value.toDouble();

  /// The structured value of [flagKey].
  static Future<Map<String, Object?>> getObject(
    String flagKey, {
    required Map<String, Object?> defaultValue,
    TomFlagContext? context,
  }) async => (await details<Map<String, Object?>>(
    flagKey,
    defaultValue,
    context,
  )).value;

  /// [flagKey] resolved as a [T], with the reason; [defaultValue] when the
  /// flag is unknown, of another type or the provider fails. Never throws.
  static Future<TomFlagResolution<T>> details<T>(
    String flagKey,
    T defaultValue, [
    TomFlagContext? context,
  ]) async {
    final TomFlagResolution<Object?>? raw;
    try {
      raw = await provider.resolve(
        flagKey,
        context ?? TomFlagContext.current(),
      );
    } on Object catch (error) {
      return TomFlagResolution(
        defaultValue,
        TomFlagResolutionReason.error,
        error: error,
      );
    }
    if (raw == null) {
      return TomFlagResolution(
        defaultValue,
        TomFlagResolutionReason.flagNotFound,
      );
    }
    final value = raw.value;
    if (value is T) {
      return TomFlagResolution(value, raw.reason, variant: raw.variant);
    }
    if (value is Map && <String, Object?>{} is T) {
      return TomFlagResolution(
        value.cast<String, Object?>() as T,
        raw.reason,
        variant: raw.variant,
      );
    }
    return TomFlagResolution(
      defaultValue,
      TomFlagResolutionReason.typeMismatch,
    );
  }
}

/// A provider of fixed values: a client's snapshot of what the server
/// evaluated for it, or a test's.
class TomStaticFlagProvider extends TomFlagProvider {
  /// A provider answering [values].
  const TomStaticFlagProvider(this.values);

  /// The values, by flag key.
  final Map<String, Object?> values;

  @override
  TomFlagResolution<Object?>? resolve(String flagKey, TomFlagContext context) =>
      values.containsKey(flagKey)
      ? TomFlagResolution(values[flagKey], TomFlagResolutionReason.staticValue)
      : null;

  @override
  Map<String, Object?> evaluateAll(TomFlagContext context) => values;
}

/// One targeting rule of a [TomFlagDefinition] — see the library
/// documentation.
class TomFlagRule {
  /// A rule giving [value] when every stated condition holds.
  const TomFlagRule({
    required this.value,
    this.tenants,
    this.roles,
    this.percentage,
  }) : assert(
         percentage == null || (percentage >= 0 && percentage <= 100),
         'percentage is 0 to 100',
       );

  /// The value the rule gives.
  final Object? value;

  /// The tenants it applies to, or `null` for any.
  final Set<String>? tenants;

  /// The roles it applies to — one suffices — or `null` for any principal.
  final Set<String>? roles;

  /// The share of principals it applies to, 0 to 100 (fractions allowed), or
  /// `null` for all. A context without a [TomFlagContext.targetingKey] is in no
  /// percentage.
  final num? percentage;

  /// Whether the rule applies to [context] for [flagKey].
  bool matches(String flagKey, TomFlagContext context) {
    final tenants = this.tenants;
    if (tenants != null && !tenants.contains(context.tenant)) return false;
    final roles = this.roles;
    if (roles != null && roles.intersection(context.roles).isEmpty) {
      return false;
    }
    final percentage = this.percentage;
    if (percentage != null) {
      final key = context.targetingKey;
      if (key == null) return false;
      return bucketOf(flagKey, key) < percentage * 100;
    }
    return true;
  }

  /// The bucket, 0 to 9999, [targetingKey] falls in for [flagKey]: the first
  /// four bytes of SHA-256(`<flagKey>:<targetingKey>`) modulo 10 000.
  static int bucketOf(String flagKey, String targetingKey) {
    final digest = sha256.convert(utf8.encode('$flagKey:$targetingKey')).bytes;
    final value =
        (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3];
    return value % 10000;
  }
}

/// A flag: its default and its rules.
class TomFlagDefinition {
  /// The flag [key], answering [defaultValue] unless one of [rules] matches;
  /// [exposed] flags are the ones a client may read.
  const TomFlagDefinition({
    required this.key,
    required this.defaultValue,
    this.rules = const [],
    this.exposed = false,
  });

  /// The flag key.
  final String key;

  /// The value when no rule matches.
  final Object? defaultValue;

  /// The rules, tried in order.
  final List<TomFlagRule> rules;

  /// Whether a client may read the flag. A flag is server-only unless it says
  /// so: an operational switch is nothing a browser needs to see.
  final bool exposed;

  /// This flag evaluated for [context].
  TomFlagResolution<Object?> evaluate(TomFlagContext context) {
    for (var i = 0; i < rules.length; i++) {
      final rule = rules[i];
      if (rule.matches(key, context)) {
        return TomFlagResolution(
          rule.value,
          rule.percentage != null
              ? TomFlagResolutionReason.split
              : TomFlagResolutionReason.targetingMatch,
          variant: 'rule:$i',
        );
      }
    }
    return TomFlagResolution(
      defaultValue,
      TomFlagResolutionReason.defaultValue,
    );
  }
}

/// The built-in provider: flags and their rules held in memory, usually read
/// from configuration ([TomRuleFlagProvider.fromConfiguration]).
class TomRuleFlagProvider extends TomFlagProvider {
  /// A provider of [flags].
  TomRuleFlagProvider(Iterable<TomFlagDefinition> flags)
    : flags = {for (final flag in flags) flag.key: flag};

  /// The flags, by key.
  final Map<String, TomFlagDefinition> flags;

  /// A provider of the flags in [config] — a map from flag key to its
  /// definition:
  ///
  /// ```yaml
  /// new-checkout:
  ///   default: false
  ///   exposed: true                  # a client may read it
  ///   rules:
  ///     - tenants: [acme]
  ///       value: true
  ///     - roles: [beta-tester]
  ///       value: true
  ///     - percentage: 25             # of principals, by a stable hash
  ///       value: true
  /// export-row-limit:
  ///   default: 1000
  /// ```
  ///
  /// Throws a [FormatException] naming the flag for a value of the wrong
  /// shape; nothing is installed.
  factory TomRuleFlagProvider.fromConfiguration(Object? config) {
    if (config is! Map) {
      throw const FormatException('The feature flags must be a map of flags.');
    }
    final definitions = <TomFlagDefinition>[];
    for (final MapEntry(:key, :value) in config.entries) {
      final name = '$key';
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(name)) {
        throw FormatException("'$name' is not a flag key.");
      }
      if (value is! Map || !value.containsKey('default')) {
        throw FormatException("The flag '$name' needs a 'default'.");
      }
      final unknown = value.keys
          .map((k) => '$k')
          .where((k) => !const {'default', 'rules', 'exposed'}.contains(k));
      if (unknown.isNotEmpty) {
        throw FormatException(
          "The flag '$name' has unknown settings: ${unknown.join(', ')}.",
        );
      }
      final exposed = value['exposed'] ?? false;
      if (exposed is! bool) {
        throw FormatException("'exposed' of '$name' must be a boolean.");
      }
      final rawRules = value['rules'] ?? const [];
      if (rawRules is! List) {
        throw FormatException("The rules of '$name' must be a list.");
      }
      definitions.add(
        TomFlagDefinition(
          key: name,
          defaultValue: _plain(value['default']),
          exposed: exposed,
          rules: [
            for (final (index, rule) in rawRules.indexed)
              _rule(name, index, rule),
          ],
        ),
      );
    }
    return TomRuleFlagProvider(definitions);
  }

  static TomFlagRule _rule(String flag, int index, Object? rule) {
    String where() => "rule $index of '$flag'";
    if (rule is! Map || !rule.containsKey('value')) {
      throw FormatException("${where()} needs a 'value'.");
    }
    final unknown = rule.keys
        .map((k) => '$k')
        .where(
          (k) => !const {'value', 'tenants', 'roles', 'percentage'}.contains(k),
        );
    if (unknown.isNotEmpty) {
      throw FormatException(
        '${where()} has unknown settings: ${unknown.join(', ')}.',
      );
    }
    Set<String>? names(String key) {
      final raw = rule[key];
      if (raw == null) return null;
      if (raw is! List || raw.isEmpty) {
        throw FormatException("'$key' of ${where()} must be a non-empty list.");
      }
      return {for (final name in raw) '$name'};
    }

    final percentage = rule['percentage'];
    if (percentage != null &&
        (percentage is! num || percentage < 0 || percentage > 100)) {
      throw FormatException("'percentage' of ${where()} is 0 to 100.");
    }
    return TomFlagRule(
      value: _plain(rule['value']),
      tenants: names('tenants'),
      roles: names('roles'),
      percentage: percentage as num?,
    );
  }

  /// [value] with YAML maps and lists turned into plain Dart ones, so a flag
  /// value encodes as JSON and compares as a map.
  static Object? _plain(Object? value) => switch (value) {
    Map() => {
      for (final MapEntry(:key, :value) in value.entries) '$key': _plain(value),
    },
    List() => [for (final item in value) _plain(item)],
    _ => value,
  };

  @override
  TomFlagResolution<Object?>? resolve(String flagKey, TomFlagContext context) =>
      flags[flagKey]?.evaluate(context);

  /// Every [TomFlagDefinition.exposed] flag evaluated for [context] — what the
  /// server hands a client. Server-only flags are left out.
  @override
  Map<String, Object?> evaluateAll(TomFlagContext context) => {
    for (final flag in flags.values)
      if (flag.exposed) flag.key: flag.evaluate(context).value,
  };
}
