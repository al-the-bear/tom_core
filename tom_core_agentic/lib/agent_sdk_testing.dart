/// Test support for suites that drive the Agent SDK transports with no model
/// behind them: a fake CLI server that speaks the wire, the spawnable fixture
/// scripts a standalone transport can start, the deadlines a spawning test
/// bounds itself with, and a Node for the live suites.
///
/// A separate entry point, as `tom_github_api`'s `testing.dart` is: a product
/// build has no reason to link it.
library;

export 'src/testing/fake_ai_server.dart' hide main;
export 'src/testing/fixture_scripts.dart';
export 'src/testing/node_runtime.dart';
export 'src/testing/spawn_timings.dart';
