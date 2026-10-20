/// Settings and secrets for Tom applications: the key port for encrypted
/// containers, the platform secret-store port, the device settings file and
/// the one-secret bootstrap that mints its settings key, the user's identity,
/// and the registered storage locations with forgetting one.
///
/// Platform-neutral: no `dart:io`, no container format and no platform plugin.
/// An encrypted settings container, a platform secret store and a container
/// key binding are supplied by the application.
library;

export 'src/device_settings.dart';
export 'src/identity.dart';
export 'src/keys/key_material.dart';
export 'src/keys/key_registry.dart';
export 'src/keys/key_store.dart';
export 'src/location_forgetting.dart';
export 'src/location_registry.dart';
export 'src/secret_store.dart';
export 'src/settings_key_bootstrap.dart';
export 'src/storage_location.dart';
