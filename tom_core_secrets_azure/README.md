# tom_core_secrets_azure

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Azure Key Vault as a secrets provider for Tom servers — configuration values
written as `secret:azure:<name>[/<version>]#<field>` references, resolved and
refreshed through the Key Vault REST API with an Entra ID token.

## Overview

`tom_core_server` lets any configuration value be written as a **reference**
to a secret store instead of the value itself:

```yaml
smtpPassword: "secret:azure:smtp-password"
```

The server resolves every reference once at boot, before it builds its
configuration object, and puts the secret where the reference was. Which store
a reference reaches is decided by the provider registered under the name in
its middle part. This package is that provider for Azure Key Vault:
`TomAzureKeyVaultSecretsProvider`, registered as `azure`.

A reference names the secret, and optionally a version: `db-password` reads
the current version, `db-password/<version>` a fixed one. A secret whose value
is a JSON object can be read a field at a time, `db#password`.

Every request carries a Microsoft Entra ID bearer token from a
**credential**: a service principal's client secret, the **managed identity**
of the VM, container or App Service the server runs on, or a token obtained
elsewhere. A token is reused until five minutes before it expires, and a `401`
from Key Vault drops it and retries once with a fresh one. The provider talks
to Key Vault's REST API (version 7.4) over HTTP with `package:http`; there is
no Azure SDK in between.

## Installation

The package is consumed by path inside this repository, beside
`tom_core_server`:

```yaml
dependencies:
  tom_core_server:
    path: ../tom_core_server
  tom_core_secrets_azure:
    path: ../tom_core_secrets_azure
```

Dart SDK `^3.10.0`. The runtime dependencies are `tom_core_server`,
`tom_core_kernel` and `http`.

## Features

| Type | What it does |
| ---- | ------------ |
| `TomAzureKeyVaultSecretsProvider` | The `TomSecretsProvider` over Key Vault: `fetch` reads `secrets/<name>[/<version>]`, answers the value with the version taken from the secret's id, and retries once with a fresh token after a `401`. `fromConfiguration` builds one from `secrets.azure`, falling back to the variables Azure's SDKs read. |
| `TomAzureCredential` | Where the bearer token comes from — `token` and `invalidate`. |
| `TomAzureClientSecretCredential` | A service principal: tenant id, client id and client secret exchanged at Entra ID's token endpoint. |
| `TomAzureManagedIdentityCredential` | The host's managed identity: the App Service / Container Apps identity endpoint when `IDENTITY_ENDPOINT` and `IDENTITY_HEADER` are set, the instance metadata endpoint otherwise; system-assigned, or user-assigned by client id. |
| `TomAzureStaticTokenCredential` | A token obtained elsewhere — `az account get-access-token`, or a test. |
| `tomAzureKeyVaultScope` · `tomAzureKeyVaultResource` | The scope and the resource a Key Vault token is requested for. |

## Quick start

A server registers the provider before it loads its secrets, and loads them
before it builds its configuration:

```dart
import 'dart:io';

import 'package:tom_core_secrets_azure/tom_core_secrets_azure.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main(List<String> args) async {
  TomSecrets.register(
    TomAzureKeyVaultSecretsProvider.fromConfiguration(
      environment: Platform.environment, // AZURE_KEYVAULT_URL, AZURE_TENANT_ID, ...
    ),
  );
  await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
  print(TomSecrets.current('secret:azure:smtp-password'));
  // the current version of the secret `smtp-password`
}
```

The configuration class built after `TomSecrets.load` receives the secret, not
the reference. On Azure compute, the host's identity needs no secret at all:

```dart
final provider = TomAzureKeyVaultSecretsProvider(
  vaultUri: Uri.parse('https://my-vault.vault.azure.net/'),
  credential: TomAzureManagedIdentityCredential(
    environment: Platform.environment,
  ),
);
```

## Example

| Example | Demonstrates |
| ------- | ------------ |
| [`example/azure_secrets_example.dart`](example/azure_secrets_example.dart) | A service principal's token, a field of a JSON secret loaded through `TomSecrets`, and a new version reaching a watcher on refresh while the cached token is reused — against in-process stand-ins for Entra ID and Key Vault, so it runs anywhere |

```bash
dart run example/azure_secrets_example.dart
```

`test/example_test.dart` runs it and requires a clean exit.

## Configuration

`TomAzureKeyVaultSecretsProvider.fromConfiguration` reads the `secrets.azure`
key of the configuration resources; each setting but `managedIdentity` falls
back to an environment variable when an `environment` map is passed:

| Setting | Variable | Meaning |
| ------- | -------- | ------- |
| `vaultUri` | `AZURE_KEYVAULT_URL` | The vault, `https://<name>.vault.azure.net/`. Required. |
| `managedIdentity` | — | `true` uses the host's managed identity. |
| `tenantId` · `clientId` · `clientSecret` | `AZURE_TENANT_ID` · `AZURE_CLIENT_ID` · `AZURE_CLIENT_SECRET` | A service principal. With `managedIdentity`, `clientId` selects a user-assigned identity. |

## Limits

- **The provider's own settings are literal values.** `secrets.azure` holds
  the credentials that open the store, so a reference inside it is not
  resolved.
- **Three credentials are built in.** A certificate credential, workload
  identity federation or the Azure CLI's cache are not; each is an
  implementation of `TomAzureCredential`.
- **A pinned version does not move.** `name/<version>` reads that version on
  every refresh, so only an unpinned reference follows a rotation.

## Further documentation

| Document | Covers |
| -------- | ------ |
| [doc/index.md](doc/index.md) | The catalogue of this package's documentation |
| [doc/azure_secrets.md](doc/azure_secrets.md) | The reference syntax, configuration, the three credentials and token caching, refresh, the error keys and the emulator suite |
| [doc/api/api_summary_tom_core_secrets_azure.md](doc/api/api_summary_tom_core_secrets_azure.md) | Every public type and member |
| [`tom_core_server/doc/configuration.md`](../tom_core_server/doc/configuration.md#secret-references) | Secret references in general: syntax, precedence, boot order, rotation, writing a provider |

The Vault and AWS providers are [`tom_core_secrets_vault`](../tom_core_secrets_vault/README.md)
and [`tom_core_secrets_aws`](../tom_core_secrets_aws/README.md).

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_core_server` | runtime | `TomSecretsProvider`, `TomSecretPayload`, `TomSecretsException`, `TomServerConfigResourceProvider` |
| `tom_core_kernel` | runtime | the framework base the server builds on |
| `http` | runtime | the Key Vault REST API and the token endpoints |
| `test`, `lints` | dev | the suite |

## Status

Version **0.1.0**. `dart test` runs the unit suite, which drives the provider
and the credentials against `MockClient` stand-ins, and the example. The tests
tagged `emulator` run against Lowkey Vault, an Azure Key Vault emulator, and
skip themselves when it does not answer; `tool/run_emulator_tests.sh` starts it
in Docker, runs them, and fails when every one of them skipped.
