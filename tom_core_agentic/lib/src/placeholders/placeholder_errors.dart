// Placeholder-system failure types.
//
// Part of the shared placeholder system (originally Extension F, step 1 of
// `tom_brain_procedure_specification.md` § 21.7, § 21.10; relocated to
// `tom_core_agentic`). The three wire codes mirror the § 21.10 failure
// table verbatim. Each is kept as a named `const` so callers can route on
// the code without string-matching the message.

/// Wire code for a placeholder expansion that did not converge inside the
/// recursion cap. Matches the § 21.10 `placeholder.recursion.exceeded` row.
const String placeholderRecursionExceededCode =
    'placeholder.recursion.exceeded';

/// Wire code for an unknown `${name}` (or `${env:NAME}`) under strict mode.
/// Matches the § 21.10 `placeholder.unresolved` row.
const String placeholderUnresolvedCode = 'placeholder.unresolved';

/// Wire code for a `${{ … }}` expression that threw or would not parse.
/// Matches the § 21.10 `placeholder.expression.failed` row.
const String placeholderExpressionFailedCode = 'placeholder.expression.failed';

/// Raised when recursive placeholder expansion does not terminate within
/// the resolver's level cap (default 10, § 21.7).
///
/// Carries the [maxRecursion] cap that was hit and the partially expanded
/// [residue] — the text still holding unresolved placeholders when the cap
/// was reached — so a trail entry can show what failed to converge (a
/// cyclic binding is the typical cause).
final class PlaceholderRecursionException implements Exception {
  /// Records a non-converging expansion.
  const PlaceholderRecursionException({
    required this.maxRecursion,
    required this.residue,
  });

  /// The level cap that was reached (10 in v1).
  final int maxRecursion;

  /// The text still containing unresolved placeholders at the cap.
  final String residue;

  /// The wire code carried by every recursion failure.
  String get code => placeholderRecursionExceededCode;

  /// Human-readable explanation, reused by [toString].
  String get message =>
      'placeholder expansion did not converge within $maxRecursion levels '
      '(likely a cyclic binding); residue: "$residue"';

  @override
  String toString() => 'PlaceholderRecursionException: $message';
}

/// Raised when an unknown `${name}` / `${env:NAME}` is encountered while
/// the resolver runs in **strict** mode (§ 21.7; § 21.10).
///
/// In lenient mode the same situation renders an empty string instead, so
/// this exception only ever surfaces under strict resolution.
final class PlaceholderUnresolvedException implements Exception {
  /// Records an unresolved placeholder reference.
  const PlaceholderUnresolvedException(this.reference);

  /// The unresolved reference, as written inside the braces (e.g. `topic`
  /// for `${topic}`, or `env:HOME` for `${env:HOME}`).
  final String reference;

  /// The wire code carried by every unresolved-placeholder failure.
  String get code => placeholderUnresolvedCode;

  /// Human-readable explanation, reused by [toString].
  String get message => 'no binding for placeholder "$reference"';

  @override
  String toString() => 'PlaceholderUnresolvedException: $message';
}

/// Raised when a `${{ … }}` expression throws or fails to parse during
/// evaluation against the expression backing (§ 21.7; § 21.10), or when a
/// `${{ … }}` form is encountered by a resolver that has no expression
/// backing (e.g. the synchronous config-layer path).
///
/// Carries the offending [expression] and the underlying [cause] surfaced
/// by the evaluator, so the failure identifies both *which* expression
/// failed and *why*.
final class PlaceholderExpressionException implements Exception {
  /// Records a failed expression evaluation.
  const PlaceholderExpressionException({
    required this.expression,
    required this.cause,
  });

  /// The expression text between the `${{` and `}}` delimiters.
  final String expression;

  /// The error the evaluator raised (a parse error or a runtime throw), or
  /// the reason no evaluator was available.
  final Object cause;

  /// The wire code carried by every expression-evaluation failure.
  String get code => placeholderExpressionFailedCode;

  /// Human-readable explanation, reused by [toString].
  String get message =>
      'd4rt expression "$expression" failed to evaluate: $cause';

  @override
  String toString() => 'PlaceholderExpressionException: $message';
}
