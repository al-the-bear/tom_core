/// Reflection seed for `advanced_authadmin_client` — the single entry point the
/// reflection generator reads to decide what to emit into
/// `reflection_seed.reflection.dart` (see `build.yaml`).
///
/// What needs reflecting, and why: a `TomForm` is itself a `TomClass`, and
/// `bind`/`save` enumerate a form's fields through kernel reflection — so both
/// the `@tomReflector` entities the forms bind AND the `@tomReflector` forms
/// themselves must be in the reflected graph. The admin console binds
/// *client-local* reflected drafts ([UserDraft]/[RoleDraft]/[GroupDraft]) rather
/// than the wire DTOs (which are plain records folded by hand), so the seed
/// pulls in the drafts and the three forms over them.
///
/// Why one seed reflects everything: the generated `initializeReflection()`
/// *assigns* the reflection data (last writer wins), so exactly one seed's
/// `initializeReflection()` may run per program. This file is that one seed.
library;

// ignore: unused_import
import 'domain/admin_drafts.dart';
// ignore: unused_import
import 'forms/user_form.dart';
// ignore: unused_import
import 'forms/role_form.dart';
// ignore: unused_import
import 'forms/group_form.dart';

// Re-export the client-local reflected types so they are discoverable through
// this one entry point, plus the generated output so `main.dart` and the tests
// get `initializeReflection()` from here (keeping
// `reflection_seed.reflection.dart` — do-not-edit, regenerate-only — an
// implementation detail).
export 'domain/admin_drafts.dart';
export 'forms/user_form.dart';
export 'forms/role_form.dart';
export 'forms/group_form.dart';
export 'reflection_seed.reflection.dart';

// The reflection generator treats this file as a runnable program and requires a
// `main`. It is never executed by the app (the entry point is `main.dart`); this
// stub exists solely to satisfy that generator contract.
void main() {}
