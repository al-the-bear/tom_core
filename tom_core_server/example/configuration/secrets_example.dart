/// Executable example for secret references in `tom_core_server`'s
/// configuration.
///
/// A configuration value written as `secret:<provider>:<path>[#<field>]` is
/// read from a [TomSecretsProvider] instead of being the value itself. The
/// boot loads every reference once, before the configuration is built, and
/// [TomBaseServerConfiguration.getDefaultValues] substitutes each in place — so
/// a secret takes the precedence of the source it was written in, and a
/// command-line value still beats a resource that names a secret.
///
/// The provider here is a [TomMapSecretsProvider], the in-memory one; the
/// HashiCorp Vault, AWS Secrets Manager and Azure Key Vault providers live in
/// their own packages and register the same way. Step 9 implements the
/// interface, which is all a third-party provider is.
///
/// Run with `dart run example/configuration/secrets_example.dart`.
/// The same behaviour is covered by `test/secrets_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

void _resources(Map<String, dynamic> tree) =>
    TomServerConfigResourceProvider.setServerConfigProvider(
      TomServerConfigResourceProvider.from(tree),
    );

Future<void> run() async {
  final vault = TomMapSecretsProvider('vault', {
    'secret/data/billing': {'password': 'pw-1', 'user': 'billing'},
    'secret/data/jwt': 'signing-key-1',
  });
  TomSecrets.register(vault);

  // 1. A resource names secrets; loading reads each provider path once.
  _resources({
    'dbPassword': 'secret:vault:secret/data/billing#password',
    'dbUser': 'secret:vault:secret/data/billing#user',
    'jwtKey': 'secret:vault:secret/data/jwt',
    'label': 'plain values pass through',
  });
  await TomSecrets.load(TomBaseServerConfiguration.collectSources([]));
  print('1. loaded ${TomSecrets.references.length} references');
  check(TomSecrets.references.length == 3, 'three references were loaded');

  // 2. The merged values a configuration object is built from hold the
  //    secrets, never the references.
  final values = TomBaseServerConfiguration.getDefaultValues([]);
  print('2. dbUser=${values['dbUser']}, label=${values['label']}');
  check(values['dbPassword'] == 'pw-1', 'a field of a secret is substituted');
  check(values['jwtKey'] == 'signing-key-1', 'a whole secret is substituted');
  check(values['label'] == 'plain values pass through', 'plain values stay');

  // 3. Precedence is the source's: the command line outranks resources, so a
  //    plain value there beats the resource's reference.
  final args = ['dbPassword=from-the-command-line'];
  await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
  final overridden = TomBaseServerConfiguration.getDefaultValues(args);
  print('3. dbPassword=${overridden['dbPassword']}');
  check(
    overridden['dbPassword'] == 'from-the-command-line',
    'a command-line value beats a resource reference',
  );

  // 4. And a reference on the command line beats a plain resource value.
  _resources({'jwtKey': 'from-the-resource'});
  final secretArgs = ['jwtKey=secret:vault:secret/data/jwt'];
  await TomSecrets.load(TomBaseServerConfiguration.collectSources(secretArgs));
  final fromArgs = TomBaseServerConfiguration.getDefaultValues(secretArgs);
  print('4. jwtKey=${fromArgs['jwtKey']}');
  check(
    fromArgs['jwtKey'] == 'signing-key-1',
    'a command-line reference beats a resource value',
  );

  // 5. A reference that was never loaded is refused — it is never handed to
  //    the configuration as if the reference text were the password.
  try {
    TomSecrets.current('secret:vault:secret/data/billing#unknown-field');
    check(false, 'an unloaded reference is refused');
  } on TomSecretsException catch (e) {
    print('5. refused: ${e.key}');
    check(e.key == 'secrets.reference.unresolved', 'refused by name');
  }

  // 6. A provider nobody registered fails the load, by name.
  try {
    await TomSecrets.load({'x': 'secret:nowhere:a'});
    check(false, 'an unknown provider fails the load');
  } on TomSecretsException catch (e) {
    print('6. refused: ${e.key}');
    check(e.key == 'secrets.provider.unknown', 'refused by name');
  }

  // 7. Rotation: a refresh fetches again and tells the watchers of the
  //    references whose value changed.
  await TomSecrets.load({'jwt': 'secret:vault:secret/data/jwt'});
  final seen = <String>[];
  final subscription = TomSecrets.watch(
    'secret:vault:secret/data/jwt',
    seen.add,
  );
  vault.secrets['secret/data/jwt'] = 'signing-key-2';
  final rotated = await TomSecrets.refresh();
  print('7. changed: ${rotated.changed}');
  check(seen.single == 'signing-key-2', 'the watcher saw the new key');
  subscription.cancel();

  // 8. A refresh that cannot fetch keeps the last value: a provider outage
  //    must not take a running server's credentials away.
  vault.secrets.remove('secret/data/jwt');
  final outage = await TomSecrets.refresh();
  print(
    '8. failed: ${outage.failed}, still ${TomSecrets.current('secret:vault:secret/data/jwt')}',
  );
  check(
    TomSecrets.current('secret:vault:secret/data/jwt') == 'signing-key-2',
    'the last good value is kept',
  );

  // 9. A provider is anything that can fetch a path: here, one that answers
  //    by computing the value, the shape a third party fills in.
  TomSecrets.register(_PrefixProvider());
  await TomSecrets.load({'greeting': 'secret:prefix:world'});
  print('9. ${TomSecrets.current('secret:prefix:world')}');
  check(
    TomSecrets.current('secret:prefix:world') == 'hello world',
    'a custom provider resolves',
  );

  await TomSecrets.reset();
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from({}),
  );
}

class _PrefixProvider implements TomSecretsProvider {
  @override
  String get name => 'prefix';

  @override
  Future<TomSecretPayload> fetch(String path) async =>
      TomSecretPayload('hello $path', version: '1');

  @override
  Future<void> close() async {}
}

Future<void> main() async {
  await run();
}
