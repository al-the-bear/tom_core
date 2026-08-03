/// The single reflection entry point shared by every example in this package.
///
/// Some of the framework's own types travel over the wire as reflected objects
/// — a `TomUserPreferenceDto` is encoded by `tomReflectionInfo`, not by a
/// hand-written `toJson` — so an example that makes a real HTTP call has to run
/// with reflection initialised or it fails on its first request.
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
