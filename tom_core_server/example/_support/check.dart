/// The check that every `tom_core_server` example states its expectations
/// through.
///
/// One definition for all of them, because the reason it exists is subtle
/// enough to be worth stating once and keeping true. A per-example copy would
/// carry a copy of that reasoning with it, which is the shape most certain to
/// drift: a reader who improves the explanation in one copy has no way of
/// knowing the others exist.
library;

/// Throws unless [ok] holds, naming the [expectation] that failed.
///
/// **Deliberately not `assert`.** `dart run` leaves assertions *disabled* —
/// that is what its `--enable-asserts` flag is for — so an `assert` in an
/// example compiles out under the very command the example's own header tells
/// a reader to use. An example whose checks vanish under its documented
/// invocation is worse than one with no checks at all: it still prints a
/// plausible transcript and still exits 0 while every expectation in it is
/// violated, so it reads as a verification to everyone including the author.
/// That is not a hypothetical and it is not left as prose: `test/fixtures/`
/// holds two programs identical but for that one line, and
/// `test/examples_test.dart` runs both under the documented command. The one
/// stating its expectation this way exits non-zero and stops; the one stating
/// it as an `assert` exits **0** and runs to the end.
///
/// A plain `if`/`throw` holds however the file is run.
///
/// [expectation] names what was supposed to be true, not what was computed —
/// it is the whole message a reader gets when an example breaks, and a
/// condition echoed back as text ("x == 3") tells them nothing the stack trace
/// does not already say.
void check(bool ok, String expectation) {
  if (!ok) throw StateError('example check failed: $expectation');
}
