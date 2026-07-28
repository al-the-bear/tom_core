// Conditional export: the right `TomFileClientConfigurationStore` is chosen at
// compile time — the native JSON-file implementation when `dart:io` is
// available, and a variant that fails loudly on construction when it is not.
// Same shape as `platform_detection_client.dart` in the runtime module.
export 'file_configuration_store_neutral.dart'
    if (dart.library.io) 'file_configuration_store_io.dart';
