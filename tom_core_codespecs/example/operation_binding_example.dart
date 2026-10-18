// CE-API — a second HTTP shape for an operation that already has a name.
//
// `tom_core_server` gives every endpoint exactly one shape, so serving the
// operation `createUser` both as the CE-API call and as a SCIM `/Users`
// resource would otherwise take a second hand-written handler. A binding
// instead names the operation and says how the second protocol spells it: the
// route, which wire parameter supplies which request member, and which error
// format a failure is written in.
//
// Run with:
//   dart run --enable-asserts example/operation_binding_example.dart

import 'package:tom_core_codespecs/tom_core_codespecs.dart';

import 'require_asserts.dart';

/// The SCIM shape of `createUser` — a top-level const, as the server project
/// declares it.
const scimCreateUser = TomOperationBinding(
  'createUser',
  method: 'POST',
  path: '/Users',
  versionPrefix: '/scim/v2',
  parameters: [
    TomBindingParameter(
      'userName',
      source: TomBindingSource.body,
      member: 'login',
    ),
  ],
  successStatus: 201,
  responseHeaders: ['Location'],
  consumes: 'application/scim+json',
  produces: 'application/scim+json',
  errorFormat: TomBindingErrorFormat.scim,
);

/// A read binding whose path carries two captures.
const scimGroupMember = TomOperationBinding(
  'getGroupMember',
  method: 'GET',
  path: '/Groups/{groupId}/members/{userId}',
  versionPrefix: '/scim/v2',
  parameters: [
    TomBindingParameter(
      'groupId',
      source: TomBindingSource.path,
      member: 'group',
    ),
    TomBindingParameter(
      'userId',
      source: TomBindingSource.path,
      member: 'user',
    ),
  ],
);

void main() {
  requireAsserts();
  print('== CE-API: operation bindings ==');

  print(
    '  ${scimCreateUser.method} ${scimCreateUser.route} '
    '-> ${scimCreateUser.operation} (${scimCreateUser.successStatus})',
  );
  assert(scimCreateUser.route == '/scim/v2/Users');
  assert(scimCreateUser.pathCaptures.isEmpty, 'POST /Users captures nothing');
  assert(TomOperationBinding.methods.contains(scimCreateUser.method));

  // The wire name and the operation's member name differ, and that is the
  // point: SCIM says `userName`, the specification says `login`.
  final wire = scimCreateUser.parameters.single;
  print(
    '  wire "${wire.name}" (${wire.source.name}) supplies "${wire.member}"',
  );
  assert(wire.name != wire.member);

  print(
    '  ${scimGroupMember.route} captures '
    '${scimGroupMember.pathCaptures.join(", ")}',
  );
  assert(scimGroupMember.pathCaptures.length == 2);
  assert(scimGroupMember.pathCaptures.first == 'groupId');

  // Every capture is supplied by a path parameter — the check a validator
  // makes, and one a binding makes askable.
  final pathParams = {
    for (final p in scimGroupMember.parameters)
      if (p.source == TomBindingSource.path) p.name,
  };
  assert(scimGroupMember.pathCaptures.every(pathParams.contains));

  // The defaults describe the primary CE-API shape: JSON in the CE-ER envelope.
  assert(scimGroupMember.successStatus == 200);
  assert(scimGroupMember.produces == 'application/json');
  assert(scimGroupMember.errorFormat == TomBindingErrorFormat.resultEnvelope);
  print('  defaults: 200, application/json, the CE-ER result envelope');
}
