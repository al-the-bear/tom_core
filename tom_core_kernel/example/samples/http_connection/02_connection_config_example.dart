/// Connection Configuration Example
///
/// This example demonstrates HTTP connection configuration including
/// MIME types, headers, API endpoints, and content disposition settings.
///
/// Key concepts:
/// - TomMimeType for content types
/// - Parsing and comparing MIME types
/// - File extension to MIME type mapping
/// - HTTP header constants
/// - TomApiEndpoint for structured API definitions
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// Example Class
// ============================================================================

class ConnectionConfigExample {
  // Captured results
  static late TomMimeType jsonMime;
  static late TomMimeType htmlMime;
  static late TomMimeType pdfMime;
  static late TomMimeType parsedJson;
  static late TomMimeType customMime;
  static late TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>
  getUserEndpoint;
  static late TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>
  createUserEndpoint;

  // -------------------------------------------------------------------------
  // Example 1: Working with MIME types
  // -------------------------------------------------------------------------
  static void example1MimeTypes() {
    print('1. MIME Types:');

    // Predefined MIME types
    jsonMime = TomMimeType.json;
    htmlMime = TomMimeType.html;
    pdfMime = TomMimeType.pdf;
    final octetMime = TomMimeType.octetStream;

    print('   - JSON: ${jsonMime.primaryType}/${jsonMime.subType}');
    print('   - HTML: ${htmlMime.primaryType}/${htmlMime.subType}');
    print(
      '   - PDF: ${pdfMime.primaryType}/${pdfMime.subType}, charset: ${pdfMime.charset ?? 'none'}',
    );
    print('   - Octet-stream: ${octetMime.primaryType}/${octetMime.subType}');

    // Header value generation
    final jsonHeader = jsonMime.toHeaderValue();
    final pdfHeader = pdfMime.toHeaderValue();
    print('   - JSON header value: $jsonHeader');
    print('   - PDF header value: $pdfHeader');

    // Assertions
    assert(
      jsonMime.primaryType == 'application',
      'JSON primary type should be application',
    );
    assert(jsonMime.subType == 'json', 'JSON subtype should be json');
  }

  // -------------------------------------------------------------------------
  // Example 2: Parsing and comparing MIME types
  // -------------------------------------------------------------------------
  static void example2ParsingMimeTypes() {
    print('\n2. Parsing and comparing MIME types:');

    parsedJson = TomMimeType.parse('application/json');
    final parsedHtml = TomMimeType.parse('text/html');

    print('   - Parsed JSON: ${parsedJson.primaryType}/${parsedJson.subType}');
    print('   - Parsed HTML: ${parsedHtml.primaryType}/${parsedHtml.subType}');

    // Check if types match
    final jsonMatch = jsonMime.isEqualType(parsedJson);
    print('   - JSON constants match parsed: $jsonMatch');

    // A peer may shout its media type: RFC 2045 makes the type and subtype
    // case-insensitive, so both comparisons see through the spelling while the
    // fields still echo the header the way it arrived.
    final shouted = TomMimeType.parse('TEXT/HTML;charset=utf-8');
    final shoutedMatch = shouted == htmlMime;
    print('   - TEXT/HTML equals text/html: $shoutedMatch');
    print('   - ...rendered back as: ${shouted.toHeaderValue()}');

    // Text detection
    final jsonIsText = jsonMime.isText;
    final pdfIsText = pdfMime.isText;
    final htmlIsText = htmlMime.isText;
    print('   - JSON isText: $jsonIsText');
    print('   - PDF isText: $pdfIsText');
    print('   - HTML isText: $htmlIsText');

    // Assertions
    assert(jsonMatch == true, 'JSON types should match');
    assert(shoutedMatch == true, 'Media types compare case-insensitively');
    assert(
      shouted.toHeaderValue() == 'TEXT/HTML;charset=utf-8',
      'The fields keep the spelling the header used',
    );
    assert(shouted.isText == true, 'TEXT/HTML is still text');
    assert(htmlIsText == true, 'HTML should be text');
    assert(pdfIsText == false, 'PDF should not be text');
  }

  // -------------------------------------------------------------------------
  // Example 3: Creating custom MIME types
  // -------------------------------------------------------------------------
  static void example3CustomMimeTypes() {
    print('\n3. Custom MIME types:');

    customMime = TomMimeType('application', 'vnd.api+json');
    final videoMime = TomMimeType(
      'video',
      'mp4',
      charset: null,
      codecs: ['avc1.42E01E', 'mp4a.40.2'],
    );

    print(
      '   - Custom API MIME: ${customMime.primaryType}/${customMime.subType}',
    );
    print('   - Video MIME: ${videoMime.primaryType}/${videoMime.subType}');
    print('   - Video codecs: ${videoMime.codecs}');
    print('   - Custom isText: ${customMime.isText}');

    // Assertions
    assert(
      customMime.primaryType == 'application',
      'Custom primary type should match',
    );
    assert(customMime.subType == 'vnd.api+json', 'Custom subtype should match');
    assert(videoMime.codecs.length == 2, 'Video should have 2 codecs');
  }

  // -------------------------------------------------------------------------
  // Example 4: File extension to MIME type mapping
  // -------------------------------------------------------------------------
  static void example4ExtensionMapping() {
    print('\n4. File extension mapping:');

    final jsonExt = StaticFileMimetypeMapping.getMimeType('.json');
    final pngExt = StaticFileMimetypeMapping.getMimeType('.png');
    final mp4Ext = StaticFileMimetypeMapping.getMimeType('.mp4');
    // The two a browser is strict about: an .html served as octet-stream
    // downloads instead of rendering, and a .woff2 with the wrong type is
    // refused outright.
    final htmlExt = StaticFileMimetypeMapping.getMimeType('.html');
    final woff2Ext = StaticFileMimetypeMapping.getMimeType('.woff2');
    final unknownExt = StaticFileMimetypeMapping.getMimeType('.xyz');

    print('   - .json maps to: ${jsonExt?.primaryType}/${jsonExt?.subType}');
    print('   - .png maps to: ${pngExt?.primaryType}/${pngExt?.subType}');
    print('   - .mp4 maps to: ${mp4Ext?.primaryType}/${mp4Ext?.subType}');
    print('   - .html maps to: ${htmlExt?.primaryType}/${htmlExt?.subType}');
    print('   - .woff2 maps to: ${woff2Ext?.primaryType}/${woff2Ext?.subType}');
    print('   - .xyz maps to: ${unknownExt ?? 'null (unknown)'}');

    // Assertions
    assert(jsonExt != null, 'JSON extension should be mapped');
    assert(jsonExt?.subType == 'json', 'JSON subtype should match');
    assert(pngExt?.primaryType == 'image', 'PNG should be image type');
    assert(htmlExt == TomMimeType.html, 'HTML should map to the constant');
    assert(woff2Ext?.subType == 'woff2', 'WOFF2 should map to font/woff2');
    assert(woff2Ext?.charset == null, 'A font declares no charset');
    assert(unknownExt == null, 'Unknown extension should return null');
  }

  // -------------------------------------------------------------------------
  // Example 5: HTTP header constants
  // -------------------------------------------------------------------------
  static void example5HeaderConstants() {
    print('\n5. HTTP Header constants:');

    print('   - Content-Type header: ${TomHeader.contentType}');
    print('   - Content-Disposition header: ${TomHeader.contentDisposition}');
    print('   - Attachment disposition: ${TomContentDisposition.attachment}');

    // Assertions
    assert(
      TomHeader.contentType == 'Content-Type',
      'Content-Type header should match',
    );
    assert(
      TomHeader.contentDisposition == 'Content-Disposition',
      'Content-Disposition should match',
    );
  }

  // -------------------------------------------------------------------------
  // Example 6: Defining API endpoints
  // -------------------------------------------------------------------------
  static void example6ApiEndpoints() {
    print('\n6. API endpoint definitions:');

    // Define an endpoint
    getUserEndpoint =
        TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
          id: 'getUser',
          uri: '/get',
          method: TomHttpMethod.get,
          consumes: TomMimeType.none,
          produces: TomMimeType.json,
          description: 'Retrieves a user by ID',
        );

    createUserEndpoint =
        TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
          id: 'createUser',
          uri: '/create',
          method: TomHttpMethod.post,
          consumes: TomMimeType.json,
          produces: TomMimeType.json,
          description: 'Creates a new user',
          requestHeaders: {'X-API-Version': '2.0'},
          followRedirects: false,
          includeBearerAuthentication: true,
        );

    final downloadEndpoint =
        TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
          id: 'downloadReport',
          uri: '/report/download',
          method: TomHttpMethod.get,
          produces: TomMimeType.pdf,
          contentDisposition: 'attachment; filename="report.pdf"',
          description: 'Downloads a PDF report',
        );

    print('   - Get User endpoint:');
    print('     • ID: ${getUserEndpoint.id}');
    print('     • URI: ${getUserEndpoint.uri}');
    print('     • Method: ${getUserEndpoint.method.name}');
    print(
      '     • Produces: ${getUserEndpoint.produces.primaryType}/${getUserEndpoint.produces.subType}',
    );

    print('   - Create User endpoint:');
    print('     • ID: ${createUserEndpoint.id}');
    print('     • Method: ${createUserEndpoint.method.name}');
    print(
      '     • Consumes: ${createUserEndpoint.consumes.primaryType}/${createUserEndpoint.consumes.subType}',
    );
    print('     • Request headers: ${createUserEndpoint.requestHeaders}');

    print('   - Download endpoint:');
    print('     • ID: ${downloadEndpoint.id}');
    print('     • Content-Disposition: ${downloadEndpoint.contentDisposition}');

    // Assertions
    assert(getUserEndpoint.id == 'getUser', 'Endpoint ID should match');
    assert(getUserEndpoint.method == TomHttpMethod.get, 'Method should be GET');
    assert(
      createUserEndpoint.consumes == TomMimeType.json,
      'Should consume JSON',
    );
    assert(
      createUserEndpoint.includeBearerAuthentication == true,
      'Should include bearer auth',
    );
    assert(downloadEndpoint.produces == TomMimeType.pdf, 'Should produce PDF');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 02: Connection Configuration Example ===\n');

    example1MimeTypes();
    example2ParsingMimeTypes();
    example3CustomMimeTypes();
    example4ExtensionMapping();
    example5HeaderConstants();
    example6ApiEndpoints();

    print('\n=== Connection Configuration Example Complete ===\n');
  }
}

void run() => ConnectionConfigExample.run();

void main() {
  prepareSampleProcess();
  run();
}
