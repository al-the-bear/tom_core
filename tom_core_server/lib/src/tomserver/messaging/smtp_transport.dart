/// SMTP delivery: the settings, the conversation, and the failure
/// classification that drives every retry decision downstream.
///
/// ## Why the transport is written here rather than taken from a package
///
/// The protocol surface a server actually needs is small — greet, optionally
/// upgrade to TLS, optionally authenticate, address, transfer — and the part
/// that matters most for a *reliable* mailer is not the wire format at all but
/// the classification of what comes back. A dependency that returns "it
/// failed" without saying whether the failure is worth repeating pushes the
/// hardest decision back onto the caller, which is where mailers go wrong.
/// Owning the conversation is what lets [TomSmtpTransport] map every reply code
/// to a retry judgement once, in one place, and document why.
///
/// ## The classification rule
///
/// SMTP's reply codes carry the answer in their first digit, and the standard
/// means it:
///
/// | Code | Meaning | Judgement |
/// |------|---------|-----------|
/// | `2xx` | accepted | success |
/// | `3xx` | send more | intermediate, never final |
/// | `4xx` | transient negative — "not now" | **retry** |
/// | `5xx` | permanent negative — "no" | **do not retry** |
///
/// The two exceptions are deliberate and documented at their call sites:
/// authentication failures (`535`) are permanent as the RFC says but are the
/// single most common *misconfiguration*, so the message names the setting;
/// and a socket that dies mid-conversation is transient regardless of what code
/// preceded it, because no answer at all is not a refusal.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import 'message.dart';
import 'message_transport.dart';
import 'mime_encoder.dart';

// =============================================================================
// SETTINGS
// =============================================================================

/// How the connection to the mail server is secured.
enum TomSmtpSecurity {
  /// Plain TCP, no encryption. For a mail relay reachable only over a trusted
  /// network — anything else sends the credential in the clear.
  none,

  /// Plain TCP upgraded with `STARTTLS` after the greeting. The usual choice on
  /// port 587.
  startTls,

  /// TLS from the first byte ("SMTPS"). The usual choice on port 465.
  implicitTls,
}

/// Everything needed to reach one mail server.
///
/// Separate from the transport so it can be built from
/// [TomBaseServerConfiguration] without the transport knowing about
/// configuration, and built literally in a test without a configuration
/// existing at all.
class TomSmtpSettings {
  /// The mail server's host name.
  final String host;

  /// The port. Defaults follow [security] when not given explicitly.
  final int port;

  /// How the connection is secured.
  final TomSmtpSecurity security;

  /// The login name, or `null` for an unauthenticated relay.
  final String? username;

  /// The password — **never authored**; see [TomBaseServerConfiguration].
  final String? password;

  /// The address messages are sent from when they do not name their own.
  final TomRecipient? defaultFrom;

  /// The name this client announces in `EHLO`.
  final String clientName;

  /// How long to wait for the connection and for each reply.
  final Duration timeout;

  /// Whether to accept a server certificate that does not validate.
  ///
  /// `false`, and it should stay that way. It exists because self-signed certs
  /// are common on internal relays and a developer who cannot turn this on will
  /// disable TLS entirely, which is strictly worse.
  final bool allowInsecureCertificate;

  /// Creates SMTP settings.
  TomSmtpSettings({
    required this.host,
    int? port,
    this.security = TomSmtpSecurity.startTls,
    this.username,
    this.password,
    this.defaultFrom,
    this.clientName = 'localhost',
    this.timeout = const Duration(seconds: 30),
    this.allowInsecureCertificate = false,
  }) : port = port ?? _defaultPort(security) {
    if (host.trim().isEmpty) {
      throw TomMessagingException(
        'messaging.smtp.no_host',
        'SMTP settings need a host.',
      );
    }
    if (username != null && (password == null || password!.isEmpty)) {
      // Caught here rather than at the `AUTH` command, because a deployment
      // that forgot to supply the secret should fail at startup with a message
      // naming the setting, not on the first notification with a `535`.
      throw TomMessagingException(
        'messaging.smtp.no_password',
        'SMTP username "$username" was configured without a password. The '
            'password is supplied out-of-band (environment, .env or command '
            'line) and is never authored in a spec or config tree.',
        parameters: {'host': host, 'username': username},
      );
    }
  }

  /// Whether the credential should be presented.
  bool get isAuthenticated => username != null && username!.isNotEmpty;

  static int _defaultPort(TomSmtpSecurity security) => switch (security) {
    TomSmtpSecurity.implicitTls => 465,
    TomSmtpSecurity.startTls => 587,
    TomSmtpSecurity.none => 25,
  };

  /// Reads settings from a server configuration's `smtp*` fields.
  ///
  /// Returns `null` when [TomBaseServerConfiguration.smtpHost] is unset, which
  /// is how a deployment says "no mail" — the caller registers a
  /// [TomNoOpMessageTransport] instead of failing to start.
  static TomSmtpSettings? fromConfiguration(
    TomBaseServerConfiguration configuration,
  ) {
    final host = configuration.smtpHost;
    if (host == null || host.trim().isEmpty) return null;
    return TomSmtpSettings(
      host: host,
      port: configuration.smtpPort == 0 ? null : configuration.smtpPort,
      security: TomSmtpSecurity.values.firstWhere(
        (s) => s.name.toLowerCase() == configuration.smtpSecurity.toLowerCase(),
        orElse: () => TomSmtpSecurity.startTls,
      ),
      username: _blankToNull(configuration.smtpUsername),
      password: _blankToNull(configuration.smtpPassword),
      defaultFrom: _blankToNull(configuration.smtpFromAddress) == null
          ? null
          : TomRecipient(
              configuration.smtpFromAddress!,
              displayName: _blankToNull(configuration.smtpFromName),
            ),
      clientName: configuration.smtpClientName,
      allowInsecureCertificate: configuration.smtpAllowInsecureCertificate,
    );
  }

  static String? _blankToNull(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  /// A description safe to log. The password is never included, at any level —
  /// a secret that reaches a log file has stopped being one.
  @override
  String toString() =>
      'TomSmtpSettings($host:$port, ${security.name}'
      '${isAuthenticated ? ', as $username' : ', unauthenticated'})';
}

// =============================================================================
// AFTER-THE-FACT FAILURES
// =============================================================================

/// Runs [action], writing any failure down instead of raising it.
///
/// The policy is the same wherever this is used: the outcome that matters is
/// already decided, and an error while tidying up afterwards must not be
/// allowed to contradict it. A relay that drops the socket instead of
/// answering `QUIT` has not un-delivered the message it accepted on the `250`,
/// and reporting a failure there would produce a *duplicate* on the retry.
///
/// Swallowing is not the same as discarding. A relay that consistently errors
/// on `QUIT`, or a TLS socket that never shuts down cleanly, is invisible
/// until someone reads a packet capture — so the error is logged at debug,
/// where it costs nothing until somebody goes looking.
///
/// [stage] names where the failure happened. These lines are read long after
/// the fact, when the reader has no idea which half of a teardown produced
/// them, so "an error was ignored" on its own is barely better than silence.
Future<void> _quietly(String stage, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    tomLog.debug('Ignoring SMTP error during $stage: $error');
  }
}

// =============================================================================
// TRANSPORT
// =============================================================================

/// Delivers [TomMessageChannel.email] over SMTP.
///
/// One connection per message. That is the right default for a server whose
/// mail is occasional — a pooled connection to a relay that closes idle
/// sockets is a source of failures that only appear under light load — and the
/// cost is one handshake per notification, which the outbox is already
/// absorbing asynchronously.
class TomSmtpTransport extends TomMessageTransport {
  /// Where and how to connect.
  final TomSmtpSettings settings;

  /// Renders the message document.
  ///
  /// Injectable so a test can pin the boundaries and the date — and so a
  /// deployment that must **sign** its mail can, without forking the transport:
  /// a subclass overriding [TomMimeEncoder.encode] to prepend a
  /// `DKIM-Signature` header to `super.encode(message)` is the whole seam.
  ///
  /// It is needed because this transport writes the document to the socket
  /// exactly as the encoder produced it. **A deployment relying on that relies
  /// on its relay to sign**, which is fine for a provider relay and is a
  /// requirement to state for one sending directly to destination MX hosts:
  /// unsigned mail is accepted and then filed as spam, so nothing here can ever
  /// report that it happened. See `doc/messaging.md`.
  final TomMimeEncoder encoder;

  /// Opens the connection. Injectable so the protocol can be tested against an
  /// in-process fake server without opening a real socket.
  final Future<TomSmtpConnection> Function(TomSmtpSettings settings) connect;

  /// Creates an SMTP transport.
  TomSmtpTransport(
    this.settings, {
    TomMimeEncoder? encoder,
    Future<TomSmtpConnection> Function(TomSmtpSettings settings)? connect,
  }) : encoder = encoder ?? TomMimeEncoder(),
       connect = connect ?? TomSocketSmtpConnection.open;

  @override
  TomMessageChannel get channel => TomMessageChannel.email;

  @override
  bool get supportsCopies => true;

  @override
  bool get supportsAttachments => true;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);

    final sender = message.from ?? settings.defaultFrom;
    if (sender == null) {
      throw TomDeliveryException.permanent(
        'messaging.smtp.no_sender',
        'Message ${message.id} names no sender and no default From address is '
            'configured (smtpFromAddress).',
        parameters: {'messageId': message.id},
      );
    }
    // The message the encoder sees must carry the resolved sender, or the
    // `From:` header and the envelope disagree — which is what most spam
    // filters look at first.
    final outgoing = message.from == null
        ? message.copyWith(from: sender)
        : message;

    final connection = await _connectOrDefer();
    try {
      return await _converse(connection, outgoing, sender);
    } finally {
      // A `finally` that throws replaces whatever the body produced, so an
      // unprotected close here could turn an accepted message into a reported
      // failure — and the retry would deliver a second copy. Same policy as
      // QUIT, one stage later.
      await _quietly('connection close', connection.close);
    }
  }

  Future<TomSmtpConnection> _connectOrDefer() async {
    try {
      return await connect(settings);
    } on TomDeliveryException {
      rethrow;
    } catch (error, stack) {
      // Unreachable is the textbook transient failure: the relay is restarting,
      // DNS is flapping, the network is down. Nothing about the message is
      // wrong, so nothing is gained by giving up on it.
      throw TomDeliveryException.transient(
        'messaging.smtp.unreachable',
        'Could not connect to ${settings.host}:${settings.port}.',
        parameters: {'host': settings.host, 'port': settings.port},
        rootException: error,
        stack: stack,
      );
    }
  }

  /// Runs one delivery conversation on an open [connection].
  Future<TomDeliveryReceipt> _converse(
    TomSmtpConnection connection,
    TomMessage message,
    TomRecipient sender,
  ) async {
    _expect(await connection.readReply(), 220, 'greeting');

    var capabilities = await _greet(connection);

    if (settings.security == TomSmtpSecurity.startTls) {
      if (!capabilities.contains('STARTTLS')) {
        // Configured for TLS and offered none: refusing is the only safe
        // reading. Continuing would send the credential in the clear, and
        // retrying cannot make a server advertise a capability it lacks.
        throw TomDeliveryException.permanent(
          'messaging.smtp.no_starttls',
          '${settings.host} does not offer STARTTLS but the configuration '
              'requires it.',
          parameters: {'host': settings.host},
        );
      }
      await connection.write('STARTTLS');
      _expect(await connection.readReply(), 220, 'STARTTLS');
      await connection.upgradeToTls();
      // The capability list before an upgrade is not binding afterwards — most
      // servers only advertise AUTH once the channel is private, which is the
      // whole point of the upgrade.
      capabilities = await _greet(connection);
    }

    if (settings.isAuthenticated) {
      await _authenticate(connection, capabilities);
    }

    await connection.write('MAIL FROM:<${sender.address}>');
    _expect(await connection.readReply(), 250, 'MAIL FROM');

    final rejected = <String>[];
    for (final address in message.envelopeAddresses) {
      await connection.write('RCPT TO:<$address>');
      final reply = await connection.readReply();
      if (reply.isPositive) continue;
      if (reply.isPermanentNegative) {
        // One dead address in a distribution list must not cost the other
        // recipients their mail; it is reported on the receipt instead.
        rejected.add(address);
        continue;
      }
      throw _failureFor(reply, 'RCPT TO <$address>');
    }
    if (rejected.length == message.envelopeAddresses.length) {
      throw TomDeliveryException.permanent(
        'messaging.smtp.all_recipients_rejected',
        'Every recipient of message ${message.id} was rejected: '
            '${rejected.join(', ')}.',
        parameters: {'messageId': message.id, 'rejected': rejected.join(', ')},
      );
    }

    await connection.write('DATA');
    _expect(await connection.readReply(), 354, 'DATA');
    await connection.writeData(encoder.encode(message));
    final accepted = _expect(await connection.readReply(), 250, 'body');

    await _quietly('QUIT after delivery', () async {
      await connection.write('QUIT');
      await connection.readReply();
    });

    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
      remoteId: accepted.text,
      detail: accepted.text,
      rejectedRecipients: rejected,
    );
  }

  /// Says hello and returns the server's capability lines, uppercased.
  ///
  /// `HELO` is the fallback rather than a failure: an ancient or minimal relay
  /// that does not know `EHLO` can still carry mail, it simply cannot offer
  /// extensions — and the checks that need extensions test for them by name.
  Future<Set<String>> _greet(TomSmtpConnection connection) async {
    await connection.write('EHLO ${settings.clientName}');
    final reply = await connection.readReply();
    if (reply.isPositive) {
      return reply.lines.map((l) => l.trim().toUpperCase()).toSet();
    }
    await connection.write('HELO ${settings.clientName}');
    _expect(await connection.readReply(), 250, 'HELO');
    return const {};
  }

  Future<void> _authenticate(
    TomSmtpConnection connection,
    Set<String> capabilities,
  ) async {
    final mechanisms = capabilities
        .firstWhere((c) => c.startsWith('AUTH'), orElse: () => '')
        .split(RegExp(r'[ =]'))
        .where((m) => m.isNotEmpty && m != 'AUTH')
        .toSet();

    // PLAIN first: one round trip instead of three, and universally supported
    // where AUTH is offered at all. LOGIN is the fallback for the servers that
    // only speak it.
    if (mechanisms.isEmpty || mechanisms.contains('PLAIN')) {
      // RFC 4616: authorization-id NUL authentication-id NUL password, with
      // the authorization id left empty. The separators are NUL bytes and
      // nothing else. Written as `\x00` escapes rather than literal NULs so
      // they are visible to a reader — an invisible byte in a credential is a
      // defect nobody spots in review, and a space here yields a token the
      // server decodes as one field and refuses with a `535` that looks
      // exactly like a wrong password.
      final token = base64.encode(
        utf8.encode('\x00${settings.username}\x00${settings.password}'),
      );
      await connection.write('AUTH PLAIN $token');
      _expectAuth(await connection.readReply());
      return;
    }
    if (mechanisms.contains('LOGIN')) {
      await connection.write('AUTH LOGIN');
      _expect(await connection.readReply(), 334, 'AUTH LOGIN');
      await connection.write(base64.encode(utf8.encode(settings.username!)));
      _expect(await connection.readReply(), 334, 'AUTH LOGIN username');
      await connection.write(base64.encode(utf8.encode(settings.password!)));
      _expectAuth(await connection.readReply());
      return;
    }
    throw TomDeliveryException.permanent(
      'messaging.smtp.no_supported_auth',
      '${settings.host} offers no authentication mechanism this client '
          'supports (offered: ${mechanisms.join(', ')}).',
      parameters: {'host': settings.host, 'offered': mechanisms.join(', ')},
    );
  }

  /// Requires [reply] to be a positive completion of an `AUTH` exchange.
  ///
  /// Synchronous, like [_failureFor] and [_expect]: it inspects a reply that
  /// has already been read. A `Future` here would only add a microtask per
  /// protocol step and promise a suspension that never happens.
  void _expectAuth(TomSmtpReply reply) {
    if (reply.isPositive) return;
    // Permanent by the letter of the RFC, and worth a message that names the
    // configuration: a rejected credential is far more often a deployment that
    // supplied the wrong secret than a genuine account problem, and "535
    // authentication failed" on its own sends people looking in the wrong place.
    throw TomDeliveryException.permanent(
      'messaging.smtp.auth_failed',
      '${settings.host} rejected the credential for "${settings.username}" '
          '(${reply.code} ${reply.text}). The password comes from the '
          'deployment environment (smtpPassword), not from a spec.',
      statusCode: reply.code,
      parameters: {'host': settings.host, 'username': settings.username},
    );
  }

  /// Requires [reply] to carry [expected], failing with the right judgement.
  ///
  /// Synchronous for the same reason as [_expectAuth]: the reply is already in
  /// hand, so the only thing `async` would add is a microtask on every step of
  /// the conversation.
  TomSmtpReply _expect(TomSmtpReply reply, int expected, String stage) {
    if (reply.code == expected) return reply;
    throw _failureFor(reply, stage);
  }

  /// Turns an unexpected reply into a classified failure.
  TomDeliveryException _failureFor(TomSmtpReply reply, String stage) {
    final detail =
        '${settings.host} answered ${reply.code} '
        '"${reply.text}" at $stage.';
    final parameters = {
      'host': settings.host,
      'stage': stage,
      'code': reply.code,
    };
    return reply.isPermanentNegative
        ? TomDeliveryException.permanent(
            'messaging.smtp.rejected',
            detail,
            statusCode: reply.code,
            parameters: parameters,
          )
        : TomDeliveryException.transient(
            'messaging.smtp.deferred',
            detail,
            statusCode: reply.code,
            parameters: parameters,
          );
  }
}

// =============================================================================
// CONNECTION
// =============================================================================

/// One SMTP reply: its code and the text of every line.
class TomSmtpReply {
  /// The three-digit reply code.
  final int code;

  /// The reply's lines, without their code prefixes.
  final List<String> lines;

  /// Creates a reply.
  const TomSmtpReply(this.code, this.lines);

  /// The reply's text, lines joined.
  String get text => lines.join(' ');

  /// Whether the command succeeded (`2xx`).
  bool get isPositive => code >= 200 && code < 300;

  /// Whether the server wants more input (`3xx`).
  bool get isIntermediate => code >= 300 && code < 400;

  /// Whether the failure is worth retrying (`4xx`).
  bool get isTransientNegative => code >= 400 && code < 500;

  /// Whether the failure is final (`5xx`).
  bool get isPermanentNegative => code >= 500;

  @override
  String toString() => '$code $text';
}

/// The socket half of an SMTP conversation.
///
/// An interface rather than a concrete socket so the protocol logic in
/// [TomSmtpTransport] is testable end to end without a mail server: every
/// branch above — a missing STARTTLS, a rejected credential, a partially
/// refused recipient list, a `4xx` deferral — is reachable against a scripted
/// fake, and none of them is conveniently reachable against a real relay.
abstract class TomSmtpConnection {
  /// Sends one command line.
  Future<void> write(String command);

  /// Sends the message body and the terminating `.`.
  Future<void> writeData(String data);

  /// Reads one complete reply, following multi-line continuations.
  Future<TomSmtpReply> readReply();

  /// Upgrades the connection to TLS after a `220` to `STARTTLS`.
  Future<void> upgradeToTls();

  /// Closes the connection.
  ///
  /// May throw, but cannot be used to signal a delivery problem:
  /// [TomSmtpTransport] hangs up in a `finally` and logs a failure here at
  /// debug instead of letting it replace whatever the conversation produced.
  Future<void> close();
}

/// A [TomSmtpConnection] over a real socket.
class TomSocketSmtpConnection implements TomSmtpConnection {
  Socket _socket;
  final TomSmtpSettings _settings;
  late StreamQueue<String> _lines;

  TomSocketSmtpConnection._(this._socket, this._settings) {
    _lines = StreamQueue(
      _socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
  }

  /// Opens a connection per [settings].
  static Future<TomSmtpConnection> open(TomSmtpSettings settings) async {
    final socket = settings.security == TomSmtpSecurity.implicitTls
        ? await SecureSocket.connect(
            settings.host,
            settings.port,
            timeout: settings.timeout,
            onBadCertificate: settings.allowInsecureCertificate
                ? (_) => true
                : null,
          )
        : await Socket.connect(
            settings.host,
            settings.port,
            timeout: settings.timeout,
          );
    return TomSocketSmtpConnection._(socket, settings);
  }

  @override
  Future<void> write(String command) async {
    _socket.write('$command$tomMimeLineEnding');
    await _socket.flush();
  }

  @override
  Future<void> writeData(String data) async {
    // Dot-stuffing. A body line consisting of a single `.` is the end-of-data
    // marker, so any line that starts with one must be escaped or the message
    // is truncated exactly there. Base64 output never produces such a line, but
    // headers and future encodings can.
    final stuffed = data
        .split(RegExp(r'\r?\n'))
        .map((line) => line.startsWith('.') ? '.$line' : line)
        .join(tomMimeLineEnding);
    _socket.write(stuffed);
    if (!stuffed.endsWith(tomMimeLineEnding)) {
      _socket.write(tomMimeLineEnding);
    }
    _socket.write('.$tomMimeLineEnding');
    await _socket.flush();
  }

  @override
  Future<TomSmtpReply> readReply() async {
    final lines = <String>[];
    var code = 0;
    while (true) {
      if (!await _lines.hasNext) {
        throw TomDeliveryException.transient(
          'messaging.smtp.connection_closed',
          'The connection to ${_settings.host} closed mid-reply.',
          parameters: {'host': _settings.host},
        );
      }
      final line = await _lines.next;
      if (line.length < 4) {
        lines.add(line.trim());
        continue;
      }
      code = int.tryParse(line.substring(0, 3)) ?? code;
      lines.add(line.substring(4).trim());
      // A space in the fourth column ends the reply; a hyphen continues it.
      if (line[3] == ' ') return TomSmtpReply(code, lines);
    }
  }

  @override
  Future<void> upgradeToTls() async {
    _socket = await SecureSocket.secure(
      _socket,
      host: _settings.host,
      onBadCertificate: _settings.allowInsecureCertificate ? (_) => true : null,
    );
    _lines = StreamQueue(
      _socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter()),
    );
  }

  @override
  Future<void> close() async {
    // Closing a socket the far side already dropped is not a delivery failure
    // — the outcome was decided before we got here — but it is worth a line.
    await _quietly('socket teardown', () async {
      await _lines.cancel(immediate: true);
      await _socket.close();
    });
    // Outside the wrapper on purpose: `destroy` releases the resource and does
    // not throw, so it must run whether or not the graceful close did.
    _socket.destroy();
  }
}
