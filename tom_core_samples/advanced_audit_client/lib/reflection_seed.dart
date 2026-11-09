/// The reflection root of the audit application: the wire DTOs it decodes —
/// the audit-report answers and questions of the kernel's contract, and the
/// sample's login shapes — so the build generates their mirrors into
/// `reflection_seed.reflection.dart`. Regenerate with
/// `./reflection_generation.sh` when a reflected shape changes.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

export 'reflection_seed.reflection.dart';

@tomReflector
// ignore: unused_element
class _ContractDtoAnchor {
  TomAuditReportQueryRequest? queryRequest;
  TomAuditReportResultDto? result;
  TomAuditReportEntryDto? entry;
  TomAuditQuestionDto? question;
  TomAuditQuestionIdRequest? questionId;
  LoginRequest? loginRequest;
  LoginResult? loginResult;
}

/// Generator root; its body is empty by contract.
void main() {}
