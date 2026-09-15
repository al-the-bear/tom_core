/// Delivery reports: what a carrier says about a message *after* it accepted
/// it, and how that answer is matched back to the message it concerns.
///
/// ## The gap this closes
///
/// A transport's receipt records that the far side took responsibility, and for
/// SMS and email that is the *beginning* of delivery rather than the end. A
/// gateway answers `202` and hands back an id; the handset is reached, or is
/// not, minutes or hours later, and the carrier says so on a callback.
/// [TomDeliveryReceipt.remoteId] exists precisely so that callback can be
/// matched to the message — every transport that has an id to give fills it in
/// — and nothing read it back. So the module could report that a message was
/// *paid for* and never that it arrived.
///
/// ## Three pieces, and why they are separate
///
/// | Piece | What it does | Why it is not part of the next one |
/// | ----- | ------------ | ---------------------------------- |
/// | [TomDeliveryReportProtocol] | Maps a carrier's callback body to a [TomDeliveryReport] | The wire shape is a vendor's; the correlation is not |
/// | [TomDeliveryReportStore] | Remembers which message a `remoteId` belongs to, and the last state reported | Durable and query-by-id; a protocol is pure |
/// | `TomDeliveryReportService` | Receives the callback over HTTP | Needs the endpoints pipeline; the other two do not |
///
/// The split is what lets a deployment whose gateway offers no callback still
/// use the store — recording the correlation costs nothing and a support
/// engineer answering "was this delivered" can at least resolve an id — and
/// lets a deployment that receives reports some other way (a file drop, a queue
/// consumer) reuse the protocol and the store without the endpoint.
///
/// ## Why an index rather than the outbox's job store
///
/// The outbox already writes a run per message, so the job store looks like the
/// natural place to resolve one. It is not: [TomJobStore] is addressed by run
/// id and offers no lookup by any other field, so `remoteId` → message is a
/// full scan of every run ever queued. The index is its own small table, with
/// the same memory-plus-SQL pair every other store in the framework has.
library;

import 'message.dart';
import 'message_transport.dart';
import 'vendor_mapping.dart';

// =============================================================================
// WHAT A CARRIER SAYS
// =============================================================================

/// What became of a message after the far side accepted it.
///
/// Distinct from [TomDeliveryOutcome], and the distinction is the whole point:
/// an outcome is what *this* attempt achieved — the gateway took it, refused
/// it, or was unreachable — while a state is what the carrier did with it
/// afterwards. A message can be `TomDeliveryOutcome.delivered` and
/// [TomDeliveryState.failed]: accepted for delivery, and then not delivered.
enum TomDeliveryState {
  /// The carrier says it reached the recipient.
  delivered,

  /// The carrier says it did not, and will not try again.
  failed,

  /// The carrier gave up after its own retry window — a handset switched off
  /// for a day, a mailbox that stayed over quota. Separated from [failed]
  /// because the remedy differs: an expiry is worth re-sending later, a failure
  /// is an address to stop using.
  expired,

  /// A report arrived and its state was not one this module recognises.
  ///
  /// Kept rather than dropped: the report *happened*, and an operator reading a
  /// row that says `unknown` with the carrier's own word in `detail` learns
  /// more than one that says nothing. It is also the value a protocol maps an
  /// unmapped code to, which is what keeps a new carrier status from being
  /// silently read as success.
  unknown,
}

/// One thing a carrier said about one message.
class TomDeliveryReport {
  /// The carrier's identifier for the message — the value a transport put in
  /// [TomDeliveryReceipt.remoteId], and the only thing tying this report to
  /// anything.
  final String remoteId;

  /// What the carrier says became of it.
  final TomDeliveryState state;

  /// When the carrier says that happened.
  ///
  /// The *carrier's* instant where the callback supplies one, not the moment it
  /// was received: a report delayed by an hour of queueing describes an hour-old
  /// event, and stamping it with arrival time would make every latency
  /// measurement read zero.
  final DateTime at;

  /// The carrier's own words, kept verbatim for diagnosis.
  final String? detail;

  /// The carrier's status or error code, when it gave one.
  final String? providerCode;

  /// Creates a report.
  TomDeliveryReport({
    required this.remoteId,
    required this.state,
    DateTime? at,
    this.detail,
    this.providerCode,
  }) : at = at ?? DateTime.now().toUtc();

  /// Encodes this report as JSON-native values.
  Map<String, Object?> toJson() => {
    'remoteId': remoteId,
    'state': state.name,
    'at': at.toIso8601String(),
    if (detail != null) 'detail': detail,
    if (providerCode != null) 'providerCode': providerCode,
  };

  /// Decodes a map produced by [toJson].
  factory TomDeliveryReport.fromJson(Map<String, Object?> map) =>
      TomDeliveryReport(
        remoteId: map['remoteId'] as String,
        state: stateOf(map['state'] as String?),
        at: DateTime.parse(map['at'] as String),
        detail: map['detail'] as String?,
        providerCode: map['providerCode'] as String?,
      );

  /// The state [name] denotes, or [TomDeliveryState.unknown].
  ///
  /// Shared by the decoder and by every store that reads a state back out of a
  /// column, because a name written by one version and read by another must not
  /// throw: an unrecognised state is exactly what [TomDeliveryState.unknown]
  /// means.
  static TomDeliveryState stateOf(String? name) =>
      TomDeliveryState.values
          .where((state) => state.name == name)
          .firstOrNull ??
      TomDeliveryState.unknown;

  @override
  String toString() =>
      'TomDeliveryReport($remoteId ${state.name}'
      '${providerCode == null ? '' : ' code $providerCode'})';
}

// =============================================================================
// THE CORRELATION
// =============================================================================

/// What the module remembers about one sent message, so a later report can be
/// attributed to it.
///
/// One row per [remoteId], because that is the only key a carrier callback
/// carries. [messageId] is what the deployment actually wants back.
class TomDeliveryCorrelation {
  /// The carrier's identifier — the row's identity.
  final String remoteId;

  /// The [TomMessage.id] the carrier's id stands for.
  final String messageId;

  /// Which channel delivered it, so a deployment routing several carriers
  /// through one endpoint can tell whose report it is reading.
  final TomMessageChannel channel;

  /// When the transport accepted the message.
  final DateTime sentAt;

  /// The last state a report gave, or `null` while none has arrived.
  final TomDeliveryState? state;

  /// When that report was recorded, or `null` while none has arrived.
  final DateTime? reportedAt;

  /// The carrier's own words from that report.
  final String? detail;

  /// Creates a correlation.
  TomDeliveryCorrelation({
    required this.remoteId,
    required this.messageId,
    required this.channel,
    required this.sentAt,
    this.state,
    this.reportedAt,
    this.detail,
  });

  /// Whether a report has been recorded against this message.
  bool get isReported => state != null;

  /// This correlation with [report] applied.
  TomDeliveryCorrelation withReport(TomDeliveryReport report) =>
      TomDeliveryCorrelation(
        remoteId: remoteId,
        messageId: messageId,
        channel: channel,
        sentAt: sentAt,
        state: report.state,
        reportedAt: report.at,
        detail: report.detail,
      );

  @override
  String toString() =>
      'TomDeliveryCorrelation($remoteId -> $messageId, ${channel.name}'
      '${state == null ? ', unreported' : ', ${state!.name}'})';
}

/// Remembers which message a carrier's id stands for, and the last report
/// against it.
///
/// Addressed by [remoteId] because that is the only key a callback carries, and
/// [messageOf] is the single question the endpoint asks.
abstract class TomDeliveryReportStore {
  /// Creates a store.
  const TomDeliveryReportStore();

  /// Records that [correlation]'s message was accepted under its remote id.
  ///
  /// Replaces any row for the same id. A carrier re-using an id across messages
  /// would be a carrier that cannot be correlated at all, so the later message
  /// is the one worth keeping.
  Future<void> remember(TomDeliveryCorrelation correlation);

  /// The correlation for [remoteId], or `null` when none was remembered.
  Future<TomDeliveryCorrelation?> messageOf(String remoteId);

  /// Applies [report] to the correlation it names and returns the updated row,
  /// or `null` when nothing was remembered under that id.
  ///
  /// A `null` is not an error: a report can arrive for a message this node
  /// never sent (another deployment sharing a gateway account), or after the
  /// correlation was purged. The caller decides what to do about it, and the
  /// endpoint answers `404` so a carrier's own dashboard shows the mismatch.
  Future<TomDeliveryCorrelation?> record(TomDeliveryReport report);

  /// Drops correlations for messages sent before [before], answering how many
  /// went.
  ///
  /// A correlation index that never forgets grows with every message ever sent.
  /// How long to keep it is a deployment's decision — it is a delivery audit
  /// trail — so nothing purges automatically, exactly as
  /// [TomMessageOutbox.purgeFinished] leaves the same decision open.
  Future<int> purgeSentBefore(DateTime before);
}

/// A [TomDeliveryReportStore] in memory.
///
/// Right for tests and for a single-process deployment that only wants the
/// correlation for the life of the process; wrong for anything else, because a
/// restart loses every id and the reports that arrive afterwards can be matched
/// to nothing. The same caveat [TomMessageOutbox] states about its own default
/// store, and for the same reason.
class TomMemoryDeliveryReportStore extends TomDeliveryReportStore {
  final Map<String, TomDeliveryCorrelation> _rows = {};

  /// Creates an empty store.
  TomMemoryDeliveryReportStore();

  /// Everything remembered, for a test that wants to assert on the index.
  Iterable<TomDeliveryCorrelation> get correlations => _rows.values;

  @override
  Future<void> remember(TomDeliveryCorrelation correlation) async =>
      _rows[correlation.remoteId] = correlation;

  @override
  Future<TomDeliveryCorrelation?> messageOf(String remoteId) async =>
      _rows[remoteId];

  @override
  Future<TomDeliveryCorrelation?> record(TomDeliveryReport report) async {
    final existing = _rows[report.remoteId];
    if (existing == null) return null;
    return _rows[report.remoteId] = existing.withReport(report);
  }

  @override
  Future<int> purgeSentBefore(DateTime before) async {
    final doomed = _rows.values
        .where((row) => row.sentAt.isBefore(before))
        .map((row) => row.remoteId)
        .toList(growable: false);
    doomed.forEach(_rows.remove);
    return doomed.length;
  }
}

// =============================================================================
// THE VENDOR MAPPING
// =============================================================================

/// Turns a carrier's callback into a [TomDeliveryReport].
///
/// The same seam [TomSmsGatewayProtocol] is, for the same reason: the callback
/// shape is a vendor's and changes when the vendor changes, so it is
/// configuration rather than code. A protocol is **pure** — it is handed the
/// decoded body and the query parameters and returns a value — which is what
/// makes every carrier's mapping testable without an HTTP server.
abstract class TomDeliveryReportProtocol {
  /// Creates a protocol.
  const TomDeliveryReportProtocol();

  /// The reports carried by one callback.
  ///
  /// A list rather than one report because carriers batch: several gateways
  /// post an array of statuses in a single call, and a protocol that could only
  /// answer one would make the endpoint drop the rest. A callback carrying a
  /// single status answers a one-element list.
  ///
  /// Returns an empty list for a body this protocol cannot read, which the
  /// endpoint answers `400` for. Throwing would be the other option and is
  /// worse: a carrier retries a `500` and gives up on a `400`, so a malformed
  /// body has to be refused rather than deferred.
  List<TomDeliveryReport> decode(TomDeliveryCallback callback);
}

/// What a callback carried, independent of how it arrived.
///
/// A value rather than the request itself, so a protocol can be driven from a
/// file drop or a queue consumer as easily as from the endpoint — and so a
/// protocol test needs no HTTP.
class TomDeliveryCallback {
  /// The decoded JSON body, when the callback carried one.
  final Object? body;

  /// The query parameters, for carriers that report over `GET` or in the URL.
  final Map<String, String> parameters;

  /// The request headers, for a carrier that puts its status in one.
  final Map<String, String> headers;

  /// Creates a callback.
  TomDeliveryCallback({
    this.body,
    Map<String, String>? parameters,
    Map<String, String>? headers,
  }) : parameters = Map.unmodifiable(parameters ?? const {}),
       headers = Map.unmodifiable(headers ?? const {});
}

/// A [TomDeliveryReportProtocol] described by field names and status codes.
///
/// Expresses the common carriers without naming any of them, exactly as
/// [TomFieldMappedSmsProtocol] does for the submission direction — and no
/// vendor preset ships here either, for the reason stated there.
class TomFieldMappedDeliveryReportProtocol extends TomDeliveryReportProtocol {
  /// Dotted path to the carrier's message id within one report.
  final String remoteIdPath;

  /// Dotted path to the status token.
  final String statusPath;

  /// Dotted path to the carrier's own description, when it sends one.
  final String? detailPath;

  /// Dotted path to the error or status code, when it sends one.
  final String? codePath;

  /// Dotted path to the instant the carrier says the event happened.
  ///
  /// Parsed as ISO-8601; a value that does not parse leaves the report stamped
  /// with arrival time rather than failing the callback, because a bad
  /// timestamp is not a reason to refuse a status.
  final String? atPath;

  /// Dotted path to the array, when the carrier batches reports in one call.
  ///
  /// `null` means the body *is* one report.
  final String? batchPath;

  /// Status tokens that mean [TomDeliveryState.delivered], lowercased.
  final Set<String> deliveredStatuses;

  /// Status tokens that mean [TomDeliveryState.failed], lowercased.
  final Set<String> failedStatuses;

  /// Status tokens that mean [TomDeliveryState.expired], lowercased.
  final Set<String> expiredStatuses;

  /// Creates a field-mapped protocol.
  const TomFieldMappedDeliveryReportProtocol({
    required this.remoteIdPath,
    required this.statusPath,
    this.detailPath,
    this.codePath,
    this.atPath,
    this.batchPath,
    this.deliveredStatuses = const {'delivered'},
    this.failedStatuses = const {'failed', 'undelivered', 'rejected'},
    this.expiredStatuses = const {'expired'},
  });

  @override
  List<TomDeliveryReport> decode(TomDeliveryCallback callback) {
    final source = callback.body ?? callback.parameters;
    final entries = _entriesOf(source);
    final reports = <TomDeliveryReport>[];
    for (final entry in entries) {
      final remoteId = _at(entry, remoteIdPath);
      if (remoteId == null || remoteId.isEmpty) continue;
      reports.add(
        TomDeliveryReport(
          remoteId: remoteId,
          state: _stateOf(_at(entry, statusPath)),
          at: _instantOf(atPath == null ? null : _at(entry, atPath!)),
          detail: detailPath == null ? null : _at(entry, detailPath!),
          providerCode: codePath == null ? null : _at(entry, codePath!),
        ),
      );
    }
    return reports;
  }

  List<Object?> _entriesOf(Object? source) {
    if (batchPath == null) return [source];
    final batch = _listAt(source, batchPath!);
    return batch ?? const [];
  }

  /// The list at dotted [path], or `null` when the path reaches anything else.
  ///
  /// Separate from [tomVendorValueAt] because the batch path is the one place a
  /// mapping wants the container rather than a value inside it: the entries are
  /// then each read with the ordinary reader.
  static List<Object?>? _listAt(Object? source, String path) {
    Object? node = source;
    for (final step in path.split('.')) {
      final index = int.tryParse(step);
      if (index != null && index >= 0 && node is List) {
        if (index >= node.length) return null;
        node = node[index];
        continue;
      }
      if (node is! Map) return null;
      node = node[step];
    }
    return node is List ? node : null;
  }

  TomDeliveryState _stateOf(String? status) {
    final token = status?.toLowerCase();
    if (token == null) return TomDeliveryState.unknown;
    if (deliveredStatuses.contains(token)) return TomDeliveryState.delivered;
    if (failedStatuses.contains(token)) return TomDeliveryState.failed;
    if (expiredStatuses.contains(token)) return TomDeliveryState.expired;
    return TomDeliveryState.unknown;
  }

  /// [text] as an instant, or `null` — which leaves the report stamped with
  /// arrival time.
  static DateTime? _instantOf(String? text) =>
      text == null ? null : DateTime.tryParse(text)?.toUtc();

  /// The value at dotted [path], as text — see [tomVendorValueAt], which both
  /// vendor mappings read a path with.
  static String? _at(Object? source, String path) =>
      tomVendorValueAt(source, path);
}
