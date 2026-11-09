/// The inbound half of delivery reporting: the HTTP callback a carrier posts a
/// status to, and what it does with it.
///
/// ## Why this is not authenticated the way every other endpoint is
///
/// A carrier's callback is a machine on someone else's network with no account
/// here. It cannot present a bearer token, so `@TomAuthenticatedAccess` — which
/// the file endpoint uses and which the pipeline applies by default — would
/// refuse every real report. The route is therefore `@TomPublicAccess` and
/// carries its own gate, a [TomDeliveryCallbackVerifier] the installation
/// chooses, compared in **constant time**:
///
/// * [TomSharedSecretCallbackVerifier] — a shared secret the carrier presents
///   in a header. What it buys is that a passer-by cannot mark messages
///   delivered; what it does not buy is confidentiality of the secret itself,
///   which travels with every callback and is therefore only as safe as the
///   TLS under it.
/// * [TomTwilioCallbackVerifier], [TomVonageCallbackVerifier] — the request
///   signature a carrier computes with a secret it never sends, for carriers
///   that cannot add a header to their callback.
///
/// A deployment wanting more puts the endpoint behind a gateway that does
/// mutual TLS and keeps the verifier as the second factor.
///
/// **Refusing is the default.** Until [TomDeliveryReportEndpoint.install] gave
/// it a verifier, the endpoint refuses every callback rather than accepting
/// every callback. The opposite default is the one that ships an open endpoint
/// to anyone who mounts the component without reading this paragraph.
///
/// The callback is read as JSON, as a form (`application/x-www-form-urlencoded`,
/// as Twilio posts) or from the query string (as Vonage sends a `GET`); the
/// verifier sees the body before anything is decoded.
///
/// ## What it answers, and why a carrier cares
///
/// | Situation | Status | Why |
/// | --------- | ------ | --- |
/// | report recorded | `200` | A failure report also suppresses its address, when a [TomSuppressionList] is installed |
/// | body carried no readable report | `400` | A carrier retries a `5xx` and gives up on a `4xx`; a malformed body will not parse on the second attempt either |
/// | no correlation for the id | `404` | Not an error here — another deployment may share the carrier account — but the carrier's dashboard should show the mismatch |
/// | not verified (secret or signature missing or wrong) | `401` | |
/// | nothing configured | `503` | The deployment mounted the component and wired neither store nor protocol; a `404` would read as "wrong URL" |
library;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import 'delivery_callback_verifier.dart';
import 'delivery_report.dart';
import 'message_transport.dart';
import 'suppression_list.dart';

/// The handler behind [TomDeliveryReportService], as static state and one
/// entry point.
///
/// Static for the same reason the health module's analyzers are: a carrier
/// callback arrives before any request has established a zone, and the
/// configuration has to be installable at start-up — before the bean context
/// exists — which is what rules out making it a bean.
class TomDeliveryReportEndpoint {
  TomDeliveryReportEndpoint._();

  /// The route the callback is mounted at.
  static const String routeUri = '/messaging/delivery-report';

  static TomDeliveryReportStore? _store;
  static TomDeliveryReportProtocol? _protocol;
  static TomDeliveryCallbackVerifier? _verifier;
  static TomSuppressionList? _suppressions;
  static final StreamController<TomDeliveryCorrelation> _reports =
      StreamController<TomDeliveryCorrelation>.broadcast();

  /// The correlation index reports are recorded in, or `null` when none is
  /// installed.
  static TomDeliveryReportStore? get store => _store;

  /// The mapping from a carrier's callback shape, or `null` when none is
  /// installed.
  static TomDeliveryReportProtocol? get protocol => _protocol;

  /// The list a failure report adds its address to, or `null` when none is
  /// installed — then a report is recorded and nothing is suppressed.
  static TomSuppressionList? get suppressions => _suppressions;

  /// Whether a verifier has been installed.
  ///
  /// The verifier itself is deliberately not readable: it holds a secret, a
  /// getter returning it would put it in every diagnostic dump that walks a
  /// class's properties, and nothing legitimate needs to read a secret back
  /// out of the place it was installed.
  static bool get isGated => _verifier != null;

  /// Correlations as each report is recorded, for a deployment that wants to
  /// act on a delivery rather than query for it.
  ///
  /// Carries the correlation rather than the bare report, because "the
  /// order-confirmation message failed" is actionable and "the carrier id it came
  /// back under failed" is not.
  static Stream<TomDeliveryCorrelation> get reports => _reports.stream;

  /// Installs what the endpoint needs to answer a callback.
  ///
  /// [verifier] gates the route and has no default: a deployment that does
  /// not supply one gets a route that refuses everything, which is the safe
  /// direction for a public URL.
  ///
  /// With [suppressions], a recorded [TomDeliveryState.failed] report
  /// suppresses its address ([TomSuppressionList.applyReport]); give the same
  /// list to the [TomMessageRouter] that sends, so the next message leaves it
  /// out.
  static void install({
    required TomDeliveryReportStore store,
    required TomDeliveryReportProtocol protocol,
    required TomDeliveryCallbackVerifier verifier,
    TomSuppressionList? suppressions,
  }) {
    _store = store;
    _protocol = protocol;
    _verifier = verifier;
    _suppressions = suppressions;
    final suppressing = suppressions == null
        ? 'suppressing nothing'
        : 'suppressing into ${suppressions.runtimeType}';
    tomLog.info(
      'TomDeliveryReportEndpoint: installed over ${store.runtimeType} '
      'with ${protocol.runtimeType}, gated by $verifier, $suppressing',
    );
  }

  /// Puts the endpoint back the way a fresh process starts it: no store, no
  /// protocol, no verifier — and therefore refusing every callback.
  ///
  /// The supported spelling for a test that installed one, and it logs like the
  /// installation it is.
  static void reset() {
    _store = null;
    _protocol = null;
    _verifier = null;
    _suppressions = null;
    tomLog.info('TomDeliveryReportEndpoint: reset; the route now refuses');
  }

  /// Handles one carrier callback.
  static Future<Response> handle(Request request) async {
    final store = _store;
    final protocol = _protocol;
    final verifier = _verifier;
    if (store == null || protocol == null || verifier == null) {
      return _answer(503, 'messaging.delivery_report.not_configured');
    }

    final body = await request.readAsString();
    final isForm = (request.headers[TomHeader.contentType] ?? '')
        .toLowerCase()
        .startsWith('application/x-www-form-urlencoded');
    final Map<String, String> parameters;
    try {
      parameters = {
        ...request.requestedUri.queryParameters,
        if (isForm && body.isNotEmpty) ...Uri.splitQueryString(body),
      };
    } on ArgumentError {
      return _answer(400, 'messaging.delivery_report.unreadable');
    }
    final verified = verifier.verify(
      TomDeliveryCallbackRequest(
        method: request.method,
        url: request.requestedUri,
        headers: request.headers,
        body: body,
        parameters: parameters,
      ),
    );
    if (!verified) {
      return _answer(401, 'messaging.delivery_report.unauthorized');
    }

    final Object? decoded;
    try {
      decoded = isForm || body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      return _answer(400, 'messaging.delivery_report.unreadable');
    }

    final callback = TomDeliveryCallback(
      body: decoded,
      parameters: parameters,
      headers: request.headers,
    );
    final reports = protocol.decode(callback);
    if (reports.isEmpty) {
      return _answer(400, 'messaging.delivery_report.no_report');
    }

    final suppressions = _suppressions;
    var matched = 0;
    for (final report in reports) {
      final correlation = await store.record(report);
      if (correlation == null) continue;
      matched++;
      if (suppressions != null) {
        await suppressions.applyReport(correlation, report: report);
      }
      if (!_reports.isClosed) _reports.add(correlation);
    }
    // A batch in which nothing matched is the unmatched case; one in which
    // *some* matched is a success, because a carrier cannot act on "three of
    // your five ids are unknown to me" and re-posting the batch would re-report
    // the two that did match.
    if (matched == 0) {
      return _answer(404, 'messaging.delivery_report.unknown_message');
    }
    return _answer(200, 'messaging.delivery_report.recorded', reports: matched);
  }

  static Response _answer(int status, String key, {int? reports}) => Response(
    status,
    body: jsonEncode({'key': key, if (reports != null) 'reports': reports}),
    headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
  );
}

/// The delivery-report service interface, mounted by the endpoints pipeline.
@tomReflector
@tomService
abstract class TomDeliveryReportService {
  /// `POST` or `GET` on `/messaging/delivery-report`: most carriers post their
  /// reports, and Vonage can be set to send its receipts as a `GET` with the
  /// report in the query string.
  ///
  /// `@TomPublicAccess` because the caller is a carrier with no account here —
  /// see the library documentation for what gates it instead, and for why the
  /// default is to refuse.
  ///
  /// `logRequests: false`: a carrier reporting on every message doubles the
  /// access log, and the reports themselves are recorded in the index, which is
  /// the record worth keeping.
  ///
  /// Returns a shelf [Response] rather than a value, because the status *is*
  /// the answer a carrier acts on — it retries a `5xx` and gives up on a `4xx`
  /// — and the pipeline's own envelope would make every refusal a `500`.
  @TomPublicAccess()
  @TomEndpoint(
    methods: [TomHttpMethod.post, TomHttpMethod.get],
    uri: TomDeliveryReportEndpoint.routeUri,
    consumes: TomMimeType.json,
    produces: TomMimeType.json,
    logRequests: false,
  )
  Future<Response> deliveryReport(Request request);
}

/// The default [TomDeliveryReportService] implementation.
///
/// Holds no state — the configuration is [TomDeliveryReportEndpoint]'s and the
/// request is the argument — so the pipeline may construct it itself when an
/// application has registered no bean of its own.
@tomReflector
@tomComponent
class TomDeliveryReportServer implements TomDeliveryReportService {
  @override
  Future<Response> deliveryReport(Request request) =>
      TomDeliveryReportEndpoint.handle(request);
}
