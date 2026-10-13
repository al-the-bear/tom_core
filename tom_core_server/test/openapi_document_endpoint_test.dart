/// `GET /openapi.json`: the optional publication of a server's build-generated
/// OpenAPI document.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show FixtureRequiredConfig;
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  setUpAll(initializeReflection);
  tearDown(() => TomOpenApiServer.globalSettingDocumentPath = null);

  Future<(int, Map<String, Object?>?, String)> call() async {
    final response = await TomOpenApiServer().openApiDocument();
    final body = await response.readAsString();
    Map<String, Object?>? json;
    try {
      json = jsonDecode(body) as Map<String, Object?>;
    } on FormatException {
      json = null;
    }
    expect(response.headers['content-type'], startsWith('application/json'));
    return (response.statusCode, json, body);
  }

  test('a server pointed at no document answers 404 and says so', () async {
    final (status, json, _) = await call();
    expect(status, 404);
    expect(json!['errorKey'], 'openapi.document.not_served');
  });

  test('a configured document is served as it is on disk', () async {
    final dir = Directory(p.join('.dart_tool', 'openapi_endpoint_test'))
      ..createSync(recursive: true);
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'openapi.json'))
      ..writeAsStringSync('{"openapi": "3.1.0"}\n');
    TomOpenApiServer.globalSettingDocumentPath = file.path;
    final (status, _, body) = await call();
    expect(status, 200);
    expect(body, '{"openapi": "3.1.0"}\n');
  });

  test('a configured document that is missing answers 404, not 500', () async {
    TomOpenApiServer.globalSettingDocumentPath = 'no/such/openapi.json';
    final (status, json, _) = await call();
    expect(status, 404);
    expect(json!['errorKey'], 'openapi.document.missing');
  });

  test('the route is public and mounted at /openapi.json', () {
    final routing = TomEndpointRouting();
    final service = routing.scanClasses().serviceInterfaces.singleWhere(
      (c) => c.simpleName == 'TomOpenApiService',
    );
    final metadata = routing.getClassMethodMetadata(service).single;
    expect(metadata.endpoint.uri, TomOpenApiServer.documentUri);
    expect(metadata.endpoint.methods, [TomHttpMethod.get]);
    expect(metadata.access, isA<TomPublicAccess>());
  });

  test('the configuration key names the document, and is off by default', () {
    TomServerConfigResourceProvider.setServerConfigProvider(
      TomServerConfigResourceProvider.from({'dbUrl': 'x'}),
    );
    expect(FixtureRequiredConfig([]).openApiDocument, isEmpty);
    TomServerConfigResourceProvider.setServerConfigProvider(
      TomServerConfigResourceProvider.from({
        'dbUrl': 'x',
        'openApiDocument': 'openapi/openapi.json',
      }),
    );
    expect(FixtureRequiredConfig([]).openApiDocument, 'openapi/openapi.json');
  });
}
