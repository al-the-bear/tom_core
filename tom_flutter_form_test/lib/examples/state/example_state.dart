import 'package:tom_core_kernel/tom_core_kernel.dart';

// ---------------------------------------------------------------------------
// Rich state for the Examples section.
//
// Picked to cover most of the field families the form layer ships:
//   * String (TomString)              — text, search, dropdown
//   * Int    (TomInt)                 — int input / slider / stepper
//   * Double (TomDouble)              — currency, percent, decimal
//   * Bool   (TomBool)                — switch / checkbox / toggle
//   * Date   (TomDateTime)            — date picker / inline calendar
//   * Nullable string (TomNString)    — optional notes
//   * Lists  (TomList)                — addresses, orders, items
//
// Reused across H-D (full editor) and H-E (read-only with edit dialogs).
// H-A / H-B / H-C continue to use the simpler Phase 2a `Customer` and
// `Order` state — those examples focus on layout/master-detail patterns
// rather than the full field-type spread.
// ---------------------------------------------------------------------------

@tomReflector
class ExampleAddress extends TomClass {
  late final label = TomString('');
  late final line1 = TomString('');
  late final city = TomString('');
  late final country = TomString('');
}

@tomReflector
class ExampleOrderItem extends TomClass {
  late final productName = TomString('');
  late final quantity = TomInt(1);
  late final unitPrice = TomDouble(0);
  late final notes = TomNString(null);
}

@tomReflector
class ExampleOrder extends TomClass {
  late final orderId = TomString('');
  late final orderDate = TomDateTime(DateTime(2026, 1, 1));

  /// Selectable string — `standard` / `priority` / `overnight`.
  late final priority = TomString('standard');

  late final paid = TomBool(false);
  late final items = TomList<ExampleOrderItem>();
}

@tomReflector
class ExampleCustomerRich extends TomClass {
  // Strings
  late final fullName = TomString('');
  late final email = TomString('');
  late final phone = TomString('');
  late final company = TomString('');

  // Selectable string — `standard` / `silver` / `gold` / `platinum`.
  late final tier = TomString('standard');

  // Bool
  late final vip = TomBool(false);

  // Int
  late final loyaltyPoints = TomInt(0);

  // Double
  late final creditLimit = TomDouble(0);

  // Date
  late final memberSince = TomDateTime(DateTime(2026, 1, 1));

  // Nested lists
  late final addresses = TomList<ExampleAddress>();
  late final orders = TomList<ExampleOrder>();
}

@tomReflector
class ExampleCustomerDirectory extends TomClass {
  late final customers = TomList<ExampleCustomerRich>();
}

// ---------------------------------------------------------------------------
// Pre-populated singleton — one per example screen so H-D and H-E stay
// independent (each gets its own root reference).
// ---------------------------------------------------------------------------

final ExampleCustomerRich exampleCustomerHd = _seedRichCustomer();
final ExampleCustomerRich exampleCustomerHe = _seedRichCustomer();

/// Used by Example H-B (expandable rows over orders) and H-C
/// (editable items table) — each binds to its own customer so
/// edits stay isolated between examples.
final ExampleCustomerRich exampleCustomerHb = _seedRichCustomer();
final ExampleCustomerRich exampleCustomerHc = _seedRichCustomer();

ExampleCustomerRich _seedRichCustomer() {
  final c = ExampleCustomerRich();
  c.fullName | 'Ada Lovelace';
  c.email | 'ada@example.com';
  c.phone | '+44 20 7946 0958';
  c.company | 'Analytical Engines Ltd.';
  c.tier | 'gold';
  c.vip | true;
  c.loyaltyPoints | 4250;
  c.creditLimit | 25000.00;
  c.memberSince | DateTime(2024, 6, 1);

  c.addresses.add(_addr('Main Office', '1 Analytical Way', 'London', 'UK'));
  c.addresses.add(_addr('Warehouse', '7 Engine Works', 'Manchester', 'UK'));

  c.orders.add(_order('ORD-1001', DateTime(2026, 1, 15), 'priority', true, [
    _item('Difference Engine pinion', 12, 34.50, 'Brass; lot #B-117'),
    _item('Punched-card deck (1000 pk)', 3, 49.00, null),
  ]));
  c.orders.add(_order('ORD-1002', DateTime(2026, 2, 28), 'standard', false, [
    _item('Bearing block', 4, 18.75, null),
    _item('Mainspring assembly', 1, 58.50, 'Replacement unit'),
  ]));
  return c;
}

ExampleAddress _addr(String label, String line1, String city, String country) {
  final a = ExampleAddress();
  a.label | label;
  a.line1 | line1;
  a.city | city;
  a.country | country;
  return a;
}

ExampleOrder _order(
  String id,
  DateTime date,
  String priority,
  bool paid,
  List<ExampleOrderItem> items,
) {
  final o = ExampleOrder();
  o.orderId | id;
  o.orderDate | date;
  o.priority | priority;
  o.paid | paid;
  for (final i in items) {
    o.items.add(i);
  }
  return o;
}

ExampleOrderItem _item(
    String productName, int quantity, double unitPrice, String? notes) {
  final i = ExampleOrderItem();
  i.productName | productName;
  i.quantity | quantity;
  i.unitPrice | unitPrice;
  i.notes | notes;
  return i;
}
