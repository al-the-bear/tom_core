import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart'
    show
        BaseClient,
        BaseRequest,
        ClientException,
        Request,
        StreamedResponse,
        RequestAbortedException;
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'http_connection_test.reflection.dart';
import 'support/recording_client.dart';

// ============================================================================
// Reflected DTOs for the TomServerEndpoint.send tests
// ============================================================================

/// The request DTO sent by the endpoint tests.
@tomReflector
class EndpointRequest {
  /// Free-text payload, echoed into the request body.
  String note = '';

  /// Creates an empty request.
  EndpointRequest();
}

/// The response DTO the endpoint tests declare as `R`.
@tomReflector
class EndpointResponse {
  /// Identifier the server assigns; empty when nothing was deserialized.
  String id = '';

  /// Creates an empty response.
  EndpointResponse();
}

/// The DTO a `statusCodeResponseTypes` entry maps a failing status to.
@tomReflector
class EndpointFailure {
  /// The server's reason for refusing.
  String reason = '';

  /// Creates an empty failure.
  EndpointFailure();
}

// ============================================================================
// Tests for the HTTP Connection Module
// ============================================================================

void main() {
  initializeReflection();

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

      test('attachment is a compile-time constant', () {
        // A `const` context only accepts a `const` field, so this line *is* the
        // assertion: it stops compiling the moment the field becomes mutable
        // again.
        const List<String> dispositions = [TomContentDisposition.attachment];
        expect(dispositions.single, equals('attachment'));
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

      // The map is shared by every consumer of the library, so a single
      // caller writing it would silently reroute method lookup process-wide.
      test('is unmodifiable', () {
        expect(
          () => TomHttpMethod.methods['GET'] = TomHttpMethod.post,
          throwsUnsupportedError,
        );
        expect(
          () => TomHttpMethod.methods.remove('GET'),
          throwsUnsupportedError,
        );
        expect(() => TomHttpMethod.methods.clear(), throwsUnsupportedError);
        expect(TomHttpMethod.methods['GET'], equals(TomHttpMethod.get));
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

      test('reads back every constant this class renders', () {
        // `parse` exists to read a `Content-Type` header, and the header this
        // module writes is the one case it is guaranteed to meet. Asserted over
        // every constant rather than a sample, because the ones that differ are
        // precisely the ones with no charset — the default would otherwise
        // invent a `UTF-8` the header never carried.
        const constants = <TomMimeType>[
          TomMimeType.none,
          TomMimeType.plainText,
          TomMimeType.ics,
          TomMimeType.html,
          TomMimeType.css,
          TomMimeType.csv,
          TomMimeType.javascript,
          TomMimeType.json,
          TomMimeType.xml,
          TomMimeType.octetStream,
          TomMimeType.pdf,
          TomMimeType.rtf,
          TomMimeType.pkcs8,
          TomMimeType.zip,
          TomMimeType.multipartFormData,
          TomMimeType.multipartByteranges,
          TomMimeType.urlEncoded,
        ];

        for (final constant in constants) {
          final header = constant.toHeaderValue();
          expect(
            TomMimeType.parse(header),
            equals(constant),
            reason: 'round trip failed for $header',
          );
        }
      });

      test('reads back a value carrying codecs', () {
        // Codecs are rendered as a second parameter and count towards equality,
        // so a round trip that stopped at charset would still be a half one.
        const value = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1.42E01E', 'mp4a.40.2'],
        );

        expect(TomMimeType.parse(value.toHeaderValue()), equals(value));
      });

      test('reads the charset a header actually carries', () {
        final parsed = TomMimeType.parse('text/html;charset=ISO-8859-1');

        expect(parsed.charset, equals('ISO-8859-1'));
        expect(
          parsed,
          equals(TomMimeType('text', 'html', charset: 'ISO-8859-1')),
        );
      });

      test('leaves charset null when the header names none', () {
        // A header states what it states: reporting UTF-8 for a `Content-Type`
        // that never mentioned a charset is an invention, and it is the reason
        // a parsed `application/pdf` used to mismatch the constant.
        expect(TomMimeType.parse('application/pdf').charset, isNull);
      });

      test('tolerates the spacing and quoting real headers use', () {
        // `Content-Type: text/html; charset="utf-8"` is ordinary — RFC 9110
        // allows optional whitespace after the separator and a quoted parameter
        // value. Parameter *names* are case-insensitive; the value is kept
        // verbatim, since that is what the sender said.
        final parsed = TomMimeType.parse('text/html; CharSet="utf-8"');

        expect(parsed.primaryType, equals('text'));
        expect(parsed.subType, equals('html'));
        expect(parsed.charset, equals('utf-8'));
      });

      test('ignores parameters it has no field for', () {
        // A multipart request always carries a boundary. Rejecting or
        // mis-storing it would make `parse` unusable on exactly the header it
        // exists to read.
        final parsed = TomMimeType.parse(
          'multipart/form-data; boundary=----WebKitFormBoundary7MA4YWx',
        );

        expect(parsed.isEqualType(TomMimeType.multipartFormData), isTrue);
        expect(parsed.charset, isNull);
      });

      test('echoes the media type as the sender spelled it', () {
        // Equality sees through case; the *fields* do not rewrite it. A caller
        // that reads a header and echoes it back reproduces what it received,
        // which is the same rule this module already applies to a charset.
        final parsed = TomMimeType.parse('TEXT/HTML;charset=UTF-8');

        expect(parsed.primaryType, equals('TEXT'));
        expect(parsed.subType, equals('HTML'));
        expect(parsed.toHeaderValue(), equals('TEXT/HTML;charset=UTF-8'));
      });

      test(
        'still rejects a media type with multiple slashes and parameters',
        () {
          // The parameter section must not become a way to smuggle a malformed
          // media type past the check.
          expect(
            () => TomMimeType.parse('application/json/extra;charset=UTF-8'),
            throwsA(isA<TomMimeTypeException>()),
          );
        },
      );
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

      test('recognises a text type whatever case it is spelled in', () {
        // The same case-insensitivity the comparisons apply: deciding whether a
        // body is text is exactly the question that arises after reading a
        // header somebody else wrote.
        expect(TomMimeType.parse('TEXT/HTML').isText, isTrue);
        expect(TomMimeType.parse('Application/JSON').isText, isTrue);
        expect(TomMimeType.parse('APPLICATION/VND.API+XML').isText, isTrue);
        expect(TomMimeType.parse('APPLICATION/PDF').isText, isFalse);
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

      test('should include single codec with ;codecs= prefix', () {
        const mimeType = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1.42E01E'],
        );
        // A single codec must still carry the ;codecs= prefix (RFC 6381).
        expect(
          mimeType.toHeaderValue(),
          equals('video/mp4;codecs=avc1.42E01E'),
        );
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

      test('should not be equal for different charsets', () {
        // Charset is part of identity: `text/html;charset=UTF-8` and the same
        // type in Latin-1 decode to different characters, so a value is not
        // interchangeable with one that differs only there. `isEqualType` is
        // the comparison that ignores parameters, and the server reaches for it
        // by name where parameter-blind matching is what it wants.
        final utf8Html = TomMimeType('text', 'html', charset: 'UTF-8');
        final latin1Html = TomMimeType('text', 'html', charset: 'ISO-8859-1');

        expect(utf8Html == latin1Html, isFalse);
        expect(utf8Html.isEqualType(latin1Html), isTrue);
      });

      test('equal values hash equally and collapse in a hash set', () {
        // The equals/hashCode contract, asserted on values built separately
        // rather than on canonicalized constants — a `const` pair shares one
        // instance and so cannot detect a hashCode that disagrees with `==`.
        final left = TomMimeType('application', 'json');
        final right = TomMimeType('application', 'json');

        expect(left == right, isTrue);
        expect(left.hashCode, equals(right.hashCode));
        expect({left, right}, hasLength(1));
        expect({left: 'v'}[right], equals('v'));
      });

      test(
        'equal codecs hash equally though the lists are distinct objects',
        () {
          // `Object.hash` on a List hashes the list *object*, so two values with
          // equal codec content hashed differently while `==` compared them
          // element-wise — the same contract break as charset, one field over.
          final left = TomMimeType(
            'video',
            'mp4',
            charset: null,
            codecs: ['avc1', 'mp4a'],
          );
          final right = TomMimeType(
            'video',
            'mp4',
            charset: null,
            codecs: ['avc1', 'mp4a'],
          );

          expect(left == right, isTrue);
          expect(left.hashCode, equals(right.hashCode));
          expect({left, right}, hasLength(1));
        },
      );

      test('matches a media type spelled in a different case', () {
        // RFC 2045 §5.1 makes the type and subtype case-insensitive, so a
        // server writing `TEXT/HTML` names the constant's media type. Hashing
        // has to agree or the value is equal but unfindable in a set or map.
        final shouted = TomMimeType.parse('TEXT/HTML;charset=UTF-8');

        expect(shouted == TomMimeType.html, isTrue);
        expect(shouted.hashCode, equals(TomMimeType.html.hashCode));
        expect({TomMimeType.html, shouted}, hasLength(1));
        expect({TomMimeType.html: 'v'}[shouted], equals('v'));
      });

      test('matches a charset spelled in a different case', () {
        // `charset=utf-8` and `charset=UTF-8` name one encoding. The charset is
        // part of identity, so equality has to see through its spelling the
        // same way it does through the media type's.
        final lower = TomMimeType.parse('application/json;charset=utf-8');

        expect(lower == TomMimeType.json, isTrue);
        expect(lower.hashCode, equals(TomMimeType.json.hashCode));
      });

      test('keeps codecs case-sensitive, because their case is data', () {
        // RFC 6381 codec strings are not case-insensitive: `avc1.42E01E`
        // encodes profile and level as hex, so folding the case would merge
        // two values that describe different streams.
        const upper = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1.42E01E'],
        );
        const lower = TomMimeType(
          'video',
          'mp4',
          charset: null,
          codecs: ['avc1.42e01e'],
        );

        expect(upper == lower, isFalse);
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

      test('ignores the case of the media type', () {
        // This is the comparison the server reaches for when matching an
        // incoming `content-type` against a declared constant
        // (`tomConsumesForm`), so a case-sensitive version leaves the caller no
        // escape hatch at all.
        expect(
          const TomMimeType('TEXT', 'HTML').isEqualType(TomMimeType.html),
          isTrue,
        );
        expect(
          TomMimeType.parse(
            'Multipart/Form-Data; boundary=x',
          ).isEqualType(TomMimeType.multipartFormData),
          isTrue,
        );
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
          StaticFileMimetypeMapping.getMimeType('.ogv')?.primaryType,
          equals('video'),
        );
      });

      test('should return correct mime type for audio extensions', () {
        expect(
          StaticFileMimetypeMapping.getMimeType('.mp3')?.primaryType,
          equals('audio'),
        );
        // RFC 5334 assigns `.ogg` to audio/ogg and `.ogv` to video/ogg; the
        // extension is audio's because implementations predating the split
        // read a `.ogg` file as Vorbis audio.
        expect(
          StaticFileMimetypeMapping.getMimeType('.ogg')?.primaryType,
          equals('audio'),
        );
      });

      test('maps every extension to the type its registry assigns', () {
        // Asserted as one table rather than a handful of samples: the two
        // defects this replaces (`.avi` -> image/avif, `.mpeg` -> video/mpg)
        // were single-entry slips that no sample happened to cover, and a
        // table is the only shape that makes the next one fail here.
        //
        // Each expectation is the IANA registration for that extension, with
        // one documented exception marked below where no registration
        // assigns the extension at all.
        const expected = <String, String>{
          // -- documents and data ------------------------------------------
          '.txt': 'text/plain',
          '.html': 'text/html',
          '.htm': 'text/html',
          '.css': 'text/css',
          '.csv': 'text/csv',
          '.ics': 'text/calendar',
          '.js': 'text/javascript',
          '.json': 'application/json',
          '.xml': 'application/xml',
          '.pdf': 'application/pdf',
          '.wasm': 'application/wasm',
          '.zip': 'application/zip',
          '.rar': 'application/vnd.rar',
          // -- images -------------------------------------------------------
          '.png': 'image/png',
          '.jpg': 'image/jpeg',
          '.jpeg': 'image/jpeg',
          '.svg': 'image/svg+xml',
          '.apng': 'image/apng',
          '.avif': 'image/avif',
          '.gif': 'image/gif',
          '.webp': 'image/webp',
          // The registration is `image/vnd.microsoft.icon`; `image/x-icon` is
          // the widespread but never-registered spelling.
          '.ico': 'image/vnd.microsoft.icon',
          // -- fonts (RFC 8081) ---------------------------------------------
          '.ttf': 'font/ttf',
          '.otf': 'font/otf',
          '.woff': 'font/woff',
          '.woff2': 'font/woff2',
          // -- audio and video ----------------------------------------------
          '.mp3': 'audio/mpeg',
          '.mp4': 'video/mp4',
          '.mpeg': 'video/mpeg',
          '.webm': 'video/webm',
          // RFC 5334 splits the Ogg container by content: audio, video and the
          // generic multiplex each get their own extension.
          '.ogg': 'audio/ogg',
          '.ogv': 'video/ogg',
          '.ogx': 'application/ogg',
          // The QuickTime registration names both extensions, so both map.
          '.qt': 'video/quicktime',
          '.mov': 'video/quicktime',
          // Unregistered: IANA assigns no media type to AVI at all, so the
          // de-facto type every server and browser uses is the only option.
          '.avi': 'video/x-msvideo',
        };

        for (final entry in expected.entries) {
          final mapped = StaticFileMimetypeMapping.getMimeType(entry.key);
          expect(mapped, isNotNull, reason: 'no mapping for ${entry.key}');
          expect(
            '${mapped!.primaryType}/${mapped.subType}',
            equals(entry.value),
            reason: 'wrong media type for ${entry.key}',
          );
        }
      });

      test('serves the text types the module itself declares', () {
        // The gap this closes was not a missing *type* but a missing table
        // row: the class already defined a constant for each of these, so an
        // `.html` file served from a Tom app downloaded as a binary blob
        // while `TomMimeType.html` sat unused two hundred lines above the
        // table. Asserted against the constants rather than against literal
        // strings so the two cannot drift apart again.
        const declared = <String, TomMimeType>{
          '.txt': TomMimeType.plainText,
          '.html': TomMimeType.html,
          '.htm': TomMimeType.html,
          '.css': TomMimeType.css,
          '.csv': TomMimeType.csv,
          '.ics': TomMimeType.ics,
          '.xml': TomMimeType.xml,
          '.js': TomMimeType.javascript,
          '.json': TomMimeType.json,
          '.pdf': TomMimeType.pdf,
          '.zip': TomMimeType.zip,
        };

        for (final entry in declared.entries) {
          expect(
            StaticFileMimetypeMapping.getMimeType(entry.key),
            equals(entry.value),
            reason: '${entry.key} should map to the declared constant',
          );
        }
      });

      test('declares no charset on binary entries', () {
        // `TomMimeType` defaults `charset` to UTF-8, so a binary entry that
        // forgets to say `charset: null` sends `font/woff2;charset=UTF-8` —
        // a parameter the registration does not define, on bytes that have no
        // encoding. Every binary row in the table opts out explicitly, and
        // this is what keeps the next one from inheriting the default.
        const binary = <String>[
          '.ico',
          '.otf',
          '.woff',
          '.woff2',
          '.ttf',
          '.png',
          '.jpg',
          '.gif',
          '.webp',
          '.apng',
          '.avif',
          '.mp3',
          '.mp4',
          '.mpeg',
          '.mov',
          '.qt',
          '.webm',
          '.avi',
          '.ogg',
          '.ogv',
          '.ogx',
          '.wasm',
          '.pdf',
          '.rar',
          '.zip',
        ];

        for (final extension in binary) {
          final mapped = StaticFileMimetypeMapping.getMimeType(extension);
          expect(mapped, isNotNull, reason: 'no mapping for $extension');
          expect(
            mapped!.charset,
            isNull,
            reason: '$extension is binary and must not declare a charset',
          );
        }
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
        final api = TomApi(id: 'testApi', name: 'Test API', endpoints: []);

        registry.register(api);

        expect(registry.apis.containsKey('testApi'), isTrue);
        expect(registry.apis['testApi'], equals(api));
      });

      test('should replace API with same id', () {
        final api1 = TomApi(id: 'testApi', name: 'Original API', endpoints: []);
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
        final api = TomApi(id: 'testApi', name: 'Test API', endpoints: []);
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
        final api = TomApi(id: 'testApi', name: 'Test API', endpoints: []);

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
        final api = TomApi(id: 'minimalApi', endpoints: []);

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
        final api = TomApi(id: 'apiWithEndpoints', endpoints: [endpoint]);

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
        final api = TomApi(id: 'testApi', endpoints: [endpoint]);

        final retrieved = api['myEndpoint'];

        expect(retrieved, equals(endpoint));
      });

      test('should throw TomEndpointException for unknown endpoint', () {
        final api = TomApi(id: 'testApi', endpoints: []);

        expect(
          () => api['unknownEndpoint'],
          throwsA(isA<TomEndpointException>()),
        );
      });
    });

    group('bracket assignment operator []=', () {
      test('should add endpoint using assignment', () {
        final api = TomApi(id: 'testApi', endpoints: []);
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
        // No contract-declared policy by default: the server pipeline falls back
        // to its global protection default (or a handler-side annotation).
        expect(endpoint.access, isNull);
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

    group('contract-declared access (G-API-3)', () {
      test('carries the declared TomAccessControl policy', () {
        const policy = TomRoleAccess(['admin']);
        final endpoint = TomApiEndpoint(
          id: 'guardedEndpoint',
          method: TomHttpMethod.get,
          access: policy,
        );

        expect(identical(endpoint.access, policy), isTrue);
      });

      test('one shared const policy backs many endpoints', () {
        const authenticated = TomAuthenticatedAccess();
        final a = TomApiEndpoint(
          id: 'a',
          method: TomHttpMethod.get,
          access: authenticated,
        );
        final b = TomApiEndpoint(
          id: 'b',
          method: TomHttpMethod.get,
          access: authenticated,
        );

        expect(identical(a.access, b.access), isTrue);
      });
    });

    group('api property', () {
      test('should return parent API when set', () {
        final endpoint = TomApiEndpoint(
          id: 'testEndpoint',
          method: TomHttpMethod.get,
        );
        final api = TomApi(id: 'parentApi', endpoints: [endpoint]);

        expect(endpoint.api, equals(api));
      });

      test('should throw TomEndpointException when API not set', () {
        final endpoint = TomApiEndpoint(
          id: 'orphanEndpoint',
          method: TomHttpMethod.get,
        );

        expect(() => endpoint.api, throwsA(isA<TomEndpointException>()));
      });
    });

    // The client-side inverse of the server pipeline's URL-parameter binding:
    // the server folds path captures and named query parameters *into* a request
    // DTO, this builds the URL those values came from. The two are asserted
    // against the same rules on purpose — a second spelling of either would
    // agree with the other only by inspection.
    group('resolveUri', () {
      TomApiEndpoint endpointIn(TomApi api, String endpointId) =>
          api[endpointId];

      TomApi itemsApi({
        String? apiUri = '/api/items',
        String? endpointUri = '/{id}',
        Map<String, String> mapping = const {'id': 'id'},
      }) => TomApi(
        id: 'items-${apiUri}-$endpointUri-${mapping.length}',
        uri: apiUri,
        endpoints: [
          TomApiEndpoint(
            id: 'byId',
            uri: endpointUri,
            method: TomHttpMethod.get,
            urlParameterMapping: mapping,
          ),
        ],
      );

      test('a versioned API is served under its /v<version> segment', () {
        final v2 = TomApi(
          id: 'orders-v2',
          uri: '/orders',
          version: 2,
          endpoints: [
            TomApiEndpoint(id: 'list', uri: '/all', method: TomHttpMethod.get),
          ],
        );
        expect(v2.path, '/v2/orders');
        expect(v2['list'].path, '/v2/orders/all');
        expect(
          v2['list']
              .resolveUri(Uri.parse('https://api.example.com'))
              .toString(),
          'https://api.example.com/v2/orders/all',
        );
        // Unversioned, the path is the URI as declared.
        expect(itemsApi().path, '/api/items');
        expect(
          () => TomApi(id: 'bad', version: 0, endpoints: const []),
          throwsA(
            isA<TomEndpointException>().having(
              (e) => e.key,
              'key',
              'apis.version.invalid',
            ),
          ),
        );
      });

      test('joins the API base, the endpoint path and the host base', () {
        final endpoint = endpointIn(itemsApi(endpointUri: ''), 'byId');

        expect(
          endpoint.resolveUri(Uri.parse('https://api.example.com')).toString(),
          equals('https://api.example.com/api/items'),
        );
      });

      test('keeps a path already carried by the base URI', () {
        // The base may itself be mounted under a prefix; concatenating the raw
        // strings would produce `/gateway/preferences` → `/gatewaypreferences`.
        final endpoint = endpointIn(
          itemsApi(apiUri: '/preferences', endpointUri: ''),
          'byId',
        );

        expect(
          endpoint
              .resolveUri(Uri.parse('https://api.example.com/gateway'))
              .toString(),
          equals('https://api.example.com/gateway/preferences'),
        );
      });

      test('substitutes a path capture from its mapped field', () {
        final endpoint = endpointIn(
          itemsApi(mapping: const {'id': 'itemId'}),
          'byId',
        );

        expect(
          endpoint
              .resolveUri(
                Uri.parse('https://api.example.com'),
                parameters: {'itemId': 4711},
              )
              .toString(),
          equals('https://api.example.com/api/items/4711'),
        );
      });

      test('substitutes an unmapped path capture by its own name', () {
        // The identity fallback the server applies to path captures: a capture
        // is part of the route, so binding it by its own name is safe.
        final endpoint = endpointIn(itemsApi(mapping: const {}), 'byId');

        expect(
          endpoint
              .resolveUri(
                Uri.parse('https://api.example.com'),
                parameters: {'id': 'a-key'},
              )
              .toString(),
          equals('https://api.example.com/api/items/a-key'),
        );
      });

      test('escapes a value that would otherwise change the path', () {
        final endpoint = endpointIn(itemsApi(), 'byId');

        expect(
          endpoint
              .resolveUri(
                Uri.parse('https://api.example.com'),
                parameters: {'id': 'tom/theme?x=1'},
              )
              .toString(),
          // `=` is legal inside a path segment and stays as it is; the two
          // characters that would have changed the *address* — the separator
          // and the query introducer — are escaped, so the value addresses one
          // segment of one route.
          equals('https://api.example.com/api/items/tom%2Ftheme%3Fx=1'),
        );
      });

      test('refuses a capture no parameter answers', () {
        final endpoint = endpointIn(itemsApi(), 'byId');

        expect(
          () => endpoint.resolveUri(Uri.parse('https://api.example.com')),
          throwsA(
            isA<TomEndpointException>().having(
              (error) => error.key,
              'key',
              'apis.endpoint.missing_url_parameter',
            ),
          ),
        );
      });

      test('appends a mapped parameter that is not a path capture', () {
        // The query half of the same mapping: `state` is declared, so it binds.
        final api = TomApi(
          id: 'callbackApi',
          uri: '/oauth',
          endpoints: [
            TomApiEndpoint(
              id: 'callback',
              uri: '/callback',
              method: TomHttpMethod.get,
              urlParameterMapping: const {
                'code': 'code',
                'error_description': 'errorDescription',
              },
            ),
          ],
        );

        expect(
          endpointIn(api, 'callback')
              .resolveUri(
                Uri.parse('https://api.example.com'),
                parameters: {'code': 'abc', 'errorDescription': 'no such user'},
              )
              .toString(),
          equals(
            'https://api.example.com/oauth/callback'
            '?code=abc&error_description=no+such+user',
          ),
        );
      });

      test('omits a mapped query parameter with no value', () {
        final api = TomApi(
          id: 'optionalQueryApi',
          uri: '/oauth',
          endpoints: [
            TomApiEndpoint(
              id: 'callback',
              uri: '/callback',
              method: TomHttpMethod.get,
              urlParameterMapping: const {'code': 'code', 'state': 'state'},
            ),
          ],
        );

        expect(
          endpointIn(api, 'callback')
              .resolveUri(
                Uri.parse('https://api.example.com'),
                parameters: {'code': 'abc'},
              )
              .toString(),
          equals('https://api.example.com/oauth/callback?code=abc'),
        );
      });

      test('binds a parameter that is both capture and query only as the '
          'capture', () {
        // The server documents that a path capture wins over a query parameter
        // mapped to the same field; sending both would be the client asserting
        // the same value twice.
        final endpoint = endpointIn(itemsApi(), 'byId');

        final resolved = endpoint.resolveUri(
          Uri.parse('https://api.example.com'),
          parameters: {'id': 'x'},
        );

        expect(resolved.path, equals('/api/items/x'));
        expect(resolved.hasQuery, isFalse);
      });

      test('binds a field reached by two URL names only as the capture', () {
        // Capture-wins is a rule about the *field*, not about the URL name that
        // happens to spell it: the server folds query parameters into the
        // request DTO first and lets the path capture overwrite the same field,
        // so a second URL name for an already-captured field would put the same
        // value on the wire twice and leak the field mapping into the query.
        final endpoint = endpointIn(
          itemsApi(mapping: const {'id': 'itemId', 'item_id': 'itemId'}),
          'byId',
        );

        final resolved = endpoint.resolveUri(
          Uri.parse('https://api.example.com'),
          parameters: {'itemId': 42},
        );

        expect(resolved.path, equals('/api/items/42'));
        expect(resolved.hasQuery, isFalse);
      });

      test('resolves the preferences contract exactly as the server mounts '
          'it', () {
        // The contract this whole resolver exists to serve, asserted against the
        // real declaration rather than a stand-in.
        final read =
            tomUserPreferencesApi[tomUserPreferencesReadEndpointId]
                as TomApiEndpoint<
                  TomUserPreferenceDto,
                  TomUserPreferenceKeyRequest
                >;

        expect(
          read
              .resolveUri(
                Uri.parse('http://localhost:8080'),
                parameters: {'key': TomUserPreferenceKeys.theme},
              )
              .toString(),
          equals('http://localhost:8080/preferences/tom.theme'),
        );
      });

      test('the preferences write endpoint cannot restate the key in the '
          'URL', () {
        // The write request carries a `key` field of its own, so the endpoint
        // declares no `{key}` capture and no mapping: a caller that offered a
        // key here has nowhere to put it, and a request whose URL and body
        // named different preferences is not expressible.
        final write = tomUserPreferencesApi[tomUserPreferencesWriteEndpointId];

        expect(
          write
              .resolveUri(
                Uri.parse('http://localhost:8080'),
                parameters: {'key': TomUserPreferenceKeys.language},
              )
              .toString(),
          equals('http://localhost:8080/preferences'),
        );
        expect(write.urlParameterMapping, isEmpty);
      });
    });
  });

  // ==========================================================================
  // TomClientRemoteContext Tests
  // ==========================================================================
  group('TomClientRemoteContext', () {
    setUp(() {
      // Reset current to null before each test. `current` has no setter —
      // reassigning it would change which remote every subsequent call
      // addresses — so the reset goes through the declared test seam.
      TomClientRemoteContext.resetCurrent();
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

    // The scoped helper, not a mutable static, is the supported way to point
    // calls at a different remote — it is
    // zone-carried, so the caller's own continuation never sees it. That
    // bounds reachability, not lifetime: anything the body *schedules* (a
    // fire-and-forget request, a timer) inherits the zone and still targets
    // the scoped remote whenever it later runs.
    group('runWithContext', () {
      test('installs the context for the duration of the body', () {
        final scoped = TomClientRemoteContext(
          Uri.parse('https://scoped.example.com'),
        );

        final seen = TomClientRemoteContext.runWithContext(
          scoped,
          () => TomClientRemoteContext.current,
        );

        expect(seen, same(scoped));
        expect(
          TomClientRemoteContext.current,
          isNull,
          reason: 'the caller continues without the scoped context',
        );
      });

      test('overrides an already-set process context, then restores it', () {
        final installed = TomClientRemoteContext(
          Uri.parse('https://installed.example.com'),
        );
        final scoped = TomClientRemoteContext(
          Uri.parse('https://scoped.example.com'),
        );
        TomClientRemoteContext.setCurrent(installed);

        final seen = TomClientRemoteContext.runWithContext(
          scoped,
          () => TomClientRemoteContext.current,
        );

        expect(seen, same(scoped));
        expect(TomClientRemoteContext.current, same(installed));
      });

      test('nests, innermost wins', () {
        final outer = TomClientRemoteContext(
          Uri.parse('https://outer.example.com'),
        );
        final inner = TomClientRemoteContext(
          Uri.parse('https://inner.example.com'),
        );

        final seen = TomClientRemoteContext.runWithContext(outer, () {
          final innerSeen = TomClientRemoteContext.runWithContext(
            inner,
            () => TomClientRemoteContext.current,
          );
          return [innerSeen, TomClientRemoteContext.current];
        });

        expect(seen, [same(inner), same(outer)]);
      });

      test('spans asynchronous gaps inside the body', () async {
        final scoped = TomClientRemoteContext(
          Uri.parse('https://scoped.example.com'),
        );

        final seen = await TomClientRemoteContext.runWithContext(
          scoped,
          () async {
            await Future<void>.delayed(Duration.zero);
            return TomClientRemoteContext.current;
          },
        );

        expect(seen, same(scoped));
      });

      test(
        'work scheduled inside the body still targets the scoped context',
        () async {
          // The zone bounds reachability, not lifetime. A fire-and-forget
          // request started here keeps addressing the scoped remote long after
          // `runWithContext` returned — which is the half of the guarantee the
          // dartdoc used to deny.
          final scoped = TomClientRemoteContext(
            Uri.parse('https://scoped.example.com'),
          );
          final deferred = Completer<TomClientRemoteContext?>();

          TomClientRemoteContext.runWithContext(scoped, () {
            Timer.run(() => deferred.complete(TomClientRemoteContext.current));
          });

          // The caller is already back out of the context...
          expect(TomClientRemoteContext.current, isNull);
          // ...but the callback the body scheduled is not.
          expect(await deferred.future, same(scoped));
        },
      );
    });

    group('resetCurrent', () {
      test('clears the context so setCurrent can run again', () {
        final first = TomClientRemoteContext(
          Uri.parse('https://first.example.com'),
        );
        final second = TomClientRemoteContext(
          Uri.parse('https://second.example.com'),
        );
        TomClientRemoteContext.setCurrent(first);

        TomClientRemoteContext.resetCurrent();

        expect(TomClientRemoteContext.current, isNull);
        TomClientRemoteContext.setCurrent(second);
        expect(TomClientRemoteContext.current, same(second));
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
        expect(specs.headers['Content-Type'], equals('application/json'));
        expect(specs.maxRedirects, equals(5));
        expect(specs.persistentConnection, isTrue);
        expect(specs.includeBearerAuthentication, isFalse);
        expect(specs.requestEncoding, equals(utf8));
        expect(specs.fallbackResponseEncoding, equals(latin1));
      });
    });

    group('headers', () {
      // Same contract as TomServerCallError.headers, for the same reason: the
      // declared type says "map", so it has to behave as one however the spec
      // was built.

      test('a spec created without headers accepts one', () {
        final specs = TomServerCallSpecs(
          'GET',
          Uri.parse('https://api.example.com/users'),
        );

        expect(() => specs.headers['X-Trace'] = 'abc', returnsNormally);
        expect(specs.headers['X-Trace'], equals('abc'));
      });

      test(
        'the spec owns its headers rather than aliasing the caller\'s map',
        () {
          final source = <String, String>{'Content-Type': 'application/json'};
          final specs = TomServerCallSpecs(
            'POST',
            Uri.parse('https://api.example.com/users'),
            headers: source,
          );

          specs.headers['X-Trace'] = 'abc';

          expect(source.containsKey('X-Trace'), isFalse);
          expect(specs.headers['Content-Type'], equals('application/json'));
        },
      );
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

      test('the caller keeps no handle on the form fields it passed in', () {
        // Without the copy the load would share the caller's map, and a body
        // could be added to — or emptied out of — a validated load through a
        // reference the load never sees.
        final fields = {'key': 'value'};
        final load = TomServerCallLoad(bodyFields: fields);

        fields['smuggled'] = 'in';

        expect(load.bodyFields, equals({'key': 'value'}));
      });

      test(
        'an absent form body stays absent rather than becoming an empty one',
        () {
          // An empty map is a body: it counts towards the single-body rule and
          // applyLoadValues writes it to the request. Copying null into `{}`
          // would quietly give every load a form body.
          final load = TomServerCallLoad(stringBody: 'text');

          expect(load.bodyFields, isNull);
        },
      );
    });

    group('immutability', () {
      // The single-body rule is checked once, in the constructor. That check is
      // only worth anything if it describes the object for as long as the object
      // exists — a settable body field would let a caller build a valid load and
      // hand a different, invalid one to applyLoadValues, which applies fields in
      // order and would half-write the request before package:http rejected the
      // second body with a message naming none of this.
      //
      // The guarantee is the compiler's, so nothing at runtime can observe it
      // being lost. It is asserted against the declarations instead: this fails
      // the moment a `final` is dropped, which is the only way to reintroduce the
      // defect.
      test('every field of TomServerCallLoad is final', () {
        const path = 'lib/src/tombase/http_connection/server_connection.dart';
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Expected to find $path relative to ${Directory.current.path}',
        );
        final source = file.readAsStringSync();

        final classStart = source.indexOf('class TomServerCallLoad {');
        expect(
          classStart,
          greaterThan(-1),
          reason: 'TomServerCallLoad is no longer declared in $path',
        );
        final constructorStart = source.indexOf(
          'TomServerCallLoad({',
          classStart,
        );
        expect(
          constructorStart,
          greaterThan(classStart),
          reason: 'TomServerCallLoad has no generative constructor',
        );
        final fieldSection = source.substring(classStart, constructorStart);

        // Field declarations only: `<type> <name>;` at class-body indentation.
        final declarations = RegExp(
          r'^  ((?:final )?)([\w<>,? ]+?) (\w+);$',
          multiLine: true,
        ).allMatches(fieldSection);
        expect(
          declarations,
          isNotEmpty,
          reason: 'No field declarations matched — the pattern has drifted',
        );

        final mutable = [
          for (final m in declarations)
            if (m.group(1)!.isEmpty) m.group(3)!,
        ];
        expect(
          mutable,
          isEmpty,
          reason:
              'These fields are settable after construction, so the '
              'constructor check no longer holds for the object: $mutable',
        );
      });
    });

    // A load is only worth the fields it can deliver. These assert what
    // `applyLoadValues` actually puts on the request, because a field that the
    // type accepts and the request never receives reads as configuration and
    // behaves as a comment.
    group('reaches the request', () {
      /// Sends [load] through a [TomServerCall] and returns the request the
      /// client was handed.
      BaseRequest sent(TomServerCallLoad load) {
        final client = _MockClient((request) async => _streamed('{}'));
        TomServerCall(
          client,
          TomServerCallSpecs('POST', Uri.parse('https://api.example.com/x')),
        ).send(load);
        return client.lastRequest!;
      }

      test('the content type a load names is the one that is sent', () {
        // Was silently dropped: `applyLoadValues` never read the field, so
        // `body =` found no content-type header and defaulted the request to
        // `text/plain`. Every TomServerEndpoint call went out mislabelled.
        final request = sent(
          TomServerCallLoad(
            stringBody: '{"name":"John"}',
            contentType: 'application/json',
          ),
        );

        expect(
          TomMimeType.parse(request.headers[TomHeader.contentType]!),
          predicate<TomMimeType>((t) => t.isEqualType(TomMimeType.json)),
          reason: 'the load named application/json',
        );
      });

      test('a load that names no content type still gets the default', () {
        // package:http labels a string body `text/plain` when nothing else
        // says otherwise. Applying the field must not disturb that.
        final request = sent(TomServerCallLoad(stringBody: 'plain words'));

        expect(
          TomMimeType.parse(request.headers[TomHeader.contentType]!),
          predicate<TomMimeType>((t) => t.isEqualType(TomMimeType.plainText)),
        );
      });

      test('the charset follows the encoding the load asked for', () {
        // The content type is applied before the body, which is what lets
        // package:http add the charset to the type the caller named rather
        // than to a type it invented. A type other than `text/plain` is used
        // deliberately: the default is `text/plain`, so the two are only
        // distinguishable when the caller names something else.
        final request = sent(
          TomServerCallLoad(
            stringBody: '<a>näh</a>',
            contentType: 'application/xml',
            encoding: latin1,
          ),
        );

        final type = TomMimeType.parse(request.headers[TomHeader.contentType]!);
        expect(type.isEqualType(TomMimeType.xml), isTrue);
        expect(type.charset?.toLowerCase(), equals('iso-8859-1'));
      });

      test('a form body is labelled as a form', () {
        final request = sent(TomServerCallLoad(bodyFields: {'k': 'v'}));

        expect(
          TomMimeType.parse(request.headers[TomHeader.contentType]!),
          predicate<TomMimeType>((t) => t.isEqualType(TomMimeType.urlEncoded)),
        );
      });

      test('the request derives its own length and refuses to be told one', () {
        // This is why TomServerCallLoad has no contentLength field. The call
        // builds a non-streaming request, whose length is its body's length
        // and whose setter throws for every value. A field for it could hold
        // nothing that did not crash the send, so there is no field.
        final request =
            sent(TomServerCallLoad(stringBody: 'hello!')) as Request;

        expect(request.contentLength, equals(6));
        expect(() => request.contentLength = 6, throwsUnsupportedError);
      });
    });

    group('refuses a form body it could not label', () {
      /// Sends [load] under [specHeaders], returning whatever `send` did.
      void send(TomServerCallLoad load, {Map<String, String>? specHeaders}) {
        TomServerCall(
          _MockClient((request) async => _streamed('{}')),
          TomServerCallSpecs(
            'POST',
            Uri.parse('https://api.example.com/x'),
            headers: specHeaders,
          ),
        ).send(load);
      }

      final refused = throwsA(
        isA<TomServerConnectionException>().having(
          (e) => e.key,
          'key',
          'server.connect.form_body_needs_form_content_type',
        ),
      );

      test('when the load names a content type that is not a form', () {
        // package:http rejects this combination with a bare StateError naming
        // neither the call nor the setting that disagreed, thrown partway
        // through writing the request.
        expect(
          () => send(
            TomServerCallLoad(
              bodyFields: {'k': 'v'},
              contentType: 'application/json',
            ),
          ),
          refused,
        );
      });

      test('when the spec headers name it instead of the load', () {
        // The label has two sources. A check on the load alone would pass this
        // one — which is the shape the module documentation had, reusing a
        // JSON spec for a form body.
        expect(
          () => send(
            TomServerCallLoad(bodyFields: {'k': 'v'}),
            specHeaders: {'Content-Type': 'application/json'},
          ),
          refused,
        );
      });

      test('a form content type carrying parameters is still a form', () {
        expect(
          () => send(
            TomServerCallLoad(
              bodyFields: {'k': 'v'},
              contentType: 'application/x-www-form-urlencoded; charset=utf-8',
            ),
          ),
          returnsNormally,
        );
      });

      test('a non-form content type is fine without a form body', () {
        expect(
          () => send(
            TomServerCallLoad(
              stringBody: '{}',
              contentType: 'application/json',
            ),
          ),
          returnsNormally,
        );
      });

      test('a content type that cannot be parsed is left to package:http', () {
        // Naming a form/label conflict would be a guess: the value states no
        // media type at all, so the fault is the value itself.
        expect(
          () => send(
            TomServerCallLoad(
              bodyFields: {'k': 'v'},
              contentType: 'not-a-media-type',
            ),
          ),
          throwsA(isNot(isA<TomServerConnectionException>())),
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

    group('headers', () {
      // The field is declared `Map<String, Object>`, so a reader takes it for a
      // map they may write to. These pin that the declaration tells the truth
      // on every path that can produce an error, not just the one where the
      // caller happened to supply a map of their own.

      test('a default-constructed error accepts a header', () {
        final error = TomServerCallError();

        expect(() => error.headers['x-trace'] = 'abc', returnsNormally);
        expect(error.headers['x-trace'], equals('abc'));
      });

      test('an error built from a response without headers accepts a header', () {
        // The path that actually occurs: `send` hands the response's header map
        // straight to the error, and a response carrying no headers supplies a
        // const one. Fixing only the parameter default would leave this case —
        // the common one in practice — still throwing.
        final error = TomServerCallError(headers: const {});

        expect(() => error.headers['x-trace'] = 'abc', returnsNormally);
      });

      test(
        'the error owns its headers rather than aliasing the caller\'s map',
        () {
          // `send` passes the live response header map. If the error aliased it,
          // annotating an error would silently rewrite the response it came from.
          final source = <String, Object>{'content-type': 'application/json'};
          final error = TomServerCallError(headers: source);

          error.headers['x-trace'] = 'abc';

          expect(source.containsKey('x-trace'), isFalse);
          expect(error.headers['content-type'], equals('application/json'));
        },
      );
    });

    group('x-tom-error body decoding', () {
      // A Tom server marks its own error format with `x-tom-error: true`, and
      // the constructor is supposed to lift the server's identifiers out of the
      // JSON body. It never did: the decode called a `get` method that no map
      // has, so every such response threw NoSuchMethodError out of the
      // constructor instead of producing an error object. Because `jsonDecode`
      // returns `dynamic` the analyzer could not see it, and no test reached
      // the branch.

      test('lifts the server error fields out of a tom error body', () {
        final error = TomServerCallError(
          statusCode: 403,
          headers: {'x-tom-error': 'true'},
          response:
              '{"errorKey":"access.check.denied","uuid":"srv-1",'
              '"requestUuid":"req-1","autoLog":true,"clientRethrow":true}',
        );

        expect(error.errorKey, equals('access.check.denied'));
        expect(error.uuid, equals('srv-1'));
        expect(error.requestUuid, equals('req-1'));
        expect(error.autoLog, isTrue);
        expect(error.clientRethrow, isTrue);
      });

      test('leaves the fields null when the header is absent', () {
        final error = TomServerCallError(
          statusCode: 403,
          response: '{"errorKey":"access.check.denied","uuid":"srv-1"}',
        );

        expect(error.errorKey, isNull);
        expect(error.uuid, isNull);
      });

      test('tolerates a tom error body missing some fields', () {
        final error = TomServerCallError(
          statusCode: 500,
          headers: {'x-tom-error': 'true'},
          response: '{"errorKey":"internal.handle.failed"}',
        );

        expect(error.errorKey, equals('internal.handle.failed'));
        expect(error.uuid, isNull);
        expect(error.clientRethrow, isNull);
      });

      test('does not throw when the tom error body is not an object', () {
        // A truncated or proxy-rewritten body still carries the header. The
        // constructor must yield an error object describing the HTTP failure
        // rather than raising a second, unrelated failure over it.
        expect(
          () => TomServerCallError(
            statusCode: 502,
            headers: {'x-tom-error': 'true'},
            response: '<html>gateway</html>',
          ),
          returnsNormally,
        );
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

    group('internal error codes', () {
      test('no two codes share a value', () {
        // `noResponseError` and `serverError` were both 2, so a caller
        // switching on `internalError` could not tell "the service said no"
        // from "the service was not reachable" — different handling, and
        // different retries.
        //
        // The codes are read out of the source rather than listed here. A
        // test that names the three it knows about cannot object to a fourth
        // added later with a value already taken, which is exactly how the
        // collision arrived: the suite asserted each constant's value
        // separately and both assertions passed.
        final source = File(
          'lib/src/tombase/http_connection/server_connection.dart',
        ).readAsStringSync();
        final declaration = RegExp(
          r'^\s+static const (\w+)\s*=\s*(-?\d+);',
          multiLine: true,
        );

        final byValue = <int, List<String>>{};
        for (final match in declaration.allMatches(source)) {
          byValue
              .putIfAbsent(int.parse(match.group(2)!), () => <String>[])
              .add(match.group(1)!);
        }

        expect(
          byValue,
          isNotEmpty,
          reason:
              'no `static const <name> = <int>;` found — the declarations '
              'moved or changed shape, so the check below is vacuous',
        );

        final collisions = byValue.entries
            .where((entry) => entry.value.length > 1)
            .map(
              (entry) => '${entry.value.join(" and ")} are both ${entry.key}',
            )
            .toList();

        expect(collisions, isEmpty, reason: collisions.join('; '));
      });

      test('each code keeps the value callers were given', () {
        // Distinctness alone would be satisfied by renumbering everything, so
        // the published values are pinned too.
        expect(TomServerCallError.jsonDecodingError, equals(1));
        expect(TomServerCallError.noResponseError, equals(2));
        expect(TomServerCallError.serverError, equals(3));
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

    group('forUri', () {
      test('takes the host and the explicit port of the URI', () {
        final channel = TomServerChannel.forUri(
          Uri.parse('https://api.example.com:8443/api/v1'),
        );

        expect(channel.host, equals('api.example.com'));
        expect(channel.port, equals(8443));
      });

      test('defaults the port by scheme when the URI names none', () {
        // A URI writes its port only when it differs from its scheme's, so a
        // default that ignored the scheme would open port 80 to every `https`
        // deployment that spells its address the ordinary way.
        expect(
          TomServerChannel.forUri(Uri.parse('https://api.example.com')).port,
          equals(443),
        );
        expect(
          TomServerChannel.forUri(Uri.parse('http://api.example.com')).port,
          equals(80),
        );
      });

      test('falls back to 80 for a scheme with no port of its own', () {
        // `Uri.port` answers 0 for an unknown scheme, which addresses nothing.
        expect(
          TomServerChannel.forUri(Uri.parse('gopher://api.example.com')).port,
          equals(80),
        );
      });

      test('passes the client factory through', () {
        final customFactory = TomHttpClientFactory();
        final channel = TomServerChannel.forUri(
          Uri.parse('https://api.example.com'),
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
  // TomHttpClientAbstractFactory Tests
  // ==========================================================================
  group('TomHttpClientAbstractFactory', () {
    // Every test here installs a global, which is process-wide state.
    tearDown(TomHttpClientFactory.resetGlobalHttpClientFactory);

    test('an implementation supplies the client every channel resolves', () {
      // `_MockClientFactory` is the whole of what a custom factory has to be:
      // one method returning a client. It implements the contract rather than
      // extending TomHttpClientFactory, so it inherits no delegation it would
      // have to remember to override.
      final produced = _MockClient((_) async => _streamed('global'));
      TomHttpClientFactory.setGlobalHttpClientFactory(
        _MockClientFactory(produced),
      );

      expect(
        TomServerChannel('api.example.com', 443).getClient(),
        same(produced),
      );
    });

    test('an implementation supplies one channel, leaving the global be', () {
      final ambient = _MockClient((_) async => _streamed('ambient'));
      final scoped = _MockClient((_) async => _streamed('scoped'));
      TomHttpClientFactory.setGlobalHttpClientFactory(
        _MockClientFactory(ambient),
      );

      final channel = TomServerChannel(
        'api.example.com',
        443,
        clientFactory: _MockClientFactory(scoped),
      );

      expect(channel.getClient(), same(scoped));
      expect(
        TomServerChannel('api.example.com', 443).getClient(),
        same(ambient),
        reason: 'a per-channel factory is not a registration',
      );
    });

    test('an implementation ends a delegation chain', () {
      // The resolver's cycle guard exists because a delegate may forward again.
      // An implementation of the contract has nothing to forward to, which is
      // why implementing — rather than extending the resolver — is the shape
      // a producing factory wants.
      final produced = _MockClient((_) async => _streamed('x'));
      final delegating = TomHttpClientFactory()
        ..instanceClientFactory = _MockClientFactory(produced);

      expect(delegating.getClient(), same(produced));
    });
  });

  // ==========================================================================
  // TomHttpClientFactory Tests
  // ==========================================================================
  group('TomHttpClientFactory', () {
    // The global factory is process-wide state, so every test here restores it.
    // Without this a test that installs a factory decides what the *next* test
    // resolves to, and the suite's outcome starts depending on its order.
    tearDown(TomHttpClientFactory.resetGlobalHttpClientFactory);

    group('initialize', () {
      test('should allow initialization', () {
        // Should not throw when called
        TomHttpClientFactory.initialize();
        // Can be called multiple times without throwing
        TomHttpClientFactory.initialize();
      });

      test('takes a default factory again after a reset, not before', () {
        // initialize() is deliberately one-shot, so the second call below is
        // ignored — which is why a reset has to exist: without one, the first
        // initialize in a process is final and no later test can install its
        // own default.
        final first = _MockClientFactory(
          _MockClient((_) async => _streamed('1')),
        );
        final second = _MockClientFactory(
          _MockClient((_) async => _streamed('2')),
        );

        TomHttpClientFactory.resetGlobalHttpClientFactory();
        TomHttpClientFactory.initialize(first);
        expect(TomHttpClientFactory().getClient(), same(first.getClient()));

        TomHttpClientFactory.initialize(second);
        expect(
          TomHttpClientFactory().getClient(),
          same(first.getClient()),
          reason: 'initialize is one-shot until reset',
        );

        TomHttpClientFactory.resetGlobalHttpClientFactory();
        TomHttpClientFactory.initialize(second);
        expect(TomHttpClientFactory().getClient(), same(second.getClient()));
      });
    });

    group('setGlobalHttpClientFactory', () {
      test('should accept custom factory', () {
        final customFactory = TomDefaultHttpClientFactory();

        // Should not throw
        TomHttpClientFactory.setGlobalHttpClientFactory(customFactory);
      });

      test('a global that only delegates is refused, not run out of stack', () {
        // A plain TomHttpClientFactory creates no clients — it forwards to the
        // global. Registering one as the global makes it forward to itself, and
        // an unbounded self-call is the worst way to report a wiring mistake:
        // StackOverflowError names neither the factory nor the registration.
        TomHttpClientFactory.setGlobalHttpClientFactory(TomHttpClientFactory());

        expect(
          () => TomHttpClientFactory().getClient(),
          throwsA(
            isA<TomServerConnectionException>().having(
              (e) => e.key,
              'key',
              'server.connect.client_factory_delegation_cycle',
            ),
          ),
        );
      });
    });

    group('constructor', () {
      test('should create factory instance', () {
        final factory = TomHttpClientFactory();

        expect(factory, isNotNull);
        expect(factory.instanceClientFactory, isNull);
      });
    });

    group('delegation', () {
      test('resolves through a delegate that does create clients', () {
        final producer = _MockClientFactory(
          _MockClient((_) async => _streamed('x')),
        );
        final delegating = TomHttpClientFactory()
          ..instanceClientFactory = producer;

        expect(delegating.getClient(), same(producer.getClient()));
      });

      test('refuses a cycle between two factories that both only delegate', () {
        // instanceClientFactory is public and writable, so a cycle need not
        // involve the global at all. Detecting only self-delegation would miss
        // this one and it would still overflow.
        final a = TomHttpClientFactory();
        final b = TomHttpClientFactory();
        a.instanceClientFactory = b;
        b.instanceClientFactory = a;

        expect(
          () => a.getClient(),
          throwsA(
            isA<TomServerConnectionException>().having(
              (e) => e.key,
              'key',
              'server.connect.client_factory_delegation_cycle',
            ),
          ),
        );
      });

      test('stays usable after a refused delegation', () {
        // The guard is re-entrancy state on the instance; if a throw left it
        // set, the factory would refuse every later call and one bad wiring
        // would poison an object that had been repaired.
        final a = TomHttpClientFactory();
        a.instanceClientFactory = a;
        expect(
          () => a.getClient(),
          throwsA(isA<TomServerConnectionException>()),
        );

        final producer = _MockClientFactory(
          _MockClient((_) async => _streamed('x')),
        );
        a.instanceClientFactory = producer;

        expect(a.getClient(), same(producer.getClient()));
      });
    });
  });

  // ==========================================================================
  // TomServerEndpoint Tests
  // ==========================================================================
  group('TomServerEndpoint', () {
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

      expect(
        load.bodyFields,
        equals({'username': 'john', 'password': 'secret'}),
      );
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
      final error = TomServerCallError(
        internalError: TomServerCallError.jsonDecodingError,
      );

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
      final error = TomServerCallError(statusCode: 302, isRedirect: true);

      expect(error.isRedirect, isTrue);
    });

    test('should create error with exception', () {
      final exception = FormatException('Invalid format');
      final error = TomServerCallError(statusCode: 500, exception: exception);

      expect(error.exception, isA<FormatException>());
    });

    test('should create error with stack trace', () {
      final stackTrace = StackTrace.current;
      final error = TomServerCallError(statusCode: 500, stackTrace: stackTrace);

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

    test('hasError returns true for 4xx/5xx status', () {
      expect(TomServerCallError(statusCode: 400).hasError, isTrue);
      expect(TomServerCallError(statusCode: 404).hasError, isTrue);
      expect(TomServerCallError(statusCode: 500).hasError, isTrue);
    });

    test('hasError returns false for any 2xx success status', () {
      // 2xx are successes, not errors (201 Created, 202 Accepted, 204 No Content).
      expect(TomServerCallError(statusCode: 200).hasError, isFalse);
      expect(TomServerCallError(statusCode: 201).hasError, isFalse);
      expect(TomServerCallError(statusCode: 202).hasError, isFalse);
      expect(TomServerCallError(statusCode: 204).hasError, isFalse);
    });

    test('hasError returns true for 3xx redirect status', () {
      expect(TomServerCallError(statusCode: 301).hasError, isTrue);
      expect(TomServerCallError(statusCode: 302).hasError, isTrue);
    });

    test('hasError returns true when internalError is set even on 2xx', () {
      expect(
        TomServerCallError(statusCode: 200, internalError: 1).hasError,
        isTrue,
      );
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

  // ==========================================================================
  // TomServerCall request-lifecycle Tests — driven by an injected mock
  // Client so no real network is required.
  // ==========================================================================
  group('TomServerCall lifecycle', () {
    // Specs with bearer auth disabled so applySpecValues() never touches the
    // TomBearerAuthentication singleton (it is not initialised in this suite).
    TomServerCallSpecs specs([String method = 'POST']) => TomServerCallSpecs(
      method,
      Uri.parse('https://api.example.com/data'),
      includeBearerAuthentication: false,
    );

    group('bearer authentication header', () {
      TomServerCallSpecs authenticatedSpecs() =>
          TomServerCallSpecs('GET', Uri.parse('https://api.example.com/data'));

      tearDown(TomBearerAuthentication.clearTokens);

      test('omits the header entirely when no one has signed in', () {
        // An absent header is a clean 401; a header reading "Bearer null" is a
        // credential the server has to fail to parse, which is the same
        // rejection dressed as a malformed request.
        TomBearerAuthentication.clearTokens();

        final call = TomServerCall(
          _MockClient((_) async => _streamed('x')),
          authenticatedSpecs(),
        );

        expect(
          call.abortableRequest.headers.containsKey('Authorization'),
          isFalse,
        );
      });

      test('sends the stored token when someone has signed in', () {
        final jwt = _bearerJwt({'username': 'dana', 'userId': 3});
        TomBearerAuthentication.setTokens(jwt, jwt, false);

        final call = TomServerCall(
          _MockClient((_) async => _streamed('x')),
          authenticatedSpecs(),
        );

        expect(
          call.abortableRequest.headers['Authorization'],
          equals('Bearer $jwt'),
        );
      });
    });

    group('send', () {
      test('sends the request through the client and stores the response', () {
        final client = _MockClient((_) async => _streamed('hello'));
        final call = TomServerCall(client, specs());

        final result = call.send(TomServerCallLoad(stringBody: 'payload'));

        expect(result, same(call));
        expect(call.response, isNotNull);
        expect(client.sendCount, equals(1));
        expect(client.lastRequest, isNotNull);
      });

      test('throws when send is called twice without reset', () {
        final client = _MockClient((_) async => _streamed('hello'));
        final call = TomServerCall(client, specs())
          ..send(TomServerCallLoad(stringBody: 'a'));

        expect(
          () => call.send(TomServerCallLoad(stringBody: 'b')),
          throwsA(isA<TomServerConnectionException>()),
        );
      });

      test(
        'a rejected second send leaves the request it refused untouched',
        () {
          // Rejecting the call but keeping its effect is the worst of both: the
          // object would describe a request that was never made, so a caller
          // inspecting it after catching the error — or a later reset() that
          // reuses the request — reads a body the server never saw.
          final client = _MockClient((_) async => _streamed('hello'));
          final call = TomServerCall(client, specs())
            ..send(TomServerCallLoad(stringBody: 'first'));

          expect(
            () => call.send(
              TomServerCallLoad(stringBody: 'second', encoding: latin1),
            ),
            throwsA(isA<TomServerConnectionException>()),
          );

          expect(call.abortableRequest.body, equals('first'));
          expect(call.abortableRequest.encoding, same(utf8));
          expect(client.sendCount, equals(1));
        },
      );
    });

    group('read / readAsString', () {
      test('read returns the response body as bytes', () async {
        final client = _MockClient((_) async => _streamed('hello bytes'));
        final call = TomServerCall(client, specs())..send(TomServerCallLoad());

        final bytes = await call.read();

        expect(utf8.decode(bytes), equals('hello bytes'));
        expect(call.serverResponse, isNotNull);
      });

      test('readAsString decodes the body with the given encoding', () async {
        final client = _MockClient((_) async => _streamed('héllo'));
        final call = TomServerCall(client, specs())..send(TomServerCallLoad());

        expect(await call.readAsString(utf8), equals('héllo'));
      });

      test('read before send throws a connection exception', () {
        final client = _MockClient((_) async => _streamed('x'));
        final call = TomServerCall(client, specs());

        expect(call.read(), throwsA(isA<TomServerConnectionException>()));
      });

      test('reading twice throws a connection exception', () async {
        final client = _MockClient((_) async => _streamed('once'));
        final call = TomServerCall(client, specs())..send(TomServerCallLoad());

        await call.read();
        expect(call.read(), throwsA(isA<TomServerConnectionException>()));
      });

      test('both readers report a second read under the same key', () async {
        // One condition, one key. A caller catching the key from read() must
        // also catch it from readAsString(), otherwise the branch that handles
        // "already consumed" works or not depending on which reader happened to
        // be called — and error keys are the contract callers match on.
        Future<String> keyOfSecondRead(
          Future<Object?> Function(TomServerCall call) secondRead,
        ) async {
          final call = TomServerCall(
            _MockClient((_) async => _streamed('once')),
            specs(),
          )..send(TomServerCallLoad());
          await call.read();
          try {
            await secondRead(call);
            fail('the second read was allowed');
          } on TomServerConnectionException catch (e) {
            return e.key;
          }
        }

        final fromRead = await keyOfSecondRead((call) => call.read());
        final fromString = await keyOfSecondRead(
          (call) => call.readAsString(utf8),
        );

        expect(fromRead, equals('server.send.illegal_state_only_read_once'));
        expect(fromString, equals(fromRead));
      });
    });

    group('response accessors', () {
      test('expose status, headers, redirect, reason and request', () async {
        final client = _MockClient(
          (req) async => _streamed(
            'created',
            statusCode: 201,
            headers: {'x-tom': 'yes'},
            reasonPhrase: 'Created',
            isRedirect: false,
            request: req,
          ),
        );
        final call = TomServerCall(client, specs())..send(TomServerCallLoad());

        expect(await call.getResponseStatusCode(), equals(201));
        expect(await call.getResponseHeaders(), containsPair('x-tom', 'yes'));
        expect(await call.getResponseIsRedirect(), isFalse);
        expect(await call.getResponseReasonPhrase(), equals('Created'));
        expect(await call.getResponseContentLength(), equals(7));
        expect(await call.getResponseRequest(), isNotNull);
      });

      test('accessors before send throw a connection exception', () {
        final client = _MockClient((_) async => _streamed('x'));
        final call = TomServerCall(client, specs());

        expect(
          call.getResponseStatusCode(),
          throwsA(isA<TomServerConnectionException>()),
        );
      });

      test('every reader reports "not sent" under the one key', () async {
        // One condition, one key -- the same contract [_ensureNotYetRead]
        // holds for "already consumed". A caller handling "this call has not
        // been sent" matches a key, and it used to have to match seven of
        // them, one per reader, with an eighth arriving whenever an eighth
        // reader did. The last segment of a key names the *condition*
        // (TomException's own convention), and the accessor is not one.
        final keys = <String, String>{};
        for (final entry in _readersBeforeSend.entries) {
          final call = TomServerCall(
            _MockClient((_) async => _streamed('x')),
            specs(),
          );
          try {
            await entry.value(call);
            fail('${entry.key} answered before send()');
          } on TomServerConnectionException catch (e) {
            keys[entry.key] = e.key;
          }
        }

        expect(
          keys.values.toSet(),
          equals({'server.send.illegal_state_read_must_be_after_send'}),
          reason: 'readers disagreed about the key for one condition: $keys',
        );
      });

      test('the "not sent" error still names what was being read', () async {
        // Collapsing seven keys into one must not cost the diagnosis. What
        // the caller was after moves from the key -- where it made the
        // condition unmatchable -- into the message and the parameters, which
        // is where a detail belongs.
        final names = <String>{};
        for (final entry in _readersBeforeSend.entries) {
          final call = TomServerCall(
            _MockClient((_) async => _streamed('x')),
            specs(),
          );
          try {
            await entry.value(call);
            fail('${entry.key} answered before send()');
          } on TomServerConnectionException catch (e) {
            final read = e.parameters?['read'];
            expect(read, isA<String>(), reason: '${entry.key} named nothing');
            expect(e.defaultUserMessage, contains(read as String));
            names.add(read);
          }
        }

        // Distinct per reader, so the parameter carries what the keys did.
        expect(names, hasLength(_readersBeforeSend.length - 1));
      });
    });

    group('reset', () {
      test('clears state so the call can be sent again', () async {
        final client = _MockClient((_) async => _streamed('again'));
        final call = TomServerCall(client, specs())..send(TomServerCallLoad());
        await call.read();

        call.reset();

        expect(call.response, isNull);
        expect(call.serverResponse, isNull);
        // A fresh send must now succeed (no illegal-state exception).
        expect(() => call.send(TomServerCallLoad()), returnsNormally);
      });

      test('applies a new string body passed to reset', () {
        final client = _MockClient((_) async => _streamed('x'));
        final call = TomServerCall(client, specs());

        call.reset(stringBody: 'reset-body');

        expect(call.abortableRequest.body, equals('reset-body'));
      });

      test('applies new body fields passed to reset', () {
        final client = _MockClient((_) async => _streamed('x'));
        final call = TomServerCall(client, specs());

        call.reset(bodyFields: {'k': 'v'});

        expect(call.abortableRequest.bodyFields, equals({'k': 'v'}));
      });
    });

    group('abort', () {
      test('abort() completes the abort trigger', () {
        final client = _MockClient((_) async => _streamed('x'));
        final call = TomServerCall(client, specs());

        expect(call.abortTrigger.isCompleted, isFalse);
        call.abort();
        expect(call.abortTrigger.isCompleted, isTrue);
      });

      test('read() of an aborted stream throws TomRequestAbortedException '
          'with the abort message', () async {
        final client = _MockClient(
          (_) async => StreamedResponse(
            Stream<List<int>>.error(RequestAbortedException()),
            200,
          ),
        );
        final call = TomServerCall(client, specs())..send(TomServerCallLoad());

        await expectLater(
          call.read(),
          throwsA(
            isA<TomRequestAbortedException>().having(
              (e) => e.defaultUserMessage,
              'defaultUserMessage',
              contains('aborted'),
            ),
          ),
        );
      });
    });

    group('timeout', () {
      /// Specs carrying a deadline short enough to keep the suite quick.
      TomServerCallSpecs timedSpecs([
        Duration timeout = const Duration(milliseconds: 50),
      ]) => TomServerCallSpecs(
        'GET',
        Uri.parse('https://api.example.com/data'),
        includeBearerAuthentication: false,
        timeout: timeout,
      );

      test('specs carry no timeout unless one is asked for', () {
        expect(specs().timeout, isNull);
      });

      test(
        'a response that never arrives throws TomRequestTimeoutException',
        () async {
          // The client never completes: this is the hang the deadline exists for.
          final client = _MockClient(
            (_) => Completer<StreamedResponse>().future,
          );
          final call = TomServerCall(client, timedSpecs())
            ..send(TomServerCallLoad());

          await expectLater(
            call.read(),
            throwsA(
              isA<TomRequestTimeoutException>().having(
                (e) => e.key,
                'key',
                equals('server.send.request_timeout'),
              ),
            ),
          );
        },
      );

      test('a body that never finishes streaming also times out', () async {
        // Headers arrive, then the body stalls — the deadline must span both
        // stages, not just the wait for the response.
        final client = _MockClient(
          (_) async =>
              StreamedResponse(StreamController<List<int>>().stream, 200),
        );
        final call = TomServerCall(client, timedSpecs())
          ..send(TomServerCallLoad());

        await expectLater(
          call.read(),
          throwsA(isA<TomRequestTimeoutException>()),
        );
      });

      test(
        'timing out aborts the request so the connection is released',
        () async {
          final client = _MockClient(
            (_) => Completer<StreamedResponse>().future,
          );
          final call = TomServerCall(client, timedSpecs())
            ..send(TomServerCallLoad());

          await expectLater(
            call.read(),
            throwsA(isA<TomRequestTimeoutException>()),
          );
          expect(call.abortTrigger.isCompleted, isTrue);
        },
      );

      test('a response inside the deadline is returned normally', () async {
        final client = _MockClient((_) async => _streamed('in time'));
        final call = TomServerCall(
          client,
          timedSpecs(const Duration(seconds: 30)),
        )..send(TomServerCallLoad());

        expect(await call.readAsString(utf8), equals('in time'));
      });

      test('a caller abort while awaiting the response reports as an abort, '
          'not as a raw client exception', () async {
        // The abort lands before any headers arrive. Without the deadline
        // plumbing this stage sat outside the guard and leaked the client's
        // own RequestAbortedException.
        final client = _MockClient(
          (_) => Future<StreamedResponse>.error(RequestAbortedException()),
        );
        final call = TomServerCall(client, specs())..send(TomServerCallLoad());

        await expectLater(
          call.read(),
          throwsA(isA<TomRequestAbortedException>()),
        );
      });

      test(
        'an endpoint declaration carries its timeout into the call specs',
        () async {
          final api = TomApi(
            id: 'timeoutApi',
            uri: '/api',
            endpoints: [
              TomApiEndpoint<String, String>(
                id: 'slow',
                uri: '/slow',
                method: TomHttpMethod.get,
                timeout: const Duration(seconds: 7),
              ),
            ],
          );

          final endpoint =
              TomServerEndpoint.createApiServerEndpoint<String, String>(
                api['slow'],
                baseUri: Uri.parse('https://api.example.com'),
              );

          expect(endpoint.specs.timeout, equals(const Duration(seconds: 7)));
        },
      );
    });

    group('via TomServerChannel.prepareCall', () {
      test(
        'a channel-prepared call round-trips through the mock client',
        () async {
          final client = _MockClient((_) async => _streamed('channel-body'));
          final channel = TomServerChannel(
            'api.example.com',
            443,
            clientFactory: _MockClientFactory(client),
          );

          final call = channel.prepareCall(specs());
          final body = await call.send(TomServerCallLoad()).readAsString(utf8);

          expect(body, equals('channel-body'));
          expect(call.client, same(client));
        },
      );
    });
  });

  // ==========================================================================
  // TomServerEndpoint.send / createApiServerEndpoint Tests
  // ==========================================================================
  group('TomServerEndpoint.createApiServerEndpoint', () {
    test('throws TomEndpointException on request/response type mismatch', () {
      // The endpoint is declared <String, String>; we ask for <int, int>,
      // so the runtime type check must reject it before any network work.
      final endpoint = TomApiEndpoint<String, String>(
        id: 'mismatch',
        method: TomHttpMethod.post,
        uri: '/mismatch',
      );
      expect(
        () => TomServerEndpoint.createApiServerEndpoint<int, int>(endpoint),
        throwsA(isA<TomEndpointException>()),
      );
    });

    test('accepts an endpoint declared in the class\'s own order', () {
      // TomApiEndpoint is <ReturnType, RequestType>; the factory takes
      // <requestType, responseType>. With the two types different, matching
      // them in the wrong order refuses every correct declaration.
      final endpoint = TomApi(
        id: 'orderedApi',
        uri: '/api',
        endpoints: [
          TomApiEndpoint<String, int>(
            id: 'ordered',
            method: TomHttpMethod.post,
            uri: '/ordered',
          ),
        ],
      )['ordered'];
      final call = TomServerEndpoint.createApiServerEndpoint<int, String>(
        endpoint,
        baseUri: Uri.parse('https://api.example.com'),
      );
      expect(call, isA<TomServerEndpoint<int, String>>());
      expect(
        () => TomServerEndpoint.createApiServerEndpoint<String, int>(endpoint),
        throwsA(isA<TomEndpointException>()),
      );
    });

    test('an API endpoint with no baseUri addresses the API server, not the '
        'authentication server', () {
      // The two URIs coincide in a single-host deployment, so a default that
      // named the wrong one would route every API call to the authentication
      // server and only show it in the split deployment the type exists for.
      // Every other test here passes baseUri explicitly, which is why this was
      // not caught: the default itself needs a context whose URIs differ.
      final api = TomApi(
        id: 'routingApi',
        uri: '/api/v1',
        endpoints: [
          TomApiEndpoint<String, String>(
            id: 'thing',
            uri: '/thing',
            method: TomHttpMethod.get,
          ),
        ],
      );

      final endpoint = TomClientRemoteContext.runWithContext(
        TomClientRemoteContext(
          Uri.parse('https://api.example.com'),
          Uri.parse('https://auth.example.com'),
        ),
        () => TomServerEndpoint.createApiServerEndpoint<String, String>(
          api['thing'],
        ),
      );

      expect(endpoint.specs.url.host, equals('api.example.com'));
      // The channel is built from the same URI, so a wrong default misroutes
      // the connection as well as the address written into the specs.
      expect(endpoint.channel.host, equals('api.example.com'));
      expect(endpoint.specs.url.path, equals('/api/v1/thing'));
    });

    test('an explicit baseUri still overrides the context', () {
      final api = TomApi(
        id: 'overrideApi',
        uri: '/api/v1',
        endpoints: [
          TomApiEndpoint<String, String>(
            id: 'thing',
            uri: '/thing',
            method: TomHttpMethod.get,
          ),
        ],
      );

      final endpoint = TomClientRemoteContext.runWithContext(
        TomClientRemoteContext(
          Uri.parse('https://api.example.com'),
          Uri.parse('https://auth.example.com'),
        ),
        () => TomServerEndpoint.createApiServerEndpoint<String, String>(
          api['thing'],
          baseUri: Uri.parse('https://reporting.example.com'),
        ),
      );

      expect(endpoint.specs.url.host, equals('reporting.example.com'));
    });

    test('the channel takes the port of the base URI, defaulting by scheme', () {
      // The channel and the specs URI address one server, so a channel port
      // derived without the scheme sends an `https` deployment to port 80 while
      // the URI beside it still reads 443.
      final api = TomApi(
        id: 'portApi',
        uri: '/api/v1',
        endpoints: [
          TomApiEndpoint<String, String>(
            id: 'thing',
            uri: '/thing',
            method: TomHttpMethod.get,
          ),
        ],
      );

      TomServerChannel channelFor(String baseUri) =>
          TomServerEndpoint.createApiServerEndpoint<String, String>(
            api['thing'],
            baseUri: Uri.parse(baseUri),
          ).channel;

      expect(channelFor('https://api.example.com').port, equals(443));
      expect(channelFor('http://api.example.com').port, equals(80));
      expect(channelFor('https://api.example.com:8443').port, equals(8443));
    });

    test('substitutes a path capture and appends a mapped query parameter', () {
      // The declaration is the only place the address is written down, so a
      // factory that joined the templates verbatim would put a literal `/{id}`
      // on the wire and drop the query binding entirely — the endpoint would be
      // unreachable through the very API that is supposed to build it.
      final api = TomApi(
        id: 'catalogApi',
        uri: '/api/items',
        endpoints: [
          TomApiEndpoint<String, String>(
            id: 'byId',
            uri: '/{id}',
            method: TomHttpMethod.get,
            urlParameterMapping: const {'id': 'itemId', 'lang': 'language'},
          ),
        ],
      );

      final endpoint =
          TomServerEndpoint.createApiServerEndpoint<String, String>(
            api['byId'],
            baseUri: Uri.parse('https://api.example.com'),
            parameters: {'itemId': 42, 'language': 'de'},
          );

      expect(
        endpoint.specs.url.toString(),
        equals('https://api.example.com/api/items/42?lang=de'),
      );
    });

    test('omits a mapped query parameter that has no value', () {
      // An optional query parameter is ordinary; only a path capture without a
      // value is a broken address.
      final api = TomApi(
        id: 'optionalApi',
        uri: '/api/items',
        endpoints: [
          TomApiEndpoint<String, String>(
            id: 'byId',
            uri: '/{id}',
            method: TomHttpMethod.get,
            urlParameterMapping: const {'id': 'itemId', 'lang': 'language'},
          ),
        ],
      );

      final endpoint =
          TomServerEndpoint.createApiServerEndpoint<String, String>(
            api['byId'],
            baseUri: Uri.parse('https://api.example.com'),
            parameters: {'itemId': 42},
          );

      expect(
        endpoint.specs.url.toString(),
        equals('https://api.example.com/api/items/42'),
      );
    });

    test('refuses to build an endpoint whose path capture has no value', () {
      // Left unresolved, the capture would travel as the literal text `{id}`
      // and address a route that does not exist — a failure the caller would
      // only see as a 404 from the server.
      final api = TomApi(
        id: 'unresolvedApi',
        uri: '/api/items',
        endpoints: [
          TomApiEndpoint<String, String>(
            id: 'byId',
            uri: '/{id}',
            method: TomHttpMethod.get,
          ),
        ],
      );

      expect(
        () => TomServerEndpoint.createApiServerEndpoint<String, String>(
          api['byId'],
          baseUri: Uri.parse('https://api.example.com'),
        ),
        throwsA(isA<TomEndpointException>()),
      );
    });

    test('keeps the base URI path in front of the API path', () {
      // A base that carries a path is the ordinary shape of a gateway-mounted
      // deployment. Joining the strings end to end fuses the last segment of
      // the base onto the first of the API path.
      final api = TomApi(
        id: 'gatewayApi',
        uri: '/api/v1',
        endpoints: [
          TomApiEndpoint<String, String>(
            id: 'thing',
            uri: '/thing',
            method: TomHttpMethod.get,
          ),
        ],
      );

      final endpoint =
          TomServerEndpoint.createApiServerEndpoint<String, String>(
            api['thing'],
            baseUri: Uri.parse('https://api.example.com/gateway'),
          );

      expect(endpoint.specs.url.path, equals('/gateway/api/v1/thing'));
    });
  });

  // ==========================================================================
  // TomServerEndpoint.send — which status codes count as a success
  // ==========================================================================
  group('TomServerEndpoint.send status handling', () {
    // Builds an endpoint whose server answers once with the given status and
    // body. statusCodeResponseTypes is the axis under test: it must not change
    // whether a 2xx response is deserialized, only what a failing one carries.
    TomServerEndpoint<EndpointRequest, EndpointResponse> endpointReturning(
      int statusCode,
      String body, {
      Map<int, Type>? statusCodeResponseTypes,
    }) {
      final channel = TomServerChannel(
        'api.example.com',
        443,
        clientFactory: _MockClientFactory(
          _MockClient((_) async => _streamed(body, statusCode: statusCode)),
        ),
      );
      return TomServerEndpoint<EndpointRequest, EndpointResponse>(
        channel,
        TomServerCallSpecs(
          'POST',
          Uri.parse('https://api.example.com/resources'),
        ),
        statusCodeResponseTypes: statusCodeResponseTypes,
      );
    }

    // The map an endpoint would realistically declare: failure codes only.
    const failureTypes = {400: EndpointFailure, 409: EndpointFailure};

    for (final declaresTypes in [false, true]) {
      final suffix = declaresTypes
          ? 'with statusCodeResponseTypes declared'
          : 'with no statusCodeResponseTypes';

      test('200 deserializes the body $suffix', () async {
        final (response, error) = await endpointReturning(
          200,
          '{"id":"r-200"}',
          statusCodeResponseTypes: declaresTypes ? failureTypes : null,
        ).send(EndpointRequest()..note = 'create');

        expect(response.id, equals('r-200'));
        expect(error?.hasError ?? false, isFalse);
      });

      test('201 deserializes the body $suffix', () async {
        // 201 Created is the ordinary answer of the POST endpoints this layer
        // exists to call, and it carries the created resource. Declaring types
        // for the failure codes must not divert it into the failure branch —
        // that branch never deserializes into R, so the caller would receive a
        // default-valued response together with an error reporting no error.
        final (response, error) = await endpointReturning(
          201,
          '{"id":"r-201"}',
          statusCodeResponseTypes: declaresTypes ? failureTypes : null,
        ).send(EndpointRequest()..note = 'create');

        expect(response.id, equals('r-201'));
        expect(error?.hasError ?? false, isFalse);
      });

      test('204 succeeds with no body to deserialize $suffix', () async {
        // 204 has no payload by definition, so there is nothing to parse and
        // the absence of a body is the expected shape, not a truncated one.
        final (response, error) = await endpointReturning(
          204,
          '',
          statusCodeResponseTypes: declaresTypes ? failureTypes : null,
        ).send(EndpointRequest()..note = 'delete');

        expect(response.id, isEmpty);
        expect(error?.hasError ?? false, isFalse);
        expect(error?.internalError, equals(0));
      });
    }

    test('a declared failure code is deserialized into its own type', () async {
      // The other half of the contract: statusCodeResponseTypes still has to
      // work for what it is for, so the success fix cannot be "ignore the map".
      final (response, error) = await endpointReturning(
        409,
        '{"reason":"duplicate"}',
        statusCodeResponseTypes: failureTypes,
      ).send(EndpointRequest()..note = 'create');

      expect(error, isNotNull);
      expect(error!.hasError, isTrue);
      expect(error.statusCode, equals(409));
      expect(error.statusCodeResponse, isA<EndpointFailure>());
      expect(
        (error.statusCodeResponse! as EndpointFailure).reason,
        equals('duplicate'),
      );
      expect(response.id, isEmpty);
    });

    test('an undeclared failure code still reports the failure', () async {
      final (_, error) = await endpointReturning(
        503,
        '{"reason":"down"}',
        statusCodeResponseTypes: failureTypes,
      ).send(EndpointRequest()..note = 'create');

      expect(error!.hasError, isTrue);
      expect(error.statusCode, equals(503));
      expect(error.statusCodeResponse, isNull);
    });
  });

  // ==========================================================================
  // TomServerEndpoint.send — when no response ever arrives
  // ==========================================================================
  group('TomServerEndpoint.send with no response', () {
    // An endpoint whose client never produces a response. How it fails is the
    // axis under test: refusing the connection outright, or going silent until
    // the deadline. Both are "the server sent no response", and both have to
    // reach the caller through the (response, error) tuple the endpoint
    // promises rather than as an exception thrown past it.
    TomServerEndpoint<EndpointRequest, EndpointResponse> endpointWith(
      Future<StreamedResponse> Function(BaseRequest request) handler, {
      Duration? timeout,
    }) {
      final channel = TomServerChannel(
        'api.example.com',
        443,
        clientFactory: _MockClientFactory(_MockClient(handler)),
      );
      return TomServerEndpoint<EndpointRequest, EndpointResponse>(
        channel,
        TomServerCallSpecs(
          'POST',
          Uri.parse('https://api.example.com/resources'),
          includeBearerAuthentication: false,
          timeout: timeout,
        ),
      );
    }

    test('a refused connection is reported as noResponseError', () async {
      // The most ordinary failure a network client meets. Every HTTP failure
      // comes back through the tuple, this one included: were it to throw
      // instead, a caller following the documented
      // `if (error?.hasError ?? false)` shape would crash on a dropped
      // network.
      final (response, error) = await endpointWith(
        (_) async => throw ClientException('Connection refused'),
      ).send(EndpointRequest()..note = 'create');

      expect(error, isNotNull);
      expect(error!.hasError, isTrue);
      expect(error.internalError, equals(TomServerCallError.noResponseError));
      // The identity of the branch, pinned without leaning on the constant:
      // noResponseError and serverError share the value 2, so the
      // code alone cannot distinguish "no response" from "the response failed
      // to parse". No status and no body can only be the former.
      expect(error.statusCode, equals(0));
      expect(error.response, isNull);
      expect(error.headers, isEmpty);
      expect(error.exception, isA<ClientException>());
      expect(error.stackTrace, isNotNull);
      // The caller still receives a usable R, defaults intact.
      expect(response.id, isEmpty);
    });

    test('a request that times out is reported as noResponseError', () async {
      // A deadline expiring is literally "no response arrived". TomServerCall
      // still raises its typed TomRequestTimeoutException — that is its own
      // contract and its tests pin it — and the endpoint translates it, keeping
      // the original reachable through `exception` for callers that care which
      // way the connection failed.
      final (_, error) = await endpointWith(
        (_) => Completer<StreamedResponse>().future,
        timeout: const Duration(milliseconds: 50),
      ).send(EndpointRequest()..note = 'create');

      expect(error!.internalError, equals(TomServerCallError.noResponseError));
      expect(error.statusCode, equals(0));
      expect(error.exception, isA<TomRequestTimeoutException>());
      expect(
        (error.exception! as TomRequestTimeoutException).key,
        equals('server.send.request_timeout'),
      );
    });

    test('a response that does arrive is never a no-response error', () async {
      // The other side of the boundary: a body that will not parse is a
      // failure of the response, not an absence of one. The two share the
      // internal code today, so this pins them apart by what only a delivered
      // response can carry.
      final (_, error) = await endpointWith(
        (_) async => _streamed('not json at all'),
      ).send(EndpointRequest()..note = 'create');

      expect(error!.hasError, isTrue);
      expect(error.statusCode, equals(200));
      expect(error.response, equals('not json at all'));
    });
  });

  // ==========================================================================
  // TomServerEndpoint.send — the request, the rethrow, and the caller's object
  // ==========================================================================
  group('TomServerEndpoint.send', () {
    late _MockClient client;

    /// An endpoint whose client answers with [handler], keeping the mock
    /// reachable so a test can read the request that was actually sent.
    TomServerEndpoint<EndpointRequest, EndpointResponse> endpointFor(
      Future<StreamedResponse> Function(BaseRequest request) handler, {
      Map<int, Type>? statusCodeResponseTypes,
    }) {
      client = _MockClient(handler);
      return TomServerEndpoint<EndpointRequest, EndpointResponse>(
        TomServerChannel(
          'api.example.com',
          443,
          clientFactory: _MockClientFactory(client),
        ),
        TomServerCallSpecs(
          'POST',
          Uri.parse('https://api.example.com/resources'),
          includeBearerAuthentication: false,
        ),
        statusCodeResponseTypes: statusCodeResponseTypes,
      );
    }

    test('the request carries the DTO as JSON', () async {
      // "Serializes request objects to JSON" is the first line of what this
      // class claims to do, and nothing had read the request back to see it.
      await endpointFor(
        (_) async => _streamed('{"id":"r-1"}'),
      ).send(EndpointRequest()..note = 'create');

      final request = client.lastRequest! as Request;
      expect(request.body, equals('{"note":"create"}'));
      expect(request.method, equals('POST'));
      expect(request.url.path, equals('/resources'));
      expect(
        request.headers[TomHeader.contentType],
        startsWith('application/json'),
      );
    });

    test('a supplied response object is the one that is populated', () async {
      // The documented second argument: a caller that already holds the object
      // hands it in, and has to get *that* object back filled, not a copy it
      // is still holding a stale version of.
      final target = EndpointResponse();

      final (response, error) = await endpointFor(
        (_) async => _streamed('{"id":"r-supplied"}'),
      ).send(EndpointRequest()..note = 'create', target);

      expect(error?.hasError ?? false, isFalse);
      expect(identical(response, target), isTrue);
      expect(target.id, equals('r-supplied'));
    });

    test('a failing status with no declared types still fails', () async {
      // The other half of the `statusCodeResponseTypes` axis: an endpoint that
      // declares none at all. There is no failure type to build, so the body
      // is read into R and the failure is reported by the status alone.
      final (response, error) = await endpointFor(
        (_) async => _streamed('{"id":"partial"}', statusCode: 500),
      ).send(EndpointRequest()..note = 'create');

      expect(error, isNotNull);
      expect(error!.hasError, isTrue);
      expect(error.statusCode, equals(500));
      expect(response.id, equals('partial'));
    });

    test('an unparseable body is a server error, not a missing one', () async {
      // Pinned by name rather than by value: `noResponseError` and
      // `serverError` are different answers to "what went wrong", and a caller
      // switching on the code has to be able to tell them apart.
      final (_, error) = await endpointFor(
        (_) async => _streamed('<html>not json</html>'),
      ).send(EndpointRequest()..note = 'create');

      expect(error!.internalError, equals(TomServerCallError.serverError));
      expect(
        error.internalError,
        isNot(equals(TomServerCallError.noResponseError)),
      );
      expect(error.statusCode, equals(200));
      expect(error.exception, isNotNull);
    });

    test('a body asking the client to rethrow raises past the tuple', () async {
      // The one documented exception to "every failure comes back through the
      // tuple". A server that sets `clientRethrow` is asking the client to
      // treat its error as an exception, and the identifying fields have to
      // travel into it or the caller cannot report which failure it was.
      await expectLater(
        endpointFor(
          (_) async => _streamed(
            '{"errorKey":"access.check.denied","uuid":"srv-1",'
            '"requestUuid":"req-1","clientRethrow":true}',
            statusCode: 403,
            headers: const {'x-tom-error': 'true'},
          ),
        ).send(EndpointRequest()..note = 'create'),
        throwsA(
          isA<TomServerConnectionException>()
              .having((e) => e.key, 'key', 'access.check.denied')
              .having((e) => e.uuid, 'uuid', 'srv-1')
              .having((e) => e.requestUuid, 'requestUuid', 'req-1')
              .having((e) => e.autoLog, 'autoLog', isTrue)
              .having(
                (e) => e.serverCallError?.statusCode,
                'serverCallError.statusCode',
                403,
              ),
        ),
      );
    });

    test('a body that does not ask to rethrow returns the tuple', () async {
      // The complement, so the guard above cannot be satisfied by throwing on
      // every Tom error body.
      final (_, error) = await endpointFor(
        (_) async => _streamed(
          '{"errorKey":"access.check.denied","clientRethrow":false}',
          statusCode: 403,
          headers: const {'x-tom-error': 'true'},
        ),
      ).send(EndpointRequest()..note = 'create');

      expect(error!.hasError, isTrue);
      expect(error.errorKey, equals('access.check.denied'));
    });

    test('a declared failure type equal to R is still built', () async {
      // The map says what a body of this status carries; nothing about it is
      // special when the type it names happens to be the endpoint's own
      // response type. Skipping that case made the entry a no-op and left
      // `statusCodeResponse` null for a status that has one — which is exactly
      // what the documented contract says cannot happen.
      final (response, error) = await endpointFor(
        (_) async => _streamed('{"id":"failure-body"}', statusCode: 409),
        statusCodeResponseTypes: const {409: EndpointResponse},
      ).send(EndpointRequest()..note = 'create');

      expect(error!.hasError, isTrue);
      expect(error.statusCode, equals(409));
      expect(error.statusCodeResponse, isA<EndpointResponse>());
      expect(
        (error.statusCodeResponse! as EndpointResponse).id,
        equals('failure-body'),
      );
      expect(
        response.id,
        isEmpty,
        reason: 'a failing status does not fill the result object',
      );
    });

    test(
      'an endpoint declared with a capture calls the resolved URL',
      () async {
        // The declaration is the only place the address is written down, so the
        // proof that resolution reaches the wire has to be a *sent* request:
        // asserting `specs.url` alone leaves open whether `send` uses it.
        final api = TomApi(
          id: 'sendCaptureApi',
          uri: '/api/items',
          endpoints: [
            TomApiEndpoint<EndpointResponse, EndpointRequest>(
              id: 'byId',
              uri: '/{id}',
              method: TomHttpMethod.post,
              urlParameterMapping: const {'id': 'itemId', 'lang': 'language'},
            ),
          ],
        );
        final mock = _MockClient((_) async => _streamed('{"id":"r-42"}'));

        final (response, error) =
            await TomServerEndpoint.createApiServerEndpoint<
                  EndpointRequest,
                  EndpointResponse
                >(
                  api['byId'],
                  baseUri: Uri.parse('https://api.example.com'),
                  parameters: {'itemId': 42, 'language': 'de'},
                  channel: TomServerChannel(
                    'api.example.com',
                    443,
                    clientFactory: _MockClientFactory(mock),
                  ),
                )
                .send(EndpointRequest()..note = 'create');

        expect(
          mock.lastRequest!.url.toString(),
          equals('https://api.example.com/api/items/42?lang=de'),
        );
        expect(error?.hasError ?? false, isFalse);
        expect(response.id, equals('r-42'));
      },
    );
  });

  // ==========================================================================
  // TomServerCallError status-code classification
  // ==========================================================================
  group('TomServerCallError status classification', () {
    test('isSuccessStatusCode spans the 2xx range and nothing else', () {
      expect(TomServerCallError.isSuccessStatusCode(199), isFalse);
      expect(TomServerCallError.isSuccessStatusCode(200), isTrue);
      expect(TomServerCallError.isSuccessStatusCode(201), isTrue);
      expect(TomServerCallError.isSuccessStatusCode(204), isTrue);
      expect(TomServerCallError.isSuccessStatusCode(299), isTrue);
      expect(TomServerCallError.isSuccessStatusCode(300), isFalse);
      expect(TomServerCallError.isSuccessStatusCode(404), isFalse);
    });

    test('hasError is the negation of it, plus the internal-error flag', () {
      // Pinning that the two read the same definition: if hasError ever spells
      // the range itself again, one of these disagrees with the other.
      for (final status in [100, 200, 201, 204, 299, 301, 404, 500]) {
        expect(
          TomServerCallError(statusCode: status).hasError,
          equals(!TomServerCallError.isSuccessStatusCode(status)),
          reason: 'status $status',
        );
      }
      expect(
        TomServerCallError(statusCode: 200, internalError: 1).hasError,
        isTrue,
      );
    });

    test('isNoContentStatusCode names only the bodiless successes', () {
      expect(TomServerCallError.isNoContentStatusCode(204), isTrue);
      expect(TomServerCallError.isNoContentStatusCode(205), isTrue);
      expect(TomServerCallError.isNoContentStatusCode(200), isFalse);
      expect(TomServerCallError.isNoContentStatusCode(201), isFalse);
    });
  });

  // ==========================================================================
  // Auth refresh/retry coordinator (auth_retry.dart)
  // ==========================================================================
  group('TomAuthRetryPolicy', () {
    tearDown(TomBean.resetBeanContext);

    test('default policy treats a single 401 as expiry and retries once', () {
      expect(tomDefaultAuthRetryPolicy.expiryStatusCodes, equals({401}));
      expect(tomDefaultAuthRetryPolicy.maxRefreshRetries, equals(1));
      expect(tomDefaultAuthRetryPolicy.isAuthExpiry(401), isTrue);
      expect(tomDefaultAuthRetryPolicy.isAuthExpiry(403), isFalse);
      expect(tomDefaultAuthRetryPolicy.isAuthExpiry(200), isFalse);
    });

    test('a custom policy tunes its expiry set and retry budget', () {
      const policy = TomAuthRetryPolicy(
        expiryStatusCodes: {419, 440},
        maxRefreshRetries: 3,
      );
      expect(policy.isAuthExpiry(419), isTrue);
      expect(policy.isAuthExpiry(440), isTrue);
      expect(policy.isAuthExpiry(401), isFalse);
      expect(policy.maxRefreshRetries, equals(3));
    });

    test('active resolves the default when no bean is registered', () {
      expect(TomAuthRetryPolicy.active, same(tomDefaultAuthRetryPolicy));
    });

    test('active resolves a registered TomAuthRetryPolicy bean', () {
      const custom = TomAuthRetryPolicy(
        expiryStatusCodes: {440},
        maxRefreshRetries: 5,
      );
      TomBean.withType<TomAuthRetryPolicy>(custom);
      expect(TomAuthRetryPolicy.active, same(custom));
    });

    test('active falls back to default after the bean context is reset', () {
      TomBean.withType<TomAuthRetryPolicy>(
        const TomAuthRetryPolicy(expiryStatusCodes: {440}),
      );
      TomBean.resetBeanContext();
      expect(TomAuthRetryPolicy.active, same(tomDefaultAuthRetryPolicy));
    });
  });

  group('TomAuthExpiredException', () {
    test('carries the persisting status code, key and message', () {
      final ex = TomAuthExpiredException(
        'auth.dead',
        'Please sign in again.',
        statusCode: 401,
      );
      expect(ex.statusCode, equals(401));
      expect(ex.key, equals('auth.dead'));
      expect(ex.defaultUserMessage, equals('Please sign in again.'));
    });
  });

  group('tomRunWithAuthRetry', () {
    tearDown(TomBean.resetBeanContext);

    // A sender that returns each scripted status in turn (holding on the last).
    Future<int> Function() scriptedSender(List<int> statuses, List<int> calls) {
      var index = 0;
      return () async {
        calls.add(index);
        final status =
            statuses[index < statuses.length ? index : statuses.length - 1];
        index++;
        return status;
      };
    }

    test('returns a non-expiry response without refreshing', () async {
      final refresher = _ScriptedRefresher();
      final calls = <int>[];
      final result = await tomRunWithAuthRetry<int>(
        send: scriptedSender([200], calls),
        statusOf: (r) => r,
        refresher: refresher,
      );
      expect(result, equals(200));
      expect(calls.length, equals(1));
      expect(refresher.refreshCount, equals(0));
    });

    test('recovers an expiry with one refresh and a retry', () async {
      final refresher = _ScriptedRefresher(succeeds: true);
      final calls = <int>[];
      final result = await tomRunWithAuthRetry<int>(
        send: scriptedSender([401, 200], calls),
        statusOf: (r) => r,
        refresher: refresher,
      );
      expect(result, equals(200));
      expect(calls.length, equals(2));
      expect(refresher.refreshCount, equals(1));
    });

    test('returns the original response when the refresher declines', () async {
      final refresher = _ScriptedRefresher(succeeds: false);
      final calls = <int>[];
      final result = await tomRunWithAuthRetry<int>(
        send: scriptedSender([401], calls),
        statusOf: (r) => r,
        refresher: refresher,
      );
      expect(result, equals(401));
      expect(calls.length, equals(1));
      expect(refresher.refreshCount, equals(1));
    });

    test(
      'throws TomAuthExpiredException when expiry persists after retry',
      () async {
        final refresher = _ScriptedRefresher(succeeds: true);
        final calls = <int>[];
        await expectLater(
          tomRunWithAuthRetry<int>(
            send: scriptedSender([401, 401], calls),
            statusOf: (r) => r,
            refresher: refresher,
            errorKeyOf: (_) => 'auth.token_dead',
          ),
          throwsA(
            isA<TomAuthExpiredException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.key, 'key', 'auth.token_dead'),
          ),
        );
        expect(refresher.refreshCount, equals(1));
      },
    );

    test('uses the default error key when errorKeyOf is omitted', () async {
      final refresher = _ScriptedRefresher(succeeds: true);
      await expectLater(
        tomRunWithAuthRetry<int>(
          send: scriptedSender([401, 401], <int>[]),
          statusOf: (r) => r,
          refresher: refresher,
        ),
        throwsA(
          isA<TomAuthExpiredException>().having(
            (e) => e.key,
            'key',
            'auth.session_expired',
          ),
        ),
      );
    });

    test(
      'passes a non-expiry error status through without refreshing',
      () async {
        final refresher = _ScriptedRefresher();
        final calls = <int>[];
        final result = await tomRunWithAuthRetry<int>(
          send: scriptedSender([403], calls),
          statusOf: (r) => r,
          refresher: refresher,
        );
        expect(result, equals(403));
        expect(refresher.refreshCount, equals(0));
      },
    );

    test('propagates an error thrown by the refresher', () async {
      final refresher = _ScriptedRefresher(throwsError: true);
      await expectLater(
        tomRunWithAuthRetry<int>(
          send: scriptedSender([401, 200], <int>[]),
          statusOf: (r) => r,
          refresher: refresher,
        ),
        throwsA(isA<StateError>()),
      );
      expect(refresher.refreshCount, equals(1));
    });

    test('honours an explicit policy over the default budget', () async {
      const policy = TomAuthRetryPolicy(
        expiryStatusCodes: {419},
        maxRefreshRetries: 2,
      );
      final refresher = _ScriptedRefresher(succeeds: true);
      final calls = <int>[];
      final result = await tomRunWithAuthRetry<int>(
        send: scriptedSender([419, 419, 200], calls),
        statusOf: (r) => r,
        refresher: refresher,
        policy: policy,
      );
      expect(result, equals(200));
      expect(calls.length, equals(3));
      expect(refresher.refreshCount, equals(2));
    });

    test('resolves the active policy bean when no policy is passed', () async {
      TomBean.withType<TomAuthRetryPolicy>(
        const TomAuthRetryPolicy(expiryStatusCodes: {419}),
      );
      final refresher = _ScriptedRefresher(succeeds: true);
      final calls = <int>[];
      // 401 is NOT an expiry under the active {419} policy, so it passes
      // through untouched and no refresh happens.
      final result = await tomRunWithAuthRetry<int>(
        send: scriptedSender([401], calls),
        statusOf: (r) => r,
        refresher: refresher,
      );
      expect(result, equals(401));
      expect(refresher.refreshCount, equals(0));
    });
  });

  // The logging module's documented remote wiring, executed.
  //
  // It lives here rather than in `logging_test.dart` for a reason worth
  // naming: that suite has no generated reflection registry, and the remote
  // send serializes `TomRemoteLogMessage` through one. Its existing remote
  // tests substitute a mock *endpoint*, which proves the module reaches its
  // endpoint and proves nothing about the channel, the method or the URL the
  // documentation tells a reader to write. This suite has both a registry and
  // the transport under test, so the documented wiring can be run end to end.
  group('the logging module\'s documented remote wiring', () {
    tearDown(() => TomRemoteLogOutput.remoteEndpoint = null);

    test('a record reaches the URL the documentation wires', () async {
      final sent = Completer<void>();
      final client = RecordingClient(
        (request) async =>
            jsonResponse(request, '{"hasError":false,"errorMessage":""}'),
      )..onSend = () => sent.complete();

      // Built exactly as `TomRemoteLogOutput`'s dartdoc shows it.
      TomRemoteLogOutput.remoteEndpoint =
          TomServerEndpoint<TomRemoteLogMessage, TomRemoteLogResult>(
            TomServerChannel(
              'logs.example.com',
              443,
              clientFactory: RecordingClientFactory(client),
            ),
            TomServerCallSpecs(
              'POST',
              Uri.parse('https://logs.example.com/api/logs'),
            ),
          );

      TomRemoteLogOutput().output(
        TomLogLevel.production,
        TomLogLevel.info,
        'INFO   ',
        'the message that goes out',
        'main',
        DateTime(2026, 1, 2, 10, 0, 0),
        null,
      );
      await sent.future.timeout(const Duration(seconds: 10));

      expect(client.lastRequest!.method, equals('POST'));
      expect(
        client.lastRequest!.url,
        equals(Uri.parse('https://logs.example.com/api/logs')),
      );
      final body =
          jsonDecode((client.lastRequest! as Request).body)
              as Map<String, Object?>;
      expect(body['message'], contains('the message that goes out'));
      expect(body['isolateName'], equals('main'));
    });
  });
}

// ============================================================================
// Test doubles for the request-lifecycle tests.
// ============================================================================

/// A minimal [BaseClient] whose [send] is driven by a supplied handler, so
/// tests fully control the response (or stream error) a [TomServerCall] sees.
class _MockClient extends BaseClient {
  _MockClient(this.handler);

  final Future<StreamedResponse> Function(BaseRequest request) handler;

  /// Number of times [send] was invoked.
  int sendCount = 0;

  /// The last request passed to [send].
  BaseRequest? lastRequest;

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    sendCount++;
    lastRequest = request;
    return handler(request);
  }
}

/// A [TomHttpClientAbstractFactory] that always hands out the same mock
/// client, so a [TomServerChannel] can be wired to a [_MockClient].
class _MockClientFactory implements TomHttpClientAbstractFactory {
  _MockClientFactory(this._client);

  final _MockClient _client;

  @override
  _MockClient getClient() => _client;
}

/// Builds a [StreamedResponse] from a string body for the success cases.
StreamedResponse _streamed(
  String body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
  String? reasonPhrase,
  bool isRedirect = false,
  BaseRequest? request,
}) {
  final bytes = utf8.encode(body);
  return StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    contentLength: bytes.length,
    headers: headers,
    reasonPhrase: reasonPhrase,
    isRedirect: isRedirect,
    request: request,
  );
}

/// Every [TomServerCall] member that reads something off the response, keyed by
/// name.
///
/// The "you must send first" guard is what they have in common, and the tests
/// that pin it are exhaustive over this map: adding a reader without adding it
/// here is the one way the convention could quietly stop holding.
const Map<String, Future<Object?> Function(TomServerCall call)>
_readersBeforeSend = {
  'read': _readBytes,
  'readAsString': _readString,
  'getResponseHeaders': _getHeaders,
  'getResponseStatusCode': _getStatusCode,
  'getResponseContentLength': _getContentLength,
  'getResponseIsRedirect': _getIsRedirect,
  'getResponseReasonPhrase': _getReasonPhrase,
  'getResponseRequest': _getRequest,
};

Future<Object?> _readBytes(TomServerCall call) => call.read();
Future<Object?> _readString(TomServerCall call) => call.readAsString(utf8);
Future<Object?> _getHeaders(TomServerCall call) => call.getResponseHeaders();
Future<Object?> _getStatusCode(TomServerCall call) =>
    call.getResponseStatusCode();
Future<Object?> _getContentLength(TomServerCall call) =>
    call.getResponseContentLength();
Future<Object?> _getIsRedirect(TomServerCall call) =>
    call.getResponseIsRedirect();
Future<Object?> _getReasonPhrase(TomServerCall call) =>
    call.getResponseReasonPhrase();
Future<Object?> _getRequest(TomServerCall call) => call.getResponseRequest();

/// A [TomAuthRefresher] scripted for the auth-retry tests: it counts calls and
/// either succeeds (a usable token), declines (no session), or throws.
class _ScriptedRefresher implements TomAuthRefresher {
  _ScriptedRefresher({this.succeeds = true, this.throwsError = false});

  /// Whether a refresh yields a usable new token (worth retrying).
  final bool succeeds;

  /// Whether the refresh call itself fails so the error must propagate.
  final bool throwsError;

  /// How many times [refresh] was invoked.
  int refreshCount = 0;

  @override
  Future<bool> refresh() async {
    refreshCount++;
    if (throwsError) {
      throw StateError('refresh endpoint unreachable');
    }
    return succeeds;
  }
}

/// A syntactically valid, unsigned JWT carrying [payload].
///
/// Signed tokens are the security suite's business; here the token only has to
/// be *parseable*, because what is under test is which header carries it.
String _bearerJwt(Map<String, dynamic> payload) {
  String segment(Map<String, dynamic> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
  // A live `exp`: a token without one yields no principal.
  final claims = {'exp': 4102444800, ...payload};
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment(claims)}.sig';
}
