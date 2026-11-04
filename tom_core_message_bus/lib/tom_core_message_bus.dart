/// A broker-neutral message bus for Tom services: the [TomMessageBus]
/// contract, typed payloads ([TomBusCodec]), the trace across the bus
/// ([TomBusTrace]) and the in-memory bus ([TomMemoryMessageBus]).
///
/// The conformance suite every bus passes is
/// `package:tom_core_message_bus/conformance.dart`.
library;

// not-exported: conformance.dart — it imports package:test, which an
// application importing the bus must not load; adapters import it in tests.

export 'src/bus.dart';
export 'src/codec.dart';
export 'src/memory_bus.dart';
export 'src/message.dart';
export 'src/trace.dart';
