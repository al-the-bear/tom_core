import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
        GreetingServer,
        TodoApiServer,
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
    DateTime timeStamp, [
    String? origin,
  ]) => lines.add(convertToString(message));
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

/// A DELETE for [path], carrying the same request context as [_get].
Request _delete(String path) => Request(
  'DELETE',
  Uri.parse('http://localhost$path'),
  context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
);

/// A CORS preflight for [path].
///
/// A browser sends this before a cross-origin call and reads only the
/// `Access-Control-*` headers off the answer. It carries no principal and no
/// body, which is the point: the pipeline must answer it before it asks who is
/// calling.
Request _options(String path) => Request(
  'OPTIONS',
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

  // The behavioural half of the resolution above, and the claim `doc/endpoints.md`
  // actually makes to a reader: *declare the policy on the contract and the
  // request is checked against it* — you need not restate it inline.
  //
  // The group above pins which object lands in `metadata.access`; the automatic
  // -protection group calls `checkAutomaticAccess` directly. Neither issues a
  // request, so "the contract gates the endpoint" was an inference from two
  // separately-true facts rather than a checked claim — and an inference is
  // exactly what breaks in the middle. A reader who trusts the document and
  // omits the inline annotation is relying on the composition, so the
  // composition is what is asserted here.
  group('a contract-declared policy gates the live request', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    /// Runs [body] as an authenticated principal holding exactly [roles].
    T asPrincipalWithRoles<T>(List<String> roles, T Function() body) =>
        runZoned(
          body,
          zoneValues: {
            TomPrincipal: TomPrincipal(
              user: TomUser(id: 1, username: 'role-holder'),
              authenticated: true,
              aci: TomAccessControlInformation(roles: roles),
            ),
          },
        );

    /// What a denied caller receives: a bare 404, indistinguishable from a
    /// route that is not there.
    ///
    /// Asserted as a *response* rather than as a thrown exception because that
    /// is what the caller sees. The exception still exists — it carries the
    /// message into the server log — but it does not leave the pipeline, and a
    /// test that watched for it would go on passing if the status changed.
    Future<void> expectDenied(Future<Response> pending) async {
      final response = await pending;
      expect(response.statusCode, 404);
      final body = await response.readAsString();
      expect(
        body,
        isNot(contains(tomEndpointAccessDeniedErrorKey)),
        reason: 'a body naming the denial undoes the status that hides it',
      );
      expect(
        response.headers['x-tom-error'],
        isNull,
        reason: 'nor may a header mark it as an error envelope',
      );
    }

    test('the contract role admits a handler that declares nothing', () async {
      final response = await asPrincipalWithRoles([
        'fixture-contract-role',
      ], () => router.call(_get('/fixture-access/contract-gated')));
      expect(response.statusCode, 200);
      expect(jsonDecode(await response.readAsString())['source'], 'contract');
    });

    test('a caller without the contract role is refused', () async {
      // The half that makes the contract policy load-bearing rather than
      // decorative. If this passed, the document would be telling readers to
      // rely on a declaration that gates nothing — the worse of the two
      // possible failures, because the endpoint looks protected.
      await expectDenied(
        asPrincipalWithRoles([
          'some-other-role',
        ], () => router.call(_get('/fixture-access/contract-gated'))),
      );
    });

    test(
      'the handler override is what the request is checked against',
      () async {
        // The override stated as a request outcome rather than as an identity on
        // a metadata object: holding the *contract's* role does not open an
        // endpoint whose handler declared a different one. Swapping the two
        // operands of `tea ?? ae?.access` would widen access here, which is the
        // direction that matters.
        await expectDenied(
          asPrincipalWithRoles([
            'fixture-contract-role',
          ], () => router.call(_get('/fixture-access/overridden'))),
        );
      },
    );

    test('the handler role admits the endpoint that declares it', () async {
      // The converse, so the test above is about *which* policy applied and not
      // about the route being broken for everyone.
      final response = await asPrincipalWithRoles([
        'fixture-handler-role',
      ], () => router.call(_get('/fixture-access/overridden')));
      expect(response.statusCode, 200);
      expect(jsonDecode(await response.readAsString())['source'], 'handler');
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

    // An endpoint declared `Future<void>` promises the caller nothing, but
    // `Future<void>` does not *erase* a value: an implementation that narrows to
    // `Future<int>` — which Dart permits, and which any method tail-calling
    // `TomRepository.deleteById` does — completes with the int, and it travels
    // to the pipeline invisible in every static type along the way.
    //
    // The declaration is the authority here, not the value that arrives: the
    // client's typed proxy is generated from the same declaration and has
    // nowhere to put a body, so a body is at best unread and at worst — as
    // below — unrenderable. Asserted through the router rather than on the
    // handler, because the claim is about what the *caller* receives.
    group('an endpoint declaring no result answers with no body', () {
      test('a leaked value the converter cannot render is not a 500', () async {
        // `int` carries no @tomReflector, so the outbound converter's last
        // fallback throws `reflector.type.not_annotated` on it. Before the
        // declaration was consulted this turned a successful delete into an
        // HTTP 500 — the work done, and reported as a server fault.
        final response = await router.call(_delete('/fixture/silent'));
        expect(response.statusCode, 200);
        expect(await response.readAsString(), isEmpty);
      });

      test('a leaked value the converter *can* render is dropped too', () async {
        // The quieter half: a Map renders happily, so the leak would surface as
        // a body the contract never announced rather than as an error. Both are
        // the same defect, and one rule answers both.
        final response = await router.call(
          _delete('/fixture/silent_renderable'),
        );
        expect(response.statusCode, 200);
        expect(await response.readAsString(), isEmpty);
      });
    });

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
  });

  // CORS is a browser-facing boundary, and the only failure mode it has is a
  // request refused inside a browser and nowhere else: `curl` ignores these
  // headers, every server-side test that calls the router directly gets its
  // answer regardless, and the integration suites speak to the server from
  // Dart. So a regression here reaches production intact and surfaces as "the
  // web app cannot call the API" with nothing in the server log to explain it.
  //
  // The tempting shape for a preflight test — send an OPTIONS to
  // `/fixture/health` and assert `inInclusiveRange(200, 299)` — checks neither
  // claim it appears to. That endpoint answers 200 when it *is* invoked, so a
  // "returns without invoking" caption holds either way, and no Access-Control
  // header is read at all. Both real claims are asserted here instead: that the
  // method is not invoked, and that the three headers carry the values the
  // endpoint and the defaults resolve to.
  group('CORS preflight', () {
    late Router router;
    late String originalOrigin;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      router = TomEndpointRouting().initializeRouter();
      // The defaults are mutable statics, so one test changing one would
      // otherwise leak into every test after it — including the default-case
      // assertions, which would then be checking a value this file set.
      originalOrigin =
          TomEndpointHandler.globalSettingCorsAllowedOriginsDefault;
    });

    tearDown(() {
      TomEndpointHandler.globalSettingCorsAllowedOriginsDefault =
          originalOrigin;
      TomBean.resetBeanContext();
    });

    test('the three headers carry the global defaults', () async {
      // `/fixture/health` overrides none of the three, so a preflight on it is
      // the defaults as a browser sees them — the values are read off the
      // response rather than restated, so the statics and the wire agree by
      // construction rather than by a copy in this file going stale.
      final response = await router.call(_options('/fixture/health'));
      expect(response.statusCode, 200);
      expect(
        response.headers['access-control-allow-origin'],
        TomEndpointHandler.globalSettingCorsAllowedOriginsDefault,
      );
      expect(
        response.headers['access-control-allow-methods'],
        TomEndpointHandler.globalSettingCorsAllowedMethodsDefault,
      );
      expect(
        response.headers['access-control-allow-headers'],
        TomEndpointHandler.globalSettingCorsAllowedHeadersDefault,
      );
    });

    test('the shipped defaults are open, and say so', () async {
      // The values themselves, once, so that a change to the *package's* posture
      // is a deliberate edit here rather than something the assertions above
      // would follow silently. `*` is the permissive default a framework ships
      // to keep first contact working; narrowing it is a deployment's job.
      final response = await router.call(_options('/fixture/health'));
      expect(response.headers['access-control-allow-origin'], '*');
      expect(
        response.headers['access-control-allow-methods'],
        'GET, POST, PUT, DELETE, TRACE, PATCH, HEAD, CONNECT',
      );
      expect(
        response.headers['access-control-allow-headers'],
        'Origin, Content-Type, Accept, Authorization, Referer, User-Agent',
      );
    });

    test('the endpoint method is not invoked', () async {
      // What the old test's caption claimed. `/fixture/health` returns a JSON
      // body when invoked, so an empty body is the observable difference
      // between answering the preflight and running the endpoint — a status
      // code cannot tell the two apart, because both are 200.
      final response = await router.call(_options('/fixture/health'));
      expect(await response.readAsString(), isEmpty);
    });

    test('an endpoint override replaces only the value it states', () async {
      // `/fixture/cors_origin` states an origin and nothing else. Each header
      // falls back on its own, so the other two must still be the defaults:
      // an implementation that treated "has any override" as "use the
      // endpoint's three values" would answer null for both.
      final response = await router.call(_options('/fixture/cors_origin'));
      expect(
        response.headers['access-control-allow-origin'],
        'https://origin.example.com',
      );
      expect(
        response.headers['access-control-allow-methods'],
        TomEndpointHandler.globalSettingCorsAllowedMethodsDefault,
      );
      expect(
        response.headers['access-control-allow-headers'],
        TomEndpointHandler.globalSettingCorsAllowedHeadersDefault,
      );
    });

    test('all three values are overridable', () async {
      // `/fixture/cors_full` narrows all three. The methods and headers
      // overrides have no other exercise in the package: with no endpoint
      // stating them, dropping their `??` and always answering the default
      // would leave every other test in this group green.
      final response = await router.call(_options('/fixture/cors_full'));
      expect(
        response.headers['access-control-allow-origin'],
        'https://full.example.com',
      );
      expect(response.headers['access-control-allow-methods'], 'GET, HEAD');
      expect(response.headers['access-control-allow-headers'], 'Authorization');
    });

    test('a changed default reaches an already-mounted route', () async {
      // What makes these `globalSetting*` rather than constants. The routes
      // were mounted in setUp, before this assignment, so an implementation
      // that read the default once at mount time — or copied it into the
      // handler — would keep answering `*` here. That is the shape of the
      // mistake that matters: an operator locks the origin down at startup,
      // the log says nothing, and the server keeps advertising `*`.
      TomEndpointHandler.globalSettingCorsAllowedOriginsDefault =
          'https://locked-down.example.com';
      final response = await router.call(_options('/fixture/health'));
      expect(
        response.headers['access-control-allow-origin'],
        'https://locked-down.example.com',
      );
    });

    test('a gated endpoint answers preflight with no principal', () async {
      // A browser sends a preflight *unauthenticated* — no cookie, no
      // Authorization header — and treats anything but a success as "this
      // request is not allowed". So preflight has to be answered before access
      // control, not after it. `/fixture-access/contract-gated` requires a role
      // and is called here from a zone with no principal at all: moving the
      // preflight check below `enforceAccess` would 401 here while leaving
      // every direct-call test of that endpoint untouched, and the endpoint
      // would work everywhere except in a browser.
      final response = await router.call(
        _options('/fixture-access/contract-gated'),
      );
      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], '*');
    });

    test('a socket route answers preflight like any other', () async {
      // `createRoutesForEndpoint` mounts OPTIONS beside the handshake GET so
      // that "a browser can discover the route the same way it discovers any
      // other" — the source says so, and nothing checked it. A socket route is
      // the one place where the preflight registration is written separately
      // from the ordinary path, so it is also the one that can be dropped on
      // its own.
      final response = await router.call(_options('/fixture/socket'));
      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], '*');
    });
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
      // `initializeRouter` starts from an empty table, so a stale entry from an
      // earlier run cannot let an absent route look present here.
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

  // Which `TomHttpMethod` constants may appear in `methods:` is decided by one
  // switch, and `doc/endpoints.md` now states the answer to a reader. A switch
  // grows a case far more readily than a document grows a sentence, so the set
  // is pinned here rather than left to prose: adding `options` to the switch, or
  // dropping `connect` from it, fails a test instead of quietly making the
  // document wrong.
  //
  // `createRoutesForEndpoint` is called directly rather than through
  // `initializeRouter`. The obvious alternative — a fixture service declaring
  // `methods: [TomHttpMethod.options]` — would be scanned by every other group's
  // `initializeRouter()` in this file and fail all of them, which is a
  // file-wide cost for one negative case.
  // The two tables are the framework's only public statement about what it is
  // serving, which is why they are exposed at all — a diagnostics caller reads
  // them without holding the router. That makes them worth reading and not
  // worth writing: a caller that could append would be describing a route
  // nothing serves, and one that could remove would be hiding a route that is
  // still served. Either leaves every reader wrong about the process it is
  // reporting on, and neither changes what the server answers, so the damage is
  // undetectable from the outside.
  group('the routing tables are readable, not writable', () {
    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
    });

    tearDown(() {
      TomEndpointRouting.resetRoutes();
      TomBean.resetBeanContext();
    });

    test('the handler list refuses every mutation', () {
      final handler = TomEndpointRouting.handlers.first;
      expect(
        () => TomEndpointRouting.handlers.add(handler),
        throwsUnsupportedError,
      );
      expect(TomEndpointRouting.handlers.clear, throwsUnsupportedError);
      expect(
        () => TomEndpointRouting.handlers[0] = handler,
        throwsUnsupportedError,
      );
    });

    test('the route table refuses every mutation', () {
      final key = TomEndpointRouting.routingInfo.keys.first;
      final info = TomEndpointRouting.routingInfo[key]!;
      expect(
        () => TomEndpointRouting.routingInfo[key] = info,
        throwsUnsupportedError,
      );
      expect(
        () => TomEndpointRouting.routingInfo.remove(key),
        throwsUnsupportedError,
      );
      expect(TomEndpointRouting.routingInfo.clear, throwsUnsupportedError);
    });

    test('the views are live, not snapshots', () {
      // A view rather than a copy, so a diagnostics caller holding the
      // reference sees a later mount — and so that reading the table costs
      // nothing on a path an operator may poll.
      final routes = TomEndpointRouting.routingInfo;
      final handlers = TomEndpointRouting.handlers;
      final beforeRoutes = routes.length;
      final beforeHandlers = handlers.length;

      final mounted = TomEndpointRouting.routingInfo.values.first.handler;
      TomEndpointRouting().createRoutesForEndpoint(
        TomEndpoint(uri: '/probe_live', methods: [TomHttpMethod.get]),
        Router(),
        mounted,
        mounted.metadata,
        tomReflector.reflectType(FixtureApiServer) as ClassMirror,
      );

      expect(routes.length, beforeRoutes + 1);
      expect(handlers.length, beforeHandlers + 1);
      expect(routes.containsKey((uri: '/probe_live', method: 'GET')), isTrue);
    });

    test('resetRoutes empties both', () {
      expect(TomEndpointRouting.handlers, isNotEmpty);
      expect(TomEndpointRouting.routingInfo, isNotEmpty);

      TomEndpointRouting.resetRoutes();

      expect(TomEndpointRouting.handlers, isEmpty);
      expect(TomEndpointRouting.routingInfo, isEmpty);
    });

    test('a second initializeRouter describes the second run, not both', () {
      // What the doc comment claims — "the last run" — and what was false
      // while nothing cleared the tables: the handler list grew by a full
      // router's worth on every initialisation, without bound, and a route
      // deleted from the source would have gone on being reported as mounted.
      final first = TomEndpointRouting.handlers.length;
      final firstRoutes = TomEndpointRouting.routingInfo.length;
      expect(first, greaterThan(0));

      TomEndpointRouting().initializeRouter();

      expect(TomEndpointRouting.handlers, hasLength(first));
      expect(TomEndpointRouting.routingInfo, hasLength(firstRoutes));
    });
  });

  group('the HTTP methods an endpoint may declare', () {
    late TomEndpointHandler handler;
    late ClassMirror serviceMirror;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
      // Any mounted endpoint will do. The switch reads `tep.methods`; the
      // handler and the mirror are only what serves the route and what names the
      // failure, so borrowing a real pair keeps the test to its one variable.
      handler = _routeInfo('/fixture/health').handler;
      serviceMirror = tomReflector.reflectType(FixtureApiServer) as ClassMirror;
    });

    tearDown(() {
      // `createRoutesForEndpoint` writes both tables, and `/probe` is not a
      // route any other group should be able to find.
      TomEndpointRouting.resetRoutes();
      TomBean.resetBeanContext();
    });

    /// Mounts `/probe` for [method] on a throwaway router.
    ///
    /// A fresh `Router` per call, so mounting the same path repeatedly is not
    /// itself the thing under test.
    void mount(TomHttpMethod method) =>
        TomEndpointRouting().createRoutesForEndpoint(
          TomEndpoint(uri: '/probe', methods: [method]),
          Router(),
          handler,
          handler.metadata,
          serviceMirror,
        );

    /// What an undeclarable method fails the build with.
    final invalidMethod = throwsA(
      isA<TomEndpointPipelineException>().having(
        (e) => e.key,
        'key',
        'endpoint_pipeline.initialize_router.invalid_http_method',
      ),
    );

    test('the nine declarable constants all mount', () {
      for (final method in const [
        TomHttpMethod.get,
        TomHttpMethod.post,
        TomHttpMethod.put,
        TomHttpMethod.patch,
        TomHttpMethod.delete,
        TomHttpMethod.head,
        TomHttpMethod.connect,
        TomHttpMethod.trace,
        TomHttpMethod.all,
      ]) {
        expect(
          () => mount(method),
          returnsNormally,
          reason: '${method.name} is declarable',
        );
      }
    });

    test('OPTIONS is the one constant that cannot be declared', () {
      // Not an oversight. The pipeline mounts OPTIONS on every route itself so
      // that preflight is answered uniformly; a declared one would be a second
      // registration on the same path, and shelf dispatches to the first match,
      // so it could never be reached.
      expect(() => mount(TomHttpMethod.options), invalidMethod);
    });

    test('a method built at runtime is not one of the nine', () {
      // `TomHttpMethod` has a public constructor and no value equality, so a
      // constant pattern matches by identity. `TomHttpMethod.get` is canonical;
      // an equally-named instance built at runtime is a different object and
      // falls through to the throw.
      //
      // Worth pinning because of how the failure reads: "Endpoint method
      // GET/true invalid" is not a sentence whose cause anyone would go looking
      // for, and the fix is to use the constant rather than to change the verb.
      final rebuiltGet = TomHttpMethod(TomHttpMethod.get.name);
      expect(() => mount(rebuiltGet), invalidMethod);
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

  // The module readme's Quick start is the first code a reader of this module
  // copies, and for a scanned pipeline "it compiles" is only half the claim: a
  // declaration can be perfectly well-formed Dart and still mount nothing,
  // because what mounts a route is the annotation set and the instance
  // resolution, neither of which the compiler checks. The readme previously got
  // both halves wrong — `extends TomApiImplementation` does not compile, and the
  // class it described would not have been scanned if it had. So the snippet is
  // declared as real reflected code in the fixture ([TodoApi] / [TodoApiServer])
  // and asserted here, end to end, in the three steps the readme names.
  // The worked example of `doc/endpoints.md`'s "Declaring an Endpoint" — the
  // first snippet a reader of that document meets. It showed one concrete
  // `@tomService class GreetingService` carrying its own body, which is
  // well-formed Dart that mounts nothing: `findServiceInstance` matches by
  // supertype and a class is not its own supertype. The guide now shows the
  // two-type pair, and these tests are what let it say the pair works — for a
  // scanned pipeline "it compiles" is only half the claim, since the compiler
  // checks neither the annotation set nor the instance resolution.
  group('the endpoints guide worked example', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(GreetingServer, GreetingServer());
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test('mounts the route the snippet declares', () {
      expect(
        TomEndpointRouting.routingInfo.containsKey((
          uri: '/greet',
          method: 'POST',
        )),
        isTrue,
      );
    });

    test('binds the request body and returns the response', () async {
      // The half a mount check cannot make: the DTOs are ordinary reflected
      // classes, and the guide says so, so the round trip is what establishes
      // that "ordinary" is enough — body decoded into `GreetingRequest`, result
      // encoded from `GreetingResponse`, by the same field walk.
      final response = await router.call(
        _post('/greet', jsonEncode({'name': 'Ada'})),
      );
      expect(response.statusCode, 200);
      expect(jsonDecode(await response.readAsString()), {
        'greeting': 'Hello, Ada',
      });
    });

    test('resolves the @tomComponent as the @tomService instance', () {
      // The assertion that fails if the guide is ever collapsed back into one
      // class: a self-referential service resolves to nothing, so the route
      // would mount against no instance.
      expect(
        _routeInfo('/greet', 'POST').handler.instance.reflectee,
        isA<GreetingServer>(),
      );
    });

    test('stays anonymous when the deployment protects by default', () async {
      // The snippet declares `@TomPublicAccess()`, which looks decorative under
      // the suite's permissive default. It is not: a deployment that turns
      // automatic protection on is the case it exists for, and without it the
      // guide's first route would answer 403 the moment the reader hardened
      // their server.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(
        () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
      );
      final response = await router.call(
        _post('/greet', jsonEncode({'name': 'Ada'})),
      );
      expect(response.statusCode, 200);
    });

    test('is the pair doc/endpoints.md shows, verbatim', () {
      // The three tests above establish that this pair mounts and serves. They
      // say nothing about the *guide*, which is where a reader meets it — so
      // this is what joins the two claims. Without it the fixture could be
      // corrected and the document left showing the shape that mounts nothing,
      // which is exactly the state this group was written for.
      //
      // Compared without comments or blank lines: the fixture carries dartdoc
      // the guide has no room for, and requiring that to match too would make
      // the pair impossible to keep identical rather than merely required to
      // be.
      List<String> code(String source) => source
          .split('\n')
          .map((line) => line.trimRight())
          .where((line) => line.isNotEmpty && !line.trimLeft().startsWith('//'))
          .toList();

      const opening =
          '@tomReflector\n@tomService\nabstract class '
          'GreetingService';
      const closing = '}';

      final guide = File('doc/endpoints.md').readAsStringSync();
      final fixture = File(
        'test/fixtures/reflection_fixture.dart',
      ).readAsStringSync();

      expect(
        guide.contains(opening),
        isTrue,
        reason: 'no GreetingService pair in doc/endpoints.md',
      );

      // The guide's pair runs from the declaration to the fence that closes the
      // block; the fixture's is the same many lines from the same opening.
      final fromGuide = code(
        guide.substring(guide.indexOf(opening)),
      ).takeWhile((line) => line != '```').toList();
      final fromFixture = code(
        fixture.substring(fixture.indexOf(opening)),
      ).take(fromGuide.length).toList();

      expect(fromGuide.last, closing, reason: 'the snippet ends at a class');
      expect(
        fromFixture,
        fromGuide,
        reason:
            'doc/endpoints.md and test/fixtures/reflection_fixture.dart have '
            'drifted apart. The guide tells a reader the pair it shows is the '
            'one the suite mounts and serves; keep them identical, or stop '
            'claiming it.',
      );
    });
  });

  group('the readme Quick start', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      // Step 2 of the readme: register the implementation as its own bean. The
      // router would fall back to default-constructing it, but the readme shows
      // the explicit registration because that is the step an application with a
      // real constructor cannot skip.
      TomBean.withType(TodoApiServer, TodoApiServer());
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test('mounts the route the snippet declares', () {
      // The annotation says `GET /todos`; the routing table is the record of
      // what the scan actually made of it.
      expect(
        TomEndpointRouting.routingInfo.containsKey((
          uri: '/todos',
          method: 'GET',
        )),
        isTrue,
      );
    });

    test('serves the body the snippet returns', () async {
      final response = await router.call(_get('/todos'));
      expect(response.statusCode, 200);
      expect(jsonDecode(await response.readAsString()), [
        'buy milk',
        'write readme',
      ]);
    });

    test('resolves the @tomComponent as the @tomService instance', () {
      // The two halves are separate types on purpose: `findServiceInstance`
      // matches by supertype, so a single self-referential class resolves to
      // nothing and the route mounts against no instance. This is the assertion
      // that fails if the readme is ever collapsed back into one class.
      expect(
        _routeInfo('/todos').handler.instance.reflectee,
        isA<TodoApiServer>(),
      );
    });

    test('stays anonymous when the deployment protects by default', () async {
      // The snippet declares `@TomPublicAccess()`, and under the suite's
      // permissive default an endpoint that declared nothing would serve
      // anonymously too — so the annotation looks decorative. It is not: a
      // deployment that turns automatic protection on is exactly the case it
      // exists for, and without it the readme's first route would answer 403 the
      // moment the reader hardened their server.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(
        () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
      );
      final response = await router.call(_get('/todos'));
      expect(response.statusCode, 200);
    });
  });

  // The socket example carried by `doc/endpoints.md` and by
  // `web_socket_endpoint.dart`'s library dartdoc. Both annotated it
  // `@TomAccessControl`, which is abstract — the type the scan matches
  // (`tag is TomAccessControl`), never a thing you can write.
  //
  // What makes that worth a test rather than a correction is where the error
  // hides. `instantiate_abstract_class` is reported for a `const` variable and
  // for an expression, but **not** for metadata: `@TomAccessControl()` analyzes
  // clean. So the reader's compiler agrees with the document, and the endpoint
  // is wrong anyway. The security annotation is the one part of a declaration
  // nobody should be guessing at, so the corrected snippet is compiled as
  // [FixtureApiService.ticker] and its behaviour asserted here.
  group('the documented resource-key socket endpoint', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    /// Runs [body] as a principal holding exactly [keys].
    T asHolderOf<T>(List<String> keys, T Function() body) => runZoned(
      body,
      zoneValues: {
        TomPrincipal: TomPrincipal(
          user: TomUser(id: 1, username: 'keyholder'),
          authenticated: true,
          aci: TomAccessControlInformation(resourceKeys: keys),
        ),
      },
    );

    test('the scan resolves the concrete control the document names', () {
      // Not merely "some access rule was recorded": the document tells a reader
      // which class to write and with which argument, and this is that claim.
      final access = _routeInfo('/fixture/ticker').handler.metadata.access;
      expect(access, isA<TomResourceKeyAccess>());
      expect((access as TomResourceKeyAccess).key, 'ticker');
    });

    test('grants everyone while resource-key protection is off', () {
      // The second operand this control has and its siblings do not: until the
      // global switch is on, resource keys are not enforced at all. Worth
      // pinning, because it is why a reader can paste the snippet and see it
      // work, and then have it stop working when the deployment hardens.
      expect(_routeInfo('/fixture/ticker').handler.checkAccess(null), isTrue);
    });

    group('once resource-key protection is on', () {
      setUp(() {
        TomResourceKeyProtection.globalSettingProtectionDefault = true;
        addTearDown(
          () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
        );
      });

      test('a principal holding the key is granted', () {
        expect(
          _routeInfo('/fixture/ticker').handler.checkAccess(
            TomPrincipal(
              user: TomUser(id: 1, username: 'keyholder'),
              authenticated: true,
              aci: TomAccessControlInformation(resourceKeys: ['ticker']),
            ),
          ),
          isTrue,
        );
      });

      test('a principal without the key is denied', () {
        // The half that makes the annotation load-bearing rather than
        // decorative. If this passed, `@TomResourceKeyAccess('ticker')` would
        // be gating nothing and the document would be recommending a no-op.
        expect(
          _routeInfo('/fixture/ticker').handler.checkAccess(
            TomPrincipal(
              user: TomUser(id: 1, username: 'nobody'),
              authenticated: true,
              aci: TomAccessControlInformation(resourceKeys: ['other']),
            ),
          ),
          isFalse,
        );
      });

      test('the handshake is refused before the upgrade', () async {
        // The document's actual claim about sockets: a socket endpoint is
        // authorized by exactly the code that authorizes every other endpoint.
        // `handleWebSocketCall` awaits `enforceAccess()` before it builds the
        // connection, so a denied caller never reaches the upgrade.
        //
        // The *status* cannot say which of the two happened, and that is the
        // point of it: a denial answers 404, and so does an accepted request
        // that turns out not to be a WebSocket handshake. A socket that
        // answered anything else would be the disclosure oracle the request
        // path closes, reachable by upgrading instead of asking.
        //
        // So the discriminator is the audit trail, which is the stronger one
        // and was always available: a denial records `TomAuditOutcome.denied`,
        // and a request that got past the check records nothing. Skip
        // `enforceAccess` on the socket path and this fails on an empty trail
        // while the status stays 404.
        final sink = TomMemoryAuditSink();
        TomAuditTrail.install(sink);
        addTearDown(() {
          TomAuditTrail.uninstall();
          TomAuditTrail.resetPolicyCache();
        });

        final response = await router.call(_get('/fixture/ticker'));
        expect(response.statusCode, 404);
        expect(await response.readAsString(), isNot(contains('access_denied')));
        expect(sink.records.single.outcome, TomAuditOutcome.denied);
        expect(sink.records.single.target, contains('ticker'));
      });

      test('a key-holding caller reaches the upgrade', () async {
        // The converse, and the reason the test above is about *access* rather
        // than about sockets being broken in general: the same request from a
        // principal holding the key gets past `enforceAccess` and fails only on
        // not being a WebSocket handshake.
        final response = await asHolderOf([
          'ticker',
        ], () => router.call(_get('/fixture/ticker')));
        expect(response.statusCode, 404, reason: 'not a WebSocket request');
      });
    });
  });

  group('healthcheck GET /health route', () {
    late Router router;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomHealthServer.resetHealthChecks();
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(TomBean.resetBeanContext);

    test(
      'mounts /health and returns the analyzer status as plain text',
      () async {
        final response = await router.call(_get('/health'));
        // An unauthenticated probe reaches the route: no principal is
        // established anywhere in this call.
        //
        // Note what this does *not* pin. Under the suite's permissive default
        // an endpoint declaring no access control at all serves anonymously
        // too, so deleting `@TomPublicAccess` leaves this 200 exactly where it
        // is. That the annotation is load-bearing is pinned by 'stays
        // anonymous when the deployment protects by default', below.
        expect(
          response.statusCode,
          200,
          reason: 'an unauthenticated probe reaches /health',
        );
        expect(await response.readAsString(), 'OK');

        // The caption's second clause, which until now was only a caption. The
        // pipeline sets Content-Type from `TomEndpoint.produces`, whose default
        // is `TomMimeType.json` — so deleting the endpoint's
        // `produces: TomMimeType.plainText` does not remove the header, it
        // silently turns the body into an `application/json` one.
        //
        // Which is the reason this needs asserting at all rather than being
        // left to the reader of the annotation: a probe matching the body for
        // `OK` still finds those two characters inside a JSON-wrapped payload,
        // so the regression reaches production intact and shows up only in
        // whatever downstream parses the response strictly.
        //
        // Matched with `startsWith` because the charset parameter is the
        // header serializer's business, not this endpoint's contract.
        expect(
          response.headers[TomHeader.contentType],
          startsWith('text/plain'),
          reason: 'produces: TomMimeType.plainText, not the JSON default',
        );
      },
    );

    test('stays anonymous when the deployment protects by default', () async {
      // What makes `@TomPublicAccess` load-bearing rather than decorative, and
      // the only condition under which it can be observed at all: with the
      // suite's permissive default, `checkAccess` falls back to
      // `!globalSettingProtectionDefault` for an endpoint that declares
      // nothing — which is `true`, the same answer the annotation gives. So
      // every assertion made against the open default passes with the
      // annotation deleted.
      //
      // Flipping the default is what separates the two: an endpoint declaring
      // nothing is then refused, and only a declared public policy still
      // serves. Which is precisely the deployment this endpoint has to survive
      // — a hardened server still owes its orchestrator a liveness probe, and
      // a probe cannot hold a token or be issued one, so a /health that
      // answered 403 under hardening would take the pod down with it.
      //
      // Deliberately shares its name with the test of the same property on the
      // `/todos` route, in the 'the readme Quick start' group above: same
      // property, same reason, same shape.
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(
        () => TomResourceKeyProtection.globalSettingProtectionDefault = false,
      );
      final response = await router.call(_get('/health'));
      expect(
        response.statusCode,
        200,
        reason:
            '@TomPublicAccess: /health survives a protect-by-default server',
      );
      expect(await response.readAsString(), 'OK');
    });

    test('a probe of /health is not written to the request log', () async {
      // The third documented-as-deliberate choice, and the one whose regression
      // is least visible: `logRequests: false` exists so orchestrator probes —
      // which arrive every few seconds, forever — do not fill the log. Flipping
      // it to true breaks nothing a test would notice and nothing a user would
      // report; it just quietly costs a line per probe until someone reads a
      // log days later and finds nothing else in it.
      final previousOutput = tomLog.logOutput;
      final captured = _CapturingLogOutput();
      tomLog.logOutput = captured;
      addTearDown(() => tomLog.logOutput = previousOutput);

      // Deliberately hostile: with the global default at `true`, silence can
      // only come from the endpoint's own annotation. Left at whatever the
      // default happens to be, this test would keep passing after the
      // annotation was deleted.
      final priorDefault = TomEndpointHandler.globalSettingLogRequestsDefault;
      TomEndpointHandler.globalSettingLogRequestsDefault = true;
      addTearDown(
        () => TomEndpointHandler.globalSettingLogRequestsDefault = priorDefault,
      );

      // The pipeline's own success line. Matched on rather than on the path
      // alone because trace output and the logging middleware's fallback line
      // both name the path too; `[Normal processing]` appears in one place.
      bool loggedLineFor(String path) => captured.lines.any(
        (l) => l.contains('[Normal processing]') && l.contains(path),
      );

      expect((await router.call(_get('/health'))).statusCode, 200);
      expect(loggedLineFor('/health'), isFalse);

      // The other half, and what stops this being a test of a broken harness:
      // an assertion that *nothing* was logged passes just as happily when the
      // capture is not wired up, the router is misbuilt, or the pipeline logs
      // nowhere at all. `/fixture/health` carries `logRequests: true`, so a
      // line for it proves the observation works and isolates the difference
      // to the annotation.
      expect((await router.call(_get('/fixture/health'))).statusCode, 200);
      expect(
        loggedLineFor('/fixture/health'),
        isTrue,
        reason: 'the capture observes logging when an endpoint asks for it',
      );
    });

    test('/ready is mounted beside it, and answers independently', () async {
      // Two routes because the two questions have opposite consequences: a
      // failing readiness probe takes the pod out of the load balancer, a
      // failing liveness probe restarts it. "The container started but its
      // database is unreachable" is ready-false with live-true, and one route
      // could only pick one of those.
      //
      // Asserted through the *mounted* routes: a second `@TomEndpoint` on the
      // same service is exactly the declaration a reflection build can fail to
      // pick up, and nothing else would notice.
      TomHealthServer.installReadinessAnalyzer(_DegradedAnalyzer());
      addTearDown(TomHealthServer.resetHealthChecks);

      final ready = await router.call(_get('/ready'));
      expect(ready.statusCode, 503);
      expect(await ready.readAsString(), 'DEGRADED');

      final live = await router.call(_get('/health'));
      expect(
        live.statusCode,
        200,
        reason: 'an unready process is still alive, and must not be restarted',
      );
      expect(await live.readAsString(), 'OK');
    });

    test('an unhealthy analyzer answers 503 through the mounted route', () async {
      TomHealthServer.installLivenessAnalyzer(_DegradedAnalyzer());
      addTearDown(TomHealthServer.resetHealthChecks);
      // The route binds the same singleton server, whose health() delegates to
      // the now-unhealthy analyzer.
      final response = await router.call(_get('/health'));

      // The status code, first, because it is the thing that was wrong. A load
      // balancer's default check and a Kubernetes `httpGet` probe both read the
      // code and nothing else, so a deployment whose analyzer correctly
      // reported a dead database went on receiving traffic. Asserted through
      // the *mounted route* rather than against `health()` directly, because
      // the pipeline is what turns a handler's return value into a response and
      // a `Response` it did not pass through untouched would land back at 200.
      expect(
        response.statusCode,
        503,
        reason: 'the verdict reaches the status code a probe reads',
      );

      // And the message is still the body, verbatim: a probe that wants the
      // reason reads it where it has always been.
      expect(await response.readAsString(), 'DEGRADED');
      expect(
        response.headers[TomHeader.contentType],
        startsWith('text/plain'),
        reason: 'a returned Response bypasses produces, so it sets its own',
      );
    });

    test('a throwing analyzer keeps the plain-text shape, not the error '
        'envelope', () async {
      // The claim this pins is about the response *shape*, and only the mounted
      // route can make it: an exception leaving the handler is caught by the
      // pipeline's error handling, which answers a 500 with its own envelope.
      // That is a different content type and a different body from the one
      // every probe was configured to read, and on liveness a 500 is a restart
      // — so a datasource that is merely down would kill the pod and hand the
      // operator a response its probe cannot parse.
      TomHealthServer.installLivenessAnalyzer(_BrokenAnalyzer());
      addTearDown(TomHealthServer.resetHealthChecks);

      final response = await router.call(_get('/health'));

      expect(
        response.statusCode,
        503,
        reason: 'unhealthy, not the pipeline 500 that means "the server broke"',
      );
      expect(
        response.headers[TomHeader.contentType],
        startsWith('text/plain'),
        reason: 'the probe reads the shape it was configured for',
      );
      final body = await response.readAsString();
      expect(body, startsWith('FAILED:'));
      expect(
        body,
        contains('the pool is closed'),
        reason: 'the cause reaches the operator on the wire',
      );
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

    test('checkAutomaticAccess grants nothing while resource keys are off', () {
      // With resource keys not enforced `isProtected` answers "held" for
      // every key there is. Granting from that would overturn every refusal
      // the ordinary check made — the endpoint switch is on by default, so
      // every role-gated endpoint would open — and asking about `-<member>`
      // would read as every endpoint revoked. The prior decision stands,
      // both ways round.
      expect(TomResourceKeyProtection.globalSettingProtectionDefault, isFalse);
      expect(unguardedHandler.checkAutomaticAccess(false), isFalse);
      expect(unguardedHandler.checkAutomaticAccess(true), isTrue);
    });

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
  // after the ordinary check has already refused, only while
  // `globalSettingUseAutomaticEndpointProtection` is on, and it grants only
  // while resource keys are enforced. All three keep the rule out of ordinary
  // traffic, which is why it is pinned here directly.
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

    test('a "*" grant holds every API but no revocation', () {
      // `*` holds every key except one beginning with `-`. A principal granted
      // everything is not thereby issued every revocation — which would refuse
      // it every member of every container it holds.
      expect(accessHolding(contractGatedHandler, ['*']), isTrue);
      expect(accessHolding(unguardedHandler, ['*']), isTrue);
      expect(
        accessHolding(contractGatedHandler, [
          '*',
          '-fixture_access.contractGated',
        ]),
        isFalse,
        reason: 'a revocation issued by name still carves the endpoint out',
      );
    });

    test('an "<api>.*" grant holds every member of the API', () {
      expect(accessHolding(contractGatedHandler, ['fixture_access.*']), isTrue);
      expect(accessHolding(overriddenHandler, ['fixture_access.*']), isTrue);
      expect(
        accessHolding(inlineHandler, ['fixture_access.*']),
        isFalse,
        reason: 'it is not part of the API contract',
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

  // The group above establishes *which* keys protect an endpoint, by calling
  // `checkAutomaticAccess` directly. What a direct call cannot show is that a
  // request reaches it. `enforceAccess` reaches the rule down two conditions —
  // the ordinary check must have refused, and
  // `globalSettingUseAutomaticEndpointProtection` must be on — and the question
  // an operator actually asks is "I minted a key for this API; does it open the
  // endpoint?". These tests ask it through `enforceAccess`, which is the unit
  // that owns both conditions and the denial that follows them.
  group('automatic protection through enforceAccess', () {
    late TomEndpointHandler contractGatedHandler;
    late TomEndpointHandler overriddenHandler;

    setUp(() {
      TomResourceKeyProtection.globalSettingProtectionDefault = true;
      addTearDown(TomResourceKeyProtection.restoreDefaults);
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
      contractGatedHandler = _routeInfo(
        '/fixture-access/contract-gated',
      ).handler;
      overriddenHandler = _routeInfo('/fixture-access/overridden').handler;
    });

    tearDown(TomBean.resetBeanContext);

    /// Runs [handler]'s full access enforcement as a principal holding exactly
    /// [keys] and [roles] — the call the pipeline makes before it materialises
    /// a single argument.
    ///
    /// Both fixture endpoints are gated by a role the principal is given only
    /// when a test says so, so the default is a principal the ordinary check
    /// refuses. That refusal is the precondition of everything here: it is what
    /// makes the second chance reachable at all.
    Future<void> enforceAs(
      TomEndpointHandler handler, {
      List<String> keys = const [],
      List<String> roles = const [],
    }) => runZoned(
      handler.enforceAccess,
      zoneValues: {
        TomPrincipal: TomPrincipal(
          user: TomUser(id: 1, username: 'keyholder'),
          authenticated: true,
          aci: TomAccessControlInformation(resourceKeys: keys, roles: roles),
        ),
      },
    );

    test('a resource key opens nothing while the gate is off', () async {
      // The half that makes the gate a gate. The principal holds exactly the
      // key the rule would honour, and the endpoint stays shut because nothing
      // asks. Without this the next test would pass just as well against an
      // `enforceAccess` that consulted the rule unconditionally.
      TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection =
          false;
      await expectLater(
        enforceAs(contractGatedHandler, keys: ['fixture_access']),
        throwsA(isA<TomEndpointHandlerException>()),
      );
    });

    test('the gate opens nothing while resource keys are not enforced', () {
      // The gate is on by default, so this is the configuration of every
      // deployment that has not switched resource keys on. With no grants in
      // force every key reads as held; granting from that would open every
      // role-gated endpoint to anyone, which is what this pins shut.
      TomResourceKeyProtection.restoreDefaults();
      expect(
        TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection,
        isTrue,
      );
      expect(TomResourceKeyProtection.globalSettingProtectionDefault, isFalse);
      return expectLater(
        enforceAs(contractGatedHandler),
        throwsA(isA<TomEndpointHandlerException>()),
      );
    });

    test('the gate admits the API-id key as a second chance', () async {
      TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection =
          true;
      // Same principal, same key, one switch different: the contract identity
      // now opens the endpoint its contract declares, through the production
      // call site rather than by calling the rule directly.
      await expectLater(
        enforceAs(contractGatedHandler, keys: ['fixture_access']),
        completes,
      );
    });

    test('the implementation class name opens nothing through the gate', () {
      TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection =
          true;
      // The security half, end to end: renaming the class must not be a change
      // to the authorization surface, so its name must not be a key.
      expect(
        enforceAs(contractGatedHandler, keys: ['FixtureAccessApiService']),
        throwsA(isA<TomEndpointHandlerException>()),
      );
    });

    test('a -<member> exception shuts one endpoint and spares its sibling', () {
      TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection =
          true;
      const keys = ['fixture_access', '-fixture_access.contractGated'];
      expect(
        enforceAs(contractGatedHandler, keys: keys),
        throwsA(isA<TomEndpointHandlerException>()),
        reason: 'the named endpoint is carved out of the API-wide grant',
      );
      expect(
        enforceAs(overriddenHandler, keys: keys),
        completes,
        reason: 'an exception names one member, not the container',
      );
    });

    test('the second chance cannot lower a grant the role already made', () {
      TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection =
          true;
      // `enforceAccess` consults the rule only after a refusal, so a principal
      // the contract role already admits never reaches it — which is why the
      // carve-out this principal is also subject to changes nothing.
      //
      // The key set is chosen so that the rule, *if* it ran, would refuse:
      // holding the container with the member revoked is exactly the shape that
      // returns false. So a second chance wired to run unconditionally would
      // turn this legitimate role-granted request into a denial, and the test
      // fails. With a weaker key set the rule would fall through to the
      // decision it was given and the mutation would survive.
      expect(
        enforceAs(
          contractGatedHandler,
          keys: ['fixture_access', '-fixture_access.contractGated'],
          roles: ['fixture-contract-role'],
        ),
        completes,
      );
    });

    test('a denial that survives the second chance is audited', () async {
      TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection =
          true;
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      addTearDown(TomAuditTrail.uninstall);

      await expectLater(
        enforceAs(contractGatedHandler, keys: ['some-other-api']),
        throwsA(isA<TomEndpointHandlerException>()),
      );

      // `contractGated` carries no `@TomAudited`, so this entry exists purely
      // because a denial is recorded whether or not the endpoint opted in — the
      // one auditable event the repository chokepoint cannot see, since the
      // request is refused before it reaches any data.
      final record = sink.records.single;
      expect(record.outcome, TomAuditOutcome.denied);
      expect(record.action, TomAuditAction.execute);
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
        // The other direction, and the one that shows the setting is a
        // *setting*. Resolve the annotation with `raw == true` and both
        // directions produce the same output, because the raw annotation is
        // null in both and `null == true` is false either way.
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
      // Reached with a plain GET — no `Upgrade` header — which
      // `shelf_web_socket` refuses with a 404. That is the *refused* outcome,
      // and it is the only one reachable without a socket: an accepted
      // handshake hijacks the connection, and `hijack` throws
      // `HijackException`, so it leaves `handleWebSocketCall` by a different
      // route entirely. Its own line is asserted over a loopback server in
      // `endpoints_transport_test.dart`, which is the only place a real upgrade
      // can be made.
      Future<bool> socketLogged(bool globalDefault) async {
        TomEndpointHandler.globalSettingLogRequestsDefault = globalDefault;
        captured.lines.clear();
        final response = await router.call(_get('/fixture/socket'));
        expect(response.statusCode, 404, reason: 'not a WebSocket request');
        return captured.lines.any(
          (l) => l.contains('[WebSocket handshake refused]'),
        );
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

      // The caller is answered `404` and told nothing. The assertion that
      // matters is on the *trail*, which must hold the entry either way — the
      // record is what an operator asking "why did this caller get a 404" has,
      // and it is the whole of what the status gives up.
      final response = await router.call(_get('/fixture/unguarded'));
      expect(response.statusCode, 404);

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

    test(
      'an endpoint declaring @TomAudited(enabled: false) is not recorded',
      () async {
        // The flag is the annotation's own off switch; reading the annotation's
        // presence as the decision would audit exactly what it declines.
        final response = await router.call(_get('/fixture/audit_disabled'));
        expect(response.statusCode, 200);
        expect(sink.records, isEmpty);
      },
    );

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
      // rather than the bare TypeError an unguarded cast would surface.
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
  // The two `null`s `coercePrimitiveParameter` can answer are different
  // answers, and the loop used to read both as "this strategy does not apply".
  // So `?ratio=xyz` on a `num` parameter was not a client error: the parameter
  // fell through every remaining strategy and ended unbound, and the caller was
  // told `unbindable_parameter` — a message naming neither the value nor the
  // fact that it was nearly right. `isBindablePrimitive` is asked first now, so
  // past it a `null` means one thing.
  group('a URL value that will not parse is refused, not skipped', () {
    late TomEndpointHandler typed;

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      TomEndpointRouting().initializeRouter();
      typed = _routeInfo('/fixture/typed/{id}').handler;
    });

    tearDown(TomBean.resetBeanContext);

    /// A GET of `/fixture/typed/<id>?ratio=<ratio>&active=<active>` with `id`
    /// as the route capture a matched route would have supplied.
    Request typedRequest(String id, String ratio, [String active = 'true']) =>
        Request(
          'GET',
          Uri.parse(
            'http://localhost/fixture/typed/$id?ratio=$ratio&active=$active',
          ),
          context: {
            TomRequestLogInfo.contextName: TomRequestLogInfo(),
            'shelf_router/params': {'id': id},
          },
        );

    /// The refusal for a URL value, with [value] in its message.
    ///
    /// Read off `defaultUserMessage` rather than `toString()`: the parameters
    /// map carries the value too, so a message that named neither would still
    /// satisfy a `toString()` match — the assertion would pass on a message
    /// that says nothing, which is the thing being pinned.
    Matcher refusedValue(String value, String parameter) => throwsA(
      isA<TomEndpointHandlerException>()
          .having(
            (e) => e.key,
            'key',
            'endpoint_pipeline.bind_parameters.unparsable_url_value',
          )
          .having(
            (e) => e.defaultUserMessage,
            'message',
            allOf(contains(value), contains(parameter)),
          )
          .having(
            (e) => e.parameters,
            'parameters',
            allOf(
              containsPair('value', value),
              containsPair('parameter', parameter),
            ),
          ),
    );

    test('a well-formed request still binds all three values', () async {
      // The control. Everything below asserts a throw, so without this the
      // group would be satisfied by a loop that refused every URL value.
      final bound = await typed.bindParameters(typedRequest('7', '1.5'));
      expect(bound, [7, 1.5, true]);
    });

    test('every accepted bool spelling binds through the loop', () async {
      // The unit tests pin the spellings; this pins that the loop reaches them.
      // A bool is the one primitive whose coercion can be written as a total
      // function — `raw == 'true'` answers for every input — and a total
      // coercion gives the refusing branch no null to act on.
      for (final raw in const ['true', 'TRUE', '1', 'yes', 'on']) {
        expect(
          await typed.bindParameters(typedRequest('7', '1.5', raw)),
          [7, 1.5, true],
          reason: '"$raw" is a spelling of true',
        );
      }
      for (final raw in const ['false', 'FALSE', '0', 'no', 'off']) {
        expect(
          await typed.bindParameters(typedRequest('7', '1.5', raw)),
          [7, 1.5, false],
          reason: '"$raw" is a spelling of false',
        );
      }
    });

    test('a bool spelling the set does not contain is refused', () {
      // The invisible failure, made visible: under a total coercion
      // `?active=maybe` binds as `false` and the caller is told nothing, so the
      // endpoint acts on the opposite of what was written.
      expect(
        () => typed.bindParameters(typedRequest('7', '1.5', 'maybe')),
        refusedValue('maybe', 'active'),
      );
    });

    test('a path variable that is not an int is refused by name', () {
      expect(
        () => typed.bindParameters(typedRequest('abc', '1.5')),
        refusedValue('abc', 'id'),
      );
    });

    test('a query value that is not a num is refused by name', () {
      expect(
        () => typed.bindParameters(typedRequest('7', 'xyz')),
        refusedValue('xyz', 'ratio'),
      );
    });

    test('the refusal names the type and the source', () async {
      // Both are the diagnosis: the type says what would have been accepted,
      // and the source says where to look for it — a path segment and a query
      // parameter are edited in different places.
      Object? caught;
      try {
        await typed.bindParameters(typedRequest('abc', '1.5'));
      } catch (error) {
        caught = error;
      }
      expect(caught, isA<TomEndpointHandlerException>());
      final message =
          (caught as TomEndpointHandlerException).defaultUserMessage;
      expect(message, contains('int'));
      expect(message, contains('path variable'));

      Object? fromQuery;
      try {
        await typed.bindParameters(typedRequest('7', 'xyz'));
      } catch (error) {
        fromQuery = error;
      }
      final queryMessage =
          (fromQuery as TomEndpointHandlerException).defaultUserMessage;
      expect(queryMessage, contains('query parameter'));
      expect(queryMessage, contains('num'));
    });

    test('the refusal reaches the client rather than being masked', () async {
      // `TomServerException.clientThrow` defaults to true and this raise site
      // keeps it: the message names the caller's own value, which is the one
      // thing they can act on, and masking it would leave them with a key and
      // no idea which parameter was wrong.
      Object? caught;
      try {
        await typed.bindParameters(typedRequest('abc', '1.5'));
      } catch (error) {
        caught = error;
      }
      expect((caught as TomServerException).clientThrow, isTrue);
    });

    test('it is not the fall-through failure any more', () async {
      // The defect this closes, pinned by its own key: falling through ended
      // with `unbindable_parameter`, which says only that nothing could supply
      // the parameter.
      Object? caught;
      try {
        await typed.bindParameters(typedRequest('abc', '1.5'));
      } catch (error) {
        caught = error;
      }
      expect(
        (caught as TomEndpointHandlerException).key,
        isNot('endpoint_pipeline.bind_parameters.unbindable_parameter'),
      );
    });

    test('a non-primitive parameter still falls through', () {
      // The other half of the pair, and the reason the predicate exists: a
      // `FixtureParseRequest` parameter is not a primitive, so a path capture
      // or query value of the same name must not refuse the request — the DTO
      // strategy below is the one that binds it.
      final parse = _routeInfo('/fixture/parse', 'POST').handler;
      expect(
        parse.bindParameters(
          Request(
            'POST',
            Uri.parse('http://localhost/fixture/parse?first=abc'),
            body: '{"label":"x","when":"2026-08-25T00:00:00Z"}',
            context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
          ),
        ),
        completes,
      );
    });
  });

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
      FixtureApiServer.transactionalParticipant = null;
      FixtureApiServer.transactionalArrivals.clear();
      TomBean.resetBeanContext();
    });

    test(
      'a vetoed commit fails the request, whatever the method returned',
      () async {
        // The method completes; its transaction then does not commit. Answering
        // 200 with the method's result would report work that was rolled back.
        final vetoing = _VetoingParticipant();
        FixtureApiServer.transactionalParticipant = vetoing;

        final response = await router.call(_get('/fixture/transactional'));

        expect(response.statusCode, isNot(200));
        expect(
          vetoing.calls,
          ['start', 'prepare', 'rollback', 'end'],
          reason: 'rolled back once by the coordinator, never a second time',
        );
      },
    );

    test('a committed participant leaves the request at 200', () async {
      final committing = _VetoingParticipant(veto: false);
      FixtureApiServer.transactionalParticipant = committing;

      final response = await router.call(_get('/fixture/transactional'));

      expect(response.statusCode, 200);
      expect(committing.calls, ['start', 'prepare', 'commit', 'end']);
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

/// A [TomHealthAnalyzer] returning an unhealthy verdict, to prove the route
/// reflects the configured analyzer rather than a hardcoded string — and that
/// the verdict reaches the status code.
class _DegradedAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() async =>
      const TomHealthStatus.unhealthy('DEGRADED');
}

/// A [TomHealthAnalyzer] that throws — the datasource that is down rather than
/// slow, which is the likelier way a real analyzer fails.
class _BrokenAnalyzer extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() async =>
      throw StateError('the pool is closed');
}

/// A participant that records its lifecycle and, unless told otherwise, vetoes
/// at prepare.
class _VetoingParticipant implements TomTransactionParticipant {
  _VetoingParticipant({this.veto = true});

  final bool veto;
  final List<String> calls = [];

  @override
  String getParticipantId() => 'vetoing-participant';

  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    calls.add('start');
    return true;
  }

  @override
  Future<bool> prepare() async {
    calls.add('prepare');
    return !veto;
  }

  @override
  Future<bool> commit() async {
    calls.add('commit');
    return true;
  }

  @override
  Future<bool> rollback() async {
    calls.add('rollback');
    return true;
  }

  @override
  Future<bool> endTransaction() async {
    calls.add('end');
    return true;
  }
}
