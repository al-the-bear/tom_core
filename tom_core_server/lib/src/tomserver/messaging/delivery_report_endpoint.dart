/// The inbound half of delivery reporting: the HTTP callback a carrier posts a
/// status to, and what it does with it.
///
/// ## Why this is not authenticated the way every other endpoint is
///
/// A carrier's callback is a machine on someone else's network with no account
/// here. It cannot present a bearer token, so `@TomAuthenticatedAccess` — which
/// the file endpoint uses and which the pipeline applies by default — would
/// refuse every real report. The route is therefore `@TomPublicAccess` and
/// carries its own gate: a shared secret the deployment configures and the
/// carrier presents, compared in **constant time**.
///
/// That is a weaker guarantee than a token and it is stated rather than
/// glossed. What the secret buys is that a passer-by cannot mark messages
/// delivered; what it does not buy is confidentiality of the secret itself,
/// which travels in a header on every callback and is therefore only as safe as
/// the TLS under it. A deployment wanting more puts the endpoint behind a
/// gateway that does mutual TLS and leaves the secret as the second factor.
///
/// **Refusing is the default.** [TomDeliveryReportEndpoint.secret] starts
/// `null`, and a `null` secret refuses every callback rather than accepting
/// every callback. The opposite default is the one that ships an open endpoint
/// to anyone who mounts the component without reading this paragraph.
///
/// ## What it answers, and why a carrier cares
///
/// | Situation | Status | Why |
/// | --------- | ------ | --- |
/// | report recorded | `200` | |
/// | body carried no readable report | `400` | A carrier retries a `5xx` and gives up on a `4xx`; a malformed body will not parse on the second attempt either |
/// | no correlation for the id | `404` | Not an error here — another deployment may share the carrier account — but the carrier's dashboard should show the mismatch |
/// | secret missing or wrong | `401` | |
/// | nothing configured | `503` | The deployment mounted the component and wired neither store nor protocol; a `404` would read as "wrong URL" |
library;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../endpoints/endpoint_annotation.dart';
import 'delivery_report.dart';
import 'message.dart';

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

  /// The header a carrier presents the shared secret in.
  ///
  /// A header rather than a query parameter because a URL is logged by every
  /// proxy between here and the carrier, and a secret in a log is a secret
  /// somebody has to rotate.
  static const String secretHeader = 'x-tom-delivery-secret';

  static TomDeliveryReportStore? _store;
  static TomDeliveryReportProtocol? _protocol;
  static String? _secret;
  static final StreamController<TomDeliveryCorrelation> _reports =
      StreamController<TomDeliveryCorrelation>.broadcast();

  /// The correlation index reports are recorded in, or `null` when none is
  /// installed.
  static TomDeliveryReportStore? get store => _store;

  /// The mapping from a carrier's callback shape, or `null` when none is
  /// installed.
  static TomDeliveryReportProtocol? get protocol => _protocol;

  /// Whether a shared secret has been installed.
  ///
  /// The secret itself is deliberately not readable: a getter returning it
  /// would put it in every diagnostic dump that walks a class's properties, and
  /// nothing legitimate needs to read a secret back out of the place it was
  /// installed.
  static bool get isGated => _secret != null;

  /// Correlations as each report is recorded, for a deployment that wants to
  /// act on a delivery rather than query for it.
  ///
  /// Carries the correlation rather than the bare report, because "the
  /// order-confirmation message failed" is actionable and "the carrier id it came
  /// back under failed" is not.
  static Stream<TomDeliveryCorrelation> get reports => _reports.stream;

  /// Installs what the endpoint needs to answer a callback.
  ///
  /// [secret] gates the route and has no default: a deployment that does not
  /// supply one gets a route that refuses everything, which is the safe
  /// direction for a public URL.
  static void install({
    required TomDeliveryReportStore store,
    required TomDeliveryReportProtocol protocol,
    required String secret,
  }) {
    if (secret.isEmpty) {
      throw TomMessagingException(
        'messaging.delivery_report.empty_secret',
        'The delivery-report endpoint needs a non-empty shared secret; an '
            'empty one gates nothing.',
      );
    }
    _store = store;
    _protocol = protocol;
    _secret = secret;
    tomLog.info(
      'TomDeliveryReportEndpoint: installed over ${store.runtimeType} '
      'with ${protocol.runtimeType}',
    );
  }

  /// Puts the endpoint back the way a fresh process starts it: no store, no
  /// protocol, no secret — and therefore refusing every callback.
  ///
  /// The supported spelling for a test that installed one, and it logs like the
  /// installation it is.
  static void reset() {
    _store = null;
    _protocol = null;
    _secret = null;
    tomLog.info('TomDeliveryReportEndpoint: reset; the route now refuses');
  }

  /// Handles one carrier callback.
  static Future<Response> handle(Request request) async {
    final store = _store;
    final protocol = _protocol;
    final secret = _secret;
    if (store == null || protocol == null || secret == null) {
      return _answer(503, 'messaging.delivery_report.not_configured');
    }
    if (!_presents(request, secret)) {
      return _answer(401, 'messaging.delivery_report.unauthorized');
    }

    final body = await request.readAsString();
    final Object? decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      return _answer(400, 'messaging.delivery_report.unreadable');
    }

    final callback = TomDeliveryCallback(
      body: decoded,
      parameters: request.url.queryParameters,
      headers: request.headers,
    );
    final reports = protocol.decode(callback);
    if (reports.isEmpty) {
      return _answer(400, 'messaging.delivery_report.no_report');
    }

    var matched = 0;
    for (final report in reports) {
      final correlation = await store.record(report);
      if (correlation == null) continue;
      matched++;
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

  /// Whether [request] presents [secret].
  ///
  /// Constant-time: a comparison that returns early on the first wrong byte
  /// leaks the secret one byte at a time to anyone who can measure the answer,
  /// and a public endpoint is exactly where someone can.
  static bool _presents(Request request, String secret) {
    final presented = request.headers[secretHeader];
    if (presented == null) return false;
    final a = utf8.encode(presented);
    final b = utf8.encode(secret);
    var difference = a.length ^ b.length;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i % b.length];
    }
    return difference == 0;
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
  /// `POST` on `/messaging/delivery-report`.
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
    methods: [TomHttpMethod.post],
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
