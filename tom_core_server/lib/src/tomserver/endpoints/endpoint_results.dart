/// Result *directives* an endpoint handler may return instead of a value: a
/// shape the pipeline recognises and turns into the response it describes.
///
/// ## Why a directive rather than a raw `Response`
///
/// The pipeline already lets a handler return a shelf [Response] and passes it
/// through untouched — that is the escape hatch streaming needs, where only the
/// handler knows how to build the body. A redirect is the opposite case: there
/// is *no* body, and everything about the response is already known from a
/// status and a URL. Returning a hand-built `Response` for it would mean every
/// redirecting handler re-deriving the same three facts (which status, which
/// header, what to put in the body), and each one free to get them wrong.
///
/// So a handler returns [TomRedirect] — a value that says *what it wants* — and
/// the pipeline decides how that reaches the wire. The handler stays
/// transport-free and stays unit-testable: asserting `result.location` needs no
/// HTTP at all, whereas asserting on a `Response` means reading headers back
/// out of a transport object the test had no reason to involve.
library;

import 'package:shelf/shelf.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A directive telling the pipeline to answer with an HTTP redirect to
/// [location].
///
/// Returned from a handler in place of a result value:
///
/// ```dart
/// @TomEndpoint(uri: '/documents', methods: [TomHttpMethod.post])
/// Future<Object> create(DocumentRequest request) async {
///   final saved = await documents.save(request.toDocument());
///   return TomRedirect.seeOther('/documents/${saved.id}');
/// }
/// ```
///
/// The three named constructors cover the three redirects that differ in ways a
/// caller can observe, and deliberately not the rest: [seeOther] (303) turns a
/// `POST` into a `GET` of the new resource, [temporary] (307) and [permanent]
/// (308) both preserve the method and differ only in whether the client may
/// remember the new address. 301 and 302 are omitted on purpose — they are the
/// same two intentions as 308/307 but with the method-rewriting behaviour left
/// ambiguous across clients, so an endpoint that means one of them is better
/// served saying so unambiguously.
class TomRedirect {
  /// The target of the redirect, as it will appear in the `Location` header.
  ///
  /// Passed through as given: a relative path (`/documents/42`) is the usual
  /// choice and is valid, and an absolute URL is equally acceptable when the
  /// target is genuinely elsewhere.
  final String location;

  /// The 3xx status to answer with.
  final int status;

  /// Creates a redirect to [location] with an explicit [status].
  ///
  /// Prefer the named constructors; this one exists for the endpoint that
  /// genuinely needs a status they do not cover.
  TomRedirect(this.location, {this.status = 303})
    : assert(location.isNotEmpty, 'A redirect needs a location.'),
      assert(
        status >= 300 && status < 400,
        'A redirect status must be in the 3xx range.',
      );

  /// `303 See Other` — the target should be fetched with `GET`.
  ///
  /// The right answer to a successful `POST`: it stops a browser reload from
  /// re-submitting the form, because what gets reloaded is the `GET` of the
  /// created resource rather than the `POST` that created it.
  TomRedirect.seeOther(this.location)
    : status = 303,
      assert(location.isNotEmpty, 'A redirect needs a location.');

  /// `307 Temporary Redirect` — same request, different address, this once.
  ///
  /// The method and body are preserved, so a `POST` stays a `POST`.
  TomRedirect.temporary(this.location)
    : status = 307,
      assert(location.isNotEmpty, 'A redirect needs a location.');

  /// `308 Permanent Redirect` — the resource has moved for good.
  ///
  /// The method and body are preserved. Clients may cache this indefinitely,
  /// so it is the one redirect that is expensive to get wrong.
  TomRedirect.permanent(this.location)
    : status = 308,
      assert(location.isNotEmpty, 'A redirect needs a location.');

  /// Builds the shelf [Response] this directive describes.
  ///
  /// The body is empty: a redirect's meaning is entirely in its status and its
  /// `Location` header, and a body would be read by nothing.
  Response toResponse() =>
      Response(status, headers: {TomHeader.location: location});

  @override
  String toString() => 'TomRedirect($status -> $location)';
}
