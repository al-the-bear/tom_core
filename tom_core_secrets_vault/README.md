# tom_core_secrets_vault

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

HashiCorp Vault as a secrets provider for Tom servers — configuration values
written as `secret:vault:<path>#<field>` references, resolved and refreshed
through the Vault HTTP API.

## Overview

`tom_core_server` lets any configuration value be written as a **reference**
to a secret store instead of the value itself:

```yaml
jwtSharedSecretKey: "secret:vault:secret/data/billing#jwt"
```

The server resolves every reference once at boot, before it builds its
configuration object, and puts the secret where the reference was. Which store
a reference reaches is decided by the provider registered under the name in
its middle part. This package is that provider for HashiCorp Vault:
`TomVaultSecretsProvider`, registered as `vault`.

A reference names the API path after `/v1/`, exactly as Vault's own CLI and
documentation do, and `#<field>` picks one value of the entry. Both KV versions
are read — version 2 nests the entry under `data` a second time and carries a
version number — and so is any engine whose response holds its values under
`data`. The provider talks to Vault over HTTP with `package:http`; there is no
Vault SDK in between.

Two ways to authenticate are built in: a fixed **token** (a developer's
`VAULT_TOKEN`, an agent sidecar, a CI job) and **AppRole** (a role id and a
secret id exchanged for a token that is renewed by logging in again).

## Installation

The package is consumed by path inside this repository, beside
`tom_core_server`:

```yaml
dependencies:
  tom_core_server:
    path: ../tom_core_server
  tom_core_secrets_vault:
    path: ../tom_core_secrets_vault
```

Dart SDK `^3.10.0`. The runtime dependencies are `tom_core_server`,
`tom_core_kernel` and `http`.

## Features

| Type | What it does |
| ---- | ------------ |
| `TomVaultSecretsProvider` | The `TomSecretsProvider` over Vault: `fetch` reads a path through `GET /v1/<path>`, understands KV version 1 and 2, sends the namespace header, and retries once with a fresh token after a `403`. `fromConfiguration` builds one from `secrets.vault`, falling back to Vault's own environment variables. |
| `TomVaultAuth` | How the provider obtains its token — `token` and `invalidate`. |
| `TomVaultTokenAuth` | A fixed token. |
| `TomVaultAppRoleAuth` | AppRole: logs in at `auth/<mount>/login`, keeps the token for nine tenths of its lease, and logs in again when the lease runs out or Vault refuses the token. |

## Quick start

A server registers the provider before it loads its secrets, and loads them
before it builds its configuration:

```dart
import 'dart:io';

import 'package:tom_core_secrets_vault/tom_core_secrets_vault.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main(List<String> args) async {
  TomSecrets.register(
    TomVaultSecretsProvider.fromConfiguration(
      environment: Platform.environment, // VAULT_ADDR, VAULT_TOKEN, ...
    ),
  );
  await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
  print(TomSecrets.current('secret:vault:secret/data/billing#jwt'));
  // the field `jwt` of the KV v2 entry `billing`
}
```

The configuration class built after `TomSecrets.load` receives the secret, not
the reference: `TomBaseServerConfiguration.getDefaultValues` substitutes every
loaded reference in place. `TomSecrets.startRefresh` keeps the values current
when Vault rotates them; see [doc/vault_secrets.md](doc/vault_secrets.md).

Without a configuration, construct the provider directly:

```dart
final provider = TomVaultSecretsProvider(
  address: Uri.parse('https://vault.example.com:8200'),
  auth: TomVaultAppRoleAuth(roleId: roleId, secretId: secretId),
  namespace: 'team-a',
);
```

## Example

| Example | Demonstrates |
| ------- | ------------ |
| [`example/vault_secrets_example.dart`](example/vault_secrets_example.dart) | Building the provider from configuration, loading two fields of one KV v2 entry, and a rotation reaching a watcher on refresh — against an in-process stand-in for Vault, so it runs anywhere |

```bash
dart run example/vault_secrets_example.dart
```

`test/example_test.dart` runs it and requires a clean exit.

## Configuration

`TomVaultSecretsProvider.fromConfiguration` reads the `secrets.vault` key of
the configuration resources; each setting falls back to an environment
variable when an `environment` map is passed:

| Setting | Variable | Meaning |
| ------- | -------- | ------- |
| `address` | `VAULT_ADDR` | Where Vault answers. Required. |
| `token` | `VAULT_TOKEN` | A fixed token. |
| `roleId` · `secretId` | `VAULT_ROLE_ID` · `VAULT_SECRET_ID` | AppRole; preferred over a token when both are given. |
| `appRoleMount` | `VAULT_APPROLE_MOUNT` | Where the AppRole method is mounted; `approle` by default. |
| `namespace` | `VAULT_NAMESPACE` | The Vault Enterprise namespace, sent as `X-Vault-Namespace`. |

## Limits

- **The provider's own settings are literal values.** `secrets.vault` holds
  the credentials that open the store, so it is read as written and a
  reference inside it is not resolved.
- **A dynamic secret's lease is not renewed.** An engine that issues
  credentials with a lease — the database engine, say — is read like any
  other; the provider re-reads the path on refresh, and renewing or revoking
  the lease stays with Vault.
- **Only token and AppRole are built in.** Another auth method is an
  implementation of `TomVaultAuth`, which logs in through the provider's public
  `call`.

## Further documentation

| Document | Covers |
| -------- | ------ |
| [doc/index.md](doc/index.md) | The catalogue of this package's documentation |
| [doc/vault_secrets.md](doc/vault_secrets.md) | The reference syntax, configuration, the two auth methods, namespaces, refresh, the error keys and the emulator suite |
| [doc/api/api_summary_tom_core_secrets_vault.md](doc/api/api_summary_tom_core_secrets_vault.md) | Every public type and member |
| [`tom_core_server/doc/configuration.md`](../tom_core_server/doc/configuration.md#secret-references) | Secret references in general: syntax, precedence, boot order, rotation, writing a provider |

The AWS and Azure providers are [`tom_core_secrets_aws`](../tom_core_secrets_aws/README.md)
and [`tom_core_secrets_azure`](../tom_core_secrets_azure/README.md).

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_core_server` | runtime | `TomSecretsProvider`, `TomSecretPayload`, `TomSecretsException`, `TomServerConfigResourceProvider` |
| `tom_core_kernel` | runtime | the framework base the server builds on |
| `http` | runtime | the Vault HTTP API |
| `test`, `lints` | dev | the suite |

## Status

Version **0.1.0**. `dart test` runs the unit suite, which drives the provider
against `MockClient` stand-ins, and the example. The tests tagged `emulator`
run against a real Vault dev server and skip themselves when none answers;
`tool/run_emulator_tests.sh` starts one in Docker, runs them, and fails when
every one of them skipped.
