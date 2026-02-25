/// Demonstrates HTTP connection configuration including MIME types,
/// headers, API endpoints, and content disposition settings.
///
/// This example covers TomMimeType, TomHeader, TomApi, TomApiEndpoint,
/// and TomRemoteApis for structured API management.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

void run() {
  print('=== 02: Connection Configuration Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Working with MIME types
  // -------------------------------------------------------------------------
  print('1. MIME Types:');

  // Predefined MIME types
  final jsonMime = TomMimeType.json;
  final htmlMime = TomMimeType.html;
  final pdfMime = TomMimeType.pdf;
  final octetMime = TomMimeType.octetStream;

  print('   - JSON: ${jsonMime.primaryType}/${jsonMime.subType}');
  print('   - HTML: ${htmlMime.primaryType}/${htmlMime.subType}');
  print('   - PDF: ${pdfMime.primaryType}/${pdfMime.subType}, charset: ${pdfMime.charset ?? "none"}');
  print('   - Octet-stream: ${octetMime.primaryType}/${octetMime.subType}');

  // Header value generation
  final jsonHeader = jsonMime.toHeaderValue();
  final pdfHeader = pdfMime.toHeaderValue();
  print('   - JSON header value: $jsonHeader');
  print('   - PDF header value: $pdfHeader\n');

  // -------------------------------------------------------------------------
  // Example 2: Parsing and comparing MIME types
  // -------------------------------------------------------------------------
  print('2. Parsing and comparing MIME types:');

  final parsedJson = TomMimeType.parse('application/json');
  final parsedHtml = TomMimeType.parse('text/html');

  print('   - Parsed JSON: ${parsedJson.primaryType}/${parsedJson.subType}');
  print('   - Parsed HTML: ${parsedHtml.primaryType}/${parsedHtml.subType}');

  // Check if types match
  final jsonMatch = jsonMime.isEqualType(parsedJson);
  print('   - JSON constants match parsed: $jsonMatch');

  // Text detection
  final jsonIsText = jsonMime.isText;
  final pdfIsText = pdfMime.isText;
  final htmlIsText = htmlMime.isText;
  print('   - JSON isText: $jsonIsText');
  print('   - PDF isText: $pdfIsText');
  print('   - HTML isText: $htmlIsText\n');

  // -------------------------------------------------------------------------
  // Example 3: Creating custom MIME types
  // -------------------------------------------------------------------------
  print('3. Custom MIME types:');

  final customMime = TomMimeType('application', 'vnd.api+json');
  final videoMime = TomMimeType(
    'video',
    'mp4',
    charset: null,
    codecs: ['avc1.42E01E', 'mp4a.40.2'],
  );

  print('   - Custom API MIME: ${customMime.primaryType}/${customMime.subType}');
  print('   - Video MIME: ${videoMime.primaryType}/${videoMime.subType}');
  print('   - Video codecs: ${videoMime.codecs}');
  print('   - Custom isText: ${customMime.isText}\n');

  // -------------------------------------------------------------------------
  // Example 4: File extension to MIME type mapping
  // -------------------------------------------------------------------------
  print('4. File extension mapping:');

  final jsonExt = StaticFileMimetypeMapping.getMimeType('.json');
  final pngExt = StaticFileMimetypeMapping.getMimeType('.png');
  final mp4Ext = StaticFileMimetypeMapping.getMimeType('.mp4');
  final unknownExt = StaticFileMimetypeMapping.getMimeType('.xyz');

  print('   - .json maps to: ${jsonExt?.primaryType}/${jsonExt?.subType}');
  print('   - .png maps to: ${pngExt?.primaryType}/${pngExt?.subType}');
  print('   - .mp4 maps to: ${mp4Ext?.primaryType}/${mp4Ext?.subType}');
  print('   - .xyz maps to: ${unknownExt ?? "null (unknown)"}\n');

  // -------------------------------------------------------------------------
  // Example 5: HTTP header constants
  // -------------------------------------------------------------------------
  print('5. HTTP Header constants:');

  print('   - Content-Type header: ${TomHeader.contentType}');
  print('   - Content-Disposition header: ${TomHeader.contentDisposition}');
  print('   - Attachment disposition: ${TomContentDisposition.attachment}\n');

  // -------------------------------------------------------------------------
  // Example 6: Defining API endpoints
  // -------------------------------------------------------------------------
  print('6. API endpoint definitions:');

  // Define an endpoint
  final getUserEndpoint = TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
    id: 'getUser',
    uri: '/get',
    method: TomHttpMethod.get,
    consumes: TomMimeType.none,
    produces: TomMimeType.json,
    description: 'Retrieves a user by ID',
  );

  final createUserEndpoint = TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
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

  final downloadEndpoint = TomApiEndpoint<Map<String, Object?>, Map<String, Object?>>(
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
  print('     • Produces: ${getUserEndpoint.produces.primaryType}/${getUserEndpoint.produces.subType}');

  print('   - Create User endpoint:');
  print('     • ID: ${createUserEndpoint.id}');
  print('     • Method: ${createUserEndpoint.method.name}');
  print('     • Consumes: ${createUserEndpoint.consumes.primaryType}/${createUserEndpoint.consumes.subType}');
  print('     • Request headers: ${createUserEndpoint.requestHeaders}');

  print('   - Download endpoint:');
  print('     • ID: ${downloadEndpoint.id}');
  print('     • Content-Disposition: ${downloadEndpoint.contentDisposition}\n');

  // -------------------------------------------------------------------------
  // Example 7: Creating and registering APIs
  // -------------------------------------------------------------------------
  print('7. API registration and management:');

  // Create an API with endpoints
  final userApi = TomApi(
    id: 'userApi',
    name: 'User Management API',
    description: 'Handles user CRUD operations',
    uri: '/api/v1/users',
    endpoints: [getUserEndpoint, createUserEndpoint],
  );

  final reportApi = TomApi(
    id: 'reportApi',
    name: 'Report API',
    description: 'Generates and downloads reports',
    uri: '/api/v1/reports',
    endpoints: [downloadEndpoint],
  );

  print('   - User API: ${userApi.name}');
  print('     • ID: ${userApi.id}');
  print('     • Base URI: ${userApi.uri}');
  print('     • Endpoints: ${userApi.endpoints.keys.toList()}');

  print('   - Report API: ${reportApi.name}');
  print('     • ID: ${reportApi.id}');
  print('     • Base URI: ${reportApi.uri}\n');

  // -------------------------------------------------------------------------
  // Example 8: TomRemoteApis registry
  // -------------------------------------------------------------------------
  print('8. Remote APIs registry:');

  // Register APIs
  TomRemoteApis.registerApi(userApi);
  TomRemoteApis.registerApi(reportApi);
  print('   - Registered userApi and reportApi');

  // Retrieve by ID
  final retrievedUserApi = TomRemoteApis.getApiById('userApi');
  print('   - Retrieved API: ${retrievedUserApi.name}');

  // Access via global accessor
  final globalAccessedApi = tomRemoteApis['reportApi'];
  print('   - Global accessor result: ${globalAccessedApi.name}');

  // Access endpoint from API
  final getEndpoint = retrievedUserApi['getUser'];
  print('   - Retrieved endpoint: ${getEndpoint.id} (${getEndpoint.method.name})');

  // Bracket notation for registration
  tomRemoteApis['customApi'] = TomApi(
    id: 'customApi',
    name: 'Custom API',
    uri: '/custom',
    endpoints: [],
  );
  print('   - Registered customApi via bracket notation\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: MIME types
  assert(jsonMime.primaryType == 'application');
  assert(jsonMime.subType == 'json');
  assert(pdfMime.charset == null);
  assert(jsonHeader == 'application/json;charset=UTF-8');

  // Example 2: Parsing and comparing
  assert(parsedJson.primaryType == 'application');
  assert(parsedJson.subType == 'json');
  assert(jsonMatch == true);
  assert(jsonIsText == true);
  assert(pdfIsText == false);
  assert(htmlIsText == true);

  // Example 3: Custom MIME types
  assert(customMime.isText == true); // +json suffix
  assert(videoMime.codecs.length == 2);

  // Example 4: File extension mapping
  assert(jsonExt != null);
  assert(jsonExt!.subType == 'json');
  assert(pngExt != null);
  assert(unknownExt == null);

  // Example 5: Header constants
  assert(TomHeader.contentType == 'Content-Type');
  assert(TomHeader.contentDisposition == 'Content-Disposition');

  // Example 6: Endpoint definitions
  assert(getUserEndpoint.id == 'getUser');
  assert(getUserEndpoint.method == TomHttpMethod.get);
  assert(createUserEndpoint.consumes == TomMimeType.json);
  assert(downloadEndpoint.contentDisposition != null);

  // Example 7: API creation
  assert(userApi.endpoints.length == 2);
  assert(userApi.endpoints.containsKey('getUser'));
  assert(userApi.endpoints.containsKey('createUser'));

  // Example 8: Registry
  assert(retrievedUserApi.id == 'userApi');
  assert(globalAccessedApi.id == 'reportApi');
  assert(getEndpoint.id == 'getUser');
  assert(tomRemoteApis.apis.containsKey('customApi'));
}
