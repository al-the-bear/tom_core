/// Delivery reporting: the correlation index, the vendor mapping, and the
/// callback endpoint that joins them.
///
/// The gap this closes is specific. `TomDeliveryReceipt.remoteId` was written
/// by every transport that had an id to give and read by nothing, so the module
/// could report that a message was *paid for* and never that it arrived. What
/// is asserted here is the round trip: an outbox that remembers the id a
/// transport came back with, a protocol that reads a carrier's callback, and an
/// endpoint that puts the two together — plus the refusals, which on a public
/// URL are the part worth being sure about.
///
/// Connection-free: no socket, no database. The SQL store's statements are
/// covered by `framework_schema_test.dart`, which audits them against the table
/// descriptor, and its behaviour by `delivery_report_db_test.dart` where a
/// database is reachable.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A transport that accepts everything and hands back the carrier id it is
/// told to — the seam between "sent" and "reported".
class _IdIssuingTransport extends TomMessageTransport {
  _IdIssuingTransport(this.remoteId);

  final String? remoteId;

  @override
  TomMessageChannel get channel => TomMessageChannel.sms;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async =>
      TomDeliveryReceipt(
        messageId: message.id,
        outcome: TomDeliveryOutcome.delivered,
        remoteId: remoteId,
        at: DateTime.utc(2026, 9, 15, 12),
      );
}

TomMessage _sms({String id = 'm1'}) => TomMessage(
  id: id,
  channel: TomMessageChannel.sms,
  recipients: [TomRecipient('+41791234567')],
  bodies: [TomMessageBody.text('hello')],
);

TomDeliveryCorrelation _correlation({
  String remoteId = 'SM1',
  String messageId = 'm1',
  DateTime? sentAt,
}) => TomDeliveryCorrelation(
  remoteId: remoteId,
  messageId: messageId,
  channel: TomMessageChannel.sms,
  sentAt: sentAt ?? DateTime.utc(2026, 9, 15, 12),
);

/// The shape the common gateways post: a batch of per-message statuses.
const _protocol = TomFieldMappedDeliveryReportProtocol(
  batchPath: 'statuses',
  remoteIdPath: 'sid',
  statusPath: 'status',
  detailPath: 'message',
  codePath: 'code',
  atPath: 'occurredAt',
);

Request _callback(Object? body, {String? secret = 'shared-secret'}) => Request(
  'POST',
  Uri.parse('https://example.com/messaging/delivery-report'),
  body: body == null ? '' : jsonEncode(body),
  headers: {if (secret != null) TomDeliveryReportEndpoint.secretHeader: secret},
);

Future<Map<String, Object?>> _bodyOf(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, Object?>;

void main() {
  tearDown(TomDeliveryReportEndpoint.reset);

  group('the state a carrier reports is not the outcome a transport saw', () {
    test('a message can be delivered and then fail', () {
      // The distinction the whole feature rests on. An outcome is what *this*
      // attempt achieved — the gateway took it; a state is what the carrier did
      // with it afterwards, hours later and over a different network.
      final receipt = TomDeliveryReceipt(
        messageId: 'm1',
        outcome: TomDeliveryOutcome.delivered,
        remoteId: 'SM1',
      );
      final report = TomDeliveryReport(
        remoteId: 'SM1',
        state: TomDeliveryState.failed,
      );
      expect(receipt.isDelivered, isTrue);
      expect(report.state, TomDeliveryState.failed);
    });

    test('there are four states, and expiry is its own', () {
      // Pinned by name. `expired` is separate from `failed` because the
      // remedies differ: an expiry is worth re-sending later, a failure is an
      // address to stop using.
      expect(TomDeliveryState.values, [
        TomDeliveryState.delivered,
        TomDeliveryState.failed,
        TomDeliveryState.expired,
        TomDeliveryState.unknown,
      ]);
    });

    test('an unrecognised state name reads as unknown, not as an error', () {
      // A name written by one version and read by another must not throw: that
      // is exactly what `unknown` means, and a throw here would lose a report
      // that did happen.
      expect(TomDeliveryReport.stateOf('teleported'), TomDeliveryState.unknown);
      expect(TomDeliveryReport.stateOf(null), TomDeliveryState.unknown);
    });

    test('a report survives a JSON round trip', () {
      final report = TomDeliveryReport(
        remoteId: 'SM1',
        state: TomDeliveryState.expired,
        at: DateTime.utc(2026, 9, 15, 13),
        detail: 'handset off',
        providerCode: '30005',
      );
      final back = TomDeliveryReport.fromJson(report.toJson());
      expect(back.remoteId, 'SM1');
      expect(back.state, TomDeliveryState.expired);
      expect(back.at, DateTime.utc(2026, 9, 15, 13));
      expect(back.detail, 'handset off');
      expect(back.providerCode, '30005');
    });
  });

  group('the correlation index', () {
    test('remembers an id and gives back the message', () async {
      final store = TomMemoryDeliveryReportStore();
      await store.remember(_correlation());
      expect((await store.messageOf('SM1'))?.messageId, 'm1');
    });

    test('an unremembered id is null, not an error', () async {
      // A report can arrive for a message this node never sent — another
      // deployment sharing a gateway account — or after the row was purged.
      final store = TomMemoryDeliveryReportStore();
      expect(await store.messageOf('SM1'), isNull);
      expect(
        await store.record(
          TomDeliveryReport(remoteId: 'SM1', state: TomDeliveryState.delivered),
        ),
        isNull,
      );
    });

    test('a row is unreported until a report arrives', () async {
      final store = TomMemoryDeliveryReportStore();
      await store.remember(_correlation());
      expect((await store.messageOf('SM1'))!.isReported, isFalse);

      final updated = await store.record(
        TomDeliveryReport(
          remoteId: 'SM1',
          state: TomDeliveryState.delivered,
          at: DateTime.utc(2026, 9, 15, 12, 5),
          detail: 'ok',
        ),
      );
      expect(updated!.isReported, isTrue);
      expect(updated.state, TomDeliveryState.delivered);
      expect(updated.reportedAt, DateTime.utc(2026, 9, 15, 12, 5));
      expect(updated.detail, 'ok');
      expect(
        updated.messageId,
        'm1',
        reason: 'the report must not overwrite what the row is for',
      );
    });

    test('a later report replaces an earlier one', () async {
      // Carriers send intermediate statuses. The last one is the answer.
      final store = TomMemoryDeliveryReportStore();
      await store.remember(_correlation());
      await store.record(
        TomDeliveryReport(remoteId: 'SM1', state: TomDeliveryState.unknown),
      );
      final last = await store.record(
        TomDeliveryReport(remoteId: 'SM1', state: TomDeliveryState.delivered),
      );
      expect(last!.state, TomDeliveryState.delivered);
    });

    test('the sweep drops by send time, not report time', () async {
      // Retention is about how long the index is kept, and a message sent long
      // ago whose report never came is exactly the row worth dropping.
      final store = TomMemoryDeliveryReportStore();
      await store.remember(
        _correlation(remoteId: 'old', sentAt: DateTime.utc(2026, 1, 1)),
      );
      await store.remember(
        _correlation(remoteId: 'new', sentAt: DateTime.utc(2026, 9, 1)),
      );
      expect(await store.purgeSentBefore(DateTime.utc(2026, 6, 1)), 1);
      expect(await store.messageOf('old'), isNull);
      expect(await store.messageOf('new'), isNotNull);
    });
  });

  group('the outbox remembers what a transport came back with', () {
    test('a receipt with a carrier id is indexed', () async {
      final store = TomMemoryDeliveryReportStore();
      final outbox = TomMessageOutbox(
        router: TomMessageRouter([_IdIssuingTransport('SM1')]),
        reportStore: store,
      );
      addTearDown(outbox.close);

      await outbox.sendNow(_sms());

      final row = await store.messageOf('SM1');
      expect(row, isNotNull);
      expect(row!.messageId, 'm1');
      expect(row.channel, TomMessageChannel.sms);
      expect(row.sentAt, DateTime.utc(2026, 9, 15, 12));
      expect(row.isReported, isFalse);
    });

    test('a receipt without one writes no row nobody could match', () async {
      final store = TomMemoryDeliveryReportStore();
      final outbox = TomMessageOutbox(
        router: TomMessageRouter([_IdIssuingTransport(null)]),
        reportStore: store,
      );
      addTearDown(outbox.close);

      await outbox.sendNow(_sms());

      expect(store.correlations, isEmpty);
    });

    test('an outbox with no index still delivers', () async {
      // The index is opt-in: a deployment whose channels report nothing back
      // configures none, and nothing about delivery changes.
      final outbox = TomMessageOutbox(
        router: TomMessageRouter([_IdIssuingTransport('SM1')]),
      );
      addTearDown(outbox.close);

      await outbox.sendNow(_sms());

      final run = (await outbox.store.all()).single;
      expect(run.state, TomJobRunState.succeeded);
    });
  });

  group('the vendor mapping', () {
    test('reads a batch of statuses', () {
      final reports = _protocol.decode(
        TomDeliveryCallback(
          body: {
            'statuses': [
              {
                'sid': 'SM1',
                'status': 'delivered',
                'occurredAt': '2026-09-15T13:00:00Z',
              },
              {'sid': 'SM2', 'status': 'undelivered', 'code': '30003'},
            ],
          },
        ),
      );
      expect(reports, hasLength(2));
      expect(reports.first.remoteId, 'SM1');
      expect(reports.first.state, TomDeliveryState.delivered);
      expect(reports.first.at, DateTime.utc(2026, 9, 15, 13));
      expect(reports.last.state, TomDeliveryState.failed);
      expect(reports.last.providerCode, '30003');
    });

    test('a status the mapping does not name is unknown, not delivered', () {
      // The direction that matters. Reading an unmapped status as success would
      // report every new carrier state as a delivery.
      final reports = _protocol.decode(
        TomDeliveryCallback(
          body: {
            'statuses': [
              {'sid': 'SM1', 'status': 'accepted'},
            ],
          },
        ),
      );
      expect(reports.single.state, TomDeliveryState.unknown);
    });

    test('an entry with no id is dropped rather than half-read', () {
      final reports = _protocol.decode(
        TomDeliveryCallback(
          body: {
            'statuses': [
              {'status': 'delivered'},
              {'sid': 'SM2', 'status': 'delivered'},
            ],
          },
        ),
      );
      expect(reports.map((r) => r.remoteId), ['SM2']);
    });

    test('an unparseable timestamp leaves arrival time, not a refusal', () {
      // A bad timestamp is not a reason to refuse a status.
      final reports = _protocol.decode(
        TomDeliveryCallback(
          body: {
            'statuses': [
              {'sid': 'SM1', 'status': 'delivered', 'occurredAt': 'yesterday'},
            ],
          },
        ),
      );
      expect(reports.single.at.isUtc, isTrue);
    });

    test('a body this protocol cannot read yields nothing', () {
      expect(_protocol.decode(TomDeliveryCallback(body: 'nonsense')), isEmpty);
      expect(_protocol.decode(TomDeliveryCallback()), isEmpty);
    });

    test('a carrier reporting in the query string is read too', () {
      // Several gateways report over GET. The protocol is handed the parameters
      // when there is no body, which is what makes one mapping serve both.
      const flat = TomFieldMappedDeliveryReportProtocol(
        remoteIdPath: 'id',
        statusPath: 'st',
      );
      final reports = flat.decode(
        TomDeliveryCallback(parameters: {'id': 'SM9', 'st': 'delivered'}),
      );
      expect(reports.single.remoteId, 'SM9');
      expect(reports.single.state, TomDeliveryState.delivered);
    });
  });

  group('the declared route', () {
    // Read from the source that declares them. The mounted route is produced by
    // the reflection-based endpoints pipeline from a *generated* mirror that is
    // checked in, so a test driving the pipeline observes the annotation values
    // as they were when somebody last regenerated — changing `uri` here, or the
    // access annotation, would leave such a test green. The source is the only
    // place these four facts are current.
    final source = File(
      'lib/src/tomserver/messaging/delivery_report_endpoint.dart',
    ).readAsStringSync();
    final annotation = source.substring(
      source.indexOf('@TomPublicAccess()'),
      source.indexOf('Future<Response> deliveryReport('),
    );

    test('is mounted at the route the endpoint names', () {
      expect(annotation, contains('uri: TomDeliveryReportEndpoint.routeUri'));
      expect(
        TomDeliveryReportEndpoint.routeUri,
        '/messaging/delivery-report',
        reason: 'the path is a contract a carrier is configured with',
      );
    });

    test('is public, because a carrier has no account here', () {
      // A callback is a machine on someone else's network. The pipeline's
      // default, and the file endpoint's `@TomAuthenticatedAccess`, would
      // refuse every real report — so the route is public and the shared secret
      // is what gates it.
      expect(annotation, contains('@TomPublicAccess()'));
      expect(annotation, isNot(contains('TomAuthenticatedAccess')));
    });

    test('takes POST only', () {
      expect(annotation, contains('methods: [TomHttpMethod.post]'));
    });

    test('keeps carrier traffic out of the request log', () {
      // A carrier reporting on every message doubles the access log, and the
      // reports themselves are recorded in the index — the record worth keeping.
      expect(annotation, contains('logRequests: false'));
    });
  });

  group('the callback endpoint', () {
    void install({TomDeliveryReportStore? store}) =>
        TomDeliveryReportEndpoint.install(
          store: store ?? TomMemoryDeliveryReportStore(),
          protocol: _protocol,
          secret: 'shared-secret',
        );

    test('an unconfigured endpoint refuses, and says which refusal', () async {
      // 503 rather than 404: the component is mounted and the deployment wired
      // neither store nor protocol, and a 404 would read as "wrong URL".
      final response = await TomDeliveryReportEndpoint.handle(_callback(null));
      expect(response.statusCode, 503);
      expect(
        (await _bodyOf(response))['key'],
        'messaging.delivery_report.not_configured',
      );
    });

    test('a callback with no secret is refused', () async {
      install();
      final response = await TomDeliveryReportEndpoint.handle(
        _callback({'statuses': []}, secret: null),
      );
      expect(response.statusCode, 401);
    });

    test('a callback with the wrong secret is refused', () async {
      install();
      final response = await TomDeliveryReportEndpoint.handle(
        _callback({'statuses': []}, secret: 'guess'),
      );
      expect(response.statusCode, 401);
    });

    test('a secret that is a prefix of the real one is refused', () async {
      // The comparison is over the whole value, not a prefix — the failure a
      // naive constant-time loop over the shorter string would have.
      install();
      final response = await TomDeliveryReportEndpoint.handle(
        _callback({'statuses': []}, secret: 'shared'),
      );
      expect(response.statusCode, 401);
    });

    test('an empty secret cannot be installed', () {
      // A gate that lets everything through is worse than no gate, because it
      // reads like one.
      expect(
        () => TomDeliveryReportEndpoint.install(
          store: TomMemoryDeliveryReportStore(),
          protocol: _protocol,
          secret: '',
        ),
        // A messaging exception, not the kernel's base type: a server raise
        // site throws the family, so `on TomServerException` reaches it and it
        // carries the isolate and the request like every other.
        throwsA(
          isA<TomMessagingException>().having(
            (e) => e.key,
            'key',
            'messaging.delivery_report.empty_secret',
          ),
        ),
      );
    });

    test('a recognised report is recorded and reported back', () async {
      final store = TomMemoryDeliveryReportStore();
      await store.remember(_correlation());
      install(store: store);

      final seen = <TomDeliveryCorrelation>[];
      final subscription = TomDeliveryReportEndpoint.reports.listen(seen.add);
      addTearDown(subscription.cancel);

      final response = await TomDeliveryReportEndpoint.handle(
        _callback({
          'statuses': [
            {'sid': 'SM1', 'status': 'delivered'},
          ],
        }),
      );

      expect(response.statusCode, 200);
      expect((await _bodyOf(response))['reports'], 1);
      expect((await store.messageOf('SM1'))!.state, TomDeliveryState.delivered);

      await Future<void>.delayed(Duration.zero);
      expect(seen.single.messageId, 'm1');
    });

    test('a report for an unknown id answers 404', () async {
      install();
      final response = await TomDeliveryReportEndpoint.handle(
        _callback({
          'statuses': [
            {'sid': 'nobody', 'status': 'delivered'},
          ],
        }),
      );
      expect(response.statusCode, 404);
      expect(
        (await _bodyOf(response))['key'],
        'messaging.delivery_report.unknown_message',
      );
    });

    test('a batch in which some matched is a success', () async {
      // A carrier cannot act on "three of your five ids are unknown to me", and
      // re-posting the batch would re-report the ones that did match.
      final store = TomMemoryDeliveryReportStore();
      await store.remember(_correlation());
      install(store: store);

      final response = await TomDeliveryReportEndpoint.handle(
        _callback({
          'statuses': [
            {'sid': 'nobody', 'status': 'delivered'},
            {'sid': 'SM1', 'status': 'delivered'},
          ],
        }),
      );
      expect(response.statusCode, 200);
      expect((await _bodyOf(response))['reports'], 1);
    });

    test('an unreadable body answers 400, not 500', () async {
      // A carrier retries a 5xx and gives up on a 4xx. A malformed body will
      // not parse on the second attempt either, so deferring it is a loop.
      install();
      final response = await TomDeliveryReportEndpoint.handle(
        Request(
          'POST',
          Uri.parse('https://example.com/messaging/delivery-report'),
          body: 'not json',
          headers: {TomDeliveryReportEndpoint.secretHeader: 'shared-secret'},
        ),
      );
      expect(response.statusCode, 400);
      expect(
        (await _bodyOf(response))['key'],
        'messaging.delivery_report.unreadable',
      );
    });

    test('a well-formed body carrying no report answers 400', () async {
      install();
      final response = await TomDeliveryReportEndpoint.handle(
        _callback({'statuses': []}),
      );
      expect(response.statusCode, 400);
      expect(
        (await _bodyOf(response))['key'],
        'messaging.delivery_report.no_report',
      );
    });

    test('reset puts the route back to refusing', () async {
      install();
      expect(TomDeliveryReportEndpoint.isGated, isTrue);
      TomDeliveryReportEndpoint.reset();
      expect(TomDeliveryReportEndpoint.isGated, isFalse);
      expect(TomDeliveryReportEndpoint.store, isNull);
      expect(
        (await TomDeliveryReportEndpoint.handle(_callback(null))).statusCode,
        503,
      );
    });
  });
}
