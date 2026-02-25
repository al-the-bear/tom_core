import 'dart:isolate';

import 'package:tom_core_server/src/tomserver/server/server.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

class TomServerException extends TomException {

  String isolateName = Isolate.current.debugName ?? "unnamed isolate";
  bool clientThrow;

  TomServerException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    this.clientThrow = true,
  }) {
    TomRequestId? requestId = getFromCurrentZone<TomRequestId>();
    if( requestId != null ) {
      requestUuid = requestId.uuid;
    }
  }

  @override
  String toString() => "${super.toString()} $isolateName client-throw: $clientThrow $requestUuid";
}
