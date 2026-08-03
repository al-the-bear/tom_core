/// Ambiguous interface selection: two implementations, no way to choose.
///
/// The two fixtures below both declare themselves implementations of the same
/// interface and neither carries an environment or a platform selector, so
/// they qualify identically at every tier. There is no principled way to
/// prefer one, and quietly taking the first would bind a deployment to an
/// arbitrary implementation — the code runs, the tests pass, production
/// misbehaves. Discovery must refuse instead, naming both candidates.
///
/// This lives in its own file because discovery is all-or-nothing: the pass
/// that raises this error would abort any other interface's selection in the
/// same reflection domain, so a deliberately-unresolvable fixture cannot share
/// a domain with a resolvable one.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_ambiguous_selection_test.reflection.dart';
import 'support/bean_selection_support.dart';

/// The interface with two indistinguishable implementations.
abstract class DuplicatedService {}

@tomReflector
@TomComponent(DuplicatedService)
class FirstDuplicatedService implements DuplicatedService {}

@tomReflector
@TomComponent(DuplicatedService)
class SecondDuplicatedService implements DuplicatedService {}

void main() {
  setUpAll(() {
    initializeReflection();
  });

  group('two indistinguishable implementations', () {
    test('fail discovery with the ambiguous-implementation key', () {
      expect(
        keyOfThrow(() => discoverBeansIn(prodEnvironment, platformWeb)),
        equals('beanlocator.initialization.ambiguous_implementation'),
        reason: 'an arbitrary pick would silently mis-wire the deployment',
      );
    });

    test('report the interface and both candidates', () {
      final failure = locatorExceptionOf(
        () => discoverBeansIn(prodEnvironment, platformWeb),
      );

      expect(failure, isNotNull);
      expect(failure!.parameters?['type'], equals(DuplicatedService));

      // Both losers must be named: "one of these two" is the whole diagnosis.
      final named = '${failure.parameters?['first']} '
          '${failure.parameters?['second']}';
      expect(named, contains('FirstDuplicatedService'));
      expect(named, contains('SecondDuplicatedService'));

      expect(
        failure.parameters?['match'],
        contains('default match'),
        reason: 'the tier the two candidates tied on is part of the diagnosis',
      );
    });

    test('leave the interface unbound', () {
      locatorExceptionOf(() => discoverBeansIn(prodEnvironment, platformWeb));

      expect(
        TomBean.getBeanByType(DuplicatedService),
        isNull,
        reason: 'refusing to choose must not half-bind one of the candidates',
      );
    });

    test('fail the same way in every environment', () {
      // Nothing about the ambiguity is environment-dependent: neither
      // candidate constrains anything, so no environment can break the tie.
      expect(
        keyOfThrow(() => discoverBeansIn(devEnvironment, platformMacos)),
        equals('beanlocator.initialization.ambiguous_implementation'),
      );
    });
  });
}
