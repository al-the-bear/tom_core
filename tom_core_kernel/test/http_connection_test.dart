import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Tests for the HTTP Connection Module
// ============================================================================

void main() {
  // ==========================================================================
  // TomHeader Tests
  // ==========================================================================
  group('TomHeader', () {
    group('constants', () {
      test('should have correct contentType constant', () {
        expect(TomHeader.contentType, equals('Content-Type'));
      });

      test('should have correct contentDisposition constant', () {
        expect(TomHeader.contentDisposition, equals('Content-Disposition'));
      });
    });
  });

  // ==========================================================================
  // TomContentDisposition Tests
  // ==========================================================================
  group('TomContentDisposition', () {
    group('constants', () {
      test('should have correct attachment constant', () {
        expect(TomContentDisposition.attachment, equals('attachment'));
      });
    });
  });

  // ==========================================================================
  // TomHttpMethod Tests
  // ==========================================================================
  group('TomHttpMethod', () {
    group('predefined methods', () {
      test('should have correct GET method', () {
        expect(TomHttpMethod.get.name, equals('GET'));
        expect(TomHttpMethod.get.acceptsBody, isTrue);
      });

      test('should have correct POST method', () {
        expect(TomHttpMethod.post.name, equals('POST'));
        expect(TomHttpMethod.post.acceptsBody, isTrue);
      });

      test('should have correct PUT method', () {
        expect(TomHttpMethod.put.name, equals('PUT'));
        expect(TomHttpMethod.put.acceptsBody, isTrue);
      });

      test('should have correct PATCH method', () {
        expect(TomHttpMethod.patch.name, equals('PATCH'));
        expect(TomHttpMethod.patch.acceptsBody, isTrue);
      });

      test('should have correct DELETE method', () {
        expect(TomHttpMethod.delete.name, equals('DELETE'));
        expect(TomHttpMethod.delete.acceptsBody, isTrue);
      });

      test('should have correct HEAD method', () {
        expect(TomHttpMethod.head.name, equals('HEAD'));
        expect(TomHttpMethod.head.acceptsBody, isTrue);
      });

      test('should have correct CONNECT method', () {
        expect(TomHttpMethod.connect.name, equals('CONNECT'));
        expect(TomHttpMethod.connect.acceptsBody, isTrue);
      });

      test('should have correct TRACE method with no body', () {
        expect(TomHttpMethod.trace.name, equals('TRACE'));
        expect(TomHttpMethod.trace.acceptsBody, isFalse);
      });

      test('should have correct ALL wildcard method', () {
        expect(TomHttpMethod.all.name, equals('ALL'));
        expect(TomHttpMethod.all.acceptsBody, isTrue);
      });
    });

    group('methods map', () {
      test('should contain all predefined methods', () {
        expect(TomHttpMethod.methods.length, equals(10));
        expect(TomHttpMethod.methods.containsKey('GET'), isTrue);
        expect(TomHttpMethod.methods.containsKey('POST'), isTrue);
        expect(TomHttpMethod.methods.containsKey('PUT'), isTrue);
        expect(TomHttpMethod.methods.containsKey('PATCH'), isTrue);
        expect(TomHttpMethod.methods.containsKey('DELETE'), isTrue);
        expect(TomHttpMethod.methods.containsKey('HEAD'), isTrue);
        expect(TomHttpMethod.methods.containsKey('CONNECT'), isTrue);
        expect(TomHttpMethod.methods.containsKey('TRACE'), isTrue);
        expect(TomHttpMethod.methods.containsKey('OPTIONS'), isTrue);
        expect(TomHttpMethod.methods.containsKey('ALL'), isTrue);
      });

      test('should return correct method by name', () {
        expect(TomHttpMethod.methods['GET'], equals(TomHttpMethod.get));
        expect(TomHttpMethod.methods['POST'], equals(TomHttpMethod.post));
        expect(TomHttpMethod.methods['TRACE'], equals(TomHttpMethod.trace));
      });

      test('should return null for unknown method', () {
        expect(TomHttpMethod.methods['UNKNOWN'], isNull);
      });
    });

    group('constructor', () {
      test('should create custom method with body', () {
        const customMethod = TomHttpMethod('CUSTOM');

        expect(customMethod.name, equals('CUSTOM'));
        expect(customMethod.acceptsBody, isTrue);
      });

      test('should create custom method without body', () {
        const customMethod = TomHttpMethod('CUSTOM', false);

        expect(customMethod.name, equals('CUSTOM'));
        expect(customMethod.acceptsBody, isFalse);
      });
    });

    group('toString', () {
      test('should return name/acceptsBody format', () {
        expect(TomHttpMethod.get.toString(), equals('GET/true'));
        expect(TomHttpMethod.trace.toString(), equals('TRACE/false'));
      });
    });
  });

  // ==========================================================================
  // TomMimeType Tests
  // ==========================================================================
  group('TomMimeType', () {
    group('predefined types', () {
      test('should have correct json type', () {
        expect(TomMimeType.json.primaryType, equals('application'));
        expect(TomMimeType.json.subType, equals('json'));
        expect(TomMimeType.json.charset, equals('UTF-8'));
      });

      test('should have correct html type', () {
        expect(TomMimeType.html.primaryType, equals('text'));
        expect(TomMimeType.html.subType, equals('html'));
        expect(TomMimeType.html.charset, equals('UTF-8'));
      });

      test('should have correct plainText type', () {
        expect(TomMimeType.plainText.primaryType, equals('text'));
        expect(TomMimeType.plainText.subType, equals('plain'));
        expect(TomMimeType.plainText.charset, equals('UTF-8'));
      });

      test('should have correct css type', () {
        expect(TomMimeType.css.primaryType, equals('text'));
        expect(TomMimeType.css.subType, equals('css'));
      });

      test('should have correct csv type', () {
        expect(TomMimeType.csv.primaryType, equals('text'));
        expect(TomMimeType.csv.subType, equals('csv'));
      });

      test('should have correct javascript type with null charset', () {
        expect(TomMimeType.javascript.primaryType, equals('text'));
        expect(TomMimeType.javascript.subType, equals('javascript'));
        expect(TomMimeType.javascript.charset, isNull);
      });

      test('should have correct xml type', () {
        expect(TomMimeType.xml.primaryType, equals('application'));
        expect(TomMimeType.xml.subType, equals('xml'));
      });

      test('should have correct pdf type with null charset', () {
        expect(TomMimeType.pdf.primaryType, equals('application'));
        expect(TomMimeType.pdf.subType, equals('pdf'));
        expect(TomMimeType.pdf.charset, isNull);
      });

      test('should have correct octetStream type', () {
        expect(TomMimeType.octetStream.primaryType, equals('application'));
        expect(TomMimeType.octetStream.subType, equals('octet-stream'));
        expect(TomMimeType.octetStream.charset, isNull);
      });

      test('should have correct zip type', () {
        expect(TomMimeType.zip.primaryType, equals('application'));
        expect(TomMimeType.zip.subType, equals('zip'));
        expect(TomMimeType.zip.charset, isNull);
      });

      test('should have correct multipartFormData type', () {
        expect(TomMimeType.multipartFormData.primaryType, equals('multipart'));
        expect(TomMimeType.multipartFormData.subType, equals('form-data'));
        expect(TomMimeType.multipartFormData.charset, isNull);
      });

      test('should have correct urlEncoded type', () {
        expect(TomMimeType.urlEncoded.primaryType, equals('application'));
        expect(TomMimeType.urlEncoded.subType, equals('x-www-form-urlencoded'));
      });

      test('should have correct ics/calendar type', () {
        expect(TomMimeType.ics.primaryType, equals('text'));
        expect(TomMimeType.ics.subType, equals('calendar'));
      });

      test('should have none placeholder type', () {
        expect(TomMimeType.none.primaryType, equals('none'));
        expect(TomMimeType.none.subType, equals('none'));
      });
    });

    group('constructor', () {
      test('should create mime type with default charset', () {
        const mimeType = TomMimeType('custom', 'type');

        expect(mimeType.primaryType, equals('custom'));
        expect(mimeType.subType, equals('type'));
        expect(mimeType.charset, equals('UTF-8'));
        expect(mimeType.codecs, isEmpty);
      });

      test('should create mime type with custom charset', () {
        const mimeType = TomMimeType('text', 'plain', charset: 'ISO-8859-1');

        expect(mimeType.charset, equals('ISO-8859-1'));
      });

      test('should create mime type with null charset', () {
        const mimeType = TomMimeType('image', 'png', charset: null);

        expect(mimeType.charset, isNull);
      });

      test('should create mime type with codecs', () {
        const mimeType = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1.42E01E', 'mp4a.40.2'],
        );

        expect(mimeType.codecs.length, equals(2));
        expect(mimeType.codecs[0], equals('avc1.42E01E'));
        expect(mimeType.codecs[1], equals('mp4a.40.2'));
      });
    });

    group('parse', () {
      test('should parse valid mime type', () {
        final mimeType = TomMimeType.parse('application/json');

        expect(mimeType.primaryType, equals('application'));
        expect(mimeType.subType, equals('json'));
      });

      test('should parse text mime type', () {
        final mimeType = TomMimeType.parse('text/html');

        expect(mimeType.primaryType, equals('text'));
        expect(mimeType.subType, equals('html'));
      });

      test('should parse complex subtype', () {
        final mimeType = TomMimeType.parse('application/vnd.api+json');

        expect(mimeType.primaryType, equals('application'));
        expect(mimeType.subType, equals('vnd.api+json'));
      });

      test('should throw for invalid mime type with no slash', () {
        expect(
          () => TomMimeType.parse('invalid'),
          throwsA(isA<TomMimeTypeException>()),
        );
      });

      test('should throw for mime type with multiple slashes', () {
        expect(
          () => TomMimeType.parse('application/json/extra'),
          throwsA(isA<TomMimeTypeException>()),
        );
      });

      test('should throw for empty primary type', () {
        expect(
          () => TomMimeType.parse('/json'),
          throwsA(isA<TomMimeTypeException>()),
        );
      });

      test('should throw for empty sub type', () {
        expect(
          () => TomMimeType.parse('application/'),
          throwsA(isA<TomMimeTypeException>()),
        );
      });
    });

    group('isText', () {
      test('should return true for text/* types', () {
        expect(TomMimeType.plainText.isText, isTrue);
        expect(TomMimeType.html.isText, isTrue);
        expect(TomMimeType.css.isText, isTrue);
        expect(TomMimeType.csv.isText, isTrue);
        expect(TomMimeType.javascript.isText, isTrue);
      });

      test('should return true for application/json', () {
        expect(TomMimeType.json.isText, isTrue);
      });

      test('should return true for application/xml', () {
        expect(TomMimeType.xml.isText, isTrue);
      });

      test('should return true for application/x-www-form-urlencoded', () {
        expect(TomMimeType.urlEncoded.isText, isTrue);
      });

      test('should return true for +json suffix types', () {
        const mimeType = TomMimeType('application', 'vnd.api+json');
        expect(mimeType.isText, isTrue);
      });

      test('should return true for +xml suffix types', () {
        const mimeType = TomMimeType('application', 'vnd.api+xml');
        expect(mimeType.isText, isTrue);
      });

      test('should return false for binary types', () {
        expect(TomMimeType.pdf.isText, isFalse);
        expect(TomMimeType.zip.isText, isFalse);
        expect(TomMimeType.octetStream.isText, isFalse);
      });

      test('should return false for multipart types', () {
        expect(TomMimeType.multipartFormData.isText, isFalse);
      });
    });

    group('toHeaderValue', () {
      test('should include charset when present', () {
        expect(
          TomMimeType.json.toHeaderValue(),
          equals('application/json;charset=UTF-8'),
        );
      });

      test('should exclude charset when null', () {
        expect(TomMimeType.pdf.toHeaderValue(), equals('application/pdf'));
      });

      test('should include single codec without prefix', () {
        const mimeType = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1.42E01E'],
        );
        // Single codec is appended directly without ;codecs= prefix
        expect(mimeType.toHeaderValue(), equals('video/mp4avc1.42E01E'));
      });

      test('should include multiple codecs', () {
        const mimeType = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1.42E01E', 'mp4a.40.2'],
        );
        expect(
          mimeType.toHeaderValue(),
          equals('video/mp4;codecs=avc1.42E01E,mp4a.40.2'),
        );
      });
    });

    group('toString', () {
      test('should return type/subtype;charset format', () {
        expect(
          TomMimeType.json.toString(),
          equals('application/json;charset:UTF-8'),
        );
      });

      test('should exclude charset when null', () {
        expect(TomMimeType.pdf.toString(), equals('application/pdf'));
      });
    });

    group('equality', () {
      test('should be equal for same type and subtype', () {
        const type1 = TomMimeType('application', 'json');
        const type2 = TomMimeType('application', 'json');

        expect(type1 == type2, isTrue);
        expect(type1.hashCode, equals(type2.hashCode));
      });

      test('should not be equal for different types', () {
        const type1 = TomMimeType('application', 'json');
        const type2 = TomMimeType('text', 'json');

        expect(type1 == type2, isFalse);
      });

      test('should not be equal for different subtypes', () {
        const type1 = TomMimeType('application', 'json');
        const type2 = TomMimeType('application', 'xml');

        expect(type1 == type2, isFalse);
      });

      test('should not be equal for different codecs', () {
        const type1 = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1'],
        );
        const type2 = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['hevc'],
        );

        expect(type1 == type2, isFalse);
      });

      test('should not be equal for different codec counts', () {
        const type1 = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1'],
        );
        const type2 = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1', 'mp4a'],
        );

        expect(type1 == type2, isFalse);
      });

      test('should return false when comparing with non-TomMimeType', () {
        const type1 = TomMimeType('application', 'json');

        // ignore: unrelated_type_equality_checks
        expect(type1 == 'application/json', isFalse);
      });
    });

    group('isEqualType', () {
      test('should return true for same primary and sub type', () {
        const type1 = TomMimeType('application', 'json', charset: 'UTF-8');
        const type2 = TomMimeType('application', 'json', charset: null);

        expect(type1.isEqualType(type2), isTrue);
      });

      test('should return false for different types', () {
        expect(TomMimeType.json.isEqualType(TomMimeType.xml), isFalse);
      });
    });
  });

  // ==========================================================================
  // StaticFileMimetypeMapping Tests
  // ==========================================================================
  group('StaticFileMimetypeMapping', () {
    group('getMimeType', () {
      test('should return correct mime type for .json', () {
        final mimeType = StaticFileMimetypeMapping.getMimeType('.json');

        expect(mimeType, isNotNull);
        expect(mimeType!.isEqualType(TomMimeType.json), isTrue);
      });

      test('should return correct mime type for .js', () {
        final mimeType = StaticFileMimetypeMapping.getMimeType('.js');

        expect(mimeType, isNotNull);
        expect(mimeType!.isEqualType(TomMimeType.javascript), isTrue);
      });

      test('should return correct mime type for .css', () {
        final mimeType = StaticFileMimetypeMapping.getMimeType('.css');

        expect(mimeType, isNotNull);
        expect(mimeType!.isEqualType(TomMimeType.css), isTrue);
      });

      test('should return correct mime type for .pdf', () {
        final mimeType = StaticFileMimetypeMapping.getMimeType('.pdf');

        expect(mimeType, isNotNull);
        expect(mimeType!.isEqualType(TomMimeType.pdf), isTrue);
      });

      test('should return correct mime type for .zip', () {
        final mimeType = StaticFileMimetypeMapping.getMimeType('.zip');

        expect(mimeType, isNotNull);
        expect(mimeType!.isEqualType(TomMimeType.zip), isTrue);
      });

      test('should return correct mime type for image extensions', () {
        expect(
          StaticFileMimetypeMapping.getMimeType('.png')?.primaryType,
          equals('image'),
        );
        expect(
          StaticFileMimetypeMapping.getMimeType('.jpg')?.primaryType,
          equals('image'),
        );
        expect(
          StaticFileMimetypeMapping.getMimeType('.jpeg')?.subType,
          equals('jpeg'),
        );
        expect(
          StaticFileMimetypeMapping.getMimeType('.gif')?.subType,
          equals('gif'),
        );
        expect(
          StaticFileMimetypeMapping.getMimeType('.webp')?.subType,
          equals('webp'),
        );
        expect(
          StaticFileMimetypeMapping.getMimeType('.svg')?.subType,
          equals('svg+xml'),
        );
      });

      test('should return correct mime type for video extensions', () {
        expect(
          StaticFileMimetypeMapping.getMimeType('.mp4')?.primaryType,
          equals('video'),
        );
        expect(
          StaticFileMimetypeMapping.getMimeType('.ogg')?.primaryType,
          equals('video'),
        );
      });

      test('should return correct mime type for audio extensions', () {
        expect(
          StaticFileMimetypeMapping.getMimeType('.mp3')?.primaryType,
          equals('audio'),
        );
      });

      test('should be case insensitive', () {
        final mimeTypeLower = StaticFileMimetypeMapping.getMimeType('.json');
        final mimeTypeUpper = StaticFileMimetypeMapping.getMimeType('.JSON');
        final mimeTypeMixed = StaticFileMimetypeMapping.getMimeType('.Json');

        expect(mimeTypeLower, isNotNull);
        expect(mimeTypeUpper, isNotNull);
        expect(mimeTypeMixed, isNotNull);
        expect(mimeTypeLower!.isEqualType(mimeTypeUpper!), isTrue);
        expect(mimeTypeLower.isEqualType(mimeTypeMixed!), isTrue);
      });

      test('should return null for unknown extension', () {
        expect(StaticFileMimetypeMapping.getMimeType('.unknown'), isNull);
        expect(StaticFileMimetypeMapping.getMimeType('.xyz'), isNull);
      });
    });
  });

  // ==========================================================================
  // TomRemoteApis Tests
  // ==========================================================================
  group('TomRemoteApis', () {
    late TomRemoteApis registry;

    setUp(() {
      // Create a fresh registry for each test
      registry = TomRemoteApis();
    });

    group('constructor', () {
      test('should create empty registry', () {
        expect(registry.apis, isEmpty);
      });
    });

    group('register', () {
      test('should register an API', () {
        final api = TomApi(
          id: 'testApi',
          name: 'Test API',
          endpoints: [],
        );

        registry.register(api);

        expect(registry.apis.containsKey('testApi'), isTrue);
        expect(registry.apis['testApi'], equals(api));
      });

      test('should replace API with same id', () {
        final api1 = TomApi(
          id: 'testApi',
          name: 'Original API',
          endpoints: [],
        );
        final api2 = TomApi(
          id: 'testApi',
          name: 'Replacement API',
          endpoints: [],
        );

        registry.register(api1);
        registry.register(api2);

        expect(registry.apis['testApi']?.name, equals('Replacement API'));
      });
    });

    group('bracket operator []', () {
      test('should return API by id', () {
        final api = TomApi(
          id: 'testApi',
          name: 'Test API',
          endpoints: [],
        );
        registry.register(api);

        final retrieved = registry['testApi'];

        expect(retrieved, equals(api));
      });

      test('should throw TomEndpointException for unknown API', () {
        expect(
          () => registry['unknownApi'],
          throwsA(isA<TomEndpointException>()),
        );
      });
    });

    group('bracket assignment operator []=', () {
      test('should register API using assignment', () {
        final api = TomApi(
          id: 'testApi',
          name: 'Test API',
          endpoints: [],
        );

        registry['testApi'] = api;

        expect(registry.apis['testApi'], equals(api));
      });
    });

    group('static registerApi', () {
      test('should register API in current singleton', () {
        final api = TomApi(
          id: 'staticTestApi',
          name: 'Static Test API',
          endpoints: [],
        );

        TomRemoteApis.registerApi(api);

        expect(TomRemoteApis.current.apis.containsKey('staticTestApi'), isTrue);
      });
    });

    group('static getApiById', () {
      test('should retrieve API by id from current singleton', () {
        final api = TomApi(
          id: 'staticGetApi',
          name: 'Static Get API',
          endpoints: [],
        );
        TomRemoteApis.registerApi(api);

        final retrieved = TomRemoteApis.getApiById('staticGetApi');

        expect(retrieved, equals(api));
      });
    });

    group('tomRemoteApis global accessor', () {
      test('should return current singleton', () {
        expect(tomRemoteApis, equals(TomRemoteApis.current));
      });
    });
  });

  // ==========================================================================
  // TomApi Tests
  // ==========================================================================
  group('TomApi', () {
    group('constructor', () {
      test('should create API with required fields only', () {
        final api = TomApi(
          id: 'minimalApi',
          endpoints: [],
        );

        expect(api.id, equals('minimalApi'));
        expect(api.name, isNull);
        expect(api.description, isNull);
        expect(api.uri, isNull);
        expect(api.endpoints, isEmpty);
      });

      test('should create API with all optional fields', () {
        final api = TomApi(
          id: 'fullApi',
          name: 'Full API',
          description: 'A full API with all fields',
          uri: '/api/v1',
          requestEncoding: utf8,
          responseEncoding: latin1,
          statusCodeResponseTypes: {404: String},
          endpoints: [],
        );

        expect(api.id, equals('fullApi'));
        expect(api.name, equals('Full API'));
        expect(api.description, equals('A full API with all fields'));
        expect(api.uri, equals('/api/v1'));
        expect(api.requestEncoding, equals(utf8));
        expect(api.responseEncoding, equals(latin1));
        expect(api.statusCodeResponseTypes, isNotNull);
        expect(api.statusCodeResponseTypes![404], equals(String));
      });

      test('should add endpoints and set their API reference', () {
        final endpoint = TomApiEndpoint(
          id: 'testEndpoint',
          method: TomHttpMethod.get,
        );
        final api = TomApi(
          id: 'apiWithEndpoints',
          endpoints: [endpoint],
        );

        expect(api.endpoints.containsKey('testEndpoint'), isTrue);
        expect(api.endpoints['testEndpoint'], equals(endpoint));
        // Accessing api property should not throw since it's set
        expect(endpoint.api, equals(api));
      });
    });

    group('bracket operator []', () {
      test('should return endpoint by id', () {
        final endpoint = TomApiEndpoint(
          id: 'myEndpoint',
          method: TomHttpMethod.post,
        );
        final api = TomApi(
          id: 'testApi',
          endpoints: [endpoint],
        );

        final retrieved = api['myEndpoint'];

        expect(retrieved, equals(endpoint));
      });

      test('should throw TomEndpointException for unknown endpoint', () {
        final api = TomApi(
          id: 'testApi',
          endpoints: [],
        );

        expect(
          () => api['unknownEndpoint'],
          throwsA(isA<TomEndpointException>()),
        );
      });
    });

    group('bracket assignment operator []=', () {
      test('should add endpoint using assignment', () {
        final api = TomApi(
          id: 'testApi',
          endpoints: [],
        );
        final endpoint = TomApiEndpoint(
          id: 'newEndpoint',
          method: TomHttpMethod.get,
        );

        api['newEndpoint'] = endpoint;

        expect(api.endpoints['newEndpoint'], equals(endpoint));
        expect(endpoint.api, equals(api));
      });
    });
  });

  // ==========================================================================
  // TomApiEndpoint Tests
  // ==========================================================================
  group('TomApiEndpoint', () {
    group('constructor', () {
      test('should create endpoint with required fields only', () {
        final endpoint = TomApiEndpoint(
          id: 'minimalEndpoint',
          method: TomHttpMethod.get,
        );

        expect(endpoint.id, equals('minimalEndpoint'));
        expect(endpoint.method, equals(TomHttpMethod.get));
        expect(endpoint.consumes, equals(TomMimeType.json));
        expect(endpoint.produces, equals(TomMimeType.json));
        expect(endpoint.followRedirects, isFalse);
        expect(endpoint.includeBearerAuthentication, isTrue);
      });

      test('should create endpoint with all optional fields', () {
        final endpoint = TomApiEndpoint(
          id: 'fullEndpoint',
          uri: '/users/create',
          description: 'Creates a new user',
          method: TomHttpMethod.post,
          methods: [TomHttpMethod.post, TomHttpMethod.put],
          consumes: TomMimeType.urlEncoded,
          produces: TomMimeType.html,
          contentDisposition: 'attachment',
          formFields: ['username', 'password'],
          responseHeaders: {'X-Custom': 'value'},
          requestHeaders: {'Accept': 'application/json'},
          requestTypes: [String, int],
          followRedirects: true,
          persistentConnection: true,
          includeBearerAuthentication: false,
          maxRedirects: 5,
          requestEncoding: utf8,
          responseEncoding: latin1,
          statusCodeResponseTypes: {400: String},
        );

        expect(endpoint.id, equals('fullEndpoint'));
        expect(endpoint.uri, equals('/users/create'));
        expect(endpoint.description, equals('Creates a new user'));
        expect(endpoint.method, equals(TomHttpMethod.post));
        expect(endpoint.methods?.length, equals(2));
        expect(endpoint.consumes, equals(TomMimeType.urlEncoded));
        expect(endpoint.produces, equals(TomMimeType.html));
        expect(endpoint.contentDisposition, equals('attachment'));
        expect(endpoint.formFields, contains('username'));
        expect(endpoint.responseHeaders['X-Custom'], equals('value'));
        expect(endpoint.requestHeaders['Accept'], equals('application/json'));
        expect(endpoint.requestTypes, contains(String));
        expect(endpoint.followRedirects, isTrue);
        expect(endpoint.persistentConnection, isTrue);
        expect(endpoint.includeBearerAuthentication, isFalse);
        expect(endpoint.maxRedirects, equals(5));
        expect(endpoint.requestEncoding, equals(utf8));
        expect(endpoint.responseEncoding, equals(latin1));
        expect(endpoint.statusCodeResponseTypes?[400], equals(String));
      });

      test('should set responseType to Map for dynamic return type', () {
        final endpoint = TomApiEndpoint<dynamic, String>(
          id: 'dynamicEndpoint',
          method: TomHttpMethod.get,
        );

        expect(endpoint.responseType, equals(Map<String, Object?>));
      });
    });

    group('api property', () {
      test('should return parent API when set', () {
        final endpoint = TomApiEndpoint(
          id: 'testEndpoint',
          method: TomHttpMethod.get,
        );
        final api = TomApi(
          id: 'parentApi',
          endpoints: [endpoint],
        );

        expect(endpoint.api, equals(api));
      });

      test('should throw TomEndpointException when API not set', () {
        final endpoint = TomApiEndpoint(
          id: 'orphanEndpoint',
          method: TomHttpMethod.get,
        );

        expect(
          () => endpoint.api,
          throwsA(isA<TomEndpointException>()),
        );
      });
    });
  });

  // ==========================================================================
  // TomClientRemoteContext Tests
  // ==========================================================================
  group('TomClientRemoteContext', () {
    setUp(() {
      // Reset current to null before each test
      TomClientRemoteContext.current = null;
    });

    group('constructor', () {
      test('should create context with baseUri only', () {
        final baseUri = Uri.parse('https://api.example.com');
        final context = TomClientRemoteContext(baseUri);

        expect(context.baseUri, equals(baseUri));
        expect(context.authenticationUri, equals(baseUri));
      });

      test('should create context with separate authenticationUri', () {
        final baseUri = Uri.parse('https://api.example.com');
        final authUri = Uri.parse('https://auth.example.com');
        final context = TomClientRemoteContext(baseUri, authUri);

        expect(context.baseUri, equals(baseUri));
        expect(context.authenticationUri, equals(authUri));
      });
    });

    group('setCurrent', () {
      test('should set current context when null', () {
        final context = TomClientRemoteContext(
          Uri.parse('https://api.example.com'),
        );

        TomClientRemoteContext.setCurrent(context);

        expect(TomClientRemoteContext.current, equals(context));
      });

      test('should throw when context already set', () {
        final context1 = TomClientRemoteContext(
          Uri.parse('https://api1.example.com'),
        );
        final context2 = TomClientRemoteContext(
          Uri.parse('https://api2.example.com'),
        );

        TomClientRemoteContext.setCurrent(context1);

        expect(
          () => TomClientRemoteContext.setCurrent(context2),
          throwsA(isA<TomClientRemoteContextException>()),
        );
      });
    });

    group('toString', () {
      test('should return formatted string with baseUri', () {
        final context = TomClientRemoteContext(
          Uri.parse('https://api.example.com'),
        );

        expect(
          context.toString(),
          equals('TomClientRemoteContext https://api.example.com'),
        );
      });
    });
  });

  // ==========================================================================
  // TomServerCallSpecs Tests
  // ==========================================================================
  group('TomServerCallSpecs', () {
    group('constructor', () {
      test('should create specs with required fields only', () {
        final specs = TomServerCallSpecs(
          'GET',
          Uri.parse('https://api.example.com/users'),
        );

        expect(specs.method, equals('GET'));
        expect(specs.url.toString(), equals('https://api.example.com/users'));
        expect(specs.followRedirects, isNull);
        expect(specs.headers, isEmpty);
        expect(specs.maxRedirects, isNull);
        expect(specs.persistentConnection, isNull);
        expect(specs.includeBearerAuthentication, isTrue);
        expect(specs.requestEncoding, isNull);
        expect(specs.fallbackResponseEncoding, isNull);
      });

      test('should create specs with all optional fields', () {
        final specs = TomServerCallSpecs(
          'POST',
          Uri.parse('https://api.example.com/users'),
          followRedirects: true,
          headers: {'Content-Type': 'application/json'},
          maxRedirects: 5,
          persistentConnection: true,
          includeBearerAuthentication: false,
          requestEncoding: utf8,
          fallbackResponseEncoding: latin1,
        );

        expect(specs.method, equals('POST'));
        expect(specs.followRedirects, isTrue);
        expect(specs.headers?['Content-Type'], equals('application/json'));
        expect(specs.maxRedirects, equals(5));
        expect(specs.persistentConnection, isTrue);
        expect(specs.includeBearerAuthentication, isFalse);
        expect(specs.requestEncoding, equals(utf8));
        expect(specs.fallbackResponseEncoding, equals(latin1));
      });
    });
  });

  // ==========================================================================
  // TomServerCallLoad Tests
  // ==========================================================================
  group('TomServerCallLoad', () {
    group('constructor', () {
      test('should create empty load', () {
        final load = TomServerCallLoad();

        expect(load.stringBody, isNull);
        expect(load.byteBody, isNull);
        expect(load.bodyFields, isNull);
        expect(load.contentType, isNull);
        expect(load.encoding, isNull);
        expect(load.contentLength, isNull);
      });

      test('should create load with string body', () {
        final load = TomServerCallLoad(
          stringBody: '{"name": "John"}',
          contentType: 'application/json',
          encoding: utf8,
        );

        expect(load.stringBody, equals('{"name": "John"}'));
        expect(load.contentType, equals('application/json'));
        expect(load.encoding, equals(utf8));
      });

      test('should create load with byte body', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final load = TomServerCallLoad(
          byteBody: bytes,
          contentType: 'application/octet-stream',
        );

        expect(load.byteBody, equals(bytes));
        expect(load.contentType, equals('application/octet-stream'));
      });

      test('should create load with body fields', () {
        final load = TomServerCallLoad(
          bodyFields: {'username': 'john', 'password': 'secret'},
        );

        expect(load.bodyFields, isNotNull);
        expect(load.bodyFields!['username'], equals('john'));
        expect(load.bodyFields!['password'], equals('secret'));
      });

      test('should throw when multiple body types provided', () {
        expect(
          () => TomServerCallLoad(
            stringBody: 'test',
            byteBody: Uint8List.fromList([1, 2, 3]),
          ),
          throwsA(isA<TomServerConnectionException>()),
        );
      });

      test('should throw when all three body types provided', () {
        expect(
          () => TomServerCallLoad(
            stringBody: 'test',
            byteBody: Uint8List.fromList([1, 2, 3]),
            bodyFields: {'key': 'value'},
          ),
          throwsA(isA<TomServerConnectionException>()),
        );
      });

      test('should throw when string and fields provided', () {
        expect(
          () => TomServerCallLoad(
            stringBody: 'test',
            bodyFields: {'key': 'value'},
          ),
          throwsA(isA<TomServerConnectionException>()),
        );
      });

      test('should throw when bytes and fields provided', () {
        expect(
          () => TomServerCallLoad(
            byteBody: Uint8List.fromList([1, 2, 3]),
            bodyFields: {'key': 'value'},
          ),
          throwsA(isA<TomServerConnectionException>()),
        );
      });
    });
  });

  // ==========================================================================
  // TomServerCallError Tests
  // ==========================================================================
  group('TomServerCallError', () {
    group('constructor', () {
      test('should create with default values', () {
        final error = TomServerCallError();

        expect(error.statusCode, equals(200));
        expect(error.response, isNull);
        expect(error.internalError, equals(0));
        expect(error.headers, isEmpty);
        expect(error.isRedirect, isFalse);
        expect(error.reasonPhrase, isNull);
        expect(error.exception, isNull);
        expect(error.stackTrace, isNull);
      });

      test('should create with custom values', () {
        final error = TomServerCallError(
          statusCode: 404,
          response: 'Not Found',
          internalError: 1,
          headers: {'Content-Type': 'text/plain'},
          isRedirect: false,
          reasonPhrase: 'Not Found',
        );

        expect(error.statusCode, equals(404));
        expect(error.response, equals('Not Found'));
        expect(error.internalError, equals(1));
        expect(error.headers['Content-Type'], equals('text/plain'));
        expect(error.isRedirect, isFalse);
        expect(error.reasonPhrase, equals('Not Found'));
      });
    });

    group('hasError', () {
      test('should return false for 200 status with no internal error', () {
        final error = TomServerCallError(statusCode: 200, internalError: 0);

        expect(error.hasError, isFalse);
      });

      test('should return true for non-200 status', () {
        final error = TomServerCallError(statusCode: 404, internalError: 0);

        expect(error.hasError, isTrue);
      });

      test('should return true for internal error', () {
        final error = TomServerCallError(statusCode: 200, internalError: 1);

        expect(error.hasError, isTrue);
      });

      test('should return true for both non-200 and internal error', () {
        final error = TomServerCallError(statusCode: 500, internalError: 2);

        expect(error.hasError, isTrue);
      });
    });

    group('constants', () {
      test('should have correct jsonDecodingError constant', () {
        expect(TomServerCallError.jsonDecodingError, equals(1));
      });

      test('should have correct noResponseError constant', () {
        expect(TomServerCallError.noResponseError, equals(2));
      });

      test('should have correct serverError constant', () {
        expect(TomServerCallError.serverError, equals(2));
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        final error = TomServerCallError(
          statusCode: 404,
          internalError: 0,
          response: 'Not Found',
        );

        final result = error.toString();

        expect(result, contains('HasError true'));
        expect(result, contains('Status: 404'));
        expect(result, contains('Internal: 0'));
        expect(result, contains('Response: Not Found'));
      });
    });
  });

  // ==========================================================================
  // TomServerChannel Tests
  // ==========================================================================
  group('TomServerChannel', () {
    group('constructor', () {
      test('should create channel with host and port', () {
        final channel = TomServerChannel('api.example.com', 443);

        expect(channel.host, equals('api.example.com'));
        expect(channel.port, equals(443));
        expect(channel.client, isNull);
      });

      test('should create channel with custom client factory', () {
        final customFactory = TomHttpClientFactory();
        final channel = TomServerChannel(
          'api.example.com',
          80,
          clientFactory: customFactory,
        );

        expect(channel.clientFactory, equals(customFactory));
      });
    });

    group('close', () {
      test('should handle close when client is null', () {
        final channel = TomServerChannel('api.example.com', 443);
        expect(channel.client, isNull);

        // Should not throw
        channel.close();

        expect(channel.client, isNull);
      });
    });

    group('getClient', () {
      test('should return same client on multiple calls when set', () {
        final channel = TomServerChannel('api.example.com', 443);
        // Client starts as null
        expect(channel.client, isNull);
      });
    });
  });

  // ==========================================================================
  // TomHttpClientFactory Tests
  // ==========================================================================
  group('TomHttpClientFactory', () {
    group('initialize', () {
      test('should allow initialization', () {
        // Should not throw when called
        TomHttpClientFactory.initialize();
        // Can be called multiple times without throwing
        TomHttpClientFactory.initialize();
      });
    });

    group('setGlobalHttpClientFactory', () {
      test('should accept custom factory', () {
        final customFactory = TomDefaultHttpClientFactory();

        // Should not throw
        TomHttpClientFactory.setGlobalHttpClientFactory(customFactory);
      });
    });

    group('constructor', () {
      test('should create factory instance', () {
        final factory = TomHttpClientFactory();

        expect(factory, isNotNull);
        expect(factory.instanceClientFactory, isNull);
      });
    });
  });

  // ==========================================================================
  // TomServerEndpoint Tests
  // ==========================================================================
  group('TomServerEndpoint', () {
    group('removeLeadingSlash', () {
      test('should remove leading slash', () {
        expect(
          TomServerEndpoint.removeLeadingSlash('/api/v1'),
          equals('api/v1'),
        );
      });

      test('should return unchanged if no leading slash', () {
        expect(
          TomServerEndpoint.removeLeadingSlash('api/v1'),
          equals('api/v1'),
        );
      });

      test('should return empty string for single slash', () {
        expect(
          TomServerEndpoint.removeLeadingSlash('/'),
          equals(''),
        );
      });

      test('should return empty string for empty input', () {
        expect(
          TomServerEndpoint.removeLeadingSlash(''),
          equals(''),
        );
      });
    });

    group('constructor', () {
      test('should create endpoint with channel and specs', () {
        final channel = TomServerChannel('api.example.com', 443);
        final specs = TomServerCallSpecs(
          'POST',
          Uri.parse('https://api.example.com/users'),
        );

        final endpoint = TomServerEndpoint(channel, specs);

        expect(endpoint.channel, equals(channel));
        expect(endpoint.specs, equals(specs));
        expect(endpoint.statusCodeResponseTypes, isNull);
      });

      test('should create endpoint with status code response types', () {
        final channel = TomServerChannel('api.example.com', 443);
        final specs = TomServerCallSpecs(
          'POST',
          Uri.parse('https://api.example.com/users'),
        );

        final endpoint = TomServerEndpoint(
          channel,
          specs,
          statusCodeResponseTypes: {400: String, 404: int},
        );

        expect(endpoint.statusCodeResponseTypes, isNotNull);
        expect(endpoint.statusCodeResponseTypes![400], equals(String));
        expect(endpoint.statusCodeResponseTypes![404], equals(int));
      });
    });
  });

  // ==========================================================================
  // TomServerCallSpecs Tests
  // ==========================================================================
  group('TomServerCallSpecs', () {
    test('should create specs with required parameters', () {
      final specs = TomServerCallSpecs(
        'GET',
        Uri.parse('https://api.example.com/users'),
      );

      expect(specs.method, equals('GET'));
      expect(specs.url.toString(), equals('https://api.example.com/users'));
      expect(specs.includeBearerAuthentication, isTrue); // default
    });

    test('should create specs with all optional parameters', () {
      final specs = TomServerCallSpecs(
        'POST',
        Uri.parse('https://api.example.com/users'),
        followRedirects: true,
        headers: {'X-Custom': 'value'},
        maxRedirects: 5,
        persistentConnection: true,
        includeBearerAuthentication: false,
        requestEncoding: utf8,
        fallbackResponseEncoding: latin1,
      );

      expect(specs.method, equals('POST'));
      expect(specs.followRedirects, isTrue);
      expect(specs.headers, equals({'X-Custom': 'value'}));
      expect(specs.maxRedirects, equals(5));
      expect(specs.persistentConnection, isTrue);
      expect(specs.includeBearerAuthentication, isFalse);
      expect(specs.requestEncoding, equals(utf8));
      expect(specs.fallbackResponseEncoding, equals(latin1));
    });

    test('should have empty headers by default', () {
      final specs = TomServerCallSpecs(
        'DELETE',
        Uri.parse('https://api.example.com/users/1'),
      );

      expect(specs.headers, equals({}));
    });
  });

  // ==========================================================================
  // TomServerCallLoad Tests
  // ==========================================================================
  group('TomServerCallLoad', () {
    test('should create load with string body', () {
      final load = TomServerCallLoad(
        stringBody: '{"name": "John"}',
        contentType: 'application/json',
      );

      expect(load.stringBody, equals('{"name": "John"}'));
      expect(load.contentType, equals('application/json'));
      expect(load.byteBody, isNull);
      expect(load.bodyFields, isNull);
    });

    test('should create load with byte body', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final load = TomServerCallLoad(
        byteBody: bytes,
        contentType: 'application/octet-stream',
      );

      expect(load.byteBody, equals(bytes));
      expect(load.contentType, equals('application/octet-stream'));
      expect(load.stringBody, isNull);
      expect(load.bodyFields, isNull);
    });

    test('should create load with body fields', () {
      final load = TomServerCallLoad(
        bodyFields: {'username': 'john', 'password': 'secret'},
      );

      expect(load.bodyFields, equals({'username': 'john', 'password': 'secret'}));
      expect(load.stringBody, isNull);
      expect(load.byteBody, isNull);
    });

    test('should create load with encoding', () {
      final load = TomServerCallLoad(
        stringBody: 'test content',
        encoding: utf8,
      );

      expect(load.encoding, equals(utf8));
    });

    test('should create load with content length', () {
      final load = TomServerCallLoad(
        stringBody: 'test',
        contentLength: 4,
      );

      expect(load.contentLength, equals(4));
    });

    test('should allow setting content length after creation', () {
      final load = TomServerCallLoad(stringBody: 'test');
      load.contentLength = 100;

      expect(load.contentLength, equals(100));
    });
  });

  // ==========================================================================
  // TomServerCallError Tests
  // ==========================================================================
  group('TomServerCallError', () {
    test('should create error with default values', () {
      final error = TomServerCallError();

      expect(error.statusCode, equals(200));
      expect(error.internalError, equals(0));
      expect(error.hasError, isFalse);
      expect(error.isRedirect, isFalse);
    });

    test('should create error with status code', () {
      final error = TomServerCallError(statusCode: 404);

      expect(error.statusCode, equals(404));
      expect(error.hasError, isTrue);
    });

    test('should create error with internal error', () {
      final error = TomServerCallError(internalError: TomServerCallError.jsonDecodingError);

      expect(error.internalError, equals(TomServerCallError.jsonDecodingError));
      expect(error.hasError, isTrue);
    });

    test('should create error with response', () {
      final error = TomServerCallError(
        statusCode: 400,
        response: 'Bad Request',
        reasonPhrase: 'Bad Request',
      );

      expect(error.response, equals('Bad Request'));
      expect(error.reasonPhrase, equals('Bad Request'));
    });

    test('should create error with headers', () {
      final error = TomServerCallError(
        headers: {'Content-Type': 'application/json'},
      );

      expect(error.headers['Content-Type'], equals('application/json'));
    });

    test('should create error with redirect status', () {
      final error = TomServerCallError(
        statusCode: 302,
        isRedirect: true,
      );

      expect(error.isRedirect, isTrue);
    });

    test('should create error with exception', () {
      final exception = FormatException('Invalid format');
      final error = TomServerCallError(
        statusCode: 500,
        exception: exception,
      );

      expect(error.exception, isA<FormatException>());
    });

    test('should create error with stack trace', () {
      final stackTrace = StackTrace.current;
      final error = TomServerCallError(
        statusCode: 500,
        stackTrace: stackTrace,
      );

      expect(error.stackTrace, isNotNull);
    });

    test('should create error with status code response', () {
      final responseObject = {'message': 'Not found', 'code': 'NOT_FOUND'};
      final error = TomServerCallError(
        statusCode: 404,
        statusCodeResponse: responseObject,
      );

      expect(error.statusCodeResponse, equals(responseObject));
    });

    test('hasError returns true for non-200 status', () {
      expect(TomServerCallError(statusCode: 201).hasError, isTrue);
      expect(TomServerCallError(statusCode: 400).hasError, isTrue);
      expect(TomServerCallError(statusCode: 500).hasError, isTrue);
    });

    test('hasError returns false only for 200 with no internal error', () {
      expect(TomServerCallError(statusCode: 200, internalError: 0).hasError, isFalse);
    });

    group('error constants', () {
      test('jsonDecodingError is defined', () {
        expect(TomServerCallError.jsonDecodingError, equals(1));
      });

      test('noResponseError is defined', () {
        expect(TomServerCallError.noResponseError, equals(2));
      });

      test('serverError is defined', () {
        expect(TomServerCallError.serverError, equals(2));
      });
    });
  });

  // ==========================================================================
  // TomServerConnectionException Tests
  // ==========================================================================
  group('TomServerConnectionException', () {
    test('should create exception with key and message', () {
      final exception = TomServerConnectionException(
        'connection.error',
        'Connection failed',
      );

      expect(exception.key, equals('connection.error'));
      expect(exception.defaultUserMessage, equals('Connection failed'));
    });

    test('should create exception with parameters', () {
      final exception = TomServerConnectionException(
        'connection.error',
        'Connection to host failed',
        parameters: {'host': 'api.example.com', 'port': 443},
      );

      expect(exception.parameters, isNotNull);
      expect(exception.parameters!['host'], equals('api.example.com'));
      expect(exception.parameters!['port'], equals(443));
    });

    test('should create exception with root exception', () {
      final rootException = SocketException('Network unreachable');
      final exception = TomServerConnectionException(
        'connection.network_error',
        'Network error',
        rootException: rootException,
      );

      expect(exception.rootException, isA<SocketException>());
    });

    test('should be throwable', () {
      expect(
        () => throw TomServerConnectionException('error.key', 'Error message'),
        throwsA(isA<TomServerConnectionException>()),
      );
    });
  });

  // ==========================================================================
  // TomRequestAbortedException Tests
  // ==========================================================================
  group('TomRequestAbortedException', () {
    test('should create exception with key and message', () {
      final exception = TomRequestAbortedException(
        'request.aborted',
        'Request was aborted',
      );

      expect(exception.key, equals('request.aborted'));
      expect(exception.defaultUserMessage, equals('Request was aborted'));
    });

    test('should create exception with request UUID', () {
      final exception = TomRequestAbortedException(
        'request.aborted',
        'Request was aborted',
        requestUuid: 'req-123-456',
      );

      expect(exception.requestUuid, equals('req-123-456'));
    });

    test('should be throwable', () {
      expect(
        () => throw TomRequestAbortedException('aborted', 'Aborted'),
        throwsA(isA<TomRequestAbortedException>()),
      );
    });
  });
}
