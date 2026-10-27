/// Static resource map used by the Examples section.
///
/// The Demos section already loads `assets/demo_resources.json` and installs
/// it as the global [TomTextResourceProvider] in `main()`. We merge this map
/// into that provider at startup so every example can resolve its keys
/// without polluting the demo namespace.
///
/// Every example key carries an `example` prefix — `exampleCustomer`,
/// `exampleOrder` — so it cannot collide with a demo resource. The prefix is
/// part of the top-level segment rather than a level above it because these
/// segments are form ids, and a form id is used directly as a scope id: a
/// scope id may not contain the '.' that scope paths are joined with, or an
/// id read from data could forge a path into another scope's resources. The
/// forms in `examples/forms/` spell the same names.
const Map<String, dynamic> exampleResourceMap = <String, dynamic>{
  'exampleCommon': {
    'save': 'Save',
    'discard': 'Discard',
    'add': 'Add',
    'remove': 'Remove',
    'edit': 'Edit',
    'close': 'Close',
  },
  'exampleCustomer': {
    'panel': {'title': 'Customers'},
    'fullName': {'label': 'Full name'},
    'email': {'label': 'Email'},
    'phone': {'label': 'Phone'},
    'company': {'label': 'Company'},
    'tier': {'label': 'Tier'},
    'vip': {'label': 'VIP customer'},
    'loyaltyPoints': {'label': 'Loyalty points'},
    'creditLimit': {'label': 'Credit limit'},
    'memberSince': {'label': 'Member since'},
  },
  'exampleAddress': {
    'panel': {'title': 'Addresses'},
    'label': {'label': 'Label'},
    'line1': {'label': 'Address line 1'},
    'city': {'label': 'City'},
    'country': {'label': 'Country'},
  },
  'exampleOrder': {
    'panel': {'title': 'Orders'},
    'orderId': {'label': 'Order ID'},
    'orderDate': {'label': 'Order date'},
    'priority': {'label': 'Priority'},
    'paid': {'label': 'Paid'},
  },
  'exampleOrderItem': {
    'panel': {'title': 'Items'},
    'productName': {'label': 'Product'},
    'quantity': {'label': 'Qty'},
    'unitPrice': {'label': 'Unit price'},
    'notes': {'label': 'Notes'},
  },
};
