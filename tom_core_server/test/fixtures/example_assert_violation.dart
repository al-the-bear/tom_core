/// The same program as `example_check_violation.dart`, stating the same
/// violated expectation as an `assert`.
///
/// It is the control the other fixture is measured against, and the evidence
/// for the claim `example/_support/check.dart` makes in prose: that `dart run`
/// leaves assertions disabled, so an example that states its expectations this
/// way exits 0 with every one of them violated. Nothing else in the package
/// checks that claim, and a reason nobody verifies is how the defect it
/// describes got in.
///
/// Held deliberately identical to its sibling apart from the one line that
/// differs. The pair only means anything if the *only* difference between an
/// exit code of 0 and a failing run is `assert` versus `check`.
library;

Future<void> main() async {
  print('1. before the violated expectation');
  await Future<void>.delayed(Duration.zero);
  assert(false, 'the fixture violates this expectation deliberately');
  print('2. after the violated expectation');
}
