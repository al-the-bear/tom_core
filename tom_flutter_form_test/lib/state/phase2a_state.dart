import 'package:tom_core_kernel/tom_core_kernel.dart';

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
