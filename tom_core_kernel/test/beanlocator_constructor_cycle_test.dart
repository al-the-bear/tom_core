/// A cycle through constructors is refused, naming the chain.
///
/// Two components that each require the other as a constructor parameter
/// cannot both be built: whichever is first needs the second to exist, and the
/// second needs the first. Through `TomBean` handles the same mutual
/// dependency is fine, because a handle resolves on use and neither resolves
/// during construction — `beanlocator_constructor_injection_test.dart` holds
/// that. Through constructors it is unsatisfiable and has its own key.
///
/// Its own reflection domain, because a refused component aborts the pass.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_constructor_cycle_test.reflection.dart';
import 'support/bean_selection_support.dart';

@tomReflector
@TomComponent(TomNoInterface)
class CycleFirst {
  CycleFirst(this.second);

  final CycleSecond second;
}

@tomReflector
@TomComponent(TomNoInterface)
class CycleSecond {
  CycleSecond(this.first);

  final CycleFirst first;
}

void main() {
  initializeReflection();

  test('a cycle through constructors names the class, parameter and chain', () {
    final error = locatorExceptionOf(
      () => discoverBeansIn(prodEnvironment, platformWeb),
    );

    expect(
      error?.key,
      equals('beanlocator.initialization.constructor_dependency_cycle'),
    );
    // Which of the two the pass starts from depends on the registry's order,
    // so the assertion names the pair rather than one direction of it.
    final owner = error?.parameters?['class'];
    expect(owner, anyOf('CycleFirst', 'CycleSecond'));
    expect(
      error?.parameters?['parameter'],
      owner == 'CycleFirst' ? equals('second') : equals('first'),
    );
    expect(
      error?.parameters?['cycle'],
      anyOf(
        equals(['CycleFirst', 'CycleSecond', 'CycleFirst']),
        equals(['CycleSecond', 'CycleFirst', 'CycleSecond']),
      ),
    );
    expect(error?.defaultUserMessage, contains('TomBean field'));
  });
}
