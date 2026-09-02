import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureAccessApiService,
        FixtureApiServer,
        FixtureEchoHookDto,
        FixtureEchoInterfaceDto,
        FixtureEchoMethodDto,
        FixtureEchoObservableDto,
        FixtureEchoPlainDto,
        registerFixtureAccessApi;
import 'fixtures/reflection_fixture.reflection.dart';

/// The endpoint pipeline and the HTTP client serialize through the same two
/// central points.
///
/// They did not. The pipeline ran a five-way chain of its own on the way out
/// (`String`, `TomClass`, `TomJsonSerializable`, `Map`, `List`, then
/// reflection) and decoded with `jsonDecode` + `createInstanceFromJson`; the
/// kernel's client called `convertToJsonString` / `convertFromJsonString`. Two
/// transports restating one policy is two policies, and they had already
/// drifted: a type could round-trip on one side and fail on the other.
///
/// A round trip is what settles it, because a hook that is honoured on three
/// legs and skipped on the fourth is invisible to anything smaller. Each DTO
/// here **renames its field on the wire**, so a skipped hook does not produce
/// a differently-spelled payload — it produces a *lost value*, on whichever
/// leg dropped it:
///
/// | leg | who serializes | entry point |
/// | --- | --- | --- |
/// | client → wire | `TomServerEndpoint.send` | `convertToJsonString` |
/// | wire → handler | the endpoint pipeline | `createInstanceFromJson` |
/// | handler → wire | the endpoint pipeline | `convertToJsonString` |
/// | wire → client | `TomServerEndpoint.send` | `convertFromJsonString` |
///
/// The handler is an identity — it hands the decoded object straight back — so
/// serialization is the only thing between what was sent and what returns.
void main() {
  // The fixture API contract has to be registered alongside the reflection
  // bootstrap: FixtureAccessApiService is a @TomApiImplementation, so the
  // router's scan finds it and resolving its endpoints throws for an
  // unregistered API rather than skipping it — every route in the table would
  // fail to mount, not just its own.
  setUpAll(() {
    initializeReflection();
    registerFixtureAccessApi();
    // The client half of the round trip needs a real HTTP client, and the
    // platform is what supplies one — a test isolate starts on the throwing
    // fallback, so `TomServerChannel.getClient` raises `UnimplementedError`
    // before a request is ever built. A server process installs this in
    // `main`; a test file is its own process and has to do the same.
    TomPlatformUtils.setCurrentPlatform(TomStandalonePlatformUtils());
  });

  group('a DTO crosses both directions identically', () {
    late HttpServer server;
    late Router router;

    setUp(() async {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      router = TomEndpointRouting().initializeRouter();
      final handler = const Pipeline()
          .addMiddleware(
            contextSetupMiddleware("test context", {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addMiddleware(tomDefaultAuthenticationMiddleware("test auth"))
          .addHandler(router.call);
      server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close(force: true);
      TomBean.resetBeanContext();
    });

    /// A client endpoint aimed at [path] on the loopback server.
    ///
    /// This is the kernel's own client, not a hand-rolled request: the point of
    /// the test is which code the *shipped* client runs, so substituting a
    /// simpler sender would assert something no caller does.
    TomServerEndpoint<T, R> endpoint<T extends Object, R extends Object>(
      String path,
    ) => TomServerEndpoint<T, R>(
      TomServerChannel('localhost', server.port),
      TomServerCallSpecs(
        'POST',
        Uri.parse('http://localhost:${server.port}$path'),
      ),
    );

    /// Posts [body] to [path] and returns the response body verbatim.
    ///
    /// For the two endpoints whose result is a JSON *container*: a list and a
    /// map are not reflected types, so `TomServerEndpoint` cannot name one as
    /// its `R` — the wire text is the assertion, and it is the one that
    /// matters here anyway.
    Future<String> postRaw(String path, String body) async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        Uri.parse('http://localhost:${server.port}$path'),
      );
      request.headers.set('content-type', 'application/json');
      request.write(body);
      final response = await request.close();
      return response.transform(utf8.decoder).join();
    }

    test('the TomClass shape survives all four legs', () async {
      final sent = FixtureEchoObservableDto();
      sent.value | 'observable';

      final (
        received,
        error,
      ) = await endpoint<FixtureEchoObservableDto, FixtureEchoObservableDto>(
        '/fixture/echo_observable',
      ).send(sent);

      expect(error?.hasError, isFalse);
      // A TomString is not something the reflected field walk can write or
      // `jsonEncode` can render, so a value that arrives at all proves the
      // TomClass branch was taken — on the way out and on the way back.
      expect(received.value.get(), 'observable');
    });

    test('the TomJsonSerializable shape survives all four legs', () async {
      final (
        received,
        error,
      ) = await endpoint<FixtureEchoInterfaceDto, FixtureEchoInterfaceDto>(
        '/fixture/echo_interface',
      ).send(FixtureEchoInterfaceDto()..value = 'interface');

      expect(error?.hasError, isFalse);
      expect(received.value, 'interface');
    });

    test('the structural toJson shape survives all four legs', () async {
      final (
        received,
        error,
      ) = await endpoint<FixtureEchoMethodDto, FixtureEchoMethodDto>(
        '/fixture/echo_method',
      ).send(FixtureEchoMethodDto()..value = 'method');

      expect(error?.hasError, isFalse);
      expect(received.value, 'method');
    });

    test(
      'the jsonEncode/jsonDecode hook shape survives all four legs',
      () async {
        final (
          received,
          error,
        ) = await endpoint<FixtureEchoHookDto, FixtureEchoHookDto>(
          '/fixture/echo_hook',
        ).send(FixtureEchoHookDto()..value = 'hook');

        expect(error?.hasError, isFalse);
        expect(received.value, 'hook');
      },
    );

    test('the plain field-walk shape survives all four legs', () async {
      final (
        received,
        error,
      ) = await endpoint<FixtureEchoPlainDto, FixtureEchoPlainDto>(
        '/fixture/echo_plain',
      ).send(FixtureEchoPlainDto()..value = 'plain');

      expect(error?.hasError, isFalse);
      expect(received.value, 'plain');
    });

    test('the server renders a DTO exactly as the client would', () async {
      // The claim under test, stated directly: one object, two serializers,
      // one string. Every hook shape at once, so a divergence in any of them
      // is a failure here even if that shape's round trip happened to survive
      // it (a rename both sides got wrong the same way, say).
      final cases = <String, Object>{
        '/fixture/echo_interface': FixtureEchoInterfaceDto()..value = 'same',
        '/fixture/echo_method': FixtureEchoMethodDto()..value = 'same',
        '/fixture/echo_hook': FixtureEchoHookDto()..value = 'same',
        '/fixture/echo_plain': FixtureEchoPlainDto()..value = 'same',
      };

      for (final entry in cases.entries) {
        final clientRendering = tomReflectionInfo.convertToJsonString(
          entry.value,
        );
        final serverRendering = await postRaw(entry.key, clientRendering);
        expect(
          serverRendering,
          clientRendering,
          reason: 'the two entry points disagree at ${entry.key}',
        );
      }
    });

    test('a handler returning a list of DTOs reaches the wire', () async {
      // `getValues` refuses a List — it is not a reflected type — which is why
      // the pipeline grew a chain of its own to encode one. The outbound entry
      // point takes the containers now, so the transport does not have to.
      final body = await postRaw(
        '/fixture/echo_list',
        tomReflectionInfo.convertToJsonString(
          FixtureEchoInterfaceDto()..value = 'listed',
        ),
      );

      // Rendered by the DTO's own hook, inside the container: an element is
      // not serialized on easier terms than a top-level object would be.
      expect(body, '[{"viaInterface":"listed"},{"viaInterface":"listed"}]');
    });

    test(
      'a handler returning a map with a DTO value reaches the wire',
      () async {
        // Two defects in one line of the old chain: its type test named
        // `Map<String, Object>`, which a `Map<String, dynamic>` is not, so this
        // fell through to a converter that then refused it — and had it matched,
        // `jsonEncode` would have thrown on the DTO value.
        final body = await postRaw(
          '/fixture/echo_map',
          tomReflectionInfo.convertToJsonString(
            FixtureEchoInterfaceDto()..value = 'mapped',
          ),
        );

        expect(body, '{"wrapped":{"viaInterface":"mapped"},"count":1}');
      },
    );
  });
}
