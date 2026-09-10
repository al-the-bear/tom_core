/// A component whose constructor takes arguments cannot be discovered.
///
/// Discovery builds every `@TomComponent` class by invoking its unnamed
/// constructor with no arguments. A component that declares a required
/// parameter therefore names a constructor the pass will never call, and the
/// dependency it was reaching for has to come from a `TomBean` field instead.
///
/// This fixture lives in its own reflection domain because discovery is
/// all-or-nothing: a class the pass cannot construct aborts the whole pass, so
/// a deliberately unconstructable component cannot share a domain with the
/// components other tests expect to be bound.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_constructor_arity_test.reflection.dart';
import 'support/bean_selection_support.dart';

/// The interface whose implementation asks for its dependency by constructor.
abstract class ArityService {}

@tomReflector
@TomComponent(ArityService)
class ConstructorInjectedService implements ArityService {
  final String dependency;

  ConstructorInjectedService(this.dependency);
}

void main() {
  initializeReflection();

  test(
    'a component that requires a constructor argument is refused by name',
    () {
      // Without this the pass reaches `newInstance` and the failure arrives as
      // `NoSuchCapabilityError: no capability to invoke the constructor ""`,
      // which names the reflector's configuration rather than the parameter.
      // A reader following that message adds capabilities, which cannot help:
      // no capability makes a one-argument constructor callable with none.
      // It is also an exception type this module never tells anyone to catch.
      final error = locatorExceptionOf(
        () => discoverBeansIn(prodEnvironment, platformWeb),
      );

      expect(
        error?.key,
        equals('beanlocator.initialization.constructor_takes_arguments'),
      );
      expect(
        error?.defaultUserMessage,
        allOf(
          contains('ConstructorInjectedService'),
          contains('dependency'),
          contains('TomBean'),
        ),
        reason: 'the class, the parameter it insists on, and the way out',
      );
    },
  );
}
