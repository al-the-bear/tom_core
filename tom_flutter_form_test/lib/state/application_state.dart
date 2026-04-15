import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'company_state.dart';

// ---------------------------------------------------------------------------
// Application State
// ---------------------------------------------------------------------------

@tomReflector
class ApplicationState extends TomClass {
  late final companyProfile = CompanyProfile();
}

/// Global singleton — all demos bind their forms to this instance.
ApplicationState demoState = _createDemoState();

ApplicationState _createDemoState() {
  final s = ApplicationState();

  // Basic info (used by Demo 1, 3, 4)
  s.companyProfile.name | 'Acme Corporation';
  s.companyProfile.industry | 'tech';
  s.companyProfile.taxId | 'US-12345-ABC';
  s.companyProfile.website | 'https://acme.example.com';

  // Headquarters address (used by Demo 2)
  s.companyProfile.headquarters.street | '123 Main St';
  s.companyProfile.headquarters.city | 'San Francisco';
  s.companyProfile.headquarters.state | 'CA';
  s.companyProfile.headquarters.zipCode | '94102';
  s.companyProfile.headquarters.country | 'US';

  // CEO info (used by Demo 2)
  s.companyProfile.ceo.firstName | 'Jane';
  s.companyProfile.ceo.lastName | 'Doe';
  s.companyProfile.ceo.email | 'jane.doe@acme.example.com';
  s.companyProfile.ceo.title | 'Chief Executive Officer';

  return s;
}
