/// TomClass Integration Example
///
/// This example demonstrates how the reflection system integrates with
/// TomClass observable objects for reactive data binding.
///
/// Key concepts:
/// - TomClass with TomString, TomInt, TomDouble, TomBool fields
/// - Reflection on observable properties
/// - Nested TomClass objects
/// - Observer notifications with reflection updates
/// - Serialization of TomClass objects
library;

import 'dart:convert' show jsonEncode;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

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
// Example Class
// ============================================================================

class TomClassIntegrationExample {
  // Captured results
  static late ObservablePerson person;
  static late ObservableCustomer customer;
  static late ObservableOrder order;
  static int personNotifyCount = 0;
  static int customerNotifyCount = 0;
  static int orderNotifyCount = 0;

  // -------------------------------------------------------------------------
  // Example 1: Creating and populating TomClass
  // -------------------------------------------------------------------------
  static void example1CreateAndPopulate() {
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
    print('   Active: ${~person.isActive}');

    TomClassIntegrationExample.person = person;

    // Assertions
    assert(~person.name == 'John Doe', 'Name should match');
    assert(~person.age == 30, 'Age should be 30');
    assert(~person.email == 'john@example.com', 'Email should match');
    assert(~person.isActive == true, 'Should be active');
  }

  // -------------------------------------------------------------------------
  // Example 2: Observing changes
  // -------------------------------------------------------------------------
  static void example2ObservingChanges() {
    print('\n2. Observing changes:');

    personNotifyCount = 0;
    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final personObserver =
        person >>
        (obs) {
          personNotifyCount++;
          print(
            '   [Observer] Person changed! (notification #$personNotifyCount)',
          );
        };

    // Changes via setValues trigger observers
    tomReflectionInfo.setValues(person, {
      'name': 'John Smith', // This triggers the observer
    });

    print('   Updated name: ${~person.name}');
    print('   Total notifications: $personNotifyCount');

    // Assertions
    assert(~person.name == 'John Smith', 'Name should be updated');
    assert(personNotifyCount >= 1, 'Should have at least 1 notification');

    person.removeObserver(personObserver);
  }

  // -------------------------------------------------------------------------
  // Example 3: Serializing TomClass to JSON
  // -------------------------------------------------------------------------
  static void example3SerializingToJson() {
    print('\n3. Serializing TomClass to JSON:');

    // getValues on TomClass automatically uses TomClass.toJson()
    final personJson = tomReflectionInfo.getValues(person);
    print('   JSON Map: $personJson');

    final personJsonString = tomReflectionInfo.convertToJsonString(person);
    print('   JSON String: $personJsonString');

    // Assertions
    assert(personJson['name'] == 'John Smith', 'Name in JSON should match');
    assert(personJson['age'] == 30, 'Age in JSON should match');
  }

  // -------------------------------------------------------------------------
  // Example 4: Nested TomClass
  // -------------------------------------------------------------------------
  static void example4NestedTomClass() {
    print('\n4. Nested TomClass:');

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
    print('   City: ${~customer.address.city}, ${~customer.address.zipCode}');

    TomClassIntegrationExample.customer = customer;

    // Assertions
    assert(~customer.customerId == 'CUST-001', 'Customer ID should match');
    assert(~customer.address.city == 'New York', 'City should match');
  }

  // -------------------------------------------------------------------------
  // Example 5: Observing nested changes
  // -------------------------------------------------------------------------
  static void example5ObservingNestedChanges() {
    print('\n5. Observing nested changes:');

    customerNotifyCount = 0;
    final customerObserver =
        customer >>
        (obs) {
          customerNotifyCount++;
          print('   [Observer] Customer changed! (#$customerNotifyCount)');
        };

    // Changing nested address triggers customer observer
    customer.address.city | 'Los Angeles';
    print('   Updated city: ${~customer.address.city}');
    print('   Customer notifications: $customerNotifyCount');

    // Assertions
    assert(~customer.address.city == 'Los Angeles', 'City should be updated');
    assert(
      customerNotifyCount >= 1,
      'Should have notifications for nested changes',
    );

    customer.removeObserver(customerObserver);
  }

  // -------------------------------------------------------------------------
  // Example 6: TomList with TomClass elements
  // -------------------------------------------------------------------------
  static void example6TomListWithElements() {
    print('\n6. TomList with TomClass elements:');

    final order = ObservableOrder();

    // Add items manually first
    final item1 = ObservableItem();
    item1.productId | 'PROD-001';
    item1.name | 'Widget';
    item1.quantity | 2;
    item1.price | 29.99;
    order.items.append(item1);

    final item2 = ObservableItem();
    item2.productId | 'PROD-002';
    item2.name | 'Gadget';
    item2.quantity | 1;
    item2.price | 49.99;
    order.items.append(item2);

    order.orderId | 'ORD-001';
    order.status | 'confirmed';
    order.total | 109.97;

    print('   Order: ${~order.orderId}');
    print('   Status: ${~order.status}');
    print('   Items: ${order.items.length}');
    for (var item in order.items) {
      print('   - ${~item.name}: ${~item.quantity} x \$${~item.price}');
    }
    print('   Total: \$${~order.total}');

    TomClassIntegrationExample.order = order;

    // Assertions
    assert(~order.orderId == 'ORD-001', 'Order ID should match');
    assert(order.items.length == 2, 'Should have 2 items');
    assert(~order.items[0].name == 'Widget', 'First item name should match');
  }

  // -------------------------------------------------------------------------
  // Example 7: Mute/unmute during batch updates
  // -------------------------------------------------------------------------
  static void example7MuteUnmute() {
    print('\n7. Mute/unmute during batch updates:');

    orderNotifyCount = 0;
    final orderObserver =
        order >>
        (obs) {
          orderNotifyCount++;
        };

    print('   Making 3 changes without mute...');
    final beforeMuteCount = orderNotifyCount;
    order.status | 'processing';
    order.total | 115.97;
    (order.items[0]).quantity | 3;
    final withoutMuteNotifications = orderNotifyCount - beforeMuteCount;
    print('   Notifications without mute: $withoutMuteNotifications');

    orderNotifyCount = 0;
    print('   Making 3 changes with mute...');
    order.mute();
    order.status | 'shipped';
    order.total | 125.97;
    (order.items[0]).quantity | 4;
    order.unmute();
    print('   Notifications with mute: $orderNotifyCount (consolidated)');

    // Assertions
    assert(~order.status == 'shipped', 'Status should be updated');
    assert(
      withoutMuteNotifications >= 1,
      'Should have notifications without mute',
    );

    order.removeObserver(orderObserver);
  }

  // -------------------------------------------------------------------------
  // Example 8: Round-trip serialization
  // -------------------------------------------------------------------------
  static void example8RoundTrip() {
    print('\n8. Round-trip serialization:');

    // For TomClass, use the built-in toJson/fromJson methods directly
    // The reflection system's convertToJsonString doesn't work with nested TomClass
    // because TomClass has its own serialization mechanism
    final customerJsonMap = customer.toJson();
    final customerJsonString = jsonEncode(customerJsonMap);
    print('   Serialized (via toJson): $customerJsonString');

    final customer2 = ObservableCustomer();
    customer2.fromJson(customerJsonString);
    print('   Restored name: ${~customer2.name}');
    print('   Restored city: ${~customer2.address.city}');

    // Assertions
    assert(~customer2.name == 'Acme Corp', 'Name should be restored');
    assert(~customer2.address.city == 'Los Angeles', 'City should be restored');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 05: TomClass Integration Example ===\n');

    example1CreateAndPopulate();
    example2ObservingChanges();
    example3SerializingToJson();
    example4NestedTomClass();
    example5ObservingNestedChanges();
    example6TomListWithElements();
    example7MuteUnmute();
    example8RoundTrip();

    print('\n=== TomClass Integration Example Complete ===\n');
  }
}

void run() => TomClassIntegrationExample.run();

void main() {
  bootstrapSamples();
  run();
}
