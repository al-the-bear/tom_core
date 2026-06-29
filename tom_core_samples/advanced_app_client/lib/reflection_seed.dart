// Reflection entry point: the single seed file the reflection generator reads
// to decide what to emit into `reflection_seed.reflection.dart` (see build.yaml).
//
// What needs reflecting, and why: a `TomForm` is itself a `TomClass`, and
// `bind`/`save` enumerate a form's fields through kernel reflection — so both
// the @tomReflector domain entities the forms bind AND the @tomReflector forms
// themselves must be in the reflected graph. This app binds the shared
// advanced_todo_domain entities ([TodoItem] and friends) plus the client-local
// [LoginCredentials], so the seed imports all the sources.
//
// Why one seed reflects everything: the generated `initializeReflection()`
// *assigns* the reflection data (last writer wins), so exactly one seed's
// `initializeReflection()` may run per program. This file is that one seed — it
// must cover every reflected type the app touches, which is why it pulls in
// advanced_todo_domain's entities even though they live in another package.

// ignore: unused_import
import 'domain/login_credentials.dart';
// ignore: unused_import
import 'forms/login_form.dart';
// ignore: unused_import
import 'forms/todo_item_form.dart';
// ignore: unused_import
import 'package:advanced_todo_domain/advanced_todo_domain.dart';

// Re-export the client-local reflected types so they are discoverable through
// this one entry point, plus the generated output so `main.dart` and the tests
// get `initializeReflection()` from here (keeping
// `reflection_seed.reflection.dart` — do-not-edit, regenerate-only — an
// implementation detail).
export 'domain/login_credentials.dart';
export 'forms/login_form.dart';
export 'forms/todo_item_form.dart';
// advanced_todo_domain is imported (above) for generator discovery but
// intentionally NOT re-exported: its library carries its own
// `initializeReflection`, which would collide with the one this seed exports
// below. Callers import advanced_todo_domain directly for its entities.
export 'reflection_seed.reflection.dart';

// The reflection generator treats this file as a runnable program and requires a
// `main`. It is never executed by the app (the entry point is `main.dart`); this
// stub exists solely to satisfy that generator contract.
void main() {}
