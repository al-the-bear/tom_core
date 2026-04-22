import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Phase 2a state — Customer master-detail + Order with line items
// ---------------------------------------------------------------------------
//
// All fields are TomString because Phase 1+2 only ship string- and
// boolean-backed form fields. Numeric fields land in Phase 3, so for now
// quantity / unit price / total are kept as strings and parsed at display
// time. The point of these demos is the list / master-detail / table
// patterns, not numeric input — keeping every field a string also lets
// the demos compose nicely with the existing TomFormStringInput widget.

@tomReflector
class Customer extends TomClass {
  late final fullName = TomString('');
  late final email = TomString('');
  late final phone = TomString('');
  late final company = TomString('');
  late final tier = TomString('standard');
}

@tomReflector
class CustomerDirectory extends TomClass {
  late final customers = TomList<Customer>();
}

@tomReflector
class OrderItem extends TomClass {
  late final productName = TomString('');
  late final quantity = TomString('1');
  late final unitPrice = TomString('0.00');
  late final notes = TomString('');
}

@tomReflector
class Order extends TomClass {
  late final orderNumber = TomString('');
  late final customer = TomString('');
  late final items = TomList<OrderItem>();
}

// ---------------------------------------------------------------------------
// Pre-populated singletons so Phase 2a demos show real data on first open.
// ---------------------------------------------------------------------------

CustomerDirectory phase2aCustomers = _initialCustomers();
Order phase2aExpandableOrder = _initialExpandableOrder();
Order phase2aTableOrder = _initialTableOrder();

CustomerDirectory _initialCustomers() {
  final dir = CustomerDirectory();
  dir.customers.add(_customer(
    fullName: 'Ada Lovelace',
    email: 'ada@analytical.example',
    phone: '+44 20 7946 0958',
    company: 'Analytical Engines Ltd.',
    tier: 'gold',
  ));
  dir.customers.add(_customer(
    fullName: 'Grace Hopper',
    email: 'grace@navy.example',
    phone: '+1 202 555 0140',
    company: 'COBOL Systems Inc.',
    tier: 'platinum',
  ));
  dir.customers.add(_customer(
    fullName: 'Linus Torvalds',
    email: 'torvalds@kernel.example',
    phone: '+1 503 555 0177',
    company: 'Linux Foundation',
    tier: 'silver',
  ));
  return dir;
}

Customer _customer({
  required String fullName,
  required String email,
  required String phone,
  required String company,
  required String tier,
}) {
  final c = Customer();
  c.fullName | fullName;
  c.email | email;
  c.phone | phone;
  c.company | company;
  c.tier | tier;
  return c;
}

Order _initialExpandableOrder() {
  final o = Order();
  o.orderNumber | 'ORD-1042';
  o.customer | 'Analytical Engines Ltd.';
  o.items.add(_item('Difference Engine pinion', '12', '34.50',
      'Brass; lot #B-117'));
  o.items.add(_item('Punched-card deck (1000 pk)', '3', '49.00',
      'Standard Hollerith perforation'));
  o.items.add(_item('Lubricating oil (1L)', '5', '6.75', ''));
  return o;
}

Order _initialTableOrder() {
  final o = Order();
  o.orderNumber | 'ORD-2057';
  o.customer | 'Linux Foundation';
  o.items.add(_item('Patch review token', '4', '12.00', ''));
  o.items.add(_item('Maintainer T-shirt', '2', '24.50', 'XL'));
  o.items.add(_item('Conference badge', '6', '0.00', 'Sponsor pass'));
  return o;
}

OrderItem _item(String product, String qty, String price, String notes) {
  final i = OrderItem();
  i.productName | product;
  i.quantity | qty;
  i.unitPrice | price;
  i.notes | notes;
  return i;
}

// ---------------------------------------------------------------------------
// Product catalog — used by Demo H-B / H-C OrderItemForm so the product
// name field becomes a searchable picker that auto-fills the unit price
// when an entry is chosen. ~50 entries to make the search experience
// realistic.
// ---------------------------------------------------------------------------

class Phase2aProduct {
  final String name;
  final double price;
  const Phase2aProduct(this.name, this.price);
}

const List<Phase2aProduct> phase2aProductCatalog = [
  // Existing fixture data (kept stable so bound demos still parse cleanly).
  Phase2aProduct('Difference Engine pinion', 34.50),
  Phase2aProduct('Punched-card deck (1000 pk)', 49.00),
  Phase2aProduct('Lubricating oil (1L)', 6.75),
  Phase2aProduct('Patch review token', 12.00),
  Phase2aProduct('Maintainer T-shirt', 24.50),
  Phase2aProduct('Conference badge', 0.00),
  // Hardware
  Phase2aProduct('Brass gear (small)', 4.20),
  Phase2aProduct('Brass gear (medium)', 7.80),
  Phase2aProduct('Brass gear (large)', 13.40),
  Phase2aProduct('Crank handle', 22.00),
  Phase2aProduct('Mainspring assembly', 58.50),
  Phase2aProduct('Drive belt 12"', 9.95),
  Phase2aProduct('Drive belt 24"', 16.45),
  Phase2aProduct('Mounting bracket', 11.10),
  Phase2aProduct('Stainless screw set', 3.25),
  Phase2aProduct('Bearing block', 18.75),
  // Consumables
  Phase2aProduct('Ink ribbon (black)', 4.50),
  Phase2aProduct('Ink ribbon (red)', 4.80),
  Phase2aProduct('Wax seal sticks (10pk)', 7.20),
  Phase2aProduct('Punch tape roll (50m)', 14.00),
  Phase2aProduct('Carbon paper (100 sht)', 6.40),
  Phase2aProduct('Cleaning brush set', 5.10),
  Phase2aProduct('Polishing compound (250g)', 8.30),
  // Tools
  Phase2aProduct('Calipers (vernier)', 27.50),
  Phase2aProduct('Micrometer', 41.00),
  Phase2aProduct('Soldering iron 25W', 19.80),
  Phase2aProduct('Solder spool (lead-free)', 11.40),
  Phase2aProduct('Wire stripper', 8.90),
  Phase2aProduct('Precision screwdriver kit', 15.60),
  // Office
  Phase2aProduct('Logbook (leather)', 22.00),
  Phase2aProduct('Logbook (cloth)', 12.00),
  Phase2aProduct('Quill pen set', 9.40),
  Phase2aProduct('Drafting paper (A1, 50 sht)', 18.20),
  Phase2aProduct('Slide rule (10")', 31.00),
  Phase2aProduct('Reference manual', 14.95),
  // Software / services
  Phase2aProduct('Patch review token', 12.00),
  Phase2aProduct('Bug bounty voucher', 25.00),
  Phase2aProduct('Annual support contract', 480.00),
  Phase2aProduct('On-site training day', 1450.00),
  Phase2aProduct('Code audit (per kLOC)', 320.00),
  // Apparel & swag
  Phase2aProduct('Maintainer T-shirt', 24.50),
  Phase2aProduct('Project hoodie', 48.00),
  Phase2aProduct('Sticker pack', 4.00),
  Phase2aProduct('Enamel pin set', 9.50),
  Phase2aProduct('Coffee mug (project logo)', 11.00),
  // Misc
  Phase2aProduct('Conference badge', 0.00),
  Phase2aProduct('Sponsor pass upgrade', 75.00),
  Phase2aProduct('Demo unit (loaner)', 0.00),
  Phase2aProduct('Shipping (standard)', 12.00),
  Phase2aProduct('Shipping (expedited)', 38.00),
  Phase2aProduct('Restocking fee', -25.00),
];

/// Look up a catalog price by exact name. Returns `null` if the name
/// isn't in the catalog (e.g. a free-form entry the user typed).
double? phase2aLookupProductPrice(String name) {
  for (final p in phase2aProductCatalog) {
    if (p.name == name) return p.price;
  }
  return null;
}

/// Build a `TomSelectableSource<String>` over the catalog. The label
/// embeds the price so users see both columns in the search dropdown.
TomSelectableSource<String> phase2aProductSource() {
  // Deduplicate names so the search list stays clean even if the
  // catalog has overlapping entries.
  final seen = <String>{};
  final items = <SelectableItem<String>>[];
  for (final p in phase2aProductCatalog) {
    if (!seen.add(p.name)) continue;
    items.add(SelectableItem<String>(
      value: p.name,
      label: '${p.name}  —  \$${p.price.toStringAsFixed(2)}',
    ));
  }
  return StaticSelectableSource<String>(items);
}
