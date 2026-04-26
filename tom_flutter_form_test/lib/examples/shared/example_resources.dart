/// Static resource map used by the Examples section.
///
/// The Demos section already loads `assets/demo_resources.json` and installs
/// it as the global [TomTextResourceProvider] in `main()`. We merge this map
/// into that provider at startup so every example can resolve its keys
/// without polluting the demo namespace.
///
/// All example keys are nested under `example.*` so they cannot collide with
/// existing demo resources.
const Map<String, dynamic> exampleResourceMap = <String, dynamic>{
  'example': {
    'common': {
      'save': 'Save',
      'discard': 'Discard',
      'add': 'Add',
      'remove': 'Remove',
      'edit': 'Edit',
      'close': 'Close',
    },
    'customer': {
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
    'address': {
      'panel': {'title': 'Addresses'},
      'label': {'label': 'Label'},
      'line1': {'label': 'Address line 1'},
      'city': {'label': 'City'},
      'country': {'label': 'Country'},
    },
    'order': {
      'panel': {'title': 'Orders'},
      'orderId': {'label': 'Order ID'},
      'orderDate': {'label': 'Order date'},
      'priority': {'label': 'Priority'},
      'paid': {'label': 'Paid'},
    },
    'orderItem': {
      'panel': {'title': 'Items'},
      'productName': {'label': 'Product'},
      'quantity': {'label': 'Qty'},
      'unitPrice': {'label': 'Unit price'},
      'notes': {'label': 'Notes'},
    },
  },
};
