import 'package:uuid/v4.dart';

/// A per-request correlation id.
///
/// `tomDefaultAuthenticationMiddleware` creates one [TomRequestId] per incoming
/// request and publishes it into the request zone (keyed by `TomRequestId`), so
/// any code running under that request can recover it with
/// `getFromCurrentZone<TomRequestId>()`. It is the source of the `requestUuid`
/// stamped onto server exceptions (`TomServerException`), of the request id the
/// endpoints pipeline logs, and of the `requestId` column on an audit entry.
///
/// It lives in `little_things` rather than beside the middleware that seeds it
/// because it is consumed further down the package than it is produced: the
/// exception base reads it in its constructor, and `little_things` is the
/// module every other one depends on. Declaring it beside the server would
/// point that arrow backwards and make the most depended-upon module in the
/// package import the largest one.
class TomRequestId {
  /// A freshly generated v4 UUID identifying this request.
  late final String uuid;

  /// Creates a request id with a new random v4 [uuid].
  TomRequestId() {
    var generator = UuidV4();
    uuid = generator.generate();
  }

  @override
  String toString() => "TomRequestId: $uuid";
}
