# configuration

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Typed access to server configuration. A `TomBaseServerConfiguration` loads
property sources (YAML via `TomYaml`, env, args) into the active
`TomServerConfigResourceProvider`; `TomConfig<T>` and its typed subclasses then
resolve individual keys — obligatory (throws when absent) or with a default.
A value in any source may be a secret reference, `secret:<provider>:<path>[#<field>]`,
which `TomSecrets` resolves from a secret store before the configuration is
built.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomBaseServerConfiguration` | Abstract configuration root: assembles the property sources, refuses to build when a field marked `@TomRequiredField` was supplied by no source, warns about configuration-resource keys no field declares and about `@TomRecommendedField` settings no source supplied, and installs the active config provider. |
| `TomServerConfigResourceProvider` | Holds the merged config map; `exists(key)` / `get(key)` back every `TomConfig` lookup. `get` is total — an unknown key resolves to the key string, a cleared one to `null` — so **gate on `exists`**: that is what tells "never mentioned" from "configured as nothing". |
| `TomConfig<T>` | Resolves one key to `T`; `TomConfig(key)` is obligatory, `TomConfig.withDefault(key, value)` falls back. `get()` / `~config` read the value. The read is **eager**, so build one only after a provider is installed — building one before any exists is refused, naming the ordering rather than answering from an empty placeholder. |
| `TomBaseServerConfiguration` JWT fields | `jwtAlgorithm` (`JWT_ALGORITHM`), `jwtSigningKeyFile` (`JWT_SIGNING_KEY_FILE`), `jwtVerificationKeyFiles` (`JWT_VERIFICATION_KEY_FILES`), `jwtIssuer` (`JWT_ISSUER`), `jwtAudience` (`JWT_AUDIENCE`), `jwtSharedSecretKey` (`JWT_SHARED_SECRET_KEY`, the HS256 secret) and the payload-encryption pair `jwtRsaPrivKey` / `jwtRsaPubKey` — the token signing configuration `installJwtSigning` reads at boot. |
| `TomBaseServerConfiguration.usesDevelopmentTlsMaterial()` | Whether either half of the TLS material is still the pair committed to this repository. `TomServer.start` warns on it before every TLS bind; nothing refuses to start. |
| `TomConfigurationException` | Every way resolution fails, as one `TomServerException` subtype told apart by `key`: absent-and-undefaulted, bad cast, no provider yet. `clientThrow` is `false` — a configuration message names internal keys and, for a mismatch, the offending value. |
| `TomStringConfig` · `TomIntConfig` · `TomDoubleConfig` · `TomBoolConfig` | Typed specialisations of `TomConfig<T>`. |
| `TomConfigurationException` | Raised when a value fails the cast to `T`. Chains the `TypeError` as `rootException` — read it for a generic mismatch, where the message alone names a value that looks valid. |
| `TomYaml` | Parses YAML configuration resources, expanding `${VAR:default}` from `Platform.environment` or from an `environment:` map you pass (`TomEnvFile.resolveEnvironment()` to include a `.env`). `loadYamlFile` / `mergeInYamlFile` require the file to exist and throw `PathNotFoundException` when it does not — unlike `TomEnvFile.read`, which returns `{}`; `loadYamlFileIfPresent` / `mergeInYamlFileIfPresent` forgive an absent file, and only an absent file, and report whether it was there. |
| `TomSecrets` | The secrets registry: `register` a `TomSecretsProvider`, `load` every reference in `TomBaseServerConfiguration.collectSources(args)` before the configuration is built (fatal on any failure), and `getDefaultValues` substitutes each in place — so a secret has its source's precedence. `refresh` / `startRefresh` re-read the store fail-soft and call `watch`ers of changed references. |
| `TomSecretsProvider` · `TomMapSecretsProvider` | A secret store, registered under the name references use; the map-backed one is for tests and local development. Vault, AWS Secrets Manager and Azure Key Vault have a package each (`tom_core_secrets_vault`, `_aws`, `_azure`). |
| `TomSecretReference` · `TomSecretPayload` · `TomSecretSubscription` · `TomSecretsRefresh` · `TomSecretsException` | A parsed reference, what a provider read, a watcher's registration, a refresh's outcome, and every secrets failure, keyed `secrets.*`. |
| `selectedRuntimeEnvironmentName` | Which runtime environment the deployment selected (`env`), read from the command line, then the `.env`, then the OS environment. The selection has to happen *before* the configuration exists — it is what picks the overlay — so it reads those sources itself rather than coming out of the merge. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  // The provider first. A TomConfig reads its value once, at construction, so
  // one built before any provider exists is refused rather than answered from
  // an empty default. A server gets this from TomBaseServerConfiguration.
  TomServerConfigResourceProvider.setServerConfigProvider(
    TomServerConfigResourceProvider.from({
      'server': {'host': 'localhost'},
    }),
  );

  final port = TomIntConfig.withDefault('server.port', 8080);
  final host = TomStringConfig.withDefault('server.host', 'localhost');

  print(~port); // 8080  (the default, since the tree has no server.port)
  print(~host); // localhost  (from the tree)
}
```

**Metrics.** `metricsEndpoint`, `metricsPath`, `metricsToken`, `otlpEndpoint`,
`otlpHeaders` and `otlpMetricsIntervalSeconds` decide whether the series leave
the process as a Prometheus scrape, an OTLP push, or both — see [`doc/metrics.md`](../../../../doc/metrics.md).

See [`doc/configuration.md`](../../../../doc/configuration.md) for the source
precedence, the typed key wrappers and the loader hook, and
`example/configuration/configuration_example.dart` for a twelve-step walkthrough
that checks its own results — beginning with the loader hook, because a provider
installed after the first read is a provider that read did not see.
`example/configuration/secrets_example.dart` walks secret references in nine
checked steps — precedence, an unloaded reference refused, rotation, a
third-party provider — and `test/secrets_test.dart` covers them.
`test/configuration_test.dart` covers the module and also runs the example,
`test/runtime_environment_test.dart` covers the environment selector, and
`test/readme_quick_start_test.dart` runs the snippet above, so none can drift
unnoticed.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
