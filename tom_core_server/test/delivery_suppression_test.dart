/// Acting on delivery reports: the suppression list a failure feeds, the router
/// that consults it, and the Twilio and Vonage delivery-report presets.
///
/// The end-to-end case is the one the feature exists for: a message is sent,
/// the carrier reports its address as undeliverable, and the next message to
/// that address is not sent. The presets are checked against the sample
/// callbacks the two carriers document. Connection-free; the SQL list's
/// statements are covered by `framework_schema_test.dart` and its behaviour by
/// `delivery_suppression_db_test.dart`.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A transport that hands back a fixed carrier id and records what it sent.
class _CarrierTransport extends TomMessageTransport {
  _CarrierTransport({this.channel = TomMessageChannel.sms});

  @override
  final TomMessageChannel channel;

  final List<TomMessage> sent = [];

  @override
  bool get supportsCopies => true;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    sent.add(message);
    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      remoteId: 'SM${sent.length}',
    );
  }
}

TomMessage _sms(List<String> to, {String id = 'm1'}) => TomMessage(
  id: id,
  channel: TomMessageChannel.sms,
  recipients: [for (final address in to) TomRecipient(address)],
  bodies: [TomMessageBody.text('hello')],
);

TomDeliveryCorrelation _failed({
  List<String> addresses = const ['+14155552671'],
  TomDeliveryState state = TomDeliveryState.failed,
}) => TomDeliveryCorrelation(
  remoteId: 'SM1',
  messageId: 'm1',
  channel: TomMessageChannel.sms,
  sentAt: DateTime.utc(2026, 11, 7, 9),
  state: state,
  reportedAt: DateTime.utc(2026, 11, 7, 9, 1),
  detail: 'undelivered',
  providerCode: '30005',
  tenant: 'acme',
  addresses: addresses,
);

/// Twilio's status callback, as its documentation shows it: a form post.
String _twilioCallback({
  required String sid,
  required String status,
  String? errorCode,
  String to = '+14155552671',
}) => Uri(
  queryParameters: {
    'SmsSid': sid,
    'SmsStatus': status,
    'MessageStatus': status,
    'To': to,
    'MessagingServiceSid': 'MG1234567890abcdef1234567890abcdef',
    'MessageSid': sid,
    'AccountSid': 'AC1234567890abcdef1234567890abcdef',
    'From': '+15017122661',
    'ApiVersion': '2010-04-01',
    'ErrorCode': ?errorCode,
  },
).query;

/// Vonage's SMS delivery receipt, as its documentation shows it.
Map<String, String> _vonageReceipt({
  String status = 'delivered',
  String errCode = '0',
}) => {
  'msisdn': '447700900000',
  'to': 'AcmeInc',
  'network-code': '12345',
  'messageId': '0A0000001234567B',
  'price': '0.03330000',
  'status': status,
  'scts': '2001011400',
  'err-code': errCode,
  'api-key': 'abcd1234',
  'message-timestamp': '2020-01-01 12:00:00',
};

TomDeliveryReport _decodeOne(
  TomDeliveryReportProtocol protocol,
  TomDeliveryCallback callback,
) => protocol.decode(callback).single;

void main() {
  tearDown(TomDeliveryReportEndpoint.reset);

  group('the Twilio preset', () {
    final twilio = TomFieldMappedDeliveryReportProtocol.twilio();
    TomDeliveryReport read(String form) => _decodeOne(
      twilio,
      TomDeliveryCallback(parameters: Uri.splitQueryString(form)),
    );

    test('DS-1: a delivered callback reads as delivered, with its '
        'recipient', () {
      final report = read(_twilioCallback(sid: 'SMa1', status: 'delivered'));
      expect(report.remoteId, 'SMa1');
      expect(report.state, TomDeliveryState.delivered);
      expect(report.recipient, '+14155552671');
      expect(report.providerCode, isNull);
    });

    test('DS-2: an unknown handset (30005) is a failure, an unreachable one '
        '(30003) an expiry, a carrier filter (30007) unknown', () {
      expect(
        read(
          _twilioCallback(
            sid: 'SMa2',
            status: 'undelivered',
            errorCode: '30005',
          ),
        ).state,
        TomDeliveryState.failed,
      );
      final expired = read(
        _twilioCallback(sid: 'SMa3', status: 'undelivered', errorCode: '30003'),
      );
      expect(expired.state, TomDeliveryState.expired);
      expect(expired.providerCode, '30003');
      expect(
        read(
          _twilioCallback(sid: 'SMa4', status: 'failed', errorCode: '30007'),
        ).state,
        TomDeliveryState.unknown,
      );
    });

    test('DS-3: an unlisted code on a failure suppresses nothing, and an '
        'intermediate status is unknown', () {
      expect(
        read(
          _twilioCallback(sid: 'SMa5', status: 'failed', errorCode: '21610'),
        ).state,
        TomDeliveryState.unknown,
      );
      expect(
        read(_twilioCallback(sid: 'SMa6', status: 'sent')).state,
        TomDeliveryState.unknown,
      );
    });
  });

  group('the Vonage preset', () {
    final vonage = TomFieldMappedDeliveryReportProtocol.vonage();

    test('DS-4: a delivery receipt in the query string reads as delivered, '
        'its zone-less timestamp as UTC', () {
      final report = _decodeOne(
        vonage,
        TomDeliveryCallback(parameters: _vonageReceipt()),
      );
      expect(report.remoteId, '0A0000001234567B');
      expect(report.state, TomDeliveryState.delivered);
      expect(report.recipient, '447700900000');
      expect(report.at, DateTime.utc(2020, 1, 1, 12));
      expect(report.at.isUtc, isTrue);
    });

    test('DS-5: the same receipt posted as JSON reads alike', () {
      final report = _decodeOne(
        vonage,
        TomDeliveryCallback(body: _vonageReceipt()),
      );
      expect(report.state, TomDeliveryState.delivered);
      expect(report.at, DateTime.utc(2020, 1, 1, 12));
    });

    test('DS-6: err-code 3 is a failure, 2 an expiry, 99 unknown, and a '
        'rejection for spam (6) suppresses nothing', () {
      TomDeliveryState stateOf(String status, String code) => _decodeOne(
        vonage,
        TomDeliveryCallback(
          parameters: _vonageReceipt(status: status, errCode: code),
        ),
      ).state;
      expect(stateOf('failed', '3'), TomDeliveryState.failed);
      expect(stateOf('failed', '2'), TomDeliveryState.expired);
      expect(stateOf('expired', '2'), TomDeliveryState.expired);
      expect(stateOf('failed', '99'), TomDeliveryState.unknown);
      expect(stateOf('rejected', '6'), TomDeliveryState.unknown);
      expect(stateOf('rejected', '9'), TomDeliveryState.failed);
    });
  });

  group('the field-mapped protocol', () {
    test('DS-7: a bounce is a failure by default', () {
      const protocol = TomFieldMappedDeliveryReportProtocol(
        remoteIdPath: 'id',
        statusPath: 'event',
      );
      for (final event in ['bounce', 'bounced', 'Bounced']) {
        expect(
          _decodeOne(
            protocol,
            TomDeliveryCallback(body: {'id': 'e1', 'event': event}),
          ).state,
          TomDeliveryState.failed,
          reason: event,
        );
      }
    });

    test('DS-8: without a code table, a coded failure stays a failure', () {
      const protocol = TomFieldMappedDeliveryReportProtocol(
        remoteIdPath: 'id',
        statusPath: 'status',
        codePath: 'code',
      );
      expect(
        _decodeOne(
          protocol,
          TomDeliveryCallback(
            body: {'id': 'x', 'status': 'failed', 'code': '550'},
          ),
        ).state,
        TomDeliveryState.failed,
      );
    });
  });

  group('the suppression list', () {
    test('DS-9: an email address is compared without case, a phone number '
        'by its digits', () async {
      final list = TomMemorySuppressionList();
      await list.suppress(
        TomSuppressedAddress(
          channel: TomMessageChannel.email,
          address: ' Dead@Example.COM ',
        ),
      );
      await list.suppress(
        TomSuppressedAddress(
          channel: TomMessageChannel.sms,
          address: '+44 7700 900000',
        ),
      );
      expect(
        await list.find(TomMessageChannel.email, 'dead@example.com'),
        isNotNull,
      );
      expect(
        await list.suppressedAmong(TomMessageChannel.sms, [
          '447700900000',
          '+41791234567',
        ]),
        {'447700900000'},
      );
      // The channel is part of the key.
      expect(await list.find(TomMessageChannel.email, '447700900000'), isNull);
      expect(
        await list.release(TomMessageChannel.sms, '+447700900000'),
        isTrue,
      );
      expect(
        await list.release(TomMessageChannel.sms, '+447700900000'),
        isFalse,
      );
      expect((await list.all()).single.address, 'dead@example.com');
    });

    test('DS-17: a SQL list over a data source that is not registered is '
        'refused at construction', () {
      expect(
        () => TomSqlSuppressionList.named('no_such_datasource'),
        throwsA(
          isA<TomServerException>().having(
            (e) => e.key,
            'key',
            'messaging.suppression.unknown_datasource',
          ),
        ),
      );
    });

    test('DS-10: a failure suppresses the address the report names, or the '
        "message's single address", () async {
      final list = TomMemorySuppressionList();
      final added = await list.applyReport(_failed());
      expect(added.single.address, '14155552671');
      expect(added.single.messageId, 'm1');
      expect(added.single.providerCode, '30005');
      expect(added.single.tenant, 'acme');

      final named = await list.applyReport(
        _failed(addresses: ['+15550000001', '+15550000002']),
        report: TomDeliveryReport(
          remoteId: 'SM1',
          state: TomDeliveryState.failed,
          recipient: '+15550000002',
        ),
      );
      expect(named.single.address, '15550000002');
    });

    test('DS-11: an expiry, an unknown state, and a failure of a message to '
        'several addresses that names none suppress nothing', () async {
      final list = TomMemorySuppressionList();
      expect(
        await list.applyReport(_failed(state: TomDeliveryState.expired)),
        isEmpty,
      );
      expect(
        await list.applyReport(_failed(state: TomDeliveryState.unknown)),
        isEmpty,
      );
      expect(
        await list.applyReport(
          _failed(addresses: ['+15550000001', '+15550000002']),
        ),
        isEmpty,
      );
      expect(await list.all(), isEmpty);
    });
  });

  group('the router consults the list', () {
    test(
      'DS-12: a message whose every recipient is suppressed is not sent',
      () async {
        final transport = _CarrierTransport();
        final list = TomMemorySuppressionList();
        await list.suppress(
          TomSuppressedAddress(
            channel: TomMessageChannel.sms,
            address: '+14155552671',
          ),
        );
        final router = TomMessageRouter([transport], list);

        final receipt = await router.send(_sms(['+1 415 555 2671']));

        expect(transport.sent, isEmpty);
        expect(receipt.outcome, TomDeliveryOutcome.suppressed);
        expect(receipt.rejectedRecipients, ['+1 415 555 2671']);
        expect(receipt.isDelivered, isFalse);
      },
    );

    test('DS-13: the rest are sent to, and the suppressed reported as '
        'rejected', () async {
      final transport = _CarrierTransport(channel: TomMessageChannel.email);
      final list = TomMemorySuppressionList();
      await list.suppress(
        TomSuppressedAddress(
          channel: TomMessageChannel.email,
          address: 'dead@example.com',
        ),
      );
      final router = TomMessageRouter([transport], list);

      final receipt = await router.send(
        TomMessage(
          recipients: [
            TomRecipient('ok@example.com'),
            TomRecipient('Dead@example.com', kind: TomRecipientKind.cc),
          ],
          subject: 's',
          bodies: [TomMessageBody.text('b')],
        ),
      );

      expect(transport.sent.single.envelopeAddresses, ['ok@example.com']);
      expect(receipt.outcome, TomDeliveryOutcome.delivered);
      expect(receipt.isPartial, isTrue);
      expect(receipt.rejectedRecipients, ['Dead@example.com']);
    });

    test('DS-14: a router without a list sends to everyone', () async {
      final transport = _CarrierTransport();
      final receipt = await TomMessageRouter([
        transport,
      ]).send(_sms(['+14155552671']));
      expect(transport.sent, hasLength(1));
      expect(receipt.outcome, TomDeliveryOutcome.delivered);
    });
  });

  group('a bounced address is suppressed end to end', () {
    test('DS-15: send, a Twilio failure report, and the next message is not '
        'sent', () async {
      final transport = _CarrierTransport();
      final list = TomMemorySuppressionList();
      final store = TomMemoryDeliveryReportStore();
      final outbox = TomMessageOutbox(
        router: TomMessageRouter([transport], list),
        reportStore: store,
      );
      addTearDown(outbox.close);
      TomDeliveryReportEndpoint.install(
        store: store,
        protocol: TomFieldMappedDeliveryReportProtocol.twilio(),
        verifier: TomSharedSecretCallbackVerifier('shared-secret'),
        suppressions: list,
      );

      await outbox.sendNow(_sms(['+14155552671']));
      expect(transport.sent, hasLength(1));
      final correlation = await store.messageOf('SM1');
      expect(correlation!.addresses, ['+14155552671']);

      final response = await TomDeliveryReportEndpoint.handle(
        Request(
          'POST',
          Uri.parse('https://example.com/messaging/delivery-report'),
          body: _twilioCallback(
            sid: 'SM1',
            status: 'undelivered',
            errorCode: '30005',
          ),
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            TomSharedSecretCallbackVerifier.defaultHeader: 'shared-secret',
          },
        ),
      );
      expect(response.statusCode, 200, reason: await response.readAsString());

      final entry = await list.find(TomMessageChannel.sms, '+14155552671');
      expect(entry, isNotNull);
      expect(entry!.messageId, 'm1');
      expect(entry.providerCode, '30005');
      expect((await store.messageOf('SM1'))!.providerCode, '30005');

      final receipts = <TomDeliveryReceipt>[];
      final listening = outbox.receipts.listen(receipts.add);
      addTearDown(listening.cancel);
      await outbox.sendNow(_sms(['+14155552671'], id: 'm2'));
      await pumpEventQueue();
      final next = receipts.single;
      expect(
        transport.sent,
        hasLength(1),
        reason: 'nothing sent the second time',
      );
      expect(next.outcome, TomDeliveryOutcome.suppressed);
    });

    test('DS-16: an expiry report suppresses nothing, and the next message is '
        'sent', () async {
      final transport = _CarrierTransport();
      final list = TomMemorySuppressionList();
      final store = TomMemoryDeliveryReportStore();
      final router = TomMessageRouter([transport], list);
      final outbox = TomMessageOutbox(router: router, reportStore: store);
      addTearDown(outbox.close);
      TomDeliveryReportEndpoint.install(
        store: store,
        protocol: TomFieldMappedDeliveryReportProtocol.twilio(),
        verifier: TomSharedSecretCallbackVerifier('shared-secret'),
        suppressions: list,
      );

      await outbox.sendNow(_sms(['+14155552671']));
      final response = await TomDeliveryReportEndpoint.handle(
        Request(
          'POST',
          Uri.parse('https://example.com/messaging/delivery-report'),
          body: _twilioCallback(
            sid: 'SM1',
            status: 'undelivered',
            errorCode: '30003',
          ),
          headers: {
            'content-type': 'application/x-www-form-urlencoded',
            TomSharedSecretCallbackVerifier.defaultHeader: 'shared-secret',
          },
        ),
      );
      expect(response.statusCode, 200);
      expect(jsonDecode(await response.readAsString())['reports'], 1);
      expect(await list.all(), isEmpty);

      await outbox.sendNow(_sms(['+14155552671'], id: 'm2'));
      expect(transport.sent, hasLength(2));
    });
  });
}
