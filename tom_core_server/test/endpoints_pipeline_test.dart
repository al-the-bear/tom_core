import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// The reflection root fixture (service interface + implementation + config) and
// its generated bootstrap. `initializeReflection()` populates the global
// reflection data so ClassMirror/InstanceMirror construction stops throwing
// "Reflection has not been initialized" — the precondition for exercising the
// endpoint pipeline and the health route. `main` is hidden because this test
// declares its own.
import 'fixtures/reflection_fixture.dart'
    show
        FixtureAccessApiService,
        FixtureApiServer,
        FixtureConflictingAccessService,
        FixtureParseRequest,
        fixtureContractAccess,
        fixtureContractRequestHeaders,
        fixtureContractResponseHeaders,
        fixtureHandlerAccess,
        fixtureInlineAccess,
        registerFixtureAccessApi;
import 'fixtures/reflection_fixture.reflection.dart';

/// A [TomLogOutput] that keeps every message handed to it.
///
/// Deliberately captures without consulting the level: the question these tests
/// ask is whether the *pipeline decided to log*, which is a different question
/// from whether the logger's configured level would have printed it.
class _CapturingLogOutput extends TomLogOutput {
  final List<String> lines = [];

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp,
    String? origin,
  ) => lines.add(convertToString(message));
}

/// The routing-table entry mounted for [path] under [method].
///
/// The table is keyed by route *and* method, so a lookup has to name both; most
/// fixture endpoints are `GET`, which is why that is the default rather than a
/// value every call site repeats.
TomEndpointRoutingInfo _routeInfo(String path, [String method = 'GET']) =>
    TomEndpointRouting.routingInfo[(uri: path, method: method)]!;

/// A GET request carrying the [TomRequestLogInfo] the pipeline reads from the
/// request context (the pipeline casts it unconditionally, so it must be
/// present). No principal/token is placed in the zone — the fixture endpoints
/// are anonymous.
Request _get(String path) => Request(
  'GET',
  Uri.parse('http://localhost$path'),
  context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
);

/// A POST carrying [body] as its JSON request body, with the same context the
/// pipeline requires of any request.
Request _post(String path, String body) => Request(
  'POST',
  Uri.parse('http://localhost$path'),
  body: body,
  context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
);

void main() {
  // One reflection bootstrap for the whole file (each test file is its own
  // isolate, so this does not leak into other suites). The fixture API contract
  // is registered alongside it: FixtureAccessApiService is a
  // @TomApiImplementation, so scanClasses finds it and getClassMethodMetadata
  // resolves its endpoints through tomRemoteApis — which throws for an
  // unregistered API rather than yielding null.
  setUpAll(() {
    initializeReflection();
    registerFixtureAccessApi();
  });

  group('reflection bootstrap', () {
    test('initializeReflection makes a fixture ClassMirror constructible', () {
      // Before initializeReflection this throws "Reflection has not been
      // initialized"; after it, the mirror resolves.
      final mirror = tomReflector.reflectType(FixtureApiServer) as ClassMirror;
      expect(mirror.simpleName, 'FixtureApiServer');
    });

    test('an instance mirror can be built and invoked', () async {
      final instanceMirror = tomReflector.reflect(FixtureApiServer());
      final result =
          await (instanceMirror.invoke('health', [])
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

  // C-12 / G-API-3: `final resolvedAccess = tea ?? ae?.access` — a handler-side
  // TomAccessControl is a local override and wins; otherwise the contract's
  // policy is extracted, so a registry-backed handler is gated without
  // restating the policy inline.
  //
  // The extraction half is proven live by the advanced sample's 403s. The
  // *override* half is not: no sample handler declares an inline annotation, so
  // swapping the two operands would pass every test and every integration run
  // in the workspace while silently making the contract beat a deliberate local
  // tightening. Both directions are asserted here, with no router and no server.
  //
  // `same` (identity), not `equals`: TomAccessControl values are shared consts,
  // so an equal policy from the wrong source would satisfy value-equality. The
  // generated reflection emits annotations as const expressions, so the
  // handler's annotation is canonically the same instance as the top-level
  // const the fixture declares it with.
  group('getClassMethodMetadata access resolution (C-12 / G-API-3)', () {
    late List<TomMethodMetadata> metadata;

    setUp(() {
      final mirror =
          tomReflector.reflectType(FixtureAccessApiService) as ClassMirror;
      metadata = TomEndpointRouting().getClassMethodMetadata(mirror);
    });

    TomMethodMetadata methodNamed(String name) =>
        metadata.firstWhere((m) => m.methodMirror.simpleName == name);

    test('extracts the contract policy when the handler declares none', () {
      final md = methodNamed('contractGated');
      expect(
        md.access,
        same(fixtureContractAccess),
        reason: 'the policy must come from TomApiEndpoint.access',
      );
      expect(
        md.apiEndpoint,
        isNotNull,
        reason: 'a registry-backed endpoint resolves its contract entry',
      );
    });

    test('a handler-side annotation overrides the contract policy', () {
      final md = methodNamed('overridden');
      // The branch with no coverage anywhere in the workspace before this test.
      expect(md.access, same(fixtureHandlerAccess));
      expect(
        md.access,
        isNot(same(fixtureContractAccess)),
        reason: 'a local tightening must not be overwritten by the contract',
      );
      // The contract entry is still resolved — the handler outranks it, rather
      // than the lookup being skipped, which is what makes this an override.
      expect(md.apiEndpoint?.access, same(fixtureContractAccess));
    });

    test('an inline endpoint keeps the handler policy, with no contract', () {
      final md = methodNamed('inlineGated');
      expect(md.access, same(fixtureInlineAccess));
      expect(
        md.apiEndpoint,
        isNull,
        reason: 'an inline TomEndpoint has no registry entry to shadow it',
      );
    });

    test('two TomAccessControl annotations on one method are rejected', () {
      // The conflicting-tag guard sits three lines above the resolution and
      // makes it well-defined: without it, "the handler's policy" would mean
      // whichever annotation the mirror happened to list last.
      final mirror =
          tomReflector.reflectType(FixtureConflictingAccessService)
              as ClassMirror;
      expect(
        () => TomEndpointRouting().getClassMethodMetadata(mirror),
        throwsA(
          isA<TomEndpointPipelineException>().having(
            (e) => e.key,
            'key',
            'endpoint_pipeline.get_class_method_metadata.multiple_access_control',
          ),
        ),
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
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
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

    test(
      'GET /fixture/unguarded is reachable under the default (open) policy',
      () async {
        final response = await router.call(_get('/fixture/unguarded'));
        expect(response.statusCode, 200);
        final body = jsonDecode(await response.readAsString());
        expect(body['guarded'], isFalse);
      },
    );

    test('createRoutesForEndpoint records mounted routes in routingInfo', () {
      expect(
        TomEndpointRouting.routingInfo.containsKey((
          uri: '/fixture/health',
          method: 'GET',
        )),
        isTrue,
      );
      expect(
        TomEndpointRouting.routingInfo.containsKey((
          uri: '/fixture/unguarded',
          method: 'GET',
        )),
        isTrue,
      );
    });

    test(
      'an OPTIONS preflight on a mounted route returns without invoking',
      () async {
        final req = Request(
          'OPTIONS',
          Uri.parse('http://localhost/fixture/health'),
          context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
        );
        final response = await router.call(req);
        // handlePreflight answers preflight directly (no method invocation).
        expect(response.statusCode, inInclusiveRange(200, 299));
      },
    );
  });

  // The routing table is a diagnostic: it answers "what is mounted here?" for
  // operator tooling and for tests. Keyed by URI alone it could not answer that
  // question — an endpoint's own methods overwrote each other, and two
  // endpoints sharing a path lost one of themselves outright. The router was
  // never wrong (each method was registered before the overwrite), so nothing
  // 404s and no request-level assertion can see any of this. Only the table can.
  group('routingInfo is keyed by route and method', () {
    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      // The table is static and accumulates across runs, so it is cleared here
      // rather than trusted: a stale entry from an earlier initializeRouter
      // would let an absent route look present.
      TomEndpointRouting.routingInfo.clear();
      TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test('every method of a multi-method endpoint is retrievable', () {
      for (final method in ['GET', 'PUT', 'DELETE']) {
        expect(
          TomEndpointRouting.routingInfo.containsKey((
            uri: '/fixture/multi_method',
            method: method,
          )),
          isTrue,
          reason:
              '$method is declared by the endpoint and mounted on its route',
        );
      }
    });

    test('the three entries share the one handler they were built from', () {
      final get = _routeInfo('/fixture/multi_method');
      final put = _routeInfo('/fixture/multi_method', 'PUT');
      final delete = _routeInfo('/fixture/multi_method', 'DELETE');
      // One endpoint means one handler: the entries differ in their key and in
      // `method`, not in what serves them. This is what makes the collapse so
      // quiet — the value the old table kept was never the *wrong* value, only
      // the sole survivor of three identical ones.
      expect(put.handler, same(get.handler));
      expect(delete.handler, same(get.handler));
    });

    test('an undeclared method is absent rather than mounted', () {
      // The endpoint declares GET/PUT/DELETE. Keying by method would be no
      // improvement if every method were recorded for every route.
      expect(
        TomEndpointRouting.routingInfo.containsKey((
          uri: '/fixture/multi_method',
          method: 'POST',
        )),
        isFalse,
      );
    });

    test('two endpoints splitting one route stay distinguishable', () {
      // The discriminating case. A multi-method endpoint writes the same value
      // once per method, so a table keyed by URI alone still holds something
      // correct; here the two halves are different handlers and one of them was
      // being dropped.
      final read = _routeInfo('/fixture/split_route');
      final write = _routeInfo('/fixture/split_route', 'POST');
      expect(read.handler, isNot(same(write.handler)));
      expect(read.endpoint.methods, [TomHttpMethod.get]);
      expect(write.endpoint.methods, [TomHttpMethod.post]);
    });

    test('both halves of the split route answer their own method', () {
      // The table now agrees with the router. Asserted because the table is
      // only worth keying correctly if it describes what is actually mounted.
      final read = _routeInfo('/fixture/split_route');
      final write = _routeInfo('/fixture/split_route', 'POST');
      expect(read.handler.metadata.methodMirror.simpleName, 'splitRouteRead');
      expect(write.handler.metadata.methodMirror.simpleName, 'splitRouteWrite');
    });

    test('each entry records the single method it was mounted for', () {
      // `routingInfo.values` has to be a complete picture on its own — a
      // diagnostic that dumps the values cannot reach back into the keys.
      for (final entry in TomEndpointRouting.routingInfo.entries) {
        expect(
          entry.value.method.name,
          entry.key.method,
          reason: 'the value must describe the pair its key names',
        );
        // Including the socket entries: `TomWebSocketEndpoint` converts to an
        // endpoint declaring `[get]`, so a handshake route is as much a
        // declared method as any other and needs no exemption here.
        expect(entry.value.endpoint.methods, contains(entry.value.method));
      }
    });

    test('a socket endpoint is recorded under the handshake GET', () {
      expect(
        TomEndpointRouting.routingInfo.containsKey((
          uri: '/fixture/socket',
          method: 'GET',
        )),
        isTrue,
      );
      expect(
        _routeInfo('/fixture/socket').handler.metadata.webSocket,
        isNotNull,
      );
    });

    test('the automatic OPTIONS preflight is not listed as an endpoint', () {
      // Preflight is mounted for every route, so recording it would add an
      // entry per route that tells an operator nothing. The contract is that
      // the table lists *declared* methods; assert it rather than leave the
      // absence looking like an oversight.
      expect(
        TomEndpointRouting.routingInfo.keys.where((k) => k.method == 'OPTIONS'),
        isEmpty,
      );
    });
  });

  // An endpoint may declare headers the server adds to every response. There
  // are two ways to declare them — inline on `@TomEndpoint`, or on the registry
  // contract — and a contract states the two *directions* separately:
  // `requestHeaders` are what a client is told to send, `responseHeaders` what
  // the server is told to answer with. Reading the wrong one fails silently: a
  // response that echoes the caller's own obligations back at it is well-formed
  // and looks deliberate. Only a contract declaring both, with different
  // values, can tell which one the server picked up.
  group('declared response headers', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test('an inline endpoint answers with the headers it declares', () async {
      final response = await router.call(_get('/fixture/inline_headers'));
      expect(response.statusCode, 200);
      expect(response.headers['x-fixture-inline'], 'from-inline-declaration');
    });

    test(
      'a registry endpoint answers with the contract responseHeaders',
      () async {
        final response = await router.call(_get('/fixture-access/headers'));
        expect(response.statusCode, 200);
        expect(
          response.headers['x-fixture-response'],
          fixtureContractResponseHeaders['x-fixture-response'],
        );
      },
    );

    test(
      'a registry endpoint does not echo the contract requestHeaders',
      () async {
        final response = await router.call(_get('/fixture-access/headers'));
        // The header a *client* was told to send is not one to send back. It is
        // an obligation on the caller, and re-emitting it states something about
        // the response that is not true of it.
        expect(response.headers.keys, isNot(contains('x-fixture-request')));
        expect(
          response.headers.values,
          isNot(contains(fixtureContractRequestHeaders['x-fixture-request'])),
        );
      },
    );

    test('both declaration styles add their headers and nothing else', () async {
      // Beyond the content type the pipeline always sets, a response carries
      // exactly what was declared for it — so neither style leaks a header the
      // other does not, which is the divergence this group exists to pin.
      final inline = await router.call(_get('/fixture/inline_headers'));
      final registry = await router.call(_get('/fixture-access/headers'));
      expect(inline.headers.keys.where((k) => k.startsWith('x-fixture-')), [
        'x-fixture-inline',
      ]);
      expect(registry.headers.keys.where((k) => k.startsWith('x-fixture-')), [
        'x-fixture-response',
      ]);
    });
  });

  group('healthcheck GET /health route', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomHealthServer.globalSettingsHealthAnalyzer = DefaultHealthAnalyzer();
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test(
      'mounts /health and returns the analyzer status as plain text',
      () async {
        final response = await router.call(_get('/health'));
        expect(response.statusCode, 200);
        expect(await response.readAsString(), 'OK');
      },
    );

    test('reflects the configured HealthAnalyzer status', () async {
      TomHealthServer.globalSettingsHealthAnalyzer = _DegradedAnalyzer();
      addTearDown(
        () => TomHealthServer.globalSettingsHealthAnalyzer =
            DefaultHealthAnalyzer(),
      );
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
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
      publicHandler = _routeInfo('/fixture/health').handler;
      unguardedHandler = _routeInfo('/fixture/unguarded').handler;
    });

    tearDown(TomBean.resetBeanContext);

    test(
      'a @TomPublicAccess endpoint grants access to an anonymous caller',
      () {
        expect(publicHandler.checkAccess(null), isTrue);
      },
    );

    test('an endpoint with no access annotation follows the open default', () {
      // globalSettingProtectionDefault is false -> checkAccess returns true.
      expect(unguardedHandler.checkAccess(null), isTrue);
    });

    test('checkAccess denies when global protection is switched on', () {
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(
        () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
      );
      // metadata.access is null -> returns !globalSettingProtectionDefault.
      expect(unguardedHandler.checkAccess(null), isFalse);
    });

    test(
      'checkAutomaticAccess upgrades access for an unprotected interface',
      () {
        // Default (protection off): the interface is unprotected, so a prior
        // false decision is upgraded to true.
        //
        // This also pins the one case where `isProtected` must *not* be asked
        // about the `-<member>` revocation. With protection off it answers
        // "held" for every key there is, so consulting it here would read as
        // "this endpoint has been revoked" — for every endpoint — and turn the
        // open default into a blanket denial.
        expect(unguardedHandler.checkAutomaticAccess(false), isTrue);
      },
    );

    test('checkAutomaticAccess keeps the denial when protection is on', () {
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(
        () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
      );
      // Protection on with no principal -> interface is protected, method is
      // protected -> the false decision stands.
      expect(unguardedHandler.checkAutomaticAccess(false), isFalse);
    });
  });

  // Automatic protection is a *second chance*: `enforceAccess` reaches it only
  // after the ordinary check has already refused, and only while
  // `globalSettingUseAutomaticEndpointProtection` is on. Both facts are why the
  // rule below could be wrong in three independent ways without a single test
  // or sample noticing — the switch is off by default, so nothing in the
  // workspace ever evaluated it.
  //
  // The rule has two keys per endpoint. The *container* key grants the whole
  // interface/API; the *member* key grants one method within it, and its
  // negated form `-<member>` carves one method back out of a granted container.
  // Which pair of names an endpoint uses is the question this group pins:
  // registry-backed endpoints are keyed on the identity their **contract**
  // declares, everything else on the Dart class it is routed through.
  group('automatic protection keys', () {
    late TomEndpointHandler contractGatedHandler;
    late TomEndpointHandler overriddenHandler;
    late TomEndpointHandler inlineHandler;
    late TomEndpointHandler unguardedHandler;

    setUp(() {
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(
        () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
      );
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
      contractGatedHandler = _routeInfo(
        '/fixture-access/contract-gated',
      ).handler;
      overriddenHandler = _routeInfo('/fixture-access/overridden').handler;
      inlineHandler = _routeInfo('/fixture-access/inline').handler;
      unguardedHandler = _routeInfo('/fixture/unguarded').handler;
    });

    tearDown(TomBean.resetBeanContext);

    /// Asks [handler] for its automatic decision as a principal holding exactly
    /// [keys], starting from the refusal the production call site always passes.
    bool accessHolding(TomEndpointHandler handler, List<String> keys) =>
        runZoned(
          () => handler.checkAutomaticAccess(false),
          zoneValues: {
            TomPrincipal: TomPrincipal(
              user: TomUser(id: 1, username: 'keyholder'),
              authenticated: true,
              aci: TomAccessControlInformation(resourceKeys: keys),
            ),
          },
        );

    test('a registry-backed endpoint is keyed on its API id', () {
      // The id the contract declares and the client calls — not the name of the
      // Dart class that happens to implement it.
      expect(accessHolding(contractGatedHandler, ['fixture_access']), isTrue);
    });

    test('the implementation class name grants nothing', () {
      // The security half of the same claim. Keying authorization on an
      // implementation class name would make renaming that class a silent
      // change to the authorization surface, and would let a key minted for one
      // API open an unrelated one that shares an implementation.
      expect(
        accessHolding(contractGatedHandler, ['FixtureAccessApiService']),
        isFalse,
      );
    });

    test('a per-endpoint key grants one endpoint of an ungranted API', () {
      expect(
        accessHolding(contractGatedHandler, ['fixture_access.contractGated']),
        isTrue,
        reason: 'the member key is <apiId>.<endpointId>',
      );
      expect(
        accessHolding(overriddenHandler, ['fixture_access.contractGated']),
        isFalse,
        reason: 'a member key grants its own endpoint and no sibling',
      );
    });

    test('a -<member> exception carves one endpoint out of a granted API', () {
      const keys = ['fixture_access', '-fixture_access.contractGated'];
      // Both halves matter. Without the second the exception could be
      // implemented as "deny everything once any exception is present"; without
      // the first it could be ignored entirely.
      expect(
        accessHolding(contractGatedHandler, keys),
        isFalse,
        reason: 'the named endpoint is carved out',
      );
      expect(
        accessHolding(overriddenHandler, keys),
        isTrue,
        reason: 'its siblings keep the API-wide grant',
      );
    });

    test('an inline endpoint on an API class keys on the class', () {
      // The discriminator between "registry-backed" meaning *this method* and
      // meaning *this class*. FixtureAccessApiService is a
      // @TomApiImplementation, but inlineGated is a plain @TomEndpoint with no
      // registry entry — it has no contract identity to key on, so it must fall
      // back to the class. Keying off which scan loop mounted the class would
      // get this one wrong.
      expect(accessHolding(inlineHandler, ['FixtureAccessApiService']), isTrue);
      expect(
        accessHolding(inlineHandler, ['fixture_access']),
        isFalse,
        reason: 'it is not part of the API contract',
      );
    });

    test('an interface-routed endpoint keys on the plain method name', () {
      expect(
        accessHolding(unguardedHandler, ['FixtureApiService.unguarded']),
        isTrue,
        reason:
            'the member key is <Interface>.<method>, not the qualified name',
      );
    });

    test('a granted interface grants its methods', () {
      expect(accessHolding(unguardedHandler, ['FixtureApiService']), isTrue);
    });

    test('a -<Interface>.<method> exception denies that one method', () {
      expect(
        accessHolding(unguardedHandler, [
          'FixtureApiService',
          '-FixtureApiService.unguarded',
        ]),
        isFalse,
      );
    });

    test('holding no relevant key leaves the prior decision alone', () {
      // The boundary: this is a second chance, not an independent verdict. With
      // neither key held it must return what it was given, both ways round.
      expect(accessHolding(unguardedHandler, ['something-else']), isFalse);
      expect(
        runZoned(
          () => unguardedHandler.checkAutomaticAccess(true),
          zoneValues: {
            TomPrincipal: TomPrincipal(
              aci: TomAccessControlInformation(
                resourceKeys: ['something-else'],
              ),
            ),
          },
        ),
        isTrue,
      );
    });

    test('interface is null exactly when the method has a contract', () {
      // The invariant the keying rests on, asserted directly rather than
      // through its consequences. `interface` means "routed via an interface";
      // a registry-backed method is identified by its contract instead, so the
      // field must be empty for it.
      //
      // This is tested structurally because it cannot be tested behaviourally:
      // `automaticProtectionKeys` consults the contract first, so it would key
      // a registry-backed endpoint correctly even if this field were wrongly
      // populated. The two are deliberately redundant — the getter is safe on
      // its own, and so is this. What only this can catch is the field lying to
      // anyone who reads it for another purpose, and a rename of the
      // implementation class silently re-entering the keying if the getter's
      // branch order is ever changed.
      expect(contractGatedHandler.interface, isNull);
      expect(overriddenHandler.interface, isNull);
      expect(inlineHandler.interface?.simpleName, 'FixtureAccessApiService');
      expect(unguardedHandler.interface?.simpleName, 'FixtureApiService');
    });
  });

  // `logRequests` is a three-state flag: true logs, false does not, and **null
  // defers to `globalSettingLogRequestsDefault`** — which is what the
  // annotation's own documentation promises. The pipeline computed that
  // decision and stored it on the request log info, then every log site
  // re-tested the raw annotation with `== true`, so the computed value reached
  // none of them and the global setting governed nothing.
  //
  // What made it invisible is that the request was still logged: the pipeline
  // stayed silent, the log info said `shouldBeLogged`, and the server's logging
  // middleware emitted its generic fallback line instead. The count of log
  // lines was therefore unchanged — only their *content* was, losing the
  // per-exit detail (which exit produced the response, the produced mime type,
  // the encoding) that the pipeline's lines carry and the middleware's cannot.
  //
  // So these tests assert on the emitted text rather than on the
  // `hasBeenLogged` flag. The flag would have looked correct throughout.
  group('logRequests and the computed logging default', () {
    late Router router;
    late _CapturingLogOutput captured;
    late TomLogOutput previousOutput;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      router = TomEndpointRouting().initializeRouter();

      previousOutput = tomLog.logOutput;
      captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
      addTearDown(() => tomLog.logOutput = previousOutput);

      final priorDefault = TomEndpointHandler.globalSettingLogRequestsDefault;
      addTearDown(
        () => TomEndpointHandler.globalSettingLogRequestsDefault = priorDefault,
      );
    });

    tearDown(TomBean.resetBeanContext);

    /// Serves [path] and reports whether the *pipeline* logged it.
    ///
    /// Matched on the pipeline's own success line rather than on the path
    /// alone: trace output names the path too, and so does the middleware's
    /// fallback line. `[Normal processing]` appears in exactly one place.
    Future<bool> pipelineLogged(String path) async {
      captured.lines.clear();
      final response = await router.call(_get(path));
      expect(response.statusCode, 200, reason: 'the request must succeed');
      return captured.lines.any(
        (l) => l.contains('[Normal processing]') && l.contains(path),
      );
    }

    test(
      'an unannotated endpoint logs when the global default is true',
      () async {
        TomEndpointHandler.globalSettingLogRequestsDefault = true;
        expect(await pipelineLogged('/fixture/default_logging'), isTrue);
      },
    );

    test(
      'an unannotated endpoint is silent when the global default is false',
      () async {
        // The other direction, and the one that shows the setting is a *setting*:
        // before the fix both directions produced the same output, because the
        // raw annotation was null in both and `null == true` is false either way.
        TomEndpointHandler.globalSettingLogRequestsDefault = false;
        expect(await pipelineLogged('/fixture/default_logging'), isFalse);
      },
    );

    test(
      'an explicit false is not overridden by a true global default',
      () async {
        // The boundary in the other direction: the fix replaces the *fallback*,
        // not the annotation. Reading the computed decision must not start
        // logging an endpoint that asked not to be logged.
        TomEndpointHandler.globalSettingLogRequestsDefault = true;
        expect(await pipelineLogged('/fixture/unguarded'), isFalse);
      },
    );

    test(
      'an explicit true is not overridden by a false global default',
      () async {
        TomEndpointHandler.globalSettingLogRequestsDefault = false;
        expect(await pipelineLogged('/fixture/health'), isTrue);
      },
    );

    test(
      'the flag handed to the middleware agrees with what was logged',
      () async {
        // `shouldBeLogged` is the pipeline's instruction to
        // `tomLoggingMiddleware`: "log this if nobody else did". Handing it `true`
        // while declining to log is what produced the generic fallback line, so
        // the two must not be able to disagree.
        TomEndpointHandler.globalSettingLogRequestsDefault = true;
        final logged = TomRequestLogInfo();
        await router.call(
          Request(
            'GET',
            Uri.parse('http://localhost/fixture/default_logging'),
            context: {TomRequestLogInfo.contextName: logged},
          ),
        );
        expect(logged.shouldBeLogged, isTrue);
        expect(
          logged.hasBeenLogged,
          isTrue,
          reason: 'the pipeline logged, so the middleware must not log again',
        );

        TomEndpointHandler.globalSettingLogRequestsDefault = false;
        final silent = TomRequestLogInfo();
        await router.call(
          Request(
            'GET',
            Uri.parse('http://localhost/fixture/default_logging'),
            context: {TomRequestLogInfo.contextName: silent},
          ),
        );
        expect(
          silent.shouldBeLogged,
          isFalse,
          reason: 'opting out must reach the middleware too, or it logs anyway',
        );
        expect(silent.hasBeenLogged, isFalse);
      },
    );

    test(
      'the handler-supplied-response exit follows the same default',
      () async {
        // One log statement per exit, all five of them the same decision. The
        // conversion exit is covered above; this is the other one a successful
        // request can leave by, and the one streaming endpoints always take.
        Future<bool> exitLogged(bool globalDefault) async {
          TomEndpointHandler.globalSettingLogRequestsDefault = globalDefault;
          captured.lines.clear();
          final response = await router.call(
            _get('/fixture/default_logging_response'),
          );
          expect(response.statusCode, 200);
          return captured.lines.any(
            (l) => l.contains('[handler-supplied response]'),
          );
        }

        expect(await exitLogged(true), isTrue);
        expect(await exitLogged(false), isFalse);
      },
    );

    test('the error-handler exit follows the same default', () async {
      // The exit whose log line matters most: for a failed request it is the
      // only record that the failure happened, and the middleware's fallback
      // line cannot say which exit produced the 500.
      Future<bool> exitLogged(bool globalDefault) async {
        TomEndpointHandler.globalSettingLogRequestsDefault = globalDefault;
        captured.lines.clear();
        final response = await router.call(
          _get('/fixture/default_logging_error'),
        );
        expect(response.statusCode, 500, reason: 'the handler throws');
        return captured.lines.any(
          (l) => l.contains('[handleInvocationError by error handler]'),
        );
      }

      expect(await exitLogged(true), isTrue);
      expect(await exitLogged(false), isFalse);
    });

    test('the socket path follows the same default', () async {
      // `handleWebSocketCall` computes and consults the decision separately from
      // the HTTP path, so it needs its own assertion or reverting it alone goes
      // unnoticed. `/fixture/socket` declares no `logRequests`, which is exactly
      // the case at issue.
      //
      // Reached with a plain GET — no `Upgrade` header — which `shelf_web_socket`
      // refuses with a 404. That is the only way into this log line from a test:
      // an *accepted* handshake hijacks the connection, and `hijack` throws
      // `HijackException`, so the statement after `await handler(req)` never
      // runs (quest todo
      // tcincb136_ahye-websocket-handshake-log-unreachable-on-accepted-upgrade).
      Future<bool> socketLogged(bool globalDefault) async {
        TomEndpointHandler.globalSettingLogRequestsDefault = globalDefault;
        captured.lines.clear();
        final response = await router.call(_get('/fixture/socket'));
        expect(response.statusCode, 404, reason: 'not a WebSocket request');
        return captured.lines.any((l) => l.contains('[WebSocket handshake]'));
      }

      expect(await socketLogged(true), isTrue);
      expect(await socketLogged(false), isFalse);
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
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
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
      addTearDown(
        () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
      );

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

  // A request body that cannot become the endpoint's DTO is a *reportable*
  // failure, and for a long time it was not reportable at all: both throw sites
  // in the JSON branch of `bindParameters` were enclosed by a catch that did
  // nothing but log. The named exception never left the method, the parameter
  // was simply never added to `positionalArguments`, and the request failed much
  // later inside `invoke` with a wrong-argument-count error naming neither the
  // parameter nor the body that could not be decoded — the one diagnosis a
  // client cannot act on, produced from the one situation where the client is
  // the party who can fix it.
  //
  // The two failures are kept apart because a client can do different things
  // about them: `request_body_not_json` means the bytes were not a JSON object
  // at all, `parameter_instantiation_failed` means they were, and the DTO
  // refused a value inside them. Each is asserted at its own throw site.
  group('a body that cannot become a DTO is reported, not swallowed', () {
    late TomEndpointHandler parseHandler;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
      parseHandler = _routeInfo('/fixture/parse', 'POST').handler;
    });

    tearDown(TomBean.resetBeanContext);

    test('a well-formed body still binds', () async {
      // The control. Everything below asserts a throw, so without this the group
      // would be satisfied by a `bindParameters` that rejected every body.
      final bound = await parseHandler.bindParameters(
        _post('/fixture/parse', '{"label":"x","when":"2026-08-25T00:00:00Z"}'),
      );
      expect(bound, hasLength(1));
      expect((bound.single as FixtureParseRequest).label, 'x');
    });

    test('a value the DTO refuses surfaces parameter_instantiation_failed', () {
      // `when` is a DateTime, so this body is valid JSON that the DTO cannot be
      // built from — the reflector raises reflection.set.date_parse_failed and
      // the pipeline is supposed to name it as its own.
      expect(
        () => parseHandler.bindParameters(
          _post('/fixture/parse', '{"label":"x","when":"not-a-date"}'),
        ),
        throwsA(
          isA<TomEndpointHandlerException>().having(
            (e) => e.key,
            'key',
            'endpoint_pipeline.handle_method_call.parameter_instantiation_failed',
          ),
        ),
        reason:
            'the key exists precisely so a client can be told which failure it '
            'hit; a catch that logs and continues means no client can ever '
            'receive it',
      );
    });

    test('a body that is not JSON surfaces request_body_not_json', () {
      expect(
        () => parseHandler.bindParameters(_post('/fixture/parse', '{not json')),
        throwsA(
          isA<TomEndpointHandlerException>().having(
            (e) => e.key,
            'key',
            'endpoint_pipeline.handle_method_call.request_body_not_json',
          ),
        ),
      );
    });

    test('a body that is JSON but not an object surfaces the same key', () {
      // `[1,2,3]` decodes without complaint and then fails the cast to a field
      // map. Same remedy for the client — send an object — so the same key,
      // rather than leaving this one as the bare TypeError it used to be.
      expect(
        () => parseHandler.bindParameters(_post('/fixture/parse', '[1,2,3]')),
        throwsA(
          isA<TomEndpointHandlerException>().having(
            (e) => e.key,
            'key',
            'endpoint_pipeline.handle_method_call.request_body_not_json',
          ),
        ),
      );
    });

    test('an empty body is not a body error — it falls through to binding', () {
      // The boundary this change must not cross. "No body" is how a body-less
      // GET reaches a DTO built from path and query values alone, so the body
      // branch must decline it rather than reject it; only a body that *is*
      // there and *is* wrong is a body error.
      //
      // What proves the fallthrough is *which* failure arrives. There is no
      // context bean of this type either, so binding runs out of strategies and
      // reports the parameter it could not fill — a later, different diagnosis
      // than "your body is malformed". Asserting the key rather than merely
      // `returnsNormally` is what makes this a test of the fallthrough: a
      // request_body_not_json here would mean the body branch had claimed a
      // request it has nothing to say about.
      expect(
        () => parseHandler.bindParameters(_post('/fixture/parse', '')),
        throwsA(
          isA<TomEndpointHandlerException>().having(
            (e) => e.key,
            'key',
            'endpoint_pipeline.bind_parameters.unbindable_parameter',
          ),
        ),
      );
    });
  });

  // `bindParameters` returns a *positional* list, and a positional list has no
  // way to say "this one is absent". Skipping a parameter it could not fill
  // therefore does not leave that parameter unset — it shortens the list, and
  // every parameter after it moves one place to the left. The consequence is
  // worse than the wrong-argument-count error it usually becomes: where the
  // shifted value happens to fit the earlier parameter's type, the method is
  // invoked successfully with the wrong argument in it, and nothing anywhere
  // reports that a value was misplaced.
  //
  // So the returned list is now asserted to be *positionally faithful*: entry i
  // is the value of parameter i, and the list ends where the bound parameters
  // end. That admits exactly one kind of shortening — dropping trailing
  // optionals, which is how Dart applies their defaults — and refuses every
  // other, each with a key naming the parameter at fault.
  group('binding preserves argument positions', () {
    late TomEndpointHandler pairHandler;
    late TomEndpointHandler optionalTailHandler;
    late TomEndpointHandler optionalGapHandler;
    late TomEndpointHandler namedTailHandler;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
      pairHandler = _routeInfo('/fixture/pair').handler;
      optionalTailHandler = _routeInfo('/fixture/optional_tail').handler;
      optionalGapHandler = _routeInfo('/fixture/optional_gap').handler;
      namedTailHandler = _routeInfo('/fixture/named_tail').handler;
    });

    tearDown(TomBean.resetBeanContext);

    test('the FIRST of two parameters being unbindable fails the request', () {
      // The case the whole group exists for. `first` is a request DTO on a GET
      // with no body, no path capture and no query mapping, so nothing can fill
      // it; `second` binds from the query string. Skipping `first` yields the
      // single-element list ['hello'] — and 'hello' is then the argument for
      // `first`, not for `second`.
      expect(
        () => pairHandler.bindParameters(_get('/fixture/pair?second=hello')),
        throwsA(
          isA<TomEndpointHandlerException>()
              .having(
                (e) => e.key,
                'key',
                'endpoint_pipeline.bind_parameters.unbindable_parameter',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(contains('first'), contains('FixtureParseRequest')),
              ),
        ),
        reason:
            'naming the parameter is the point: "wrong number of arguments" '
            'sends the reader to the call site, which is generated, instead of '
            'to the declaration that cannot be satisfied',
      );
    });

    test('a trailing optional that nothing binds is omitted, not an error', () {
      // The counter-case, and the reason "unbound" cannot simply mean "error".
      // A default value is the declaration saying the parameter may be absent,
      // and dropping a *trailing* optional from the positional list is exactly
      // how Dart applies that default.
      expect(
        optionalTailHandler.bindParameters(
          _get('/fixture/optional_tail?first=a'),
        ),
        completion(equals(['a'])),
      );
    });

    test('a trailing optional that does bind is still passed', () {
      expect(
        optionalTailHandler.bindParameters(
          _get('/fixture/optional_tail?first=a&second=b'),
        ),
        completion(equals(['a', 'b'])),
      );
    });

    test('an optional hole between two bound parameters fails', () {
      // `?first=1&third=3` leaves `second` unfilled with `third` filled after
      // it. Omitting `second` does not apply its default — it slides '3' into
      // `second`'s slot and leaves `third` on its own default, so the method
      // runs with two wrong arguments and no complaint. An optional may be
      // dropped only when everything after it is dropped too.
      expect(
        () => optionalGapHandler.bindParameters(
          _get('/fixture/optional_gap?first=1&third=3'),
        ),
        throwsA(
          isA<TomEndpointHandlerException>()
              .having(
                (e) => e.key,
                'key',
                'endpoint_pipeline.bind_parameters.unbindable_optional_parameter',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains('second'),
              ),
        ),
      );
    });

    test('all optionals bound is unaffected', () {
      expect(
        optionalGapHandler.bindParameters(
          _get('/fixture/optional_gap?first=1&second=2&third=3'),
        ),
        completion(equals(['1', '2', '3'])),
      );
    });

    test('a named parameter nothing binds is simply absent', () {
      // A named parameter occupies no positional slot, so leaving it out cannot
      // shift anything. Its default applies, exactly as declared.
      expect(
        namedTailHandler.bindParameters(_get('/fixture/named_tail?first=a')),
        completion(equals(['a'])),
      );
    });

    test('a named parameter that binds is refused, not mis-placed', () {
      // The corruption arriving from the other direction: the pipeline invokes
      // with positional arguments only, so a bound named value has nowhere
      // legitimate to go. Appending it positionally puts it in the slot of
      // whichever positional parameter follows — here it would simply be a
      // second argument to a one-positional-parameter method. Refusing it names
      // a declaration the binder cannot honour instead of silently honouring it
      // wrongly.
      expect(
        () => namedTailHandler.bindParameters(
          _get('/fixture/named_tail?first=a&tag=b'),
        ),
        throwsA(
          isA<TomEndpointHandlerException>()
              .having(
                (e) => e.key,
                'key',
                'endpoint_pipeline.bind_parameters.named_parameter_not_supported',
              )
              .having((e) => e.defaultUserMessage, 'message', contains('tag')),
        ),
      );
    });

    test('the failure reaches the caller as a failed request', () {
      // Asserted through the router, not just the binder: the point of throwing
      // is that the request stops. Were the exception to be absorbed anywhere
      // between here and the handler, the method would still be invoked with
      // the shifted list.
      final router = TomEndpointRouting().initializeRouter();
      expect(
        router.call(_get('/fixture/pair?second=hello')),
        throwsA(isA<TomEndpointHandlerException>()),
      );
    });
  });

  group('@TomTransactional endpoints', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      router = TomEndpointRouting().initializeRouter();
      FixtureApiServer.transactionalArrivals.clear();
    });

    tearDown(() {
      FixtureApiServer.transactionalRelease = null;
      FixtureApiServer.transactionalArrivals.clear();
      TomBean.resetBeanContext();
    });

    test('two concurrent calls run in independent transactions', () async {
      // The request-path form of the assertion this change exists for. Nothing
      // here installs the authentication middleware — the router is called
      // directly — so the scope each call runs in comes from the pipeline's own
      // guard. Both calls are parked *inside* their transactional block at the
      // same time, so the two transactions genuinely coexist rather than merely
      // being observed one after the other; with a process-wide current
      // transaction the second call would have joined the first one's.
      final release = Completer<void>();
      FixtureApiServer.transactionalRelease = release;

      final first = router.call(_get('/fixture/transactional'));
      final second = router.call(_get('/fixture/transactional'));
      while (FixtureApiServer.transactionalArrivals.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      release.complete();
      final responses = await Future.wait([first, second]);

      expect(responses.every((r) => r.statusCode == 200), isTrue);
      final arrivals = FixtureApiServer.transactionalArrivals;
      expect(arrivals[0], isNotNull, reason: 'the pipeline opened one');
      expect(arrivals[1], isNotNull);
      expect(
        identical(arrivals[0], arrivals[1]),
        isFalse,
        reason: 'each request gets its own current transaction',
      );
    });

    test('the transaction survives an await inside the endpoint', () async {
      // Zone values follow the flow across asynchronous gaps; a field on the
      // manager would not distinguish "still mine" from "whatever ran last".
      final response = await router.call(_get('/fixture/transactional'));
      final body = jsonDecode(await response.readAsString());
      expect(body['stable'], isTrue);
      expect(
        body['running'],
        isTrue,
        reason: 'the pipeline concludes the transaction after the call',
      );
    });

    test('@TomTransactional(isReadOnly: true) reaches the transaction', () async {
      // The flag was declarable and discarded, so a read-only endpoint opened a
      // read-write transaction and no participant could ever act on it.
      final response = await router.call(_get('/fixture/transactional'));
      final body = jsonDecode(await response.readAsString());
      expect(body['readOnly'], isTrue);
    });

    test(
      'a non-transactional endpoint leaves no current transaction',
      () async {
        final response = await router.call(_get('/fixture/unguarded'));
        expect(response.statusCode, 200);
        expect(
          TomTransactionManager.getCurrentTransaction(),
          isNull,
          reason: 'the request scope is not the caller\'s scope',
        );
      },
    );
  });
}

/// A [HealthAnalyzer] returning a non-OK status, to prove the route reflects the
/// configured analyzer rather than a hardcoded string.
class _DegradedAnalyzer extends HealthAnalyzer {
  @override
  Future<String> analyzeHealth() async => 'DEGRADED';
}
