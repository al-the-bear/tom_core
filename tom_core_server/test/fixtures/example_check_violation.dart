/// An example-shaped program whose expectation does not hold, so that the
/// package can prove what happens when one does not.
///
/// Every real example passes, which is the point of them and also the reason
/// none of them can answer the question this fixture exists for: whether a
/// violated expectation actually fails the run. A suite of green examples looks
/// exactly the same whether the checks inside them are load-bearing or inert —
/// that is precisely how the `assert`s this file's helper replaced survived for
/// as long as they did.
///
/// It imports the **shipped** helper rather than restating it, because a copy
/// would prove a copy works. Its `main` is `async` and the violation sits after
/// an `await` on purpose: every example is a `Future<void> main()`, so a throw
/// that did not survive the asynchronous gap would fail exactly the files that
/// matter while a synchronous fixture stayed green.
///
/// Lives under `test/` rather than `example/` because it is not something a
/// reader runs, and because the sweep in `examples_test.dart` requires that no
/// file under `example/` state an expectation that does not hold.
library;

import '../../example/_support/check.dart';

Future<void> main() async {
  print('1. before the violated expectation');
  await Future<void>.delayed(Duration.zero);
  check(false, 'the fixture violates this expectation deliberately');
  print('2. after the violated expectation');
}
