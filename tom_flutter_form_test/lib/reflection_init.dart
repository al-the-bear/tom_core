// This file is the reflection entry point.
// It imports only state classes that use @tomReflector.
// Demo files and tom_flutter_ui are NOT imported here to avoid
// reflection generator processing the entire UI library.

// ignore: unused_import
import 'state/company_state.dart';
// ignore: unused_import
import 'state/application_state.dart';

// Re-export state classes so they're discoverable
export 'state/company_state.dart';
export 'state/application_state.dart';

// Re-export generated reflection
export 'main.reflection.dart';

// Dummy main function required for reflection generator
void main() {}
