// Reflection entry point: the single seed file the reflection generator reads
// to decide what to emit into `main.reflection.dart`.
//
// Why only state/form classes are imported: the generator walks the transitive
// types reachable from this file. Importing the demo widgets or `tom_flutter_ui`
// here would drag the entire UI library into the reflected graph — slower
// generation and a much larger generated file — for no benefit, since only the
// @tomReflector-annotated state/form models actually need reflection.

// ignore: unused_import
import 'state/company_state.dart';
// ignore: unused_import
import 'state/application_state.dart';
// ignore: unused_import
import 'state/phase5_state.dart';
// ignore: unused_import
import 'forms/phase5_demo_forms.dart';

// Re-export state classes so they're discoverable
export 'state/company_state.dart';
export 'state/application_state.dart';
export 'state/phase5_state.dart';
export 'forms/phase5_demo_forms.dart';

// Re-export the generator output so consumers can get the seed types and the
// generated `initializeReflection()` through this one entry point. Why: keeps
// `main.reflection.dart` (do-not-edit, regenerate-only-on-signature-change) an
// implementation detail behind this stable file.
export 'main.reflection.dart';

// Why: the reflection generator treats this file as a runnable program and
// requires a `main`. It is never executed by the app (the app's entry point is
// `main.dart`); this stub exists solely to satisfy that generator contract.
void main() {}
