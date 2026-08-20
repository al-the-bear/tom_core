/// Four-tier interface selection: which implementation a deployment gets.
///
/// `@TomComponent(SomeInterface)` says "I am an implementation of this
/// interface"; `@TomEnvironment` / `@TomPlatform` say "…for this deployment".
/// Discovery collects every implementor of an interface and picks exactly one,
/// by four tiers in descending specificity:
///
/// 1. environment **and** platform match,
/// 2. platform matches, no environment constraint,
/// 3. environment matches, no platform constraint,
/// 4. neither constrained.
///
/// This is the mechanism the whole DI story rests on: one implementation is
/// bound per interface, so a consumer resolves a collaborator without a
/// dispatcher deciding anything at call time. The risk it carries is that a
/// regression here is silent — the wrong implementation is injected, the code
/// still runs, and only the deployment misbehaves. So the tests below assert
/// the *precedence*, not merely that something resolves: all four fixtures
/// below implement one interface and are simultaneously present in every pass,
/// so each test proves the higher tier wins over candidates that would
/// otherwise have matched.
///
/// The failure modes live in their own suites, because discovery is
/// all-or-nothing — a single unresolvable interface aborts the whole pass, so
/// a failing fixture cannot share a reflection domain with a passing one. See
/// `beanlocator_ambiguous_selection_test.dart` and
/// `beanlocator_excluded_selection_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'beanlocator_selection_test.reflection.dart';
import 'support/bean_selection_support.dart';

// ----------------------------------------------------------------------------
// One interface, one implementor per tier. Every pass sees all four, so a test
// that observes tier N also proves tiers N+1.. did not win.
// ----------------------------------------------------------------------------

/// The interface whose four candidates exercise the selection tiers.
abstract class RankedService {
  /// Names the tier this implementation is annotated for.
  String tier();
}

@tomReflector
@TomComponent(RankedService)
@prodEnvironment
@platformWeb
class RankedTierOneService implements RankedService {
  @override
  String tier() => 'tier-1';
}

@tomReflector
@TomComponent(RankedService)
@platformWeb
class RankedTierTwoService implements RankedService {
  @override
  String tier() => 'tier-2';
}

@tomReflector
@TomComponent(RankedService)
@prodEnvironment
class RankedTierThreeService implements RankedService {
  @override
  String tier() => 'tier-3';
}

@tomReflector
@TomComponent(RankedService)
class RankedTierFourService implements RankedService {
  @override
  String tier() => 'tier-4';
}

// ----------------------------------------------------------------------------
// Two implementors distinguished by nothing but the environment.
// ----------------------------------------------------------------------------

/// The interface whose two candidates differ only in their environment.
abstract class GreetingService {
  /// Names the environment this implementation is annotated for.
  String greet();
}

@tomReflector
@TomComponent(GreetingService)
@prodEnvironment
class ProdGreetingService implements GreetingService {
  @override
  String greet() => 'production';
}

@tomReflector
@TomComponent(GreetingService)
@devEnvironment
class DevGreetingService implements GreetingService {
  @override
  String greet() => 'development';
}

/// A stand-in for the selected [GreetingService], as a test would write one.
///
/// Unannotated on purpose: discovery must not find it, so the only way it can
/// end up bound is the registration the test performs itself.
class StubGreetingService implements GreetingService {
  @override
  String greet() => 'stub';
}

/// An interface no class declares itself an implementation of.
abstract class UnimplementedService {}

void main() {
  setUpAll(() {
    initializeReflection();
  });

  // ==========================================================================
  // Tier precedence
  // ==========================================================================
  group('four-tier selection', () {
    test('tier 1 wins: environment and platform both match', () {
      discoverBeansIn(prodEnvironment, platformWeb);

      expect(
        TomBean<RankedService>().get().tier(),
        equals('tier-1'),
        reason:
            'the platform-only, environment-only and unconstrained '
            'candidates all match too, and none of them may win',
      );
    });

    test('tier 2 wins: platform matches, the environment does not', () {
      discoverBeansIn(devEnvironment, platformWeb);

      expect(
        TomBean<RankedService>().get().tier(),
        equals('tier-2'),
        reason: 'the unconstrained candidate matches too and must not win',
      );
    });

    test('tier 3 wins: environment matches, the platform does not', () {
      discoverBeansIn(prodEnvironment, platformMacos);

      expect(
        TomBean<RankedService>().get().tier(),
        equals('tier-3'),
        reason: 'the unconstrained candidate matches too and must not win',
      );
    });

    test('tier 4 wins: neither selector matches', () {
      discoverBeansIn(devEnvironment, platformMacos);

      expect(TomBean<RankedService>().get().tier(), equals('tier-4'));
    });

    test('binds exactly one implementation, keyed by the interface', () {
      discoverBeansIn(prodEnvironment, platformWeb);

      // The selected implementation is registered under the *interface*, and
      // the candidates that lost are not registered at all — there is one
      // binding to resolve, not a set to choose from at call time.
      expect(TomBean.getBeanByType(RankedService), isA<RankedTierOneService>());
      expect(TomBean.getBeanByType(RankedTierOneService), isNull);
      expect(TomBean.getBeanByType(RankedTierTwoService), isNull);
      expect(TomBean.getBeanByType(RankedTierThreeService), isNull);
      expect(TomBean.getBeanByType(RankedTierFourService), isNull);
    });

    test(
      're-selects on a later pass rather than keeping the first binding',
      () {
        discoverBeansIn(prodEnvironment, platformWeb);
        expect(
          TomBean.getBeanByType(RankedService),
          isA<RankedTierOneService>(),
        );

        discoverBeansIn(devEnvironment, platformMacos);

        expect(
          TomBean.getBeanByType(RankedService),
          isA<RankedTierFourService>(),
          reason:
              'selection must follow the current runtime, not the first one '
              'discovery ever saw',
        );
      },
    );
  });

  // ==========================================================================
  // Selector interaction: the environment genuinely selects
  // ==========================================================================
  group('environment selector', () {
    test(
      'two implementors differing only by environment resolve differently',
      () {
        discoverBeansIn(prodEnvironment, platformMacos);
        expect(TomBean<GreetingService>().get().greet(), equals('production'));

        discoverBeansIn(devEnvironment, platformMacos);
        expect(TomBean<GreetingService>().get().greet(), equals('development'));
      },
    );

    test('the environment selects independently of the platform', () {
      // Same environment, different platform: neither candidate constrains the
      // platform, so the environment alone decides — tier 3 both times.
      discoverBeansIn(prodEnvironment, platformWeb);
      expect(TomBean<GreetingService>().get(), isA<ProdGreetingService>());

      discoverBeansIn(prodEnvironment, platformMacos);
      expect(TomBean<GreetingService>().get(), isA<ProdGreetingService>());
    });

    test('the unselected implementation is never instantiated', () {
      discoverBeansIn(devEnvironment, platformWeb);

      expect(TomBean.getBeanByType(GreetingService), isA<DevGreetingService>());
      expect(TomBean.getBeanByType(ProdGreetingService), isNull);
    });
  });

  // ==========================================================================
  // Selectors are matched by name, not by instance
  // ==========================================================================
  group('selectors matched by name, not by instance', () {
    // An annotation is necessarily a `const`, and const expressions are
    // canonicalised — so as long as the value handed to `TomRuntime` is also
    // written as an identical `const`, the two are the same instance and an
    // identity comparison happens to work. Nothing keeps them written that
    // way. `TomRuntime`'s own documented setup builds environments with a
    // plain constructor call, and an application taking its environment name
    // from configuration cannot do otherwise. Those instances are not the
    // annotation's, so an identity comparison would silently match nothing:
    // the implementation is right there, looks identical, and discovery
    // reports the interface as having no implementation at all.
    //
    // The fixtures below are the same ones the tier tests use; only the way
    // the active environment and platform are constructed differs.

    test('a runtime-built environment selects as the const one does', () {
      discoverBeansIn(environmentNamed('prod'), platformWeb);

      expect(
        TomBean<RankedService>().get().tier(),
        equals('tier-1'),
        reason:
            'the active environment names "prod" and the tier-1 candidate '
            'is annotated for "prod" — which instance carries the name is not '
            'something a deployment gets to control',
      );
    });

    test('a runtime-built platform selects as the const one does', () {
      discoverBeansIn(prodEnvironment, platformNamed('web'));

      expect(TomBean<RankedService>().get().tier(), equals('tier-1'));
    });

    test('both built at runtime still select', () {
      discoverBeansIn(environmentNamed('prod'), platformNamed('web'));

      expect(TomBean<RankedService>().get().tier(), equals('tier-1'));
    });

    test('a runtime-built environment still discriminates', () {
      // Matching by name must not degrade into matching everything: the
      // candidates annotated for "prod" and "web" have to lose here.
      discoverBeansIn(environmentNamed('dev'), platformNamed('macos'));

      expect(TomBean<RankedService>().get().tier(), equals('tier-4'));
    });

    test('a runtime-built environment selects between two candidates', () {
      discoverBeansIn(environmentNamed('prod'), platformMacos);
      expect(TomBean<GreetingService>().get().greet(), equals('production'));

      discoverBeansIn(environmentNamed('dev'), platformMacos);
      expect(TomBean<GreetingService>().get().greet(), equals('development'));
    });

    test('an environment differing only in its flags selects', () {
      // The other way two instances end up distinct, and the easier one to
      // write by accident: `isTest`/`isDevelopment` set on the runtime's
      // environment but not on the annotation. They describe an environment
      // rather than distinguishing one, so both name 'prod' and both are it.
      discoverBeansIn(
        const TomEnvironment('prod', isTest: true, isDevelopment: true),
        platformWeb,
      );

      expect(TomBean<RankedService>().get().tier(), equals('tier-1'));
    });
  });

  // ==========================================================================
  // Pre-binding an interface: selection must leave an occupied key alone
  // ==========================================================================
  group('interface bound before discovery', () {
    test('keeps the registered implementation instead of selecting one', () {
      // Selection runs only for interfaces nothing has bound yet. A binding
      // that is already there is an answer, not a candidate — so the pass has
      // no business replacing it, whatever its four tiers would have chosen.
      discoverBeansIn(
        prodEnvironment,
        platformMacos,
        beforeDiscovery: () =>
            TomBean.withType(GreetingService, StubGreetingService()),
      );

      expect(
        TomBean<GreetingService>().get().greet(),
        equals('stub'),
        reason:
            'the prod candidate matches the active environment and must '
            'not displace an implementation already bound',
      );
    });
  });

  // ==========================================================================
  // Failure mode 1: nothing implements the interface
  // ==========================================================================
  group('interface with no implementor', () {
    test('is not bound by discovery', () {
      discoverBeansIn(prodEnvironment, platformWeb);

      expect(TomBean.getBeanByType(UnimplementedService), isNull);
    });

    test('fails on access with the uninitialized-bean key', () {
      discoverBeansIn(prodEnvironment, platformWeb);

      expect(
        keyOfThrow(() => TomBean<UnimplementedService>().get()),
        equals('beanlocator.bean_access.no_bean_found_uninitialized'),
        reason: 'an unbound interface must name itself, not resolve to null',
      );
    });
  });

  // ==========================================================================
  // Failure mode 2: selection runs before the runtime is configured
  // ==========================================================================
  group('selection without a configured runtime', () {
    test('fails with the locator exception, naming the interface', () {
      // Selection compares each candidate's selectors against the active
      // deployment, so it cannot proceed without one. `getCurrentEnvironment`
      // signals that with a bare `Exception` — which a caller writing
      // `on TomBeanLocatorException`, as every example here does, would not
      // catch, and which names neither the interface nor the operation. Every
      // class in this domain implements an interface, so the tier scan is the
      // only path that can reach the runtime from here.
      TomRuntime.reset();
      TomBean.resetBeanContext();

      final failure = locatorExceptionOf(initializeBeanContext);

      expect(
        failure,
        isNotNull,
        reason: 'a bare Exception escaped the locator exception contract',
      );
      expect(
        failure!.key,
        equals('beanlocator.environment.runtime_environment_not_initialized'),
      );
      expect(failure.parameters?['subject'], isNotNull);
    });
  });
}
