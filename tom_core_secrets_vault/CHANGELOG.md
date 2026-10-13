# Changelog

## 0.1.0

### Added

- **`TomVaultSecretsProvider`**: a `TomSecretsProvider` over the HashiCorp
  Vault HTTP API, registered as `vault` by default. A reference names the API
  path after `/v1/` (`secret:vault:secret/data/billing#jwt`); `fetch` reads KV
  version 2 entries with their version number, KV version 1 entries, and any
  engine whose response holds its values under `data`. `call` is the public
  `/v1/<path>` client the auth methods log in through; it sends
  `X-Vault-Token` and, when set, `X-Vault-Namespace`, and retries an
  authenticated call once with a fresh token after a `403`.
- **`TomVaultSecretsProvider.fromConfiguration`**: the provider from the
  `secrets.vault` configuration key (`address`, `token`, `roleId`, `secretId`,
  `appRoleMount`, `namespace`), each falling back to `VAULT_ADDR`,
  `VAULT_TOKEN`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID`, `VAULT_APPROLE_MOUNT` and
  `VAULT_NAMESPACE` in the `environment` map passed; AppRole is preferred over
  a token. Refusals `secrets.vault.config.missing_address` and
  `secrets.vault.config.missing_credentials`.
- **`TomVaultAuth`**, **`TomVaultTokenAuth`** and **`TomVaultAppRoleAuth`**: a
  fixed token, or AppRole login at `auth/<mount>/login` with the token kept for
  nine tenths of its lease (a lease of zero never expires) and dropped on
  `invalidate`. A login answered without a client token is
  `secrets.vault.login_failed`.
- Failures are `TomSecretsException`s keyed `secrets.fetch.not_found` (a `404`)
  and `secrets.fetch.failed` (an unreachable Vault, any other status, a body
  without `data`), never carrying a secret's value.
- `example/vault_secrets_example.dart`, the `MockClient` unit suite, the
  `emulator`-tagged suite against a Vault dev server and
  `tool/run_emulator_tests.sh`, which runs it in Docker.
- `README.md`, `doc/index.md`, `doc/vault_secrets.md` and
  `doc/api/api_summary_tom_core_secrets_vault.md`.
