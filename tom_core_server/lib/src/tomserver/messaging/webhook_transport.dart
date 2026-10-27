/// Webhook delivery: a POST of the message to the URL that addresses it.
///
/// ## What a webhook needs from the shared shape
///
/// Nothing of its own, which is the third time that has been true.
/// [TomWebhookTransport] takes the same [TomMessage] and returns the same
/// [TomDeliveryReceipt] as SMTP and SMS; the channel's peculiarity — that the
/// "address" is a URL and the "message" is its own JSON — is carried by fields
/// the shared types already have. [TomRecipient.address] holds the endpoint,
/// [TomMessage.headers] holds the HTTP headers its own dartdoc always said it
/// would, and [TomMessage.toJson] is the body.
///
/// ## One endpoint per message, and why that is a refusal
///
/// A message addressed to two URLs is refused, permanently. The outbox retries
/// a *message*, not a recipient, so a POST that succeeded at one endpoint and
/// failed at another would be re-sent to both — and a webhook is not
/// idempotent: the far side would process it twice. Fan-out is expressed as two
/// messages, which the outbox then retries independently and correctly.
///
/// That is a constraint the other transports do not have, and it comes from the
/// channel rather than from this implementation: SMTP hands one submission to a
/// server that owns the per-recipient outcome and reports it back, which is
/// what [TomDeliveryReceipt.rejectedRecipients] exists for. HTTP has no such
/// server.
///
/// ## The classification rule
///
/// The transport's one judgement is whether a failure is worth repeating, and
/// for a webhook it is a single layer: the HTTP status, through
/// [TomDeliveryException.isTransientHttpStatus] — the same rule the SMS gateway
/// uses, because it is the same question. There is no second, payload-level
/// layer: an SMS gateway has one for its own reasons (a `200` carrying
/// `{"status":"failed"}` is an accepted request and a refused message), and a
/// webhook endpoint answers for itself with the status it returns.
///
/// ## No signing
///
/// This transport does not sign its requests. Signature schemes are a
/// per-consumer contract — the header name, the digest, what exactly is
/// canonicalised — and a guess at one is a guess the receiver cannot verify.
/// A deployment that has such a contract puts the header in
/// [TomWebhookSettings.headers], which is applied to every call and which a
/// message cannot override.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'message.dart';
import 'message_transport.dart';

// =============================================================================
// SETTINGS
// =============================================================================

/// How the webhook transport calls an endpoint.
///
/// Deliberately small: the endpoint is addressed by the *message*, so nothing
/// here names a host. What is here is what a deployment decides once and every
/// call shares.
class TomWebhookSettings {
  /// How long to wait for the endpoint to answer.
  final Duration timeout;

  /// Headers applied to every call — an API key, a signature, a tenant id.
  ///
  /// **These win over [TomMessage.headers].** A message is composed by
  /// application code and the headers here carry the deployment's credential;
  /// letting the composing code overwrite one would let it strip the
  /// authentication off a call, which is not a decision a message gets to make.
  final Map<String, String> headers;

  /// How much of the endpoint's answer is kept in the receipt.
  ///
  /// A cap rather than the whole body, because the body is a stranger's and the
  /// receipt is logged: an endpoint that answers with a megabyte of HTML would
  /// otherwise put a megabyte of HTML in the log for every delivery.
  final int maxDetailChars;

  /// Creates webhook settings.
  TomWebhookSettings({
    this.timeout = const Duration(seconds: 30),
    Map<String, String>? headers,
    this.maxDetailChars = 512,
  }) : headers = Map.unmodifiable(headers ?? const {}) {
    if (maxDetailChars < 0) {
      throw TomMessagingException(
        'messaging.webhook.bad_detail_cap',
        'maxDetailChars must not be negative.',
        parameters: {'maxDetailChars': maxDetailChars},
      );
    }
  }
}

// =============================================================================
// TRANSPORT
// =============================================================================

/// Delivers a [TomMessageChannel.webhook] message by POSTing it to the URL in
/// its recipient's address.
///
/// The body is [TomMessage.toJson] encoded as `application/json` — the same
/// representation the outbox already round-trips, so what the endpoint receives
/// and what a queued message *is* cannot drift apart.
class TomWebhookTransport extends TomMessageTransport {
  /// The content type every call declares and every body is.
  static const String contentType = 'application/json; charset=utf-8';

  /// What a deployment decided once, for every call.
  final TomWebhookSettings settings;

  /// Opens the connection to [endpoint]. Injectable so the whole
  /// classification is testable against a scripted client without a socket —
  /// the same seam [TomSmsTransport.openChannel] provides.
  ///
  /// It takes the endpoint because, unlike SMTP and SMS, a webhook's host comes
  /// from the *message*: there is no configured server to cache a channel for,
  /// so one is opened per delivery and closed again.
  final TomServerChannel Function(Uri endpoint) openChannel;

  /// Creates a webhook transport.
  TomWebhookTransport({
    TomWebhookSettings? settings,
    TomServerChannel Function(Uri endpoint)? openChannel,
  }) : settings = settings ?? TomWebhookSettings(),
       openChannel = openChannel ?? _defaultChannel;

  static TomServerChannel _defaultChannel(Uri endpoint) => TomServerChannel(
    endpoint.host,
    endpoint.hasPort ? endpoint.port : (endpoint.isScheme('https') ? 443 : 80),
  );

  @override
  TomMessageChannel get channel => TomMessageChannel.webhook;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    checkSupported(message);
    final endpoint = _endpointOf(message);

    final channel = openChannel(endpoint);
    try {
      final (status, body) = await _exchangeOrDefer(endpoint, message, channel);
      final detail = _truncated(body);

      if (status >= 200 && status < 300) {
        return TomDeliveryReceipt(
          messageId: message.id,
          outcome: TomDeliveryOutcome.delivered,
          detail: detail,
        );
      }

      final parameters = <String, Object?>{
        'messageId': message.id,
        'endpoint': endpoint.toString(),
        'httpStatus': status,
      };
      if (TomDeliveryException.isTransientHttpStatus(status)) {
        throw TomDeliveryException.transient(
          'messaging.webhook.refused',
          'The webhook endpoint answered $status.',
          statusCode: status,
          parameters: parameters,
        );
      }
      throw TomDeliveryException.permanent(
        'messaging.webhook.rejected',
        'The webhook endpoint answered $status.',
        statusCode: status,
        parameters: parameters,
      );
    } finally {
      channel.close();
    }
  }

  /// The single endpoint [message] addresses.
  ///
  /// Both refusals are permanent by construction: neither a second recipient
  /// nor a URL that is not HTTP becomes deliverable by being tried again.
  Uri _endpointOf(TomMessage message) {
    if (message.recipients.length != 1) {
      throw TomDeliveryException.permanent(
        'messaging.webhook.not_one_endpoint',
        'A webhook message addresses exactly one endpoint; this one names '
            '${message.recipients.length}. Send one message per endpoint, so '
            'the outbox can retry each without re-delivering the others.',
        parameters: {
          'messageId': message.id,
          'recipients': message.recipients.length,
        },
      );
    }
    final address = message.recipients.single.address;
    final endpoint = Uri.tryParse(address);
    if (endpoint == null ||
        !(endpoint.isScheme('http') || endpoint.isScheme('https')) ||
        endpoint.host.isEmpty) {
      throw TomDeliveryException.permanent(
        'messaging.webhook.bad_endpoint',
        'A webhook address must be an http or https URL.',
        parameters: {'messageId': message.id, 'endpoint': address},
      );
    }
    return endpoint;
  }

  Future<(int, String)> _exchangeOrDefer(
    Uri endpoint,
    TomMessage message,
    TomServerChannel channel,
  ) async {
    try {
      return await _exchange(
        endpoint,
        message,
        channel,
      ).timeout(settings.timeout);
    } on TomDeliveryException {
      rethrow;
    } catch (error, stack) {
      // Unreachable, refused, timed out: the textbook transient failure.
      // Nothing about the message is wrong, so nothing is gained by giving up.
      throw TomDeliveryException.transient(
        'messaging.webhook.unreachable',
        'Could not reach the webhook endpoint at ${endpoint.host}.',
        parameters: {'messageId': message.id, 'host': endpoint.host},
        rootException: error,
        stack: stack,
      );
    }
  }

  static const Set<String> _traceHeaders = {'traceparent', 'tracestate'};

  Future<(int, String)> _exchange(
    Uri endpoint,
    TomMessage message,
    TomServerChannel channel,
  ) async {
    final call = channel.prepareCall(
      TomServerCallSpecs(
        'POST',
        endpoint,
        headers: {
          // The trace a queued message carries is the one its delivery
          // continues; the call itself propagates the delivery's own position,
          // so the receiver's span is a child of this call.
          for (final header in message.headers.entries)
            if (!_traceHeaders.contains(header.key.toLowerCase()))
              header.key: header.value,
          ...settings.headers,
          TomHeader.contentType: contentType,
        },
        // The kernel call layer injects the *caller's* bearer token by default.
        // A subscribed endpoint has no idea what that is, and presenting it
        // would hand a user credential to a third party.
        includeBearerAuthentication: false,
      ),
    );
    call.send(
      TomServerCallLoad(
        stringBody: jsonEncode(message.toJson()),
        contentType: contentType,
        encoding: utf8,
      ),
    );
    // Order matters: reading the body consumes the stream, and the status is
    // only readable before that.
    final status = await call.getResponseStatusCode();
    return (status, await call.readAsString(utf8));
  }

  String? _truncated(String body) {
    if (body.isEmpty) return null;
    if (body.length <= settings.maxDetailChars) return body;
    return '${body.substring(0, settings.maxDetailChars)}…';
  }
}
