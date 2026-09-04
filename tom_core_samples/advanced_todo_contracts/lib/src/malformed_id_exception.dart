/// The fault a tier raises when a display-id it was handed is not a usable
/// database key, and the stable error key it is reported under on the wire.
///
/// Kept in the contracts package because all three tiers name it: both servers'
/// persistence mappings throw it, both servers' endpoint error handlers turn it
/// into the `400` carrying [malformedIdKey], and the client core's live suites
/// assert on that key.
library;

/// The stable error key a malformed display-id is reported under.
///
/// The `400` responses both servers build put this in their `{"error": …}`
/// body, so it is part of the wire contract and belongs beside the DTOs rather
/// than in either server.
const String malformedIdKey = 'request.id.malformed';

/// Thrown when a display-id arriving from the domain or the wire is not a
/// usable database key.
///
/// A [FormatException] *subtype* rather than a bare `FormatException`, so the
/// endpoint error handlers can recognise exactly this fault. The servers raise
/// genuine `FormatException`s that are server faults — a malformed
/// resource-bundle asset, for one — and those must stay 500s; matching the bare
/// supertype would misreport them as client errors.
class MalformedIdException extends FormatException {
  /// Reports that [value] is not a database key for [field], where the empty
  /// string *is* accepted by the caller (it marks an entity that has not been
  /// persisted yet, so the repository issues an INSERT).
  MalformedIdException(String field, String value)
    : super(
        'Malformed database key for $field: expected an integer, or the empty '
        'string for an entity that has not been persisted yet.',
        value,
      );

  /// Reports that [value] is not a database key for [field], where a key naming
  /// an already-persisted row is required.
  ///
  /// Unlike [MalformedIdException.new] this rejects the empty string too: a
  /// foreign key that must reference an existing row cannot point at "not
  /// persisted yet".
  MalformedIdException.persisted(String field, String value)
    : super(
        'Malformed database key for $field: expected an integer naming an '
        'already-persisted row.',
        value,
      );
}
