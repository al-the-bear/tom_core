/// Executable example for the resources module of `tom_core_flutter`.
///
/// Demonstrates resolving typed config values via `TomProperty` subclasses and
/// the `.withDefault` fallback, the one conversion resolution performs, and
/// **both ways resolution can fail** — an obligatory key that is not
/// configured, and a configured value that cannot be cast to the property's
/// type. A deterministic in-memory config provider is installed so the example
/// is self-contained.
///
/// Every one of those six outcomes is decided in the *constructor*: a property
/// reads its key once, when it is declared. That is why the two failures below
/// are shown wrapped around a declaration and not around a read — there is no
/// read that can fail, and a property that constructs never throws again.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so this
/// runs under the Flutter toolchain, not bare `dart run`. Run it with
/// `flutter test test/resources_test.dart`: that suite calls [run], so the
/// command executes everything below and its exit code says whether the
/// assertions held. Pointing `flutter test` at *this* file also runs it, but
/// then exits 79 ("No tests were found") whether it succeeded or not — an
/// example declares no `test()` of its own.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

void run() {
  // Install an in-memory config so the example resolves deterministically.
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from({
      'app.title': 'Tom Demo',
      'app.retries': 3,
      'app.ratio': 1.5,
      'app.flag': true,
      // Written as a whole number, read as a double — the case example 4 is
      // about. No configuration format can spell the difference.
      'app.rate': 2,
    }),
  );

  // Example 1: all four typed properties resolve their value at construction.
  final title = TomStringProperty('app.title');
  final retries = TomIntProperty('app.retries');
  final ratio = TomDoubleProperty('app.ratio');
  final flag = TomBoolProperty('app.flag');
  print(
    'title=${~title} retries=${retries.get()} '
    'ratio=${~ratio} flag=${~flag}',
  );

  // Example 2: a default fills in when the key is absent.
  final timeout = TomIntProperty.withDefault('app.timeout', 30);
  print('timeout (defaulted)=${~timeout}');

  // Example 3: withDefault prefers a present config value over the default.
  final ratioOrDefault = TomDoubleProperty.withDefault('app.ratio', 9.9);
  print('ratio (present wins over default)=${~ratioOrDefault}');

  // Assertions for the three resolutions above. The two examples that follow
  // assert inside their `catch`, because what they check is the exception.
  assert(~title == 'Tom Demo');
  assert(retries.get() == 3);
  assert(~ratio == 1.5);
  assert(~flag == true);
  assert(~timeout == 30);
  assert(~ratioOrDefault == 1.5);

  // Example 4: a whole number configured for a double property. `rate: 2` in
  // YAML and `"rate": 2` in JSON both decode to an int, so refusing it would
  // fail a value that is exactly what the operator meant — and the reflected
  // configuration path fills a declared `double` field from the same entry, so
  // one file could fill a field and fail the matching property.
  final rate = TomDoubleProperty('app.rate');
  // The widening is reached only after a cast has failed, so it cannot convert
  // a value some other type already accepted: `num` takes the int as an int.
  final rateAsNum = TomProperty<num>('app.rate');
  print('rate (widened)=${~rate} rate as num=${(~rateAsNum).runtimeType}');
  assert(~rate == 2.0);
  assert(~rateAsNum is int);

  // Example 5: an obligatory key that is not configured. The throw happens
  // during construction, not on a first read — the property never comes into
  // existence, so there is nothing to guard a later `get()` against.
  try {
    TomStringProperty('app.region');
    throw StateError('an absent obligatory key must not construct');
  } on TomPropertyException catch (error) {
    print('absent key rejected: ${error.key} — ${error.defaultUserMessage}');
    assert(error.key == 'resources.property.not_configured');
    // The message names the key, which is what makes it actionable: it says
    // which line of configuration is missing, not merely that one is.
    assert(error.defaultUserMessage.contains('app.region'));
  }

  // Example 6: a configured value that cannot be cast to the property's type.
  // This throw is at construction too, and `.withDefault` does not soften it —
  // a default covers an *absent* key, not an unusable one, so a mistyped entry
  // fails at start-up whether or not a fallback was supplied.
  try {
    TomIntProperty.withDefault('app.title', 7);
    throw StateError('a mistyped config value must not construct');
  } on TomPropertyException catch (error) {
    print('type mismatch rejected: ${error.key} — ${error.defaultUserMessage}');
    assert(error.key == 'resources.property.type_mismatch');
    assert(error.defaultUserMessage.contains('app.title'));
    // The message names the type that was *wanted* and the value, but never
    // the value's actual runtime type. The `TypeError` the cast raised is the
    // only record of that, which is why it is carried rather than discarded.
    assert(error.rootException is TypeError);
  }
}

void main() => run();
