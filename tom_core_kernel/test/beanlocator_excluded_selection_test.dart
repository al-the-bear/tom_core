/// Excluded interface selection: the only implementation does not apply here.
///
/// A selector narrows an implementation to a deployment. When the running
/// deployment is not the one it was narrowed to, and no other candidate steps
/// in, the interface has no implementation — and discovery must say so. The
/// alternative, binding the excluded implementation anyway or leaving the
/// interface silently unbound, would defer the wiring bug to the first call
/// site that happens to need it.
///
/// Two interfaces, one exclusion mechanism each: [ProdOnlyService] is narrowed
/// by environment, [WebOnlyService] by platform. They are arranged so that at
/// most one is unresolvable in any given pass, which keeps each test's failure
/// unambiguous even though discovery is all-or-nothing:
///
/// | environment | platform | `ProdOnlyService` | `WebOnlyService` |
/// | ----------- | -------- | ----------------- | ---------------- |
/// | prod        | web      | bound (tier 3)    | bound (tier 2)   |
/// | dev         | web      | **unresolvable**  | bound (tier 2)   |
/// | prod        | macos    | bound (tier 3)    | **unresolvable** |
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_excluded_selection_test.reflection.dart';
import 'support/bean_selection_support.dart';

/// The interface whose only implementation is narrowed to one environment.
abstract class ProdOnlyService {}

@tomReflector
@TomComponent(ProdOnlyService)
@prodEnvironment
class ProdOnlyServiceImpl implements ProdOnlyService {}

/// The interface whose only implementation is narrowed to one platform.
abstract class WebOnlyService {}

@tomReflector
@TomComponent(WebOnlyService)
@platformWeb
class WebOnlyServiceImpl implements WebOnlyService {}

void main() {
  setUpAll(() {
    initializeReflection();
  });

  group('a selector that includes the current deployment', () {
    test('binds the narrowed implementation', () {
      discoverBeansIn(prodEnvironment, platformWeb);

      expect(TomBean<ProdOnlyService>().get(), isA<ProdOnlyServiceImpl>());
      expect(TomBean<WebOnlyService>().get(), isA<WebOnlyServiceImpl>());
    });
  });

  group('an environment selector that excludes the current environment', () {
    test('fails discovery with the no-matching-implementation key', () {
      expect(
        keyOfThrow(() => discoverBeansIn(devEnvironment, platformWeb)),
        equals('beanlocator.initialization.no_matching_implementation_found'),
        reason: 'an excluded implementation must not be bound as a fallback',
      );
    });

    test('names the interface that could not be satisfied', () {
      final failure = locatorExceptionOf(
        () => discoverBeansIn(devEnvironment, platformWeb),
      );

      expect(failure, isNotNull);
      expect(failure!.parameters?['type'], equals(ProdOnlyService));
    });
  });

  group('a platform selector that excludes the current platform', () {
    test('fails discovery with the no-matching-implementation key', () {
      expect(
        keyOfThrow(() => discoverBeansIn(prodEnvironment, platformMacos)),
        equals('beanlocator.initialization.no_matching_implementation_found'),
      );
    });

    test('names the interface that could not be satisfied', () {
      final failure = locatorExceptionOf(
        () => discoverBeansIn(prodEnvironment, platformMacos),
      );

      expect(failure, isNotNull);
      expect(
        failure!.parameters?['type'],
        equals(WebOnlyService),
        reason:
            'the environment-narrowed interface still resolves here, so '
            'the platform-narrowed one is the only possible failure',
      );
    });
  });
}
