/// Renders a [TomMessage] as an RFC 5322 / MIME document.
///
/// Kept apart from [TomSmtpTransport] on purpose. SMTP is a *conversation* —
/// connect, greet, authenticate, address, transfer — and the document being
/// transferred is a separate concern with separate rules. Splitting them means
/// the encoder is testable without a socket (every structural assertion in
/// `messaging_test.dart` is made against a string), and a future transport that
/// submits mail some other way — an API gateway, a `sendmail` pipe — reuses the
/// document rather than reimplementing it.
///
/// ## What "correct" means here
///
/// Three rules do most of the work, and each exists because breaking it
/// produces mail that *looks* fine to the sender and is mangled for the
/// recipient:
///
/// - **Headers are 7-bit.** A subject containing anything outside US-ASCII must
///   be encoded per RFC 2047 (`=?utf-8?B?…?=`), not sent raw.
/// - **The body's structure follows its content.** A message with only text is
///   a single part; text plus HTML is `multipart/alternative`; either of those
///   plus attachments is `multipart/mixed`; and inline images make the
///   alternative into a `multipart/related`. Emitting a multipart wrapper for a
///   single part is legal but produces mail clients showing an attachment
///   nobody added.
/// - **Blind copies do not appear.** `Bcc:` recipients are in the SMTP envelope
///   and must be absent from the document. Writing them into a header is the
///   canonical way to turn a blind copy into a disclosure.
library;

import 'dart:convert';
import 'dart:math';

import 'message.dart';

/// The line ending every mail protocol requires. A bare `\n` is accepted by
/// some servers and silently corrupts the message on others.
const String tomMimeLineEnding = '\r\n';

/// The maximum line length RFC 5322 permits, excluding the line ending.
const int tomMimeMaxLineLength = 76;

/// Encodes messages into RFC 5322 documents.
class TomMimeEncoder {
  /// Source of boundary randomness. Injectable so a test can assert on an exact
  /// document rather than on a document with a different boundary every run.
  final Random _random;

  /// The clock, injectable for the same reason as [_random].
  final DateTime Function() _clock;

  /// Creates an encoder.
  TomMimeEncoder({Random? random, DateTime Function()? clock})
    : _random = random ?? Random(),
      _clock = clock ?? DateTime.now;

  /// Renders [message] as a complete RFC 5322 document.
  String encode(TomMessage message) {
    final buffer = StringBuffer();
    _writeHeaders(buffer, message);
    _writeBody(buffer, message);
    return buffer.toString();
  }

  // ===========================================================================
  // HEADERS
  // ===========================================================================

  void _writeHeaders(StringBuffer out, TomMessage message) {
    final from = message.from;
    if (from != null) _header(out, 'From', _addressList([from]));

    final to = message.recipientsOf(TomRecipientKind.to);
    if (to.isNotEmpty) _header(out, 'To', _addressList(to));

    final cc = message.recipientsOf(TomRecipientKind.cc);
    if (cc.isNotEmpty) _header(out, 'Cc', _addressList(cc));

    // Bcc is deliberately absent. The blind copies are delivered through the
    // SMTP envelope; naming them here is what makes a blind copy not blind.

    final replyTo = message.replyTo;
    if (replyTo != null) _header(out, 'Reply-To', _addressList([replyTo]));

    if (message.subject != null) {
      _header(out, 'Subject', encodeHeaderValue(message.subject!));
    }
    _header(out, 'Date', formatRfc5322Date(_clock()));
    _header(out, 'Message-ID', '<${message.id}@tom>');
    _header(out, 'MIME-Version', '1.0');

    // Caller headers last so a deployment can override anything above — a
    // `List-Unsubscribe`, a custom `X-` tag, or a `Message-ID` from a system
    // that owns its own identifiers.
    message.headers.forEach((name, value) => _header(out, name, value));
  }

  void _header(StringBuffer out, String name, String value) =>
      out.write('$name: $value$tomMimeLineEnding');

  String _addressList(List<TomRecipient> recipients) =>
      recipients.map(encodeAddress).join(', ');

  /// Renders one address, encoding the display name when it needs it.
  ///
  /// Static so a transport can render an envelope address without building an
  /// encoder.
  static String encodeAddress(TomRecipient recipient) {
    final name = recipient.displayName;
    if (name == null || name.isEmpty) return recipient.address;
    return '${encodeHeaderValue(name, quoteIfPlain: true)} '
        '<${recipient.address}>';
  }

  /// Encodes [value] for use in a header.
  ///
  /// Pure US-ASCII passes through untouched, because an encoded-word where none
  /// is needed is noise in every mail client's "show original". Anything else
  /// becomes an RFC 2047 base64 encoded-word.
  ///
  /// [quoteIfPlain] wraps an untouched value in quotes, which a display name
  /// needs and a subject does not.
  static String encodeHeaderValue(String value, {bool quoteIfPlain = false}) {
    final needsEncoding = value.codeUnits.any((c) => c < 32 || c > 126);
    if (!needsEncoding) {
      if (!quoteIfPlain) return value;
      final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      return '"$escaped"';
    }
    return '=?utf-8?B?${base64.encode(utf8.encode(value))}?=';
  }

  /// Formats [when] in the `Date:` header's fixed-width English form.
  ///
  /// Hand-rolled rather than taken from `intl`: the format is defined by RFC
  /// 5322 to be English and offset-numeric regardless of locale, so a
  /// locale-aware formatter is the wrong tool — a German locale would emit
  /// "Mo, 28 Jul" and break parsers.
  static String formatRfc5322Date(DateTime when) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String two(int n) => n.toString().padLeft(2, '0');

    final day = days[when.weekday - 1];
    final month = months[when.month - 1];
    final offset = when.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hh = two(abs.inHours);
    final mm = two(abs.inMinutes % 60);
    return '$day, ${two(when.day)} $month ${when.year} '
        '${two(when.hour)}:${two(when.minute)}:${two(when.second)} '
        '$sign$hh$mm';
  }

  // ===========================================================================
  // BODY
  // ===========================================================================

  /// Writes the body, choosing the simplest structure that carries the content.
  ///
  /// The nesting is decided here rather than by the caller because getting it
  /// wrong is invisible to the sender: a single text part wrapped in a
  /// `multipart/mixed` renders as an empty mail with one attachment in several
  /// popular clients.
  void _writeBody(StringBuffer out, TomMessage message) {
    final listed = message.attachments
        .where((a) => !a.isInline)
        .toList(growable: false);
    final inline = message.attachments
        .where((a) => a.isInline)
        .toList(growable: false);

    if (listed.isEmpty) {
      _writeContent(out, message, inline);
      return;
    }

    final boundary = _boundary('mixed');
    _header(out, 'Content-Type', 'multipart/mixed; boundary="$boundary"');
    out.write(tomMimeLineEnding);
    out.write('--$boundary$tomMimeLineEnding');
    _writeContent(out, message, inline);
    for (final attachment in listed) {
      out.write('$tomMimeLineEnding--$boundary$tomMimeLineEnding');
      _writeAttachment(out, attachment);
    }
    out.write('$tomMimeLineEnding--$boundary--$tomMimeLineEnding');
  }

  /// Writes the readable content: one part, an alternative pair, or an
  /// alternative pair wrapped with the images its HTML references.
  void _writeContent(
    StringBuffer out,
    TomMessage message,
    List<TomAttachment> inline,
  ) {
    if (inline.isNotEmpty) {
      final boundary = _boundary('related');
      _header(
        out,
        'Content-Type',
        'multipart/related; boundary="$boundary"; type="multipart/alternative"',
      );
      out.write(tomMimeLineEnding);
      out.write('--$boundary$tomMimeLineEnding');
      _writeAlternatives(out, message);
      for (final image in inline) {
        out.write('$tomMimeLineEnding--$boundary$tomMimeLineEnding');
        _writeAttachment(out, image);
      }
      out.write('$tomMimeLineEnding--$boundary--$tomMimeLineEnding');
      return;
    }
    _writeAlternatives(out, message);
  }

  /// Writes the body parts, as an alternative set only when there is more than
  /// one to choose between.
  void _writeAlternatives(StringBuffer out, TomMessage message) {
    final bodies = message.bodies;
    if (bodies.isEmpty) {
      _header(out, 'Content-Type', 'text/plain; charset=utf-8');
      _header(out, 'Content-Transfer-Encoding', 'base64');
      out.write(tomMimeLineEnding);
      return;
    }
    if (bodies.length == 1) {
      _writePart(out, bodies.single);
      return;
    }
    final boundary = _boundary('alt');
    _header(out, 'Content-Type', 'multipart/alternative; boundary="$boundary"');
    out.write(tomMimeLineEnding);
    for (final body in bodies) {
      out.write('--$boundary$tomMimeLineEnding');
      _writePart(out, body);
      out.write(tomMimeLineEnding);
    }
    out.write('--$boundary--$tomMimeLineEnding');
  }

  /// Writes one body part.
  ///
  /// Base64 throughout rather than quoted-printable: both are legal, base64 is
  /// unambiguous for any input, and quoted-printable's soft line breaks are a
  /// well-known source of corrupted messages when the content already contains
  /// long unbroken runs (a URL, a token, a minified block).
  void _writePart(StringBuffer out, TomMessageBody body) {
    _header(out, 'Content-Type', '${body.mediaType}; charset=${body.charset}');
    _header(out, 'Content-Transfer-Encoding', 'base64');
    out.write(tomMimeLineEnding);
    out.write(wrapBase64(base64.encode(utf8.encode(body.content))));
  }

  void _writeAttachment(StringBuffer out, TomAttachment attachment) {
    final name = encodeHeaderValue(attachment.fileName, quoteIfPlain: true);
    _header(out, 'Content-Type', '${attachment.mediaType}; name=$name');
    _header(out, 'Content-Transfer-Encoding', 'base64');
    if (attachment.isInline) {
      _header(out, 'Content-ID', '<${attachment.contentId}>');
      _header(out, 'Content-Disposition', 'inline; filename=$name');
    } else {
      _header(out, 'Content-Disposition', 'attachment; filename=$name');
    }
    out.write(tomMimeLineEnding);
    out.write(wrapBase64(base64.encode(attachment.bytes)));
  }

  /// Breaks [encoded] into RFC-legal lines.
  ///
  /// Not cosmetic: RFC 5322 caps a line at 998 octets and many servers enforce
  /// the 76-column recommendation, so an unwrapped base64 blob of any size is a
  /// message some servers will refuse.
  static String wrapBase64(String encoded) {
    final out = StringBuffer();
    for (var i = 0; i < encoded.length; i += tomMimeMaxLineLength) {
      final end = min(i + tomMimeMaxLineLength, encoded.length);
      out.write(encoded.substring(i, end));
      out.write(tomMimeLineEnding);
    }
    return out.toString();
  }

  /// A boundary that cannot occur in base64 content.
  ///
  /// `=` is not in the base64 alphabet except as terminal padding, and never
  /// appears at the start of a line in wrapped output, so a boundary beginning
  /// with `==_` cannot collide with the content it delimits. That is worth
  /// stating, because a colliding boundary truncates the message at exactly the
  /// point a human reader stops looking.
  String _boundary(String kind) {
    final suffix = List.generate(
      16,
      (_) => '0123456789abcdef'[_random.nextInt(16)],
    ).join();
    return '==_tom_${kind}_$suffix';
  }
}
