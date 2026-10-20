# Changelog

## 0.1.0

### Added

- **The device settings file.** `TomDeviceSettings`: plain YAML at a locator,
  read and committed through a `TomStorage`; an open registry of keys that is
  written back whole, so a key this build does not know survives; typed
  accessors for the settings-key handle, the log's path and level and the
  cache's quota and sealing; one serialized write queue, so concurrent writers
  never refuse each other; a malformed file reads as empty.
- **The settings-key bootstrap.** `TomSettingsKeyBootstrap.ensure` mints one
  random secret per device into the platform secret store and records its
  handle in device settings, idempotently; a wiped keychain re-mints the
  secret under the same handle. A store that cannot be asked raises
  `TomSecretStoreException` with its `TomSecretStoreStep` and cause.
- **The secret-store port.** `TomSecretStore` (a `TomCacheKeyStore`) and
  `TomInMemorySecretStore`.
- **The key port.** `TomKeyMaterial`, `TomKeyRegistry` with
  `TomMemoryKeyRegistry`, `TomKeyStore` with `TomInMemoryKeyStore`.
- **Identity and locations.** `TomIdentity`, `TomStorageLocation`,
  `TomLocationRegistry` with `TomInMemoryLocationRegistry`, and
  `TomLocationForgetting` with `TomLocationTraces` and `TomForgottenLocation`.

These came from the Webwork app, where they carried the `Webwork` prefix; the
bootstrap there also opened the KDBX settings container, which stays with the
container binding.
