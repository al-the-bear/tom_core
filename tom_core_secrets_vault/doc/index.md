# tom_core_secrets_vault — documentation

The catalogue of this package's documentation. The package
[README](../README.md) says what the package is for and how a server registers
it; the pages below carry the detail.

| Document | Covers |
| -------- | ------ |
| [vault_secrets.md](vault_secrets.md) | The reference syntax for Vault paths, the configuration keys and their environment fallbacks, the resilient HTTP client and its destination policy, token and AppRole authentication, namespaces, refresh and rotation, the error keys, and running the emulator suite |
| [api/api_summary_tom_core_secrets_vault.md](api/api_summary_tom_core_secrets_vault.md) | Every public type and member, with signatures |

**Elsewhere in the repository:**

| Document | Covers |
| -------- | ------ |
| [`tom_core_server/doc/configuration.md`](../../tom_core_server/doc/configuration.md#secret-references) | Secret references in any configuration source, their precedence, the boot order, rotation, and the provider interface |
| [`tom_core_server/doc/configuration.md`](../../tom_core_server/doc/configuration.md#outgoing-http-calls) § Outgoing HTTP Calls | The `httpClient` key: the timeout, retry, circuit-breaker and bulkhead policies of the provider's calls, overall and per destination |
| [`tom_core_server/doc/api/api_summary_configuration.md`](../../tom_core_server/doc/api/api_summary_configuration.md) | `TomSecrets`, `TomSecretsProvider`, `TomSecretPayload` and the rest of the framework side |
| [`tom_core_secrets_aws`](../../tom_core_secrets_aws/README.md) · [`tom_core_secrets_azure`](../../tom_core_secrets_azure/README.md) | The AWS Secrets Manager and Azure Key Vault providers |
