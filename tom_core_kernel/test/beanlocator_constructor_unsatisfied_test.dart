/// A constructor parameter nothing supplies is refused by name.
///
/// Discovery supplies a component's required constructor parameters from the
/// bean bound under exactly each parameter's declared type. A `String` is not
/// a component and nothing registers one, so this component's constructor
/// cannot be called, and the pass has to say which class, which parameter and
/// which type — rather than fail inside the reflector, whose
/// `NoSuchCapabilityError` names its own configuration instead.
///
/// This fixture lives in its own reflection domain because discovery is
/// all-or-nothing: a component the pass cannot build aborts the whole pass.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_constructor_unsatisfied_test.reflection.dart';
import 'support/bean_selection_support.dart';

/// The interface whose implementation asks for something nothing supplies.
abstract class UnsatisfiedService {}

@tomReflector
@TomComponent(UnsatisfiedService)
class StringHungryService implements UnsatisfiedService {
  StringHungryService(this.dependency);

  final String dependency;
}

void main() {
  initializeReflection();

  test(
    'a parameter type nothing supplies names the class, parameter and type',
    () {
      final error = locatorExceptionOf(
        () => discoverBeansIn(prodEnvironment, platformWeb),
      );

      expect(
        error?.key,
        equals('beanlocator.initialization.constructor_dependency_unsatisfied'),
      );
      expect(error?.parameters?['class'], equals('StringHungryService'));
      expect(error?.parameters?['parameter'], equals('dependency'));
      expect(error?.parameters?['type'], equals(String));
      expect(
        error?.defaultUserMessage,
        allOf(
          contains('StringHungryService'),
          contains('dependency'),
          contains('String'),
        ),
      );
    },
  );
}
