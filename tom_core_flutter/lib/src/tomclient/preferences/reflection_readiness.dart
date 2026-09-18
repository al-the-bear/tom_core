/// Telling "reflection was never initialised" apart from every other failure.
///
/// Both halves of this module encode `TomUserPreferenceDto` through
/// `tomReflectionInfo`, so both meet the same configuration fault: an
/// application whose `main` never called `initializeReflection()`. Reported as
/// whatever failure happened to surface, it is the worst available diagnosis —
/// the stored document reads as corrupt, or a correctly behaving server reads
/// as broken, and the first thing anyone does is inspect something that is fine.
///
/// Not exported from the package barrel: this is how the module words its own
/// errors, not a question an application asks. The two error keys it produces —
/// `device_preferences.store.reflection_not_initialised` and
/// `preferences.client.reflection_not_initialised` — are the surface.
library;

/// The half of reflection's refusal that would have to change for the message
/// to mean something else.
///
/// Matched on text rather than on a type or a constant because `tom_reflection`
/// raises a bare [StateError] built from a `const` string its barrel does not
/// export. A miss costs only the more general error that was going to be thrown
/// anyway, which is why the match is on the narrow, invariant phrase rather than
/// on the whole sentence.
const String _uninitialisedMarker = 'Reflection has not been initialized';

/// Whether [error], or anything it wraps, is reflection reporting that it was
/// never initialised.
///
/// The cause chain is short — a framework exception wrapping the [StateError] —
/// but it is walked rather than unwrapped once, because which layer catches
/// first depends on where the call entered reflection. The depth bound is
/// against a cycle, not against depth: a chain that long is already a different
/// problem.
bool isReflectionUninitialised(Object? error, [int depth = 0]) {
  if (error == null || depth > 8) return false;
  if (error is StateError && error.message.contains(_uninitialisedMarker)) {
    return true;
  }
  if ('$error'.contains(_uninitialisedMarker)) return true;
  return isReflectionUninitialised(_rootOf(error), depth + 1);
}

/// The wrapped cause of [error], when it carries one under the framework's
/// usual name.
///
/// Typed loosely on purpose: the exception families this module meets live in
/// different packages and share no supertype that declares `rootException`.
Object? _rootOf(Object error) {
  try {
    return (error as dynamic).rootException as Object?;
  } on NoSuchMethodError {
    return null;
  }
}
