/// Executable example for the endpoints module of `tom_core_server`.
///
/// The full pipeline ([TomEndpointRouting] / [TomEndpointHandler]) reflects over
/// annotated service classes and serves live HTTP requests, so it needs a
/// running server and generated reflection — it is described in
/// `doc/endpoints.md` rather than run here. This example shows the
/// reflection-free surface: the endpoint-defining annotations, the default
/// error handler's `Response`, and the file slot's default-closed rule.
///
/// Run with `dart run example/endpoints/endpoints_example.dart`.
/// The same behaviour is covered by `test/endpoints_test.dart` and, for the
/// file slot, `test/file_endpoint_test.dart`.
library;

import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> run() async {
  // 1. An inline endpoint declaration. Every field has a default, so a bare
  //    @TomEndpoint() is a JSON GET at "/".
  const endpoint = TomEndpoint(
    uri: '/greet',
    methods: [TomHttpMethod.post, TomHttpMethod.put],
  );
  print('1. endpoint: ${endpoint.uri} ${endpoint.methods}');
  print('   consumes=${endpoint.consumes} produces=${endpoint.produces}');
  assert(endpoint.uri == '/greet');
  assert(endpoint.methods.length == 2);
  assert(endpoint.consumes == TomMimeType.json);
  // convertToTomEndpoint returns the endpoint itself.
  assert(identical(endpoint.convertToTomEndpoint(), endpoint));

  // 2. A registry-bound endpoint only carries implementation-side overrides;
  //    the route comes from tomRemoteApis[apiId][endpointId].
  const apiEndpoint = TomApiEndpointImplementation(
    apiId: 'orders',
    endpointId: 'create',
    logRequests: true,
  );
  print(
    '2. api endpoint: ${apiEndpoint.apiId}.${apiEndpoint.endpointId} '
    'logRequests=${apiEndpoint.logRequests}',
  );
  assert(apiEndpoint.apiId == 'orders');

  // 3. Class-level markers: a service to scan, an API implementation, and a
  //    component reference pointing at the implementing bean.
  const service = tomService;
  const apiImpl = TomApiImplementation(apiId: 'orders');
  const ref = TomComponentReference(componentName: 'orderService');
  print(
    '3. service=$service apiImpl=${apiImpl.apiId} '
    'ref=${ref.componentName} logDefault=${apiImpl.logRequestsDefault}',
  );
  assert(apiImpl.logRequestsDefault == true);
  assert(ref.componentName == 'orderService');

  // 4. A transactional, read-only endpoint directive.
  const tx = TomTransactional(isReadOnly: true);
  print('4. transactional=${tx.isTransactional} readOnly=${tx.isReadOnly}');
  assert(tx.isTransactional == true);
  assert(tx.isReadOnly == true);

  // 5. The default error handler hides the error behind an opaque 500.
  const handler = TomDefaultErrorHandler();
  final response = handler.handleInvocationError(
    StateError('boom'),
    StackTrace.current,
    Request('POST', Uri.parse('http://localhost/greet')),
  );
  print('5. default error handler => HTTP ${response.statusCode}');
  assert(response.statusCode == 500);

  // 6. A form endpoint. `formFields` is an allow-list: left empty, every text
  //    part folds into the request DTO; named, only those do.
  const formEndpoint = TomEndpoint(
    uri: '/documents',
    methods: [TomHttpMethod.post],
    consumes: TomMimeType.multipartFormData,
    formFields: ['title', 'tags'],
  );
  print(
    '6. form endpoint: ${formEndpoint.uri} '
    'consumes=${formEndpoint.consumes} fields=${formEndpoint.formFields}',
  );
  // Both HTML form shapes answer the same question; only the reading differs.
  assert(tomConsumesForm(formEndpoint.consumes));
  assert(tomConsumesForm(TomMimeType.urlEncoded));
  assert(!tomConsumesForm(TomMimeType.json));
  assert(tomConsumesMultipartForm(formEndpoint.consumes));
  assert(!tomConsumesMultipartForm(TomMimeType.urlEncoded));

  // 7. A decoded form: text fields fold into the DTO, file parts bind as typed
  //    parameters (a file cannot travel through a JSON map into a DTO).
  final form = TomMultipartForm(
    fields: {'title': 'Quarterly report', 'tags': 'q3,final'},
    files: [
      TomFormFile(
        field: 'attachment',
        bytes: Uint8List.fromList('the numbers'.codeUnits),
        fileName: 'q3.txt',
        mediaType: 'text/plain',
      ),
    ],
  );
  final attachment = form.file('attachment')!;
  print(
    '7. form: fields=${form.fields.keys.toList()} '
    'file=${attachment.fileName} (${attachment.byteCount} bytes)',
  );
  assert(attachment.field == 'attachment');
  assert(form.file('missing') == null);

  // 8. A redirect is a directive, not a hand-built response: the handler states
  //    the status and the URL, and the pipeline builds the Response.
  final redirect = TomRedirect.seeOther('/documents/42');
  final redirectResponse = redirect.toResponse();
  print(
    '8. redirect => HTTP ${redirectResponse.statusCode} '
    '-> ${redirectResponse.headers[TomHeader.location.toLowerCase()]}',
  );
  assert(redirectResponse.statusCode == 303);
  assert(TomRedirect.permanent('/x').status == 308);

  // 9. A socket is a kind of endpoint, not a second server: it implements the
  //    same TomEndpointBase the scan already keys on, and converts to a GET.
  const socketEndpoint = TomWebSocketEndpoint(uri: '/ws/ticker');
  final converted = socketEndpoint.convertToTomEndpoint();
  print(
    '9. socket endpoint: ${socketEndpoint.uri} '
    'routes as ${converted.methods}',
  );
  // Assigning it to the base type is the whole point: `tag is TomEndpointBase`
  // is what the pipeline's scan asks of every annotation it finds.
  const TomEndpointBase asBase = socketEndpoint;
  assert(identical(asBase, socketEndpoint));
  assert(converted.methods.single == TomHttpMethod.get);

  // 10. A file slot. Expectations from here down are written as `if`/`throw`
  //     rather than `assert`, because `dart run` — the command this file's own
  //     header documents — compiles an assert out, so the checks above print
  //     their transcript without ever being evaluated.
  //
  //     The route is fixed and the address is derived: a slot is
  //     `<table>/<id>/<column>`, and both names come from annotations the
  //     entity already carries, so no mapping table exists here to go stale.
  print('10. file route: ${TomFileEndpoint.routeUri}');
  if (TomFileEndpoint.routeUri !=
      '${TomFileEndpoint.basePath}/{entity}/{id}/{column}') {
    throw StateError('a file route must carry the three slot segments');
  }

  //     Exposure is default-closed, and that is observable with nothing
  //     registered. Reflection can see every file column of every entity and
  //     publishes none of them: a column becomes reachable only when a
  //     repository is registered, and then only if its `@TomFileReference` says
  //     `exposed: true`. Registration itself needs generated reflection and so
  //     belongs with the running server in `doc/endpoints.md` — but what it
  //     decides is visible from here.
  if (TomFileSlots.slots.isNotEmpty) {
    throw StateError('no slot is reachable before a repository is registered');
  }
  if (TomFileSlots.resolve('document', 'attachment') != null) {
    throw StateError('an unregistered column must not resolve to a slot');
  }

  //     Which is the answer step 7's form part gets. `storeIn` is the join
  //     between the two upload shapes — a multipart part reaches the store
  //     through the *same* slot the raw-body endpoint uses — so it meets the
  //     same closed door and reports it the same way. Over HTTP that key is a
  //     404: a closed column is answered exactly as a non-existent one, rather
  //     than telling a caller which columns exist but are not theirs.
  try {
    await attachment.storeIn('document', 'attachment', '42');
    throw StateError('storing into an unregistered slot must not succeed');
  } on TomFileSlotException catch (error) {
    print('10. storeIn without a registered slot => ${error.key}');
    if (error.key != 'file_endpoint.unknown_slot') rethrow;
  }

  print('\nEndpoints example completed.');
}

Future<void> main() async {
  await run();
}
