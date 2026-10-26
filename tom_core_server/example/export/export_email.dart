/// The email channel: a stored export sent to people through the outbox.
///
/// The export module answers three channels — `apiResponse`
/// ([TomExportService.respondWith]), `fileExport` ([TomExportService.storeAs])
/// and **email** ([TomExportEmailDelivery.send]). The email channel does not
/// render anything: the export is rendered and stored once, and the channel
/// builds a message about it and queues that message in the `messaging`
/// module's [TomMessageOutbox], which owns durability, retry and
/// one-runner-per-message. So nothing here repeats what the outbox does.
///
/// Two shapes are shown, because they are not interchangeable:
///
///  * **link** — the message carries the address the deployment serves the
///    export at, and the recipient fetches it. The export is already durable in
///    the store; attaching it copies it once per recipient and pushes it
///    through a mail server's size limit.
///  * **attach** — the bytes ride along, read back from the store. Right for a
///    small export, and for a recipient who cannot reach the deployment.
///
/// The default, **auto**, attaches up to a size and links beyond it.
///
/// Run with `dart run example/export/export_email.dart`. Every step checks its
/// own result and the run fails when one does not hold, so a green run is a
/// verification and not just a transcript.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// ignore_for_file: avoid_print

/// The report to deliver — two rows a scheduled job might have produced.
TomTabularResult monthlyRevenue() => TomTabularResult.single(
  title: 'Monthly revenue',
  metadata: const {'Period': '2026-07', 'Currency': 'EUR'},
  section: TomTabularSection.ofMaps(
    [
      TomTabularColumn('region', label: 'Region'),
      TomTabularColumn('total', label: 'Total', type: TomColumnType.decimal),
    ],
    Stream.fromIterable(const [
      {'region': 'North', 'total': 1200.5},
      {'region': 'South', 'total': 980.0},
    ]),
    title: 'By region',
  ),
);

/// The address the deployment serves a stored export at — its own download
/// route. The export module serves none; it only needs to know how to name one.
Uri downloadLink(TomStoredExport export) =>
    Uri.parse('https://reports.example.com/exports/${export.key}');

/// Who the messages go to.
final _ada = TomRecipient('ada@example.com', displayName: 'Ada');

/// Runs [send] and answers the key of the [TomExportException] it throws, or
/// `''` when it throws none.
Future<String> refusalOf(Future<Object?> Function() send) async {
  try {
    await send();
  } on TomExportException catch (error) {
    return error.key;
  }
  return '';
}

Future<void> run() async {
  // 1. The store, the outbox, and the delivery that joins them. The export
  //    service renders and stores; the outbox delivers; the delivery builds
  //    the message between the two and knows the deployment's download route.
  final exports = TomMemoryExportStore();
  final service = TomExportService(store: exports);
  final transport = TomMemoryMessageTransport();
  final outbox = TomMessageOutbox(
    router: TomMessageRouter([transport]),
    store: TomMemoryJobStore(),
  );
  final email = TomExportEmailDelivery(
    store: exports,
    outbox: outbox,
    linkFor: downloadLink,
    from: TomRecipient('reports@example.com', displayName: 'Reporting'),
  );
  print('1. attachment limit          : ${email.maxAttachmentBytes} bytes');
  check(
    email.maxAttachmentBytes ==
        TomExportEmailDelivery.defaultMaxAttachmentBytes,
    'the delivery attaches up to 10 MiB unless told otherwise',
  );

  // 2. Render and store once — the `fileExport` channel unchanged. Every
  //    message below is about this one stored export; none renders it again.
  final key = service.keyFor(
    'Monthly revenue',
    'xlsx',
    partitionOn: DateTime.utc(2026, 8, 1),
  );
  final stored = await service.storeAs(monthlyRevenue(), 'xlsx', key: key);
  print('2. stored                    : ${stored.key}');
  print('   bytes                     : ${stored.byteCount}');
  check(
    stored.key == '2026/08/01/Monthly_revenue.xlsx',
    'keyFor partitions and sanitises the report name',
  );
  check(stored.byteCount > 0, 'the export was rendered and written');

  // 3. The **link** shape. The message carries the address after its text; the
  //    recipient fetches the bytes from the deployment.
  final linked = await email.send(
    stored,
    to: [_ada],
    subject: 'Monthly revenue is ready',
    text: 'Your report is ready.',
    mode: TomExportEmailMode.link,
  );
  print(
    '3. link in the message       : '
    '${linked.bodies.single.content.split('\n').last}',
  );
  check(
    linked.attachments.isEmpty,
    'the link shape carries no bytes — the store already has them',
  );
  check(
    linked.bodies.single.content ==
        'Your report is ready.\n\n${downloadLink(stored)}',
    'the link follows the text, as the deployment serves the export',
  );

  // 4. The **attach** shape. The bytes are read back from the store rather
  //    than rendered a second time: the stored export is what was delivered,
  //    and rendering again could produce a different document if the data
  //    moved. The file name is the key's last segment, the media type the
  //    stored export's.
  final attached = await email.send(
    stored,
    to: [_ada],
    subject: 'Monthly revenue',
    mode: TomExportEmailMode.attach,
  );
  final attachment = attached.attachments.single;
  print('4. attachment                : ${attachment.fileName}');
  print('   attachment media type     : ${attachment.mediaType}');
  check(
    attachment.bytes.length == stored.byteCount,
    'the attachment is the stored export, not a second rendering',
  );
  check(
    attachment.fileName == 'Monthly_revenue.xlsx' &&
        attachment.mediaType == stored.mediaType,
    'the recipient is told what the bytes are',
  );

  // 5. **auto**, the default, decides by size: attach up to the limit, link
  //    beyond it. Delivery is the outbox's: `send` queues durably and returns;
  //    a tick delivers. Retry and backoff are the outbox's too, which is why
  //    the channel does not deliver anything itself.
  final small = await email.send(stored, to: [_ada], subject: 'Small');
  final tight = TomExportEmailDelivery(
    store: exports,
    outbox: outbox,
    linkFor: downloadLink,
    maxAttachmentBytes: stored.byteCount - 1,
  );
  final large = await tight.send(stored, to: [_ada], subject: 'Large');
  print(
    '5. auto, under the limit     : ${small.attachments.length} attachment',
  );
  print(
    '   auto, over the limit      : ${large.attachments.length} attachments',
  );
  check(
    small.attachments.length == 1 && large.attachments.isEmpty,
    'auto attaches what fits and links what does not',
  );
  check(transport.count == 0, 'send() queues durably without delivering');
  await outbox.tick();
  print('   delivered after a tick    : ${transport.count}');
  check(
    transport.count == 4,
    'the tick delivered the four messages the steps above queued',
  );

  // 6. What the channel cannot deliver it refuses before anything is queued:
  //    no recipient, an attachment over the limit, or a link with nowhere to
  //    point. And delivering an export does not consume it — the store is the
  //    durable half, which is what makes sending it again cost nothing.
  final noLink = TomExportEmailDelivery(
    store: exports,
    outbox: outbox,
    maxAttachmentBytes: stored.byteCount - 1,
  );
  final refusals = [
    await refusalOf(() => email.send(stored, to: const [], subject: 'x')),
    await refusalOf(() => noLink.send(stored, to: [_ada], subject: 'x')),
    await refusalOf(
      () => noLink.send(
        stored,
        to: [_ada],
        subject: 'x',
        mode: TomExportEmailMode.link,
      ),
    ),
  ];
  print('6. refused                   : ${refusals.join(', ')}');
  check(
    refusals.join(',') ==
        'export.email.no_recipient,export.email.too_large,'
            'export.email.no_link',
    'each undeliverable message is refused by name',
  );
  await outbox.tick();
  check(transport.count == 4, 'a refused message was never queued');
  check(
    await exports.exists(stored.key),
    'the export is still in the store after it was sent',
  );

  await outbox.close();
  print('\nExport email-channel example completed.');
}

void main() async {
  await run();
}
