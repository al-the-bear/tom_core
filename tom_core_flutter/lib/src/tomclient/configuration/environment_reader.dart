// Conditional export: the right `readPlatformEnvironment` is chosen at compile
// time — the process environment when `dart:io` is available, and a variant
// that reports nothing when it is not. Same shape as
// `file_configuration_store.dart` beside it.
export 'environment_reader_neutral.dart'
    if (dart.library.io) 'environment_reader_io.dart';
