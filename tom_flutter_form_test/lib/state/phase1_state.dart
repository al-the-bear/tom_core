import 'package:tom_core_kernel/tom_core_kernel.dart';

// ---------------------------------------------------------------------------
// Phase 1 State — backing data for demos A, B, C
// ---------------------------------------------------------------------------

/// Backing state for the validation demo (Demo A). Fields match the
/// [ValidationForm] field IDs so `form.bind(state)` round-trips cleanly.
@tomReflector
class ValidationProfile extends TomClass {
  late final username = TomString('');
  late final email = TomString('');
  late final password = TomString('');
  late final confirmPassword = TomString('');
  late final website = TomString('');
}

/// Shipping / billing address payload reused by [CustomerProfile].
@tomReflector
class PostalAddress extends TomClass {
  late final street = TomString('');
  late final city = TomString('');
  late final state = TomString('');
  late final zipCode = TomString('');
  late final country = TomString('US');
}

/// Root state for the nested-form demo (Demo C) and the authorization demo
/// (Demo B). `billing` and `shipping` follow the naming convention — form
/// tree matches state tree.
@tomReflector
class CustomerProfile extends TomClass {
  late final fullName = TomString('');
  late final email = TomString('');
  late final phone = TomString('');
  late final customerTier = TomString('standard');
  late final notes = TomString('');
  late final billing = PostalAddress();
  late final shipping = PostalAddress();
}

// ---------------------------------------------------------------------------
// Pre-populated singletons — so the demos show data on first open.
// ---------------------------------------------------------------------------

ValidationProfile phase1ValidationState = _buildValidationState();
CustomerProfile phase1CustomerState = _buildCustomerState();

ValidationProfile _buildValidationState() {
  final s = ValidationProfile();
  s.username | 'janedoe';
  s.email | 'jane.doe@example.com';
  s.password | '';
  s.confirmPassword | '';
  s.website | 'https://example.com';
  return s;
}

CustomerProfile _buildCustomerState() {
  final s = CustomerProfile();
  s.fullName | 'Jane Doe';
  s.email | 'jane.doe@example.com';
  s.phone | '+1 555 0100';
  s.customerTier | 'gold';
  s.notes | 'VIP — priority shipping';

  s.billing.street | '100 Market Street';
  s.billing.city | 'San Francisco';
  s.billing.state | 'CA';
  s.billing.zipCode | '94103';
  s.billing.country | 'US';

  s.shipping.street | '250 Broadway';
  s.shipping.city | 'New York';
  s.shipping.state | 'NY';
  s.shipping.zipCode | '10007';
  s.shipping.country | 'US';
  return s;
}
