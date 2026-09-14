import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureAccessApiService, FixtureApiServer, registerFixtureAccessApi;
import 'fixtures/reflection_fixture.reflection.dart';

/// A [TomLogOutput] that keeps every message handed to it.
///
/// Captures without consulting the level, as the pipeline suite's own does: the
/// question is whether the pipeline *decided to log*, not whether the
/// configured level would have printed it.
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

/// The three transports the endpoint annotation surface promised and the
/// pipeline did not deliver: `multipart/form-data` binding (text parts *and* a
/// file part), the redirect directive, and WebSocket endpoints.
///
/// Most of it is asserted **without a server**: the multipart decoder takes a
/// shelf `Request` and the fold helper takes a plain map, so a boundary, a body
/// and a `TomEndpoint` are the whole apparatus. Two things genuinely need a
/// socket — a real handshake cannot be faked, because `shelf_web_socket`
/// upgrades a `dart:io` socket and nothing else — and those get a loopback
/// server, deliberately at the end of the file rather than as the default way
/// to ask a question here.

// ---------------------------------------------------------------------------
// multipart body construction
// ---------------------------------------------------------------------------

const _boundary = 'tomtestboundary';

/// The routing-table entry mounted for [path] under [method].
///
/// The table is keyed by route *and* method; every route this file looks up is
/// a `GET`, including the socket one — a handshake is a GET.
TomEndpointRoutingInfo _routeInfo(String path, [String method = 'GET']) =>
    TomEndpointRouting.routingInfo[(uri: path, method: method)]!;

/// One text part of a `multipart/form-data` body.
String _textPart(String name, String value) =>
    'content-disposition: form-data; name="$name"\r\n\r\n$value';

/// One file part: a `filename` in the content-disposition is what makes it one.
String _filePart(
  String name,
  String fileName,
  String mediaType,
  String content,
) =>
    'content-disposition: form-data; name="$name"; filename="$fileName"\r\n'
    'content-type: $mediaType\r\n\r\n$content';

/// Assembles [parts] into a complete multipart body with the closing delimiter.
String _formBody(List<String> parts) =>
    '${parts.map((part) => '--$_boundary\r\n$part\r\n').join()}'
    '--$_boundary--\r\n';

/// A `POST` carrying [parts] as a `multipart/form-data` body.
Request _formRequest(List<String> parts, {String? contentType}) => Request(
  'POST',
  Uri.parse('http://localhost/fixture/upload'),
  headers: {
    'content-type': contentType ?? 'multipart/form-data; boundary=$_boundary',
  },
  body: _formBody(parts),
  context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
);

void main() {
  // One reflection bootstrap for the whole file, with the fixture API contract
  // registered alongside it: FixtureAccessApiService is a
  // @TomApiImplementation, so scanClasses finds it and getClassMethodMetadata
  // resolves its endpoints through tomRemoteApis — which throws for an
  // unregistered API rather than yielding null.
  setUpAll(() {
    initializeReflection();
    registerFixtureAccessApi();
  });

  // -------------------------------------------------------------------------
  // Decoding
  // -------------------------------------------------------------------------

  group('TomMultipartForm.readForm', () {
    test('splits text parts from file parts by the filename', () async {
      final form = await TomMultipartForm.readForm(
        _formRequest([
          _textPart('title', 'Quarterly report'),
          _filePart('attachment', 'q3.txt', 'text/plain', 'the numbers'),
        ]),
      );
      // The envelope's own distinction, not a guess from the media type: a
      // browser sends no `filename` for a text field and a (possibly empty)
      // one for a file input.
      expect(form!.fields, {'title': 'Quarterly report'});
      expect(form.files, hasLength(1));
      expect(form.files.single.field, 'attachment');
    });

    test(
      'carries the file name, media type and bytes of a file part',
      () async {
        final form = await TomMultipartForm.readForm(
          _formRequest([
            _filePart('attachment', 'q3.txt', 'text/plain', 'the numbers'),
          ]),
        );
        final file = form!.file('attachment')!;
        expect(file.fileName, 'q3.txt');
        expect(file.mediaType, 'text/plain');
        expect(utf8.decode(file.bytes), 'the numbers');
        expect(file.byteCount, 'the numbers'.length);
      },
    );

    test(
      'treats an empty filename as no file name, not as an empty one',
      () async {
        // A browser sends `filename=""` for an untouched file input. It is still
        // a file part — the header says so — but there is no name to record.
        final form = await TomMultipartForm.readForm(
          _formRequest([_filePart('attachment', '', 'text/plain', '')]),
        );
        expect(form!.files.single.fileName, isNull);
      },
    );

    test('returns null for a request that is not multipart at all', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/fixture/upload'),
        headers: {'content-type': 'application/json'},
        body: '{"title":"x"}',
      );
      // Null rather than an exception: "this is not a form" is what the
      // pipeline asks, and every JSON endpoint asks it.
      expect(await TomMultipartForm.readForm(request), isNull);
    });

    test('returns null when the content type declares no boundary', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/fixture/upload'),
        headers: {'content-type': 'multipart/form-data'},
        body: '',
      );
      expect(await TomMultipartForm.readForm(request), isNull);
    });

    test('a malformed envelope is a named client error', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/fixture/upload'),
        headers: {'content-type': 'multipart/form-data; boundary=$_boundary'},
        // No closing delimiter and no part headers at all.
        body: 'not a multipart body',
      );
      await expectLater(
        TomMultipartForm.readForm(request),
        throwsA(
          isA<TomFormBindingException>().having(
            (e) => e.key,
            'key',
            'form_binding.malformed_multipart_body',
          ),
        ),
      );
    });

    test('a repeated text field keeps the last value', () async {
      final form = await TomMultipartForm.readForm(
        _formRequest([_textPart('tag', 'first'), _textPart('tag', 'second')]),
      );
      // One field, one value — the way a query string folds into a DTO.
      expect(form!.fields['tag'], 'second');
    });

    test(
      'a repeated file field keeps every file, and file() takes the first',
      () async {
        final form = await TomMultipartForm.readForm(
          _formRequest([
            _filePart('page', 'a.txt', 'text/plain', 'A'),
            _filePart('page', 'b.txt', 'text/plain', 'B'),
          ]),
        );
        // The deliberate asymmetry with the text case: repeated file parts are
        // distinct uploads, so silently keeping the last would discard data.
        expect(form!.filesNamed('page'), hasLength(2));
        expect(form.file('page')!.fileName, 'a.txt');
      },
    );

    test(
      'a file part over the ceiling is refused while it is being read',
      () async {
        final previous = TomMultipartForm.globalSettingMaxFilePartBytes;
        TomMultipartForm.globalSettingMaxFilePartBytes = 8;
        addTearDown(
          () => TomMultipartForm.globalSettingMaxFilePartBytes = previous,
        );

        await expectLater(
          TomMultipartForm.readForm(
            _formRequest([
              _filePart('attachment', 'big.txt', 'text/plain', 'x' * 64),
            ]),
          ),
          throwsA(
            isA<TomFormBindingException>().having(
              (e) => e.key,
              'key',
              'form_binding.file_part_too_large',
            ),
          ),
        );
      },
    );

    test('an empty form is decoded, and says so', () async {
      final form = await TomMultipartForm.readForm(_formRequest([]));
      expect(form!.isEmpty, isTrue);
    });

    test('a form file opens its bytes as a stream as often as asked', () async {
      final file = TomFormFile(
        field: 'attachment',
        bytes: utf8.encode('payload'),
      );
      // The bytes are already in memory, so single-subscription semantics do
      // not apply — and the store may well read them more than once.
      expect(
        await file.openRead().expand((c) => c).toList(),
        utf8.encode('payload'),
      );
      expect(
        await file.openRead().expand((c) => c).toList(),
        utf8.encode('payload'),
      );
    });
  });

  group('tomConsumesForm', () {
    test('matches a form declaration', () {
      expect(tomConsumesForm(TomMimeType.multipartFormData), isTrue);
    });

    test('does not match JSON', () {
      expect(tomConsumesForm(TomMimeType.json), isFalse);
    });

    test('matches ignoring parameters, which a real request always carries', () {
      // A real `content-type` carries a boundary; comparing whole values would
      // therefore never match, and every form endpoint would silently decode
      // as JSON.
      expect(
        tomConsumesForm(
          const TomMimeType('multipart', 'form-data', charset: 'UTF-8'),
        ),
        isTrue,
      );
    });

    test('matches the url-encoded shape of the same HTML form', () {
      // Which of the two a browser sends is decided by whether the form has a
      // file input — not by anything the endpoint chooses — so both are forms.
      expect(tomConsumesForm(TomMimeType.urlEncoded), isTrue);
      expect(tomConsumesMultipartForm(TomMimeType.urlEncoded), isFalse);
      expect(tomConsumesMultipartForm(TomMimeType.multipartFormData), isTrue);
    });
  });

  group('TomMultipartForm.readUrlEncodedForm', () {
    Request urlEncoded(String body) => Request(
      'POST',
      Uri.parse('http://localhost/fixture/upload'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: body,
      context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
    );

    test('decodes fields and percent-escapes', () async {
      final form = await TomMultipartForm.readUrlEncodedForm(
        urlEncoded('title=Quarterly%20report&tags=q3%2Cfinal'),
      );
      expect(form.fields, {'title': 'Quarterly report', 'tags': 'q3,final'});
    });

    test('carries no files, which is what makes it the same type', () async {
      // Everything downstream of the decode is identical to the multipart case;
      // only the reading differs, so there is no second type to bind from.
      final form = await TomMultipartForm.readUrlEncodedForm(
        urlEncoded('title=x'),
      );
      expect(form.files, isEmpty);
    });

    test('an empty body is an empty form, not an error', () async {
      final form = await TomMultipartForm.readUrlEncodedForm(urlEncoded(''));
      expect(form.isEmpty, isTrue);
    });

    test('a repeated field keeps the last value', () async {
      final form = await TomMultipartForm.readUrlEncodedForm(
        urlEncoded('tag=first&tag=second'),
      );
      expect(form.fields['tag'], 'second');
    });

    test(
      'a body that does not percent-decode is a named client error',
      () async {
        await expectLater(
          TomMultipartForm.readUrlEncodedForm(urlEncoded('title=%zz')),
          throwsA(
            isA<TomFormBindingException>().having(
              (e) => e.key,
              'key',
              'form_binding.malformed_url_encoded_body',
            ),
          ),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Folding — the third sibling of injectPathParameters/injectQueryParameters
  // -------------------------------------------------------------------------

  group('TomEndpointHandler.injectFormFields', () {
    TomMultipartForm formOf(Map<String, String> fields) =>
        TomMultipartForm(fields: fields, files: const []);

    test('an empty formFields folds every text part', () {
      const endpoint = TomEndpoint(uri: '/upload');
      final json = <String, dynamic>{};
      TomEndpointHandler.injectFormFields(
        json,
        formOf({'title': 'Report', 'tags': 'q3,final'}),
        endpoint,
      );
      // A body is the endpoint's own contract, exactly as a JSON body is — and
      // a JSON body is not filtered field-by-field either.
      expect(json, {'title': 'Report', 'tags': 'q3,final'});
    });

    test('a declared formFields is an allow-list', () {
      const endpoint = TomEndpoint(uri: '/upload', formFields: ['title']);
      final json = <String, dynamic>{};
      TomEndpointHandler.injectFormFields(
        json,
        formOf({'title': 'Report', 'injected': 'nope'}),
        endpoint,
      );
      expect(json, {'title': 'Report'});
    });

    test('a declared field that did not arrive is not manufactured', () {
      const endpoint = TomEndpoint(
        uri: '/upload',
        formFields: ['title', 'tags'],
      );
      final json = <String, dynamic>{};
      TomEndpointHandler.injectFormFields(
        json,
        formOf({'title': 'Report'}),
        endpoint,
      );
      // A null field the DTO would then have to tolerate is worse than an
      // absent one — the same rule injectPathParameters follows.
      expect(json, {'title': 'Report'});
    });

    test('a URL parameter still wins over a form field of the same name', () {
      const endpoint = TomEndpoint(uri: '/documents/{id}');
      final json = <String, dynamic>{};
      TomEndpointHandler.injectFormFields(
        json,
        formOf({'id': 'from-form'}),
        endpoint,
      );
      TomEndpointHandler.injectPathParameters(
        json,
        Request(
          'POST',
          Uri.parse('http://localhost/documents/42'),
          context: {
            'shelf_router/params': {'id': '42'},
          },
        ),
        endpoint,
      );
      // The route is the addressed resource; a form field cannot redirect the
      // call to a different row. Pinning the *order* the pipeline folds in.
      expect(json['id'], '42');
    });
  });

  // -------------------------------------------------------------------------
  // The redirect directive
  // -------------------------------------------------------------------------

  group('TomRedirect', () {
    test('defaults to 303 See Other', () {
      expect(TomRedirect('/items/42').status, 303);
    });

    test('names the three redirects that differ observably', () {
      expect(TomRedirect.seeOther('/a').status, 303);
      expect(TomRedirect.temporary('/a').status, 307);
      expect(TomRedirect.permanent('/a').status, 308);
    });

    test('builds a bodiless response carrying the Location header', () async {
      final response = TomRedirect.seeOther('/items/42').toResponse();
      expect(response.statusCode, 303);
      expect(response.headers[TomHeader.location.toLowerCase()], '/items/42');
      expect(await response.readAsString(), isEmpty);
    });

    test('rejects an empty location', () {
      expect(() => TomRedirect(''), throwsA(isA<AssertionError>()));
    });

    test('rejects a status outside the 3xx range', () {
      expect(
        () => TomRedirect('/a', status: 200),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // The WebSocket annotation and connection, without a socket
  // -------------------------------------------------------------------------

  group('TomWebSocketEndpoint', () {
    test('converts to a GET endpoint at its uri', () {
      const declaration = TomWebSocketEndpoint(uri: '/ws/ticker');
      final endpoint = declaration.convertToTomEndpoint();
      // A handshake is a GET; sharing TomEndpoint is what keeps the scan, the
      // access resolution and the routing table single-implementation.
      expect(endpoint.uri, '/ws/ticker');
      expect(endpoint.methods, [TomHttpMethod.get]);
    });

    test('is a TomEndpointBase, which is what the scan keys on', () {
      const declaration = TomWebSocketEndpoint(uri: '/ws/ticker');
      expect(declaration, isA<TomEndpointBase>());
    });

    test('carries the url parameter mapping into the converted endpoint', () {
      const declaration = TomWebSocketEndpoint(
        uri: '/ws/rooms/{room}',
        urlParameterMapping: {'room': 'roomId'},
      );
      expect(declaration.convertToTomEndpoint().urlParameterMapping, {
        'room': 'roomId',
      });
    });

    // The mapping's *query* half, composed the way the pipeline composes it.
    // The test above proves the map reaches the converted endpoint and the
    // oauth suite proves `injectQueryParameters` honours a map; neither says
    // that a handshake's query string is therefore bindable, which is the one
    // question a socket author actually has. A handshake is a GET with no
    // body, so the URL is the only thing the request DTO can be built from —
    // making this map the difference between a `?token=…` that arrives and one
    // that does not.
    test('a mapped query parameter binds on the handshake URL', () {
      const declaration = TomWebSocketEndpoint(
        uri: '/ws/rooms/{room}',
        urlParameterMapping: {'room': 'roomId', 'token': 'accessToken'},
      );
      final jsonBodyData = <String, dynamic>{};
      final req =
          Request(
            'GET',
            Uri.parse('https://s/ws/rooms/lobby?token=abc'),
          ).change(
            context: {
              'shelf_router/params': const {'room': 'lobby'},
            },
          );

      TomEndpointHandler.injectQueryParameters(
        jsonBodyData,
        req,
        declaration.convertToTomEndpoint(),
      );
      TomEndpointHandler.injectPathParameters(
        jsonBodyData,
        req,
        declaration.convertToTomEndpoint(),
      );

      expect(jsonBodyData, {'roomId': 'lobby', 'accessToken': 'abc'});
    });

    test('an unmapped query parameter does not bind on the handshake', () {
      // The asymmetry, from the socket side: the route capture binds with no
      // entry at all, the query parameter binds only with one. An author who
      // leaves the mapping empty and expects `?token=…` gets a DTO without it.
      const declaration = TomWebSocketEndpoint(uri: '/ws/rooms/{room}');
      final jsonBodyData = <String, dynamic>{};
      final req =
          Request(
            'GET',
            Uri.parse('https://s/ws/rooms/lobby?token=abc'),
          ).change(
            context: {
              'shelf_router/params': const {'room': 'lobby'},
            },
          );

      TomEndpointHandler.injectQueryParameters(
        jsonBodyData,
        req,
        declaration.convertToTomEndpoint(),
      );
      TomEndpointHandler.injectPathParameters(
        jsonBodyData,
        req,
        declaration.convertToTomEndpoint(),
      );

      expect(jsonBodyData, {'room': 'lobby'});
    });
  });

  group('TomWebSocketConnection', () {
    test('refuses to be used before it is attached', () {
      final connection = TomWebSocketConnection();
      expect(connection.isOpen, isFalse);
      // Named rather than a null dereference: the pipeline creates the
      // connection before the upgrade so binding failures stay HTTP errors,
      // which means "not attached yet" is a state that really occurs.
      expect(
        () => connection.sendText('x'),
        throwsA(
          isA<TomWebSocketException>().having(
            (e) => e.key,
            'key',
            'web_socket_endpoint.not_attached',
          ),
        ),
      );
    });

    test('closing an unattached connection is a no-op', () async {
      await TomWebSocketConnection().close();
    });
  });

  // -------------------------------------------------------------------------
  // Mounting
  // -------------------------------------------------------------------------

  group('the router mounts a socket endpoint alongside the HTTP ones', () {
    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
    });

    tearDown(TomBean.resetBeanContext);

    test('the socket route is in the routing table', () {
      final routing = TomEndpointRouting();
      routing.initializeRouter();
      expect(
        TomEndpointRouting.routingInfo.containsKey((
          uri: '/fixture/socket',
          method: 'GET',
        )),
        isTrue,
      );
    });

    test('its metadata records that it is a socket endpoint', () {
      final routing = TomEndpointRouting();
      routing.initializeRouter();
      final handler = _routeInfo('/fixture/socket').handler;
      expect(handler.metadata.webSocket, isNotNull);
      // The HTTP siblings are unaffected — the field is what distinguishes
      // them, not a separate discovery path.
      expect(_routeInfo('/fixture/health').handler.metadata.webSocket, isNull);
    });

    test('handleWebSocketCall on a non-socket endpoint is refused', () async {
      final routing = TomEndpointRouting();
      routing.initializeRouter();
      final handler = _routeInfo('/fixture/health').handler;
      await expectLater(
        handler.handleWebSocketCall(
          Request('GET', Uri.parse('http://localhost/fixture/health')),
        ),
        throwsA(isA<TomWebSocketException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Live: the two things that cannot be asserted without a real socket
  // -------------------------------------------------------------------------

  group('served over a loopback server', () {
    late HttpServer server;
    late Router router;

    setUp(() async {
      TomBean.resetBeanContext();
      TomBean.withType(FixtureApiServer, FixtureApiServer());
      TomBean.withType(TomHealthServer, TomHealthServer());
      TomBean.withType(FixtureAccessApiService, FixtureAccessApiService());
      router = TomEndpointRouting().initializeRouter();
      // Both middlewares a real server runs in front of the router, and both
      // are load-bearing here: the context one seeds the TomRequestLogInfo the
      // pipeline reads, and the authentication one establishes the request zone
      // holding the Request and the TomRequestId. The socket test asserts that
      // the pipeline *carries that zone across the upgrade* — so the zone has
      // to exist in the first place.
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

    test('a multipart form binds its text parts and its file part', () async {
      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        Uri.parse('http://localhost:${server.port}/fixture/upload'),
      );
      request.headers.set(
        'content-type',
        'multipart/form-data; boundary=$_boundary',
      );
      request.write(
        _formBody([
          _textPart('title', 'Quarterly report'),
          _textPart('tags', 'q3,final'),
          _filePart('attachment', 'q3.txt', 'text/plain', 'the numbers'),
        ]),
      );
      final response = await request.close();
      final body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;

      expect(response.statusCode, 200);
      // The two halves of a form reaching two different places: text parts
      // into the request DTO, the file part into a typed parameter.
      expect(body['title'], 'Quarterly report');
      expect(body['tags'], 'q3,final');
      expect(body['field'], 'attachment');
      expect(body['fileName'], 'q3.txt');
      expect(body['bytes'], 'the numbers'.length);
    });

    test(
      'a declared formFields keeps an undeclared part out of the DTO',
      () async {
        final client = HttpClient();
        addTearDown(client.close);
        final request = await client.postUrl(
          Uri.parse('http://localhost:${server.port}/fixture/upload_declared'),
        );
        request.headers.set(
          'content-type',
          'multipart/form-data; boundary=$_boundary',
        );
        request.write(
          _formBody([
            _textPart('title', 'Quarterly report'),
            _textPart('tags', 'should-not-arrive'),
          ]),
        );
        final response = await request.close();
        final body =
            jsonDecode(await response.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        expect(body['title'], 'Quarterly report');
        expect(body['tags'], isEmpty);
      },
    );

    test(
      'a handler returning TomRedirect answers 303 with a Location',
      () async {
        final client = HttpClient();
        addTearDown(client.close);
        // The redirect must be observed *unfollowed* — following it would assert
        // on the target and say nothing about the redirect itself.
        client.autoUncompress = false;
        final request = await client.getUrl(
          Uri.parse('http://localhost:${server.port}/fixture/moved'),
        );
        request.followRedirects = false;
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, 303);
        expect(response.headers.value('location'), '/fixture/health');
      },
    );

    test('a socket handler runs inside the request zone', () async {
      final socket = WebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/fixture/socket'),
      );
      await socket.ready;

      // The handler's first message reports what it could see of the zone. The
      // callback fires after the handshake response is finished, so without the
      // pipeline's zone capture both values would be gone (bug D22).
      final greeting = await socket.stream.first as String;
      expect(greeting, 'zone:fixture/socket;id:present');

      await socket.sink.close();
    });

    test('an accepted handshake is logged', () async {
      // The one event an operator wants in a socket access log, and the one the
      // pipeline could not record: an accepted upgrade ends in
      // `Request.hijack`, which throws `HijackException` by contract, so the
      // log line that stood after `await handler(req)` was reachable only for a
      // *refused* upgrade. The connection-free suite's assertion reaches it
      // through a plain GET, which is a refusal — so only a real socket can
      // tell the two apart, and this is that test.
      final captured = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      tomLog.logOutput = captured;
      addTearDown(() => tomLog.logOutput = previous);

      final socket = WebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/fixture/socket'),
      );
      await socket.ready;
      // The greeting proves the handshake completed rather than merely that
      // `ready` resolved, so the log line below is being asserted about a
      // connection that genuinely opened.
      expect(await socket.stream.first, 'zone:fixture/socket;id:present');

      final handshake = captured.lines.where(
        (l) => l.contains('[WebSocket handshake]'),
      );
      expect(
        handshake,
        hasLength(1),
        reason: 'an accepted upgrade is logged exactly once',
      );
      expect(
        handshake.single,
        contains('upgraded'),
        reason:
            'the line reports the outcome the pipeline can vouch for — shelf '
            'has taken the socket and writes the 101 itself',
      );
      expect(
        handshake.single,
        contains('/fixture/socket'),
        reason: 'and names the route it opened',
      );
      // And the middleware writes no second line for the same connection. It
      // reads the response through `.then`, and a hijack arrives as an *error*,
      // so the success callback never runs — `hasBeenLogged` would have
      // suppressed it in any case, and this asserts both belts at once.
      //
      // Matched on the middleware's own shape (`[appId] HTTP/…`) rather than on
      // the route, because the capture keeps trace lines too and those
      // legitimately name the route several times.
      final accessLog = RegExp(r'^(\[[^\]]+\] )?HTTP/');
      expect(
        captured.lines.where(
          (l) =>
              accessLog.hasMatch(l) &&
              l.contains('/fixture/socket') &&
              !l.contains('[WebSocket handshake]'),
        ),
        isEmpty,
        reason:
            'the middleware added a fallback line for a request the pipeline '
            'had already recorded',
      );

      await socket.sink.close();
    });

    test('a refused upgrade is logged as refused', () async {
      // The other outcome, over the same live server: a plain GET carries no
      // `Upgrade` header, so `shelf_web_socket` answers 404 and the handler
      // returns normally. Both outcomes now have a line, and they say different
      // things — which is the whole point of separating them.
      final captured = _CapturingLogOutput();
      final previous = tomLog.logOutput;
      tomLog.logOutput = captured;
      addTearDown(() => tomLog.logOutput = previous);

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.getUrl(
        Uri.parse('http://localhost:${server.port}/fixture/socket'),
      );
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 404);

      final refused = captured.lines.where(
        (l) => l.contains('[WebSocket handshake refused]'),
      );
      expect(refused, hasLength(1));
      expect(refused.single, contains('404'));
      expect(
        captured.lines.any((l) => l.contains('[WebSocket handshake]')),
        isFalse,
        reason: 'a refusal is not an upgrade and must not read as one',
      );
    });

    test('a socket handler exchanges messages over the connection', () async {
      final socket = WebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/fixture/socket'),
      );
      await socket.ready;
      final received = <String>[];
      final done = socket.stream
          .listen((m) => received.add(m as String))
          .asFuture<void>();

      socket.sink.add('hello');
      socket.sink.add('bye');
      // The handler returning ends the conversation: the pipeline closes the
      // socket, which is what completes this future.
      await done;

      expect(received, ['zone:fixture/socket;id:present', 'echo:hello']);
    });

    // CE-LG: a socket contributes two entries, and the second exists because
    // the first does not describe what happened. "A connection was accepted"
    // says the same thing about a channel that carried nothing and one that
    // carried two hundred messages over an hour, so the closing entry carries
    // the shape — how long it was open and how many frames crossed it.
    test('an audited socket records its acceptance and its close', () async {
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      addTearDown(() {
        TomAuditTrail.uninstall();
        TomAuditTrail.resetPolicyCache();
      });

      final socket = WebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/fixture/audited_socket'),
      );
      await socket.ready;
      final received = <String>[];
      final done = socket.stream
          .listen((m) => received.add(m as String))
          .asFuture<void>();
      socket.sink.add('one');
      socket.sink.add('two');
      socket.sink.add('bye');
      await done;

      expect(received, ['ready', 'echo:one', 'echo:two']);

      final records = sink.records;
      expect(records, hasLength(2));
      expect(
        records.map((r) => r.action),
        everyElement(TomAuditAction.execute),
      );
      expect(
        records.map((r) => r.outcome),
        everyElement(TomAuditOutcome.succeeded),
      );
      expect(records.first.detail, 'WebSocket connection accepted');

      // The shape. Three frames in — `one`, `two`, `bye`, all read by the
      // handler — and three out: the greeting and the two echoes.
      final closing = records.last.detail!;
      expect(closing, startsWith('WebSocket connection closed after '));
      expect(closing, contains('3 received'));
      expect(closing, contains('3 sent'));
      expect(
        closing,
        matches(RegExp(r'after \d+\.\d+s')),
        reason:
            'the duration is seconds to one decimal, for an auditor to scan',
      );

      // Joinable: both entries carry the handshake's request id, which is what
      // makes them one conversation rather than two unrelated records.
      expect(records.first.requestId, isNotNull);
      expect(records.last.requestId, records.first.requestId);
    });

    test('an unaudited socket still records nothing', () async {
      // The counter-case. Endpoint auditing is *declared*: the counting and the
      // closing entry must not turn every socket into two trail records, or the
      // opt-in would have stopped meaning anything.
      final sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      addTearDown(() {
        TomAuditTrail.uninstall();
        TomAuditTrail.resetPolicyCache();
      });

      final socket = WebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/fixture/socket'),
      );
      await socket.ready;
      final done = socket.stream.listen((_) {}).asFuture<void>();
      socket.sink.add('bye');
      await done;

      expect(sink.records, isEmpty);
    });
  });
}
