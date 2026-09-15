/// Worked `TomFieldMappedSmsProtocol` mappings for three named SMS gateways —
/// **as an example, not as library API**.
///
/// ## Why these are here and not in `lib/`
///
/// A vendor preset in the framework is a vendor's API frozen into a release.
/// When the vendor renames a field the preset becomes wrong, and a wrong
/// constant in a library is harder to route around than one that was never
/// there: a deployment has to notice it is wrong, decide the framework is at
/// fault rather than its own configuration, and then write the mapping by hand
/// anyway — having first been told by the presence of a preset that it did not
/// need to.
///
/// The real need a preset answers is **a worked mapping to copy**, and an
/// example answers it without the staleness problem. A stale example is
/// obviously the reader's to update; stale library API is not.
///
/// ## What "verified" means here, and what it does not
///
/// These mappings are written from each vendor's *published* request and
/// response shapes as of **2026-09-15**. They have not been exercised against a
/// live account, and this repository cannot exercise them: a preset for an API
/// that cannot be tested here is exactly the plausible-looking guess
/// `sms_transport.dart` declines to ship, and putting one in an example does
/// not make it verified.
///
/// What each mapping *is* checked against is a **sample answer in the vendor's
/// documented shape**, decoded through the protocol itself — step by step
/// below. That is a real assertion about the mapping (does it read the field it
/// claims to read, does it classify the code it claims to classify) and it is
/// not an assertion about the vendor. Before using one of these, read the
/// vendor's current documentation and update the sample; if the mapping still
/// decodes it, the mapping still works.
///
/// ## The shape almost every gateway has
///
/// Two of the three wrap their answer in a **list**, because their submission
/// APIs take a list of recipients and answer per recipient. Twilio is the
/// outlier: one message per call, a flat object. That is why the dotted paths
/// below contain a numeric segment — see [tomVendorValueAt].
///
/// Run with `dart run example/messaging/sms_gateway_presets.dart`. Every step
/// checks its own result and the run fails when one does not hold, so a green
/// run is a verification of the *mappings* and not just a transcript.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// =============================================================================
// THE PRESETS
// =============================================================================

/// Twilio: `POST /2010-04-01/Accounts/{AccountSid}/Messages.json`.
///
/// HTTP Basic with the account SID as the user and the auth token as the
/// password, a form-encoded body, and a flat JSON answer. One message per call,
/// which is why nothing here indexes a list.
///
/// `status` is the message's lifecycle state and `queued` / `accepted` /
/// `sending` / `sent` all mean the request was taken; `failed` and
/// `undelivered` are terminal and arrive with an `error_code`.
const twilio = TomFieldMappedSmsProtocol(
  format: TomSmsBodyFormat.form,
  toField: 'To',
  fromField: 'From',
  textField: 'Body',
  requiresSender: true,
  statusPath: 'status',
  acceptedStatuses: {'queued', 'accepted', 'sending', 'sent'},
  remoteIdPath: 'sid',
  errorCodePath: 'error_code',
  errorMessagePath: 'error_message',
  // 21211 invalid 'To'; 21610 the recipient unsubscribed; 21614 not a mobile
  // number. None of the three becomes deliverable by being tried again.
  permanentErrorCodes: {'21211', '21610', '21614'},
  // 20429 too many requests; 30001 queue overflow. Both are about now.
  transientErrorCodes: {'20429', '30001'},
);

/// A Twilio answer in its documented shape, for step 1.
const twilioAccepted =
    '{"sid":"SM1234","status":"queued","error_code":null,'
    '"error_message":null,"to":"+41791234567"}';

/// A Twilio refusal, for step 2.
const twilioRefused =
    '{"sid":"SM1235","status":"failed","error_code":21211,'
    '"error_message":"The To phone number is not valid."}';

/// Vonage: `POST https://rest.nexmo.com/sms/json`.
///
/// The credential travels in the body rather than in a header, which is what
/// [TomFieldMappedSmsProtocol.apiKeyField] and `apiSecretField` are for, and
/// the answer is a **list** — one entry per message part, because Vonage splits
/// a long text itself. The first entry is the one whose status decides the
/// submission.
///
/// Statuses are numeric strings and `"0"` is success, so `acceptedStatuses` is
/// `{'0'}` rather than a word.
const vonage = TomFieldMappedSmsProtocol(
  format: TomSmsBodyFormat.form,
  toField: 'to',
  fromField: 'from',
  textField: 'text',
  apiKeyField: 'api_key',
  apiSecretField: 'api_secret',
  requiresSender: true,
  statusPath: 'messages.0.status',
  acceptedStatuses: {'0'},
  remoteIdPath: 'messages.0.message-id',
  errorCodePath: 'messages.0.status',
  errorMessagePath: 'messages.0.error-text',
  // 2 missing parameters; 3 invalid parameter; 4 invalid credentials;
  // 6 the message is unroutable; 15 illegal sender address.
  permanentErrorCodes: {'2', '3', '4', '6', '15'},
  // 1 throttled; 5 an internal error at the gateway; 9 partner quota exceeded.
  transientErrorCodes: {'1', '5', '9'},
);

/// A Vonage answer in its documented shape, for step 3.
const vonageAccepted =
    '{"message-count":"1","messages":[{"to":"41791234567",'
    '"message-id":"0A0000001234ABCD","status":"0","remaining-balance":"3.14",'
    '"message-price":"0.03","network":"22801"}]}';

/// A Vonage refusal, for step 4.
const vonageThrottled =
    '{"message-count":"1","messages":[{"status":"1",'
    '"error-text":"Throttled"}]}';

/// MessageBird: `POST https://rest.messagebird.com/messages`.
///
/// `Authorization: AccessKey <key>` — which is neither of the two schemes
/// [TomSmsAuthScheme] names, so this one is configured as `none` and the header
/// is supplied by the deployment. A JSON body, and an answer nesting the
/// per-recipient result two levels down inside a list.
const messageBird = TomFieldMappedSmsProtocol(
  format: TomSmsBodyFormat.json,
  toField: 'recipients',
  fromField: 'originator',
  textField: 'body',
  requiresSender: true,
  statusPath: 'recipients.items.0.status',
  acceptedStatuses: {'sent', 'buffered', 'scheduled'},
  remoteIdPath: 'id',
  errorCodePath: 'errors.0.code',
  errorMessagePath: 'errors.0.description',
  // 2 request not allowed; 9 missing params; 21 bad request; 25 not enough
  // balance is permanent in the sense that retrying will not add funds.
  permanentErrorCodes: {'2', '9', '21', '25'},
  // 98 internal error; 99 service unavailable.
  transientErrorCodes: {'98', '99'},
);

/// A MessageBird answer in its documented shape, for step 5.
const messageBirdAccepted =
    '{"id":"e8077d803532c0b5937c639b60216938","originator":"TOMTEST",'
    '"body":"Your code is 123456.","recipients":{"totalCount":1,'
    '"totalSentCount":1,"items":[{"recipient":41791234567,"status":"sent"}]}}';

/// A MessageBird refusal, for step 6.
const messageBirdRefused =
    '{"errors":[{"code":21,"description":"request body can not be empty",'
    '"parameter":null}]}';

// =============================================================================
// THE WALKTHROUGH
// =============================================================================

Future<void> run() async {
  // 1. Twilio's flat answer. The mapping reads `sid` as the carrier id, which
  //    is what a delivery report later arrives under.
  final twilioOk = twilio.decode(201, twilioAccepted);
  print(
    '1. twilio accepted      => ${twilioOk.isAccepted} id ${twilioOk.remoteId}',
  );
  check(
    twilioOk.isAccepted,
    'a queued Twilio message is an accepted submission',
  );
  check(
    twilioOk.remoteId == 'SM1234',
    'the carrier id is read from the field the mapping names',
  );

  // 2. A refusal, classified by the vendor's own code rather than by the HTTP
  //    status — which is the layer that cannot tell 21211 from a rate limit.
  final twilioBad = twilio.decode(400, twilioRefused);
  print('2. twilio refused       => permanent ${twilioBad.isPermanent}');
  check(!twilioBad.isAccepted, 'a failed status is not an acceptance');
  check(
    twilioBad.isPermanent == true,
    'an invalid destination number will be invalid on the next attempt too',
  );

  // 3. Vonage answers in a list, because it splits a long text itself. Without
  //    a numeric segment there is no path from the root to `status` at all.
  final vonageOk = vonage.decode(200, vonageAccepted);
  print(
    '3. vonage accepted      => ${vonageOk.isAccepted} id ${vonageOk.remoteId}',
  );
  check(vonageOk.isAccepted, 'Vonage status "0" is success');
  check(
    vonageOk.remoteId == '0A0000001234ABCD',
    'the id is reached through the list the answer wraps it in',
  );

  // 4. Vonage reports its errors in the same field as its successes, so the
  //    status path and the error-code path are the same path — which the
  //    mapping expresses directly rather than needing a special case.
  final vonageBusy = vonage.decode(200, vonageThrottled);
  print('4. vonage throttled     => permanent ${vonageBusy.isPermanent}');
  check(!vonageBusy.isAccepted, 'a non-zero Vonage status is a refusal');
  check(
    vonageBusy.isPermanent == false,
    'throttling is the textbook transient failure: the same message later works',
  );

  // 5. MessageBird nests the per-recipient result two levels down, and puts the
  //    submission id at the top. Two different depths in one mapping.
  final birdOk = messageBird.decode(201, messageBirdAccepted);
  print(
    '5. messagebird accepted => ${birdOk.isAccepted} id ${birdOk.remoteId}',
  );
  check(birdOk.isAccepted, 'a sent recipient is an accepted submission');
  check(
    birdOk.remoteId == 'e8077d803532c0b5937c639b60216938',
    'the id is read from the top level while the status is read from the list',
  );

  // 6. And a refusal, whose code lives in a third place again.
  final birdBad = messageBird.decode(422, messageBirdRefused);
  print('6. messagebird refused  => permanent ${birdBad.isPermanent}');
  check(!birdBad.isAccepted, 'an error body is not an acceptance');
  check(
    birdBad.isPermanent == true,
    'a malformed request is not improved by being sent again',
  );

  // 7. The check that makes the other six worth something: a mapping pointed at
  //    a field the answer does not have must *not* read as success. A gateway
  //    that changed its shape has to produce an unclassifiable answer, because
  //    treating silence as acceptance is how a maintenance page becomes a
  //    delivered message.
  final renamed = twilio.decode(201, '{"message_sid":"SM1","state":"queued"}');
  print('7. a renamed field      => accepted ${renamed.isAccepted}');
  check(
    !renamed.isAccepted,
    'a status path that does not resolve is a refusal, never a success',
  );

  print('\nSMS gateway preset example completed.');
}

Future<void> main() async {
  await run();
}
