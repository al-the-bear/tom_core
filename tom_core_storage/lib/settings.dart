/// Settings and secrets for Tom applications: the key port for encrypted
/// containers, the platform secret-store port, the device settings file and
/// the one-secret bootstrap that mints its settings key, the user's identity,
/// and the registered storage locations with forgetting one.
///
/// Platform-neutral: no `dart:io`, no container format and no platform plugin.
/// An encrypted settings container, a platform secret store and a container
/// key binding are supplied by the application.
library;

export 'src/settings/device_settings.dart';
export 'src/settings/identity.dart';
export 'src/settings/keys/key_material.dart';
export 'src/settings/keys/key_registry.dart';
export 'src/settings/keys/key_store.dart';
export 'src/settings/location_forgetting.dart';
export 'src/settings/location_registry.dart';
export 'src/settings/secret_store.dart';
export 'src/settings/settings_key_bootstrap.dart';
export 'src/settings/storage_location.dart';
