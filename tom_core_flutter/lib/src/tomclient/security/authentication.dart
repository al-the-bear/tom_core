import 'package:tom_core_kernel/tom_core_kernel.dart';

// Annotation to mark classes as 2FA adaptors for the client side.
@tomReflector
class TomClient2FAAdaptor {
  final String type;
  const TomClient2FAAdaptor(this.type);
}
