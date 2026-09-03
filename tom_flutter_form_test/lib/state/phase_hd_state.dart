import 'package:tom_core_kernel/tom_core_kernel.dart';

// ---------------------------------------------------------------------------
// Phase H-D / H-E state — full customer record with addresses and orders
// ---------------------------------------------------------------------------
//
// Extends the Phase 2a vocabulary to include:
//   - A nested billing address (flat fields on CustomerHD to keep binding
//     simple — no nested TomForm required)
//   - A list of shipping addresses (ShippingAddressHD)
//   - A list of orders (OrderHD), each with a list of line items (OrderItemHD)
//
// All fields stay as TomString to maintain consistency with Phase 2a.
// The form layer (customer_hd_form.dart) applies validation at the
// appropriate point; numeric-looking strings (qty, price) are parsed
// there for computed totals.

@tomReflector
class ShippingAddressHD extends TomClass {
  /// Short human label used as list-row display and shipping selector key.
  late final label = TomString('');
  late final line1 = TomString('');
  late final line2 = TomString('');
  late final city = TomString('');
  late final stateRegion = TomString('');
  late final zipCode = TomString('');
  late final country = TomString('');
}

@tomReflector
class OrderItemHD extends TomClass {
  late final productName = TomString('');
  late final quantity = TomString('1');
  late final unitPrice = TomString('0.00');
  late final notes = TomString('');
}

@tomReflector
class OrderHD extends TomClass {
  late final orderId = TomString('');
  late final orderDate = TomString('');

  /// Label of the shipping address to use for this order.
  late final shippingLabel = TomString('');

  late final items = TomList<OrderItemHD>();
}

@tomReflector
class CustomerHD extends TomClass {
  // Direct contact fields
  late final fullName = TomString('');
  late final email = TomString('');
  late final phone = TomString('');

  // Billing address — flat fields so the main CustomerHDForm can bind
  // them directly without a nested sub-form.
  late final billLine1 = TomString('');
  late final billLine2 = TomString('');
  late final billCity = TomString('');
  late final billState = TomString('');
  late final billZip = TomString('');
  late final billCountry = TomString('');

  // Collections
  late final shippingAddresses = TomList<ShippingAddressHD>();
  late final orders = TomList<OrderHD>();
}

// ---------------------------------------------------------------------------
// Pre-populated singletons — one per demo so H-D and H-E are independent.
// ---------------------------------------------------------------------------

CustomerHD phaseHdCustomer = _initialCustomer();
CustomerHD phaseHeCustomer = _initialCustomer();

CustomerHD _initialCustomer() {
  final c = CustomerHD();
  c.fullName | 'Ada Lovelace';
  c.email | 'ada@analytical.example';
  c.phone | '+44 20 7946 0958';
  c.billLine1 | '1 Analytical Way';
  c.billLine2 | 'Suite 42';
  c.billCity | 'London';
  c.billState | 'England';
  c.billZip | 'EC1A 1BB';
  c.billCountry | 'United Kingdom';

  c.shippingAddresses.add(
    _addr(
      label: 'Main Office',
      line1: '1 Analytical Way',
      line2: 'Suite 42',
      city: 'London',
      stateRegion: 'England',
      zipCode: 'EC1A 1BB',
      country: 'United Kingdom',
    ),
  );
  c.shippingAddresses.add(
    _addr(
      label: 'Warehouse',
      line1: '7 Engine Works',
      line2: '',
      city: 'Manchester',
      stateRegion: 'England',
      zipCode: 'M1 2JL',
      country: 'United Kingdom',
    ),
  );

  c.orders.add(
    _order(
      orderId: 'ORD-1001',
      orderDate: '2026-01-15',
      shippingLabel: 'Main Office',
      items: [
        _item('Difference Engine pinion', '12', '34.50', 'Brass; lot #B-117'),
        _item('Punched-card deck (1000 pk)', '3', '49.00', 'Hollerith'),
        _item('Lubricating oil (1L)', '5', '6.75', ''),
      ],
    ),
  );
  c.orders.add(
    _order(
      orderId: 'ORD-1002',
      orderDate: '2026-02-28',
      shippingLabel: 'Warehouse',
      items: [
        _item('Bearing block', '4', '18.75', ''),
        _item('Mainspring assembly', '1', '58.50', 'Replacement unit'),
      ],
    ),
  );

  return c;
}

ShippingAddressHD _addr({
  required String label,
  required String line1,
  required String line2,
  required String city,
  required String stateRegion,
  required String zipCode,
  required String country,
}) {
  final a = ShippingAddressHD();
  a.label | label;
  a.line1 | line1;
  a.line2 | line2;
  a.city | city;
  a.stateRegion | stateRegion;
  a.zipCode | zipCode;
  a.country | country;
  return a;
}

OrderHD _order({
  required String orderId,
  required String orderDate,
  required String shippingLabel,
  required List<OrderItemHD> items,
}) {
  final o = OrderHD();
  o.orderId | orderId;
  o.orderDate | orderDate;
  o.shippingLabel | shippingLabel;
  for (final i in items) {
    o.items.add(i);
  }
  return o;
}

OrderItemHD _item(
  String productName,
  String quantity,
  String unitPrice,
  String notes,
) {
  final i = OrderItemHD();
  i.productName | productName;
  i.quantity | quantity;
  i.unitPrice | unitPrice;
  i.notes | notes;
  return i;
}
