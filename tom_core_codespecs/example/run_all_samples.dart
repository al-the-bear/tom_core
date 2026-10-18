// Runs every example in this folder, in one process, in order.
//
// The package is dependency-free and its gap classes are plain data holders,
// so there is nothing to bootstrap: no reflection registry, no platform
// identity, no service locator. This runner is therefore what it looks like —
// eight `main()` calls in sequence — and that plainness is itself a property
// of the package worth seeing.
//
// Run with:
//   dart run --enable-asserts example/run_all_samples.dart
//
// `--enable-asserts` is required, not cosmetic. Every example states its
// expected outcome with `assert` and nothing else; without the flag each one
// executes every line, prints the same transcript, exits 0 and checks nothing.
// `require_asserts.dart` refuses that run rather than letting it look like a
// pass — and each example calls it first, so this runner inherits the refusal
// from whichever example happens to run first.

import 'client_application_example.dart' as client_application;
import 'job_declaration_example.dart' as job_declaration;
import 'layout_node_example.dart' as layout_node;
import 'message_key_example.dart' as message_key;
import 'notification_model_example.dart' as notification_model;
import 'operation_binding_example.dart' as operation_binding;
import 'report_model_example.dart' as report_model;
import 'route_flow_example.dart' as route_flow;

/// One entry per gap-class file under `lib/src/`, in the same order.
///
/// The pairing is deliberate and is checked: `test/examples_test.dart` holds
/// this folder to one example per gap-class file, so a gap class added without
/// an example — or an example left behind by a gap class that was removed —
/// fails rather than going unnoticed.
final _examples = <String, Future<void> Function()>{
  'client_application': () async => client_application.main(),
  'job_declaration': () async => job_declaration.main(),
  'layout_node': () async => layout_node.main(),
  'message_key': () async => message_key.main(),
  'notification_model': () async => notification_model.main(),
  'operation_binding': () async => operation_binding.main(),
  'report_model': () async => report_model.main(),
  'route_flow': () async => route_flow.main(),
};

Future<void> main() async {
  for (final entry in _examples.entries) {
    await entry.value();
    print('');
  }
  print('all ${_examples.length} tom_core_codespecs examples completed.');
}
