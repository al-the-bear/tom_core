import 'package:flutter_test/flutter_test.dart';

import '../example/security/security_example.dart' as example;

/// Runs the security module's shipped example.
///
/// The module's own types are covered by `two_factor_client_test.dart`,
/// `two_factor_flow_test.dart`, `two_factor_texts_test.dart` and
/// `qr_code_view_test.dart`, each of which drives the widgets through a
/// `WidgetTester`. What none of them can cover is the example itself, and that
/// is what this file is for.
void main() {
  group('the shipped example runs', () {
    test('security_example.run() completes its assertions', () async {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      //
      // Awaited rather than fired and forgotten: the example walks a
      // controller through the flow, and every move it makes is a `Future`.
      // Dropping the await would let this test pass before a single assertion
      // downstream of the first move had been evaluated.
      await example.run();
    });
  });
}
