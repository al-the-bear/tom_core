import 'dart:io';

/// The process environment's value for [name], or `null` when it is not set.
///
/// Reach for it through `environment_reader.dart`, which selects this
/// implementation on targets that have a process environment.
///
/// An empty value counts as **set**. `APP_SERVER_URL=` is an operator saying
/// "this variable is present and empty", and reading it as absent would send
/// the setting to a shipped default the operator was deliberately replacing.
String? readPlatformEnvironment(String name) => Platform.environment[name];
