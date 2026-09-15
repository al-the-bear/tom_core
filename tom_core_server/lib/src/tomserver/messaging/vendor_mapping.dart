/// The one reader both vendor mappings use to reach a value inside a decoded
/// answer.
///
/// [TomFieldMappedSmsProtocol] and [TomFieldMappedDeliveryReportProtocol] are
/// the same idea pointed in opposite directions — a gateway's shape described
/// in configuration rather than coded — and both address that shape with a
/// dotted path. They had a resolver each, and the pair would have drifted the
/// moment one of them learned something the other did not: a deployment reading
/// the two classes side by side has every reason to assume `a.b.0.c` means the
/// same thing to both, and nothing would have told it otherwise.
///
/// ## Why a numeric segment indexes a list
///
/// Because almost every gateway wraps its answer in one. Submitting to Vonage
/// returns `{"messages":[{"message-id":"…","status":"0"}]}`; MessageBird
/// returns `{"recipients":{"items":[{"status":"sent"}]}}`; Infobip, Plivo and
/// ClickSend all do the same thing, because their submission APIs accept a list
/// of recipients and answer per recipient. Twilio is the outlier — one message
/// per call, a flat object — and Twilio is the shape this module's own test
/// fixture happened to be written against, which is why a map-only resolver
/// looked sufficient for as long as it did.
///
/// A map-only resolver cannot express any of the others at all: there is no
/// path from the root to `status` that does not pass through a list. So the
/// claim that the field-mapped protocol "expresses the common gateways" was
/// true of one gateway.
library;

/// The value at dotted [path] inside [json], as text, or `null`.
///
/// A segment that parses as a non-negative integer indexes a [List]; every
/// other segment reads a [Map] key. An index past the end, a missing key, or a
/// segment applied to neither answers `null` rather than throwing: a path is
/// configuration describing someone else's payload, and a gateway that changed
/// its shape should produce an unclassifiable answer rather than an exception
/// from inside a decode.
///
/// A map whose keys are digits is therefore unreachable by this reader. That is
/// a real limit and not a likely one — a JSON object keyed `"0"`, `"1"` is a
/// list somebody serialised wrongly — and the alternative, an escape syntax,
/// would cost every ordinary path a rule to remember.
String? tomVendorValueAt(Object? json, String? path) {
  if (json == null || path == null) return null;
  Object? node = json;
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
  return node?.toString();
}
