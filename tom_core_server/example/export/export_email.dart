/// The third delivery channel, composed rather than built in.
///
/// The export module answers two channels itself — `apiResponse`
/// ([TomExportService.respondWith]) and `fileExport`
/// ([TomExportService.storeAs]). The third the specification names, **email**,
/// is deliberately absent from it: an emailed export is a message with an
/// attachment, which is the `messaging` module's subject, and a third path in
/// the export service would be a second copy of the outbox's durability, retry
/// and idempotence — the one thing that module exists to own.
///
/// So the channel is a composition, and this file is it. Neither module learns
/// about the other: export renders and stores, messaging delivers, and the
/// twenty lines that put them together live in the application. That is the
/// whole point of the seam, and it is worth showing rather than asserting,
/// because "composes out of the two" is easy to write and easy to be wrong
/// about.
///
/// Two shapes are shown, because they are not interchangeable:
///
///  * **link** — the message carries the storage key, and the recipient fetches
///    it. The export is already durable in the store; attaching it copies it
///    once per recipient and pushes it through a mail server's size limit.
///  * **attach** — the bytes ride along. Right for a small export, and for a
///    recipient who cannot reach the store at all.
///
/// Run with `dart run example/export/export_email.dart`. Every step checks its
/// own result and the run fails when one does not hold, so a green run is a
/// verification and not just a transcript.
library;

import 'dart:typed_data';

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

Future<void> run() async {
  // 1. The two halves, each configured without knowing the other. The export
  //    service renders and stores; the outbox delivers. Nothing below passes
  //    one to the other — the application holds both.
  final exports = TomMemoryExportStore();
  final service = TomExportService(store: exports);
  final transport = TomMemoryMessageTransport();
  final outbox = TomMessageOutbox(
    router: TomMessageRouter([transport]),
    store: TomMemoryJobStore(),
  );
  print(
    '1. formats                   : ${service.formats.formatIds.join(', ')}',
  );
  check(
    service.formats.supports('xlsx'),
    'the export service renders the format the report will be delivered in',
  );

  // 2. Render and store, which is the `fileExport` channel unchanged. The key
  //    is built by `keyFor`, so the extension matches the format and the name
  //    is safe to use as a key — a report name comes from a user.
  final key = service.keyFor(
    'Monthly revenue',
    'xlsx',
    partitionOn: DateTime.utc(2026, 8, 1),
  );
  final stored = await service.storeAs(monthlyRevenue(), 'xlsx', key: key);
  print('2. stored                    : ${stored.key}');
  print('   media type                : ${stored.mediaType}');
  print('   bytes                     : ${stored.byteCount}');
  check(
    stored.key == '2026/08/01/Monthly_revenue.xlsx',
    'keyFor partitions and sanitises the report name',
  );
  check(stored.byteCount > 0, 'the export was rendered and written');

  // 3. The **link** shape. The message names the key; the recipient fetches the
  //    bytes from wherever the deployment serves its stored exports. The export
  //    is durable already, so an attachment would be a second copy per
  //    recipient — and the one most likely to be refused by a mail server.
  final link = TomMessage.email(
    from: TomRecipient('reports@example.com', displayName: 'Reporting'),
    to: [TomRecipient('ada@example.com', displayName: 'Ada')],
    subject: 'Monthly revenue is ready',
    text: 'Your report is ready: ${stored.key} (${stored.byteCount} bytes).',
  );
  print('3. link message              : ${link.subject}');
  check(
    link.attachments.isEmpty,
    'the link shape carries no bytes — the store already has them',
  );
  check(
    link.bodies.single.content.contains(stored.key),
    'the message names the key the recipient reads it back with',
  );

  // 4. The **attach** shape. The bytes are read back from the store rather than
  //    rendered a second time: the stored export is what was delivered, and
  //    rendering again could produce a different document if the data moved.
  //    The file name and media type come from the renderer, so the recipient
  //    sees an extension that matches the bytes.
  final renderer = service.formats.rendererFor('xlsx');
  final bytes = await collect(exports.open(stored.key));
  final attached = TomMessage.email(
    from: TomRecipient('reports@example.com', displayName: 'Reporting'),
    to: [TomRecipient('ada@example.com', displayName: 'Ada')],
    subject: 'Monthly revenue',
    text: 'The report is attached.',
    attachments: [
      TomAttachment(
        fileName: renderer.fileNameFor('monthly-revenue'),
        bytes: bytes,
        mediaType: renderer.mediaType,
      ),
    ],
  );
  print(
    '4. attachment                : ${attached.attachments.single.fileName}',
  );
  print(
    '   attachment media type     : ${attached.attachments.single.mediaType}',
  );
  check(
    attached.attachments.single.bytes.length == stored.byteCount,
    'the attachment is the stored export, not a second rendering',
  );
  check(
    attached.attachments.single.mediaType == renderer.mediaType,
    'the recipient is told what the bytes are, by the renderer that made them',
  );

  // 5. Delivery is the outbox's, not this file's. `send` returns once the
  //    message is durably queued; a tick delivers it. Retry, backoff and
  //    at-most-one-runner-per-message are the outbox's, which is why the export
  //    module does not grow a third channel: it would have to reproduce all of
  //    that or deliver worse.
  await outbox.send(attached);
  print('5. delivered before a tick   : ${transport.count}');
  check(transport.count == 0, 'send() queues durably without delivering');
  await outbox.tick();
  print('   delivered after a tick    : ${transport.count}');
  check(transport.count == 1, 'the tick delivered the message with its export');
  check(
    transport.sent.single.attachments.single.bytes.length == stored.byteCount,
    'the export arrived at the transport intact',
  );

  // 6. One render, two deliveries. The store still holds the export after the
  //    message carrying a copy of it has gone out — which is what makes the
  //    link shape possible at all, and what makes re-sending a report cost
  //    nothing. Rendering again would re-run the query behind it and could
  //    produce a different document.
  final again = await collect(exports.open(stored.key));
  print('6. still in the store         : ${again.length} bytes');
  check(
    again.length == stored.byteCount,
    'delivering an export does not consume it: the store is the durable half '
    'and a message carries a copy',
  );

  print('\nExport email-channel example completed.');
}

/// Collects a byte stream into one buffer.
Future<Uint8List> collect(Stream<List<int>> bytes) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in bytes) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

void main() async {
  await run();
}
