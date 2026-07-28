import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// The reflection root fixture (service interface + implementation + config) and
// its generated bootstrap. `initializeReflection()` populates the global
// reflection data so ClassMirror/InstanceMirror construction stops throwing
// "Reflection has not been initialized" — the precondition for exercising the
// endpoint pipeline, TomArgs.fillFromArgs, and the health route. `main` is
// hidden because this test declares its own.
import 'fixtures/reflection_fixture.dart'
    show FixtureApiServer, FixtureServerConfig;
import 'fixtures/reflection_fixture.reflection.dart';

/// A GET request carrying the [TomRequestLogInfo] the pipeline reads from the
/// request context (the pipeline casts it unconditionally, so it must be
/// present). No principal/token is placed in the zone — the fixture endpoints
/// are anonymous.
Request _get(String path) => Request(
      'GET',
      Uri.parse('http://localhost$path'),
      context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
    );

void main() {
  // One reflection bootstrap for the whole file (each test file is its own
  // isolate, so this does not leak into other suites).
  setUpAll(initializeReflection);

  group('reflection bootstrap', () {
    test('initializeReflection makes a fixture ClassMirror constructible', () {
      // Before initializeReflection this throws "Reflection has not been
      // initialized"; after it, the mirror resolves.
      final mirror = tomReflector.reflectType(FixtureApiServer) as ClassMirror;
      expect(mirror.simpleName, 'FixtureApiServer');
    });

    test('an instance mirror can be built and invoked', () async {
      final instanceMirror = tomReflector.reflect(FixtureApiServer());
      final result = await (instanceMirror.invoke('health', [])
          as Future<Map<String, Object>>);
      expect(result['status'], 'ok');
    });
  });

  group('TomEndpointRouting.scanClasses', () {
    test('partitions the fixture service interface and its component', () {
      final scan = TomEndpointRouting().scanClasses();
      expect(
        scan.serviceInterfaces.any((c) => c.simpleName == 'FixtureApiService'),
        isTrue,
        reason: 'the @tomService interface is a service interface',
      );
      expect(
        scan.componentClasses.any((c) => c.simpleName == 'FixtureApiServer'),
        isTrue,
        reason: 'the @tomComponent implementation is a component class',
      );
    });

    test('the transitively-captured health service is also scanned', () {
      final scan = TomEndpointRouting().scanClasses();
      // Proves the barrel was captured by the generator, not just the fixture.
      expect(
        scan.serviceInterfaces.any((c) => c.simpleName == 'TomHealthService'),
        isTrue,
      );
    });
  });

  group('initializeRouter + live requests', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      // The router resolves each @tomService interface to a component bean; both
      // the fixture service and the (transitively captured) health service have
      // endpoint methods, so both need a registered instance.
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test('GET /fixture/health invokes the endpoint and returns JSON', () async {
      final response = await router.call(_get('/fixture/health'));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['status'], 'ok');
      expect(body['app'], 'fixture');
    });

    test('GET /fixture/unguarded is reachable under the default (open) policy',
        () async {
      final response = await router.call(_get('/fixture/unguarded'));
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['guarded'], isFalse);
    });

    test('createRoutesForEndpoint records mounted routes in routingInfo', () {
      expect(TomEndpointRouting.routingInfo.containsKey('/fixture/health'),
          isTrue);
      expect(TomEndpointRouting.routingInfo.containsKey('/fixture/unguarded'),
          isTrue);
    });

    test('an OPTIONS preflight on a mounted route returns without invoking',
        () async {
      final req = Request(
        'OPTIONS',
        Uri.parse('http://localhost/fixture/health'),
        context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
      );
      final response = await router.call(req);
      // handlePreflight answers preflight directly (no method invocation).
      expect(response.statusCode, inInclusiveRange(200, 299));
    });
  });

  group('healthcheck GET /health route', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomHealthServer.globalSettingsHealthAnalyzer = DefaultHealthAnalyzer();
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test('mounts /health and returns the analyzer status as plain text',
        () async {
      final response = await router.call(_get('/health'));
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'OK');
    });

    test('reflects the configured HealthAnalyzer status', () async {
      TomHealthServer.globalSettingsHealthAnalyzer = _DegradedAnalyzer();
      addTearDown(() => TomHealthServer.globalSettingsHealthAnalyzer =
          DefaultHealthAnalyzer());
      // Rebuild so the route binds the same singleton server, whose health()
      // delegates to the now-degraded analyzer.
      final response = await router.call(_get('/health'));
      expect(await response.readAsString(), 'DEGRADED');
    });
  });

  group('TomEndpointHandler access checks', () {
    late TomEndpointHandler publicHandler;
    late TomEndpointHandler unguardedHandler;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomEndpointRouting().initializeRouter();
      publicHandler = TomEndpointRouting.routingInfo['/fixture/health']!.handler;
      unguardedHandler =
          TomEndpointRouting.routingInfo['/fixture/unguarded']!.handler;
    });

    tearDown(TomBean.resetBeanContext);

    test('a @TomPublicAccess endpoint grants access to an anonymous caller', () {
      expect(publicHandler.checkAccess(null), isTrue);
    });

    test('an endpoint with no access annotation follows the open default', () {
      // globalSettingProtectionDefault is false -> checkAccess returns true.
      expect(unguardedHandler.checkAccess(null), isTrue);
    });

    test('checkAccess denies when global protection is switched on', () {
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(() =>
          TomResourceKeyProtection.globalSettingProtectionDefault = false);
      // metadata.access is null -> returns !globalSettingProtectionDefault.
      expect(unguardedHandler.checkAccess(null), isFalse);
    });

    test('checkAutomaticAccess upgrades access for an unprotected interface',
        () {
      // Default (protection off): the interface is unprotected, so a prior
      // false decision is upgraded to true.
      expect(unguardedHandler.checkAutomaticAccess(false), isTrue);
    });

    test('checkAutomaticAccess keeps the denial when protection is on', () {
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(() =>
          TomResourceKeyProtection.globalSettingProtectionDefault = false);
      // Protection on with no principal -> interface is protected, method is
      // protected -> the false decision stands.
      expect(unguardedHandler.checkAutomaticAccess(false), isFalse);
    });
  });

  group('TomArgs.fillFromArgs', () {
    test('fills String and int fields from key=value arguments', () {
      final config = TomArgs.fillFromArgs(
        ['name=svc', 'port=8080'],
        FixtureServerConfig(),
      );
      expect(config.name, 'svc');
      expect(config.port, 8080);
    });

    test('coerces a key=value bool into the bool field', () {
      final config =
          TomArgs.fillFromArgs(['verbose=true'], FixtureServerConfig());
      expect(config.verbose, isTrue);
    });

    test('leaves fields untouched when no matching argument is given', () {
      final config =
          TomArgs.fillFromArgs(['unrelated=1'], FixtureServerConfig());
      expect(config.name, '');
      expect(config.port, 0);
      expect(config.verbose, isFalse);
    });

    // RCJ2: a *bare* flag is recorded by fillFromArgs as the boolean `true`
    // (matching how `key=true` converts), so it fills a reflected bool field
    // directly. Previously fillFromArgs stored the String "true", which the
    // reflection layer refused to coerce into a bool field (it threw). Aligning
    // the bare-flag encoding with parseArgsToMap keeps the reflection layer's
    // strict String/typed contract intact while making bare flags usable.
    test('a bare bool flag fills the bool field (RCJ2)', () {
      final config =
          TomArgs.fillFromArgs(['verbose'], FixtureServerConfig());
      expect(config.verbose, isTrue);
    });
  });

  // CE-LG: the endpoint pipeline is the second audit chokepoint. It covers the
  // one auditable event the repository cannot see — a request refused before it
  // reached any data — plus the invocations an endpoint has *declared*
  // auditable. Both go through `handleMethodCall`, so no handler can opt out of
  // the first or accidentally into the second.
  group('audit at the endpoint chokepoint', () {
    late Router router;
    late TomMemoryAuditSink sink;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      router = TomEndpointRouting().initializeRouter();
      sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
    });

    tearDown(() {
      TomAuditTrail.uninstall();
      TomAuditTrail.resetPolicyCache();
      TomBean.resetBeanContext();
    });

    test('a denial is recorded with no annotation and no opt-in', () async {
      // Switching global protection on denies the unannotated endpoint.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(() =>
          TomResourceKeyProtection.globalSettingProtectionDefault = false);

      // The pipeline signals the refusal by throwing; the assertion that
      // matters is on the trail, which must hold the entry either way.
      await expectLater(
        router.call(_get('/fixture/unguarded')),
        throwsA(isA<TomEndpointHandlerException>()),
      );

      final record = sink.records.single;
      expect(record.action, TomAuditAction.execute);
      expect(record.outcome, TomAuditOutcome.denied);
      expect(record.detail, contains('Access not granted'));
      // No principal reached the endpoint, so the attempt is attributed to
      // SYSTEM rather than left blank.
      expect(record.actor.username, TomAuditActor.systemUsername);
    });

    test('an endpoint declared @TomAudited records its invocation', () async {
      final response = await router.call(_get('/fixture/audited'));
      expect(response.statusCode, 200);

      final record = sink.records.single;
      expect(record.action, TomAuditAction.execute);
      expect(record.outcome, TomAuditOutcome.succeeded);
      expect(record.target, isNotEmpty);
    });

    test('an undeclared endpoint invocation is not recorded', () async {
      // Most endpoint calls are reads; auditing them all would produce a trail
      // no auditor can read. Invocation auditing is therefore declared, and
      // this endpoint declares nothing.
      final response = await router.call(_get('/fixture/unguarded'));
      expect(response.statusCode, 200);
      expect(sink.records, isEmpty);
    });

    test('with no sink installed the pipeline still serves requests', () async {
      TomAuditTrail.uninstall();
      final response = await router.call(_get('/fixture/audited'));
      expect(response.statusCode, 200);
    });
  });
}

/// A [HealthAnalyzer] returning a non-OK status, to prove the route reflects the
/// configured analyzer rather than a hardcoded string.
class _DegradedAnalyzer extends HealthAnalyzer {
  @override
  Future<String> analyzeHealth() async => 'DEGRADED';
}
