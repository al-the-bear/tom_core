# tom_core_secrets_aws — documentation

The catalogue of this package's documentation. The package
[README](../README.md) says what the package is for and how a server registers
it; the pages below carry the detail.

| Document | Covers |
| -------- | ------ |
| [aws_secrets.md](aws_secrets.md) | The reference syntax for secret names and ARNs, the configuration keys and their environment fallbacks, the resilient HTTP client and its destination policy, credentials and roles, request signing, refresh and rotation, the error keys, and running the emulator suite |
| [api/api_summary_tom_core_secrets_aws.md](api/api_summary_tom_core_secrets_aws.md) | Every public type and member, with signatures |

**Elsewhere in the repository:**

| Document | Covers |
| -------- | ------ |
| [`tom_core_server/doc/configuration.md`](../../tom_core_server/doc/configuration.md#secret-references) | Secret references in any configuration source, their precedence, the boot order, rotation, and the provider interface |
| [`tom_core_server/doc/configuration.md`](../../tom_core_server/doc/configuration.md#outgoing-http-calls) § Outgoing HTTP Calls | The `httpClient` key: the timeout, retry, circuit-breaker and bulkhead policies of the provider's calls, overall and per destination |
| [`tom_core_server/doc/api/api_summary_configuration.md`](../../tom_core_server/doc/api/api_summary_configuration.md) | `TomSecrets`, `TomSecretsProvider`, `TomSecretPayload` and the rest of the framework side |
| [`tom_core_server/doc/file_storage.md`](../../tom_core_server/doc/file_storage.md) | The S3 blob store, which signs with the same `TomAwsV4Signer` |
| [`tom_core_secrets_vault`](../../tom_core_secrets_vault/README.md) · [`tom_core_secrets_azure`](../../tom_core_secrets_azure/README.md) | The HashiCorp Vault and Azure Key Vault providers |
