# tom_core_secrets_aws

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

AWS Secrets Manager as a secrets provider for Tom servers — configuration
values written as `secret:aws:<secret-id>#<field>` references, resolved and
refreshed through the Secrets Manager API with SigV4.

## Overview

`tom_core_server` lets any configuration value be written as a **reference**
to a secret store instead of the value itself:

```yaml
databasePassword: "secret:aws:prod/billing#password"
```

The server resolves every reference once at boot, before it builds its
configuration object, and puts the secret where the reference was. Which store
a reference reaches is decided by the provider registered under the name in
its middle part. This package is that provider for AWS Secrets Manager:
`TomAwsSecretsProvider`, registered as `aws`.

A reference names the secret by **name or ARN**. Without a field the whole
`SecretString` is the value; `#<field>` reads one member of a secret that
holds a JSON object — the shape the Secrets Manager console writes for
key/value secrets. The current version (`AWSCURRENT`) is read, so a rotation
by Secrets Manager reaches the server at the next refresh.

The provider calls `GetSecretValue` over HTTP and signs it with the
framework's own Signature Version 4 signer — the one `tom_core_server`'s S3
blob store uses — so no AWS SDK is involved. Credentials come from a
**credentials source** called for every request: static keys for a developer
or a CI job, or a function returning a role's temporary credentials on an
instance or task role.

## Installation

The package is consumed by path inside this repository, beside
`tom_core_server`:

```yaml
dependencies:
  tom_core_server:
    path: ../tom_core_server
  tom_core_secrets_aws:
    path: ../tom_core_secrets_aws
```

Dart SDK `^3.10.0`. The runtime dependencies are `tom_core_server`,
`tom_core_kernel`, `http` and `crypto`.

## Features

| Type | What it does |
| ---- | ------------ |
| `TomAwsSecretsProvider` | The `TomSecretsProvider` over Secrets Manager: `fetch` calls `GetSecretValue` for a secret id, answers its `SecretString`, or its `SecretBinary` when that is UTF-8 text, with the `VersionId`. `fromConfiguration` builds one from `secrets.aws`, falling back to the standard `AWS_*` variables. `call` is the signed client for any Secrets Manager action. |
| `TomAwsCredentialsSource` | `Future<TomAwsCredentials> Function()` — where each request's credentials come from. |

## Quick start

A server registers the provider before it loads its secrets, and loads them
before it builds its configuration:

```dart
import 'dart:io';

import 'package:tom_core_secrets_aws/tom_core_secrets_aws.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main(List<String> args) async {
  TomSecrets.register(
    TomAwsSecretsProvider.fromConfiguration(
      environment: Platform.environment, // AWS_REGION, AWS_ACCESS_KEY_ID, ...
    ),
  );
  await TomSecrets.load(TomBaseServerConfiguration.collectSources(args));
  print(TomSecrets.current('secret:aws:prod/billing#password'));
  // the member `password` of the JSON secret `prod/billing`
}
```

The configuration class built after `TomSecrets.load` receives the secret, not
the reference. On a role, construct the provider with a credentials source
that returns the role's current temporary credentials instead:

```dart
final provider = TomAwsSecretsProvider(
  region: 'eu-west-1',
  credentials: roleCredentials, // a TomAwsCredentialsSource
);
```

## Example

| Example | Demonstrates |
| ------- | ------------ |
| [`example/aws_secrets_example.dart`](example/aws_secrets_example.dart) | A signed `GetSecretValue`, a member of a JSON secret loaded through `TomSecrets`, and a rotation reaching a watcher on refresh — against an in-process stand-in for Secrets Manager, so it runs anywhere |

```bash
dart run example/aws_secrets_example.dart
```

`test/example_test.dart` runs it and requires a clean exit.

## Configuration

`TomAwsSecretsProvider.fromConfiguration` reads the `secrets.aws` key of the
configuration resources; each setting falls back to the standard AWS variables
when an `environment` map is passed:

| Setting | Variable | Meaning |
| ------- | -------- | ------- |
| `region` | `AWS_REGION`, then `AWS_DEFAULT_REGION` | The region the secrets live in. Required. |
| `accessKeyId` | `AWS_ACCESS_KEY_ID` | Required for the configured form. |
| `secretAccessKey` | `AWS_SECRET_ACCESS_KEY` | Required for the configured form. |
| `sessionToken` | `AWS_SESSION_TOKEN` | Optional, for temporary credentials. |
| `endpoint` | `AWS_ENDPOINT_URL_SECRETS_MANAGER` | Optional: a VPC endpoint or an emulator instead of `https://secretsmanager.<region>.amazonaws.com/`. |

## Limits

- **`fromConfiguration` takes static keys only.** Credentials that rotate —
  an instance profile, a task role, an assumed role — are supplied by
  constructing the provider with a `TomAwsCredentialsSource`; the package does
  not call the instance metadata service or STS itself.
- **A binary secret must be text.** `SecretBinary` is decoded as UTF-8; a
  secret that is not text cannot be a configuration value and is refused,
  `secrets.aws.binary_not_text`.
- **Only the current version is read.** A reference cannot pin a `VersionId`
  or a staging label.

## Further documentation

| Document | Covers |
| -------- | ------ |
| [doc/index.md](doc/index.md) | The catalogue of this package's documentation |
| [doc/aws_secrets.md](doc/aws_secrets.md) | The reference syntax, configuration, credentials and roles, signing, refresh, the error keys and the emulator suite |
| [doc/api/api_summary_tom_core_secrets_aws.md](doc/api/api_summary_tom_core_secrets_aws.md) | Every public type and member |
| [`tom_core_server/doc/configuration.md`](../tom_core_server/doc/configuration.md#secret-references) | Secret references in general: syntax, precedence, boot order, rotation, writing a provider |

The Vault and Azure providers are [`tom_core_secrets_vault`](../tom_core_secrets_vault/README.md)
and [`tom_core_secrets_azure`](../tom_core_secrets_azure/README.md).

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_core_server` | runtime | `TomSecretsProvider`, `TomSecretPayload`, `TomSecretsException`, `TomServerConfigResourceProvider`, and the SigV4 signer `TomAwsV4Signer` with `TomAwsCredentials` |
| `tom_core_kernel` | runtime | the framework base the server builds on |
| `http` | runtime | the Secrets Manager JSON API |
| `crypto` | runtime | the SHA-256 payload hash the signature covers |
| `test`, `lints` | dev | the suite |

## Status

Version **0.1.0**. `dart test` runs the unit suite, which drives the provider
against `MockClient` stand-ins, and the example. The tests tagged `emulator`
run against LocalStack's Secrets Manager and skip themselves when it does not
answer; `tool/run_emulator_tests.sh` starts it in Docker, runs them, and fails
when every one of them skipped.
