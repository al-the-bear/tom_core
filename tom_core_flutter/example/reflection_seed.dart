/// The single reflection entry point shared by every example in this package.
///
/// The framework's own types are reflected objects like any other — a
/// `TomUserPreferenceDto` is encoded by `tomReflectionInfo`, on disk and on the
/// wire alike — so an example that exercises them runs with reflection
/// initialised, exactly as an application does. Every entrypoint runs
/// `reflection_generator` and the generated seed covers the whole dependency
/// closure, framework types included; this file is that seed for the examples.
///
/// Why one seed for the whole folder rather than one per example: the generated
/// `initializeReflection()` *assigns* the reflection data (last writer wins), so
/// only one seed may run per program, and each companion the generator emits for
/// a file importing the barrel is several megabytes. One shared seed keeps that
/// cost paid once no matter how many examples come to need it.
///
/// An example that needs reflection imports this file and calls
/// `initializeReflection()` as its first action.
library;

// Imported for generator discovery: everything reflected that an example can
// reach is reachable through the package barrel.
// ignore: unused_import
import 'package:tom_core_flutter/tom_core_flutter.dart';

export 'reflection_seed.reflection.dart';

// The reflection generator treats this file as a runnable program and requires a
// `main`. No example ever calls it; the stub exists to satisfy that contract.
void main() {}
