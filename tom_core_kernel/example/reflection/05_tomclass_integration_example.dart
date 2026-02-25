/// TomClass Integration Example
///
/// This example demonstrates how the reflection system integrates with
/// TomClass observable objects for reactive data binding.
library;

import 'dart:convert' show jsonEncode;
import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Model Classes (TomClass-based)
// ============================================================================

/// A person using TomClass for observable properties.
///
/// TomClass fields are automatically registered and can be
/// set/get via reflection with automatic observer notifications.
@tomReflector
class ObservablePerson extends TomClass {
  TomString name = TomString('');
  TomInt age = TomInt(0);
  TomString email = TomString('');
  TomBool isActive = TomBool(true);
}

/// An address using TomClass.
@tomReflector
class ObservableAddress extends TomClass {
  TomString street = TomString('');
  TomString city = TomString('');
  TomString zipCode = TomString('');
}

/// A customer with nested TomClass.
@tomReflector
class ObservableCustomer extends TomClass {
  TomString customerId = TomString('');
  TomString name = TomString('');
  ObservableAddress address = ObservableAddress();
}

/// An item for order examples.
@tomReflector
class ObservableItem extends TomClass {
  TomString productId = TomString('');
  TomString name = TomString('');
  TomInt quantity = TomInt(0);
  TomDouble price = TomDouble(0.0);
}

/// An order with a list of observable items.
@tomReflector
class ObservableOrder extends TomClass {
  TomString orderId = TomString('');
  TomString status = TomString('pending');
  TomList<ObservableItem> items = TomList();
  TomDouble total = TomDouble(0.0);
}

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 05: TomClass Integration Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Creating and populating TomClass
  // -------------------------------------------------------------------------
  print('1. Creating and populating TomClass:');
  
  final person = ObservablePerson();
  
  // setValues on TomClass automatically uses TomClass.setValues()
  tomReflectionInfo.setValues(person, {
    'name': 'John Doe',
    'age': 30,
    'email': 'john@example.com',
    'isActive': true,
  });
  
  // Access values using ~ operator
  print('   Name: ${~person.name}');
  print('   Age: ${~person.age}');
  print('   Email: ${~person.email}');
  print('   Active: ${~person.isActive}\n');

  // -------------------------------------------------------------------------
  // Example 2: Observing changes
  // -------------------------------------------------------------------------
  print('2. Observing changes:');
  
  int notifyCount = 0;
  person >> (obs) {
    notifyCount++;
    print('   [Observer] Person changed! (notification #$notifyCount)');
  };
  
  // Changes via setValues trigger observers
  tomReflectionInfo.setValues(person, {
    'name': 'John Smith',  // This triggers the observer
  });
  
  print('   Updated name: ${~person.name}');
  print('   Total notifications: $notifyCount\n');

  // -------------------------------------------------------------------------
  // Example 3: Serializing TomClass to JSON
  // -------------------------------------------------------------------------
  print('3. Serializing TomClass to JSON:');
  
  // getValues on TomClass automatically uses TomClass.toJson()
  final personJson = tomReflectionInfo.getValues(person);
  print('   JSON Map: $personJson');
  
  final personJsonString = tomReflectionInfo.convertToJsonString(person);
  print('   JSON String: $personJsonString\n');

  // -------------------------------------------------------------------------
  // Example 4: Nested TomClass
  // -------------------------------------------------------------------------
  print('4. Nested TomClass:');
  
  final customer = ObservableCustomer();
  tomReflectionInfo.setValues(customer, {
    'customerId': 'CUST-001',
    'name': 'Acme Corp',
    'address': {
      'street': '123 Main St',
      'city': 'New York',
      'zipCode': '10001',
    },
  });
  
  print('   Customer: ${~customer.name} (${~customer.customerId})');
  print('   Address: ${~customer.address.street}');
  print('   City: ${~customer.address.city}, ${~customer.address.zipCode}\n');

  // -------------------------------------------------------------------------
  // Example 5: Observing nested changes
  // -------------------------------------------------------------------------
  print('5. Observing nested changes:');
  
  int customerNotifyCount = 0;
  customer >> (obs) {
    customerNotifyCount++;
    print('   [Observer] Customer changed! (#$customerNotifyCount)');
  };
  
  // Changing nested address triggers customer observer
  customer.address.city | 'Los Angeles';
  print('   Updated city: ${~customer.address.city}');
  print('   Customer notifications: $customerNotifyCount\n');

  // -------------------------------------------------------------------------
  // Example 6: TomList with TomClass elements
  // -------------------------------------------------------------------------
  print('6. TomList with TomClass elements:');
  
  final order = ObservableOrder();
  
  // Add items manually first
  final item1 = ObservableItem();
  item1.productId | 'PROD-001';
  item1.name | 'Widget';
  item1.quantity | 2;
  item1.price | 29.99;
  order.items.add(item1);
  
  final item2 = ObservableItem();
  item2.productId | 'PROD-002';
  item2.name | 'Gadget';
  item2.quantity | 1;
  item2.price | 49.99;
  order.items.add(item2);
  
  order.orderId | 'ORD-001';
  order.status | 'confirmed';
  order.total | 109.97;
  
  print('   Order: ${~order.orderId}');
  print('   Status: ${~order.status}');
  print('   Items: ${order.items.length}');
  for (var item in order.items) {
    print('   - ${~item.name}: ${~item.quantity} x \$${~item.price}');
  }
  print('   Total: \$${~order.total}\n');

  // -------------------------------------------------------------------------
  // Example 7: Mute/unmute during batch updates
  // -------------------------------------------------------------------------
  print('7. Mute/unmute during batch updates:');
  
  int orderNotifyCount = 0;
  order >> (obs) {
    orderNotifyCount++;
  };
  
  print('   Making 3 changes without mute...');
  order.status | 'processing';
  order.total | 115.97;
  (order.items[0]).quantity | 3;
  print('   Notifications without mute: $orderNotifyCount');
  
  orderNotifyCount = 0;
  print('   Making 3 changes with mute...');
  order.mute();
  order.status | 'shipped';
  order.total | 125.97;
  (order.items[0]).quantity | 4;
  order.unmute();
  print('   Notifications with mute: $orderNotifyCount (consolidated)\n');

  // -------------------------------------------------------------------------
  // Example 8: Round-trip serialization
  // -------------------------------------------------------------------------
  print('8. Round-trip serialization:');
  
  // For TomClass, use the built-in toJson/fromJson methods directly
  // The reflection system's convertToJsonString doesn't work with nested TomClass
  // because TomClass has its own serialization mechanism
  final customerJsonMap = customer.toJson();
  final customerJsonString = jsonEncode(customerJsonMap);
  print('   Serialized (via toJson): $customerJsonString');
  
  final customer2 = ObservableCustomer();
  customer2.fromJson(customerJsonString);
  print('   Restored name: ${~customer2.name}');
  print('   Restored city: ${~customer2.address.city}\n');

  print('=== TomClass Integration Example Complete ===\n');
}
