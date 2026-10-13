# Changelog

## 0.1.0

### Added

- **`TomAzureKeyVaultSecretsProvider`**: a `TomSecretsProvider` over the Azure
  Key Vault REST API (`apiVersion` `7.4` by default), registered as `azure`. A
  reference names the secret, optionally with a version
  (`secret:azure:db-password`, `secret:azure:db-password/<version>`, a JSON
  field with `#<field>`); `fetch` answers the value with the version read from
  the secret's id. `call` is the public REST client; it sends the bearer token
  and, after a `401`, drops it and retries once with a fresh one.
- **`TomAzureKeyVaultSecretsProvider.fromConfiguration`**: the provider from
  the `secrets.azure` configuration key (`vaultUri`, `tenantId`, `clientId`,
  `clientSecret`, `managedIdentity`), falling back to `AZURE_KEYVAULT_URL`,
  `AZURE_TENANT_ID`, `AZURE_CLIENT_ID` and `AZURE_CLIENT_SECRET` in the
  `environment` map passed. Refusals `secrets.azure.config.missing_vault` and
  `secrets.azure.config.missing_credentials`.
- **`TomAzureCredential`** and three implementations:
  `TomAzureClientSecretCredential` (the client-credentials grant at
  `<authorityHost>/<tenant>/oauth2/v2.0/token`, scope
  `https://vault.azure.net/.default`), `TomAzureManagedIdentityCredential`
  (the App Service / Container Apps identity endpoint with
  `X-IDENTITY-HEADER`, or the instance metadata endpoint with `Metadata: true`;
  system- or user-assigned) and `TomAzureStaticTokenCredential`. Fetched tokens
  are kept until five minutes before they expire (half their lifetime when that
  is ten minutes or less). A token endpoint that refuses or answers without a
  token is `secrets.azure.token_failed`.
- **`tomAzureKeyVaultScope`** and **`tomAzureKeyVaultResource`**.
- Failures are `TomSecretsException`s keyed `secrets.fetch.not_found` (a `404`)
  and `secrets.fetch.failed`, never carrying a secret's value.
- `example/azure_secrets_example.dart`, the `MockClient` unit suite, the
  `emulator`-tagged suite against Lowkey Vault and
  `tool/run_emulator_tests.sh`, which runs it in Docker.
- `README.md`, `doc/index.md`, `doc/azure_secrets.md` and
  `doc/api/api_summary_tom_core_secrets_azure.md`.
