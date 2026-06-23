// Reflection entry point: the single seed file the reflection generator reads
// to decide what to emit into `reflection_seed.reflection.dart`.
//
// What needs reflecting, and why: a `TomForm` is itself a `TomClass`, and
// `bind`/`setValues` enumerate a form's fields through kernel reflection — so
// both the @tomReflector *domain entities* (CompanyProfile / ResponsiveProfile)
// AND the @tomReflector *forms* that bind them (CompanyForm / FamilyForm) must
// be in the reflected graph. This seed imports exactly those, and nothing else.
//
// On graph size: reflecting a form necessarily reflects its field types
// (`TomFormStringInput` and friends are themselves `@tomReflector`), so the
// generated file is large — the same trade-off the verified
// `tom_flutter_form_test` accepts. The win of a *dedicated* seed (over seeding
// from `main.dart`) is intent: the reflected graph is exactly the entities and
// forms this sample teaches, not whatever app-specific tree `main.dart`
// happens to reference.

// ignore: unused_import
import 'domain/responsive_entities.dart';
// ignore: unused_import
import 'forms/company_form.dart';
// ignore: unused_import
import 'forms/family_form.dart';

// Re-export the reflected types so they are discoverable through this one entry
// point, plus the generated output so `main.dart` and the tests get
// `initializeReflection()` from here (keeping `reflection_seed.reflection.dart`
// — do-not-edit, regenerate-only-on-signature-change — an implementation
// detail).
export 'domain/responsive_entities.dart';
export 'forms/company_form.dart';
export 'forms/family_form.dart';
export 'reflection_seed.reflection.dart';

// The reflection generator treats this file as a runnable program and requires
// a `main`. It is never executed by the app (the entry point is `main.dart`);
// this stub exists solely to satisfy that generator contract.
void main() {}
