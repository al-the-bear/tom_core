/// The email channel for finished exports: a stored export, sent to people
/// through the messaging outbox.
///
/// The export is rendered and stored once ([TomExportService.storeAs]); this
/// channel only tells people about it. Delivery is the outbox's — durable,
/// retried, one runner per message — so nothing here repeats what the
/// `messaging` module owns: it builds the message and queues it.
///
/// ## Link or attachment
///
/// | Mode | The message carries | Right for |
/// | ---- | ------------------- | --------- |
/// | [TomExportEmailMode.link] | a link the deployment serves the export at | large exports; recipients who can reach the deployment |
/// | [TomExportEmailMode.attach] | the stored bytes, read back from the store | small exports; recipients who cannot reach the store |
/// | [TomExportEmailMode.auto] | the bytes up to [TomExportEmailDelivery.maxAttachmentBytes], a link beyond | the usual choice |
///
/// The bytes are read back from the store rather than rendered again: the
/// stored export is what was delivered, and rendering again could produce a
/// different document if the data moved.
library;

import 'dart:typed_data';

import '../messaging/message.dart';
import '../messaging/outbox.dart';
import 'export_store.dart';
import 'tabular_result.dart';

/// How [TomExportEmailDelivery.send] delivers an export.
enum TomExportEmailMode {
  /// A link to the export, built by [TomExportEmailDelivery.linkFor].
  link,

  /// The export's bytes as an attachment.
  attach,

  /// An attachment up to [TomExportEmailDelivery.maxAttachmentBytes], a link
  /// beyond it.
  auto,
}

/// Sends stored exports by email, through a [TomMessageOutbox].
class TomExportEmailDelivery {
  /// Delivers exports held by [store] through [outbox].
  ///
  /// [linkFor] builds the address a recipient fetches an export from — the
  /// deployment's own download route, a signed URL; without it only
  /// attachments can be sent. [from] is the default sender.
  TomExportEmailDelivery({
    required this.store,
    required this.outbox,
    this.linkFor,
    this.from,
    this.maxAttachmentBytes = defaultMaxAttachmentBytes,
  });

  /// The largest export [TomExportEmailMode.auto] attaches by default: 10 MiB,
  /// beneath the limits common mail servers apply to a whole message.
  static const int defaultMaxAttachmentBytes = 10 * 1024 * 1024;

  /// Where the exports are stored.
  final TomExportStore store;

  /// The outbox the messages are queued in.
  final TomMessageOutbox outbox;

  /// The address a recipient fetches [TomStoredExport] from, or `null` when the
  /// deployment serves no download route.
  final Uri Function(TomStoredExport export)? linkFor;

  /// The default sender, or `null` for the transport's own.
  final TomRecipient? from;

  /// The largest export sent as an attachment; also the ceiling of
  /// [TomExportEmailMode.attach].
  final int maxAttachmentBytes;

  /// Queues an email delivering [export] to [to], and returns the queued
  /// message.
  ///
  /// [text] opens the body; the link, in link mode, follows it. [fileName]
  /// names the attachment, by default the last segment of the key.
  ///
  /// Throws a [TomExportException] — before anything is queued — keyed
  /// `export.email.no_link` when a link is needed and [linkFor] is not set,
  /// `export.email.too_large` when [TomExportEmailMode.attach] is asked for an
  /// export larger than [maxAttachmentBytes], and `export.email.no_recipient`
  /// for an empty [to].
  Future<TomMessage> send(
    TomStoredExport export, {
    required List<TomRecipient> to,
    required String subject,
    String text = 'Your export is ready.',
    String? fileName,
    TomRecipient? from,
    TomExportEmailMode mode = TomExportEmailMode.auto,
  }) async {
    if (to.isEmpty) {
      throw TomExportException(
        'export.email.no_recipient',
        'An export email needs at least one recipient.',
        parameters: {'key': export.key},
      );
    }
    final attach = switch (mode) {
      TomExportEmailMode.attach => true,
      TomExportEmailMode.link => false,
      TomExportEmailMode.auto =>
        export.byteCount <= maxAttachmentBytes || linkFor == null,
    };
    if (attach && export.byteCount > maxAttachmentBytes) {
      throw TomExportException(
        'export.email.too_large',
        'The export is too large to send as an attachment.',
        parameters: {
          'key': export.key,
          'bytes': export.byteCount,
          'limit': maxAttachmentBytes,
        },
      );
    }
    final link = linkFor;
    if (!attach && link == null) {
      throw TomExportException(
        'export.email.no_link',
        'The export can only be sent as a link, and no link builder is '
            'configured.',
        parameters: {'key': export.key},
      );
    }
    final message = TomMessage.email(
      from: from ?? this.from,
      to: to,
      subject: subject,
      text: attach ? text : '$text\n\n${link!(export)}',
      attachments: [
        if (attach)
          TomAttachment(
            fileName: fileName ?? export.key.split('/').last,
            bytes: await _read(export.key),
            mediaType: export.mediaType,
          ),
      ],
    );
    await outbox.send(message);
    return message;
  }

  Future<Uint8List> _read(String key) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in store.open(key)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
