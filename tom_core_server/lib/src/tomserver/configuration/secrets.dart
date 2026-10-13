/// Secrets in configuration: a value written as a **reference** to a secret
/// store, resolved before the configuration is built and refreshed when the
/// store rotates it.
///
/// ## A reference takes the place of a value
///
/// Any configuration value — in a resource file, the environment, `.env` or
/// on the command line — may be written as
///
/// ```text
/// secret:<provider>:<path>[#<field>]
/// ```
///
/// for instance `jwtSharedSecretKey: "secret:vault:secret/data/billing#jwt"`.
/// [TomSecrets.load] fetches every reference the configuration sources hold,
/// and `TomBaseServerConfiguration.getDefaultValues` then puts the secret
/// where the reference was. A secret therefore takes the **precedence of the
/// source the reference was written in** — the existing order of resources,
/// environment, `.env` and arguments decides, unchanged; a secret is not a new
/// layer with a rank of its own. A reference that was never loaded is refused
/// (`secrets.reference.unresolved`) rather than passed on as its own text, so
/// a server cannot start with `secret:vault:…` as its database password.
///
/// `#<field>` picks one member of a secret that holds several — a Vault KV
/// entry, a JSON secret in AWS Secrets Manager. Without it the secret must be a
/// single value.
///
/// ## Providers
///
/// A store is reached through a [TomSecretsProvider] registered under the name
/// the references use. The framework ships [TomMapSecretsProvider] for tests
/// and local development; the stores have one package each —
/// `tom_core_secrets_vault`, `tom_core_secrets_aws`, `tom_core_secrets_azure` —
/// so a deployment pulls in only the store it uses. A third party implements
/// [TomSecretsProvider] the same way.
///
/// ## Rotation
///
/// The configuration object is built once, so a rotated secret does not
/// change a field already read. Code holding a credential that rotates —
/// a connection pool, an outgoing API client — [TomSecrets.watch]es its
/// reference instead, and [TomSecrets.refresh] (on demand, or every
/// [TomSecrets.startRefresh] interval) fetches every reference again and calls
/// the watchers of the values that changed. A refresh that fails keeps the
/// values it had and says so; only the first [TomSecrets.load] is fatal,
/// because a server that cannot read its secrets at start must not start.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// A failure to read or resolve a secret, keyed `secrets.<area>.<condition>`.
///
/// Never names a secret's value — only its reference.
class TomSecretsException extends TomServerException {
  /// A failure with [key] and [defaultUserMessage].
  TomSecretsException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.clientThrow = false,
  });
}

/// A parsed `secret:<provider>:<path>[#<field>]` reference.
class TomSecretReference {
  /// The prefix every reference starts with.
  static const String prefix = 'secret:';

  /// The provider's registered name.
  final String provider;

  /// Where the secret lives in the provider's own terms — a Vault API path, a
  /// secret id or ARN, a Key Vault secret name.
  final String path;

  /// The member of a multi-valued secret to take, or `null` for the whole.
  final String? field;

  /// A reference.
  const TomSecretReference(this.provider, this.path, [this.field]);

  /// Whether [value] is written as a reference.
  static bool isReference(Object? value) =>
      value is String && value.startsWith(prefix);

  /// Parses [text], refusing one that is not `secret:<provider>:<path>`.
  factory TomSecretReference.parse(String text) {
    if (!text.startsWith(prefix)) {
      throw TomSecretsException(
        'secrets.reference.malformed',
        'A secret reference starts with "$prefix".',
        parameters: {'reference': text},
      );
    }
    final rest = text.substring(prefix.length);
    final colon = rest.indexOf(':');
    if (colon <= 0 || colon == rest.length - 1) {
      throw TomSecretsException(
        'secrets.reference.malformed',
        'A secret reference is secret:<provider>:<path>[#<field>], not '
            '"$text".',
        parameters: {'reference': text},
      );
    }
    final provider = rest.substring(0, colon);
    var path = rest.substring(colon + 1);
    String? field;
    final hash = path.lastIndexOf('#');
    if (hash >= 0) {
      field = path.substring(hash + 1);
      path = path.substring(0, hash);
      if (field.isEmpty || path.isEmpty) {
        throw TomSecretsException(
          'secrets.reference.malformed',
          'A secret reference names an empty path or field: "$text".',
          parameters: {'reference': text},
        );
      }
    }
    return TomSecretReference(provider, path, field);
  }

  @override
  String toString() =>
      '$prefix$provider:$path${field == null ? '' : '#$field'}';

  @override
  bool operator ==(Object other) =>
      other is TomSecretReference && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

/// What a provider read for one path.
class TomSecretPayload {
  /// The secret: a [String], or a `Map<String, Object?>` for a secret with
  /// several members.
  final Object data;

  /// The store's version of the secret, when it reports one.
  final String? version;

  /// A payload.
  const TomSecretPayload(this.data, {this.version});

  /// The member [field] of [data], or the whole when [field] is `null` —
  /// decoding a JSON object string the way a store that keeps one JSON string
  /// (AWS Secrets Manager) needs.
  String valueOf(TomSecretReference reference) {
    final field = reference.field;
    final data = this.data;
    if (field == null) {
      if (data is String) return data;
      throw TomSecretsException(
        'secrets.field.required',
        'The secret ${reference.provider}:${reference.path} holds several '
            'values; name one with #<field>.',
        parameters: {'reference': '$reference'},
      );
    }
    Map<String, Object?>? members;
    if (data is Map) {
      members = data.cast<String, Object?>();
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) members = decoded.cast<String, Object?>();
      } on FormatException {
        members = null;
      }
    }
    final value = members?[field];
    if (value == null) {
      throw TomSecretsException(
        'secrets.field.missing',
        'The secret ${reference.provider}:${reference.path} has no field '
            '"$field".',
        parameters: {'reference': '$reference'},
      );
    }
    return value is String ? value : jsonEncode(value);
  }
}

/// A secret store.
///
/// Implemented once per store; registered with [TomSecrets.register] under
/// [name], the middle part of the references that address it.
abstract class TomSecretsProvider {
  /// The name references use for this store (`vault`, `aws`, `azure`).
  String get name;

  /// Reads the secret at [path].
  ///
  /// Throws [TomSecretsException] — `secrets.fetch.not_found` for a path the
  /// store does not hold, `secrets.fetch.failed` for anything else — and
  /// never puts the secret's value in a message.
  Future<TomSecretPayload> fetch(String path);

  /// Releases anything the provider holds open. The default holds nothing.
  Future<void> close() async {}
}

/// A provider over a map — for tests, and for local development where a
/// deployment's secrets come from a file nobody commits.
class TomMapSecretsProvider implements TomSecretsProvider {
  /// A provider named [name] answering from [secrets], by path.
  TomMapSecretsProvider(this.name, Map<String, Object> secrets)
    : secrets = Map.of(secrets);

  @override
  final String name;

  /// The secrets, by path; change them to simulate a rotation.
  final Map<String, Object> secrets;

  @override
  Future<TomSecretPayload> fetch(String path) async {
    final data = secrets[path];
    if (data == null) {
      throw TomSecretsException(
        'secrets.fetch.not_found',
        'The "$name" secrets provider holds no secret at "$path".',
        parameters: {'provider': name, 'path': path},
      );
    }
    return TomSecretPayload(data);
  }

  @override
  Future<void> close() async {}
}

/// A watcher's registration, ended by [cancel].
class TomSecretSubscription {
  TomSecretSubscription._(this._cancel);

  final void Function() _cancel;

  /// Stops the watcher being called.
  void cancel() => _cancel();
}

/// What one [TomSecrets.refresh] found.
class TomSecretsRefresh {
  /// The references whose value changed.
  final List<String> changed;

  /// The references that could not be fetched, kept at their last value.
  final List<String> failed;

  /// A refresh outcome.
  const TomSecretsRefresh({this.changed = const [], this.failed = const []});
}

/// The registered providers and the secrets resolved through them.
abstract final class TomSecrets {
  static final Map<String, TomSecretsProvider> _providers = {};
  static final Map<String, String> _values = {};
  static final Map<String, List<void Function(String)>> _watchers = {};
  static Timer? _timer;

  /// Registers [provider] under its name, replacing one of that name.
  static void register(TomSecretsProvider provider) =>
      _providers[provider.name] = provider;

  /// The registered providers, by name.
  static Map<String, TomSecretsProvider> get providers =>
      Map.unmodifiable(_providers);

  /// The references resolved so far.
  static Set<String> get references => Set.unmodifiable(_values.keys);

  /// Resolves every reference [values] holds — strings anywhere in the tree —
  /// and remembers them.
  ///
  /// Called by a boot before it builds its configuration, with the merged
  /// sources (`TomBaseServerConfiguration.collectSources`). Throws
  /// [TomSecretsException] on the first reference it cannot resolve: a
  /// server must not start without its secrets.
  static Future<void> load(Object? values) async {
    final references = <TomSecretReference>{};
    _collect(values, references);
    await _resolveAll(references, failSoft: false);
  }

  /// Resolves [reference] now and returns its value.
  static Future<String> resolve(String reference) async {
    final parsed = TomSecretReference.parse(reference);
    await _resolveAll({parsed}, failSoft: false);
    return _values['$parsed']!;
  }

  /// The current value of [reference], which [load] or [resolve] must have
  /// resolved.
  static String current(String reference) {
    final value = _values['${TomSecretReference.parse(reference)}'];
    if (value == null) {
      throw TomSecretsException(
        'secrets.reference.unresolved',
        'The secret reference $reference was never loaded; call '
            'TomSecrets.load before the configuration is built.',
        parameters: {'reference': reference},
      );
    }
    return value;
  }

  /// [values] with every reference replaced by its resolved value.
  ///
  /// Throws `secrets.reference.unresolved` for a reference [load] did not
  /// resolve, rather than leaving its text in place.
  static Object? substitute(Object? values) {
    if (TomSecretReference.isReference(values)) {
      return current(values as String);
    }
    if (values is Map) {
      return {
        for (final entry in values.entries) entry.key: substitute(entry.value),
      };
    }
    if (values is List) return [for (final v in values) substitute(v)];
    return values;
  }

  /// Calls [onChange] with the new value whenever a [refresh] finds
  /// [reference] changed.
  static TomSecretSubscription watch(
    String reference,
    void Function(String value) onChange,
  ) {
    final key = '${TomSecretReference.parse(reference)}';
    final list = _watchers.putIfAbsent(key, () => []);
    list.add(onChange);
    return TomSecretSubscription._(() => list.remove(onChange));
  }

  /// Fetches every resolved reference again and calls the watchers of those
  /// that changed. A reference that cannot be fetched keeps its value and is
  /// reported in [TomSecretsRefresh.failed].
  static Future<TomSecretsRefresh> refresh() async {
    final before = Map.of(_values);
    final failed = await _resolveAll({
      for (final reference in before.keys) TomSecretReference.parse(reference),
    }, failSoft: true);
    final changed = [
      for (final entry in _values.entries)
        if (before[entry.key] != entry.value) entry.key,
    ];
    for (final reference in changed) {
      for (final watcher in List.of(_watchers[reference] ?? const [])) {
        try {
          watcher(_values[reference]!);
        } on Object catch (e) {
          tomLog.warn('A watcher of $reference failed: $e');
        }
      }
    }
    if (changed.isNotEmpty) {
      tomLog.info('Secrets refreshed; changed: ${changed.join(', ')}.');
    }
    return TomSecretsRefresh(changed: changed, failed: failed);
  }

  /// Refreshes every [every] until [stopRefresh].
  static void startRefresh(Duration every) {
    stopRefresh();
    _timer = Timer.periodic(every, (_) => refresh());
  }

  /// Stops the periodic refresh.
  static void stopRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  /// Forgets every provider, value and watcher, closing the providers.
  /// Test-support, and a server's shutdown.
  static Future<void> reset() async {
    stopRefresh();
    for (final provider in _providers.values) {
      await provider.close();
    }
    _providers.clear();
    _values.clear();
    _watchers.clear();
  }

  static void _collect(Object? node, Set<TomSecretReference> into) {
    if (TomSecretReference.isReference(node)) {
      into.add(TomSecretReference.parse(node as String));
    } else if (node is Map) {
      for (final value in node.values) {
        _collect(value, into);
      }
    } else if (node is List) {
      for (final value in node) {
        _collect(value, into);
      }
    }
  }

  /// Fetches each path once, however many fields of it are referenced, and
  /// stores the values. With [failSoft], answers the references that failed
  /// instead of throwing.
  static Future<List<String>> _resolveAll(
    Set<TomSecretReference> references, {
    required bool failSoft,
  }) async {
    final byPath = <String, List<TomSecretReference>>{};
    for (final reference in references) {
      byPath
          .putIfAbsent('${reference.provider}:${reference.path}', () => [])
          .add(reference);
    }
    final failed = <String>[];
    for (final group in byPath.values) {
      final first = group.first;
      final provider = _providers[first.provider];
      try {
        if (provider == null) {
          throw TomSecretsException(
            'secrets.provider.unknown',
            'No secrets provider is registered as "${first.provider}", which '
                '${group.map((r) => '$r').join(', ')} names.',
            parameters: {'provider': first.provider},
          );
        }
        final payload = await provider.fetch(first.path);
        for (final reference in group) {
          _values['$reference'] = payload.valueOf(reference);
        }
      } on Object catch (e) {
        if (!failSoft) {
          if (e is TomSecretsException) rethrow;
          throw TomSecretsException(
            'secrets.fetch.failed',
            'Reading ${first.provider}:${first.path} failed: $e',
            parameters: {'provider': first.provider, 'path': first.path},
            rootException: e,
          );
        }
        tomLog.warn(
          'Refreshing ${first.provider}:${first.path} failed; keeping the '
          'last value: $e',
        );
        failed.addAll(group.map((r) => '$r'));
      }
    }
    return failed;
  }
}
