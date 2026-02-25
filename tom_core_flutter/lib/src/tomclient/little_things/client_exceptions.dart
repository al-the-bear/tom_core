import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomClientException extends TomException {
  TomClientException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

class TomClientUIException extends TomClientException {
  TomClientUIException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}
