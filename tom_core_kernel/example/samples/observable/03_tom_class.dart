/// TomClass - Complex Observable Objects Example
///
/// This example demonstrates TomClass:
/// - Creating observable domain objects
/// - Automatic member observation
/// - Cascading notifications
/// - JSON serialization with toJson/fromJson
/// - Batch updates with setValues
/// - getMembers for accessing registered members
///
/// NOTE: This example requires the reflection build step to run.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A simple Person class demonstrating TomClass usage.
@tomReflector
class SamplePerson extends TomClass {
  final name = TomString('');
  final age = TomInt(0);
  final email = TomNString(null);
  final isActive = TomBool(true);
}

/// An Address class for nested object demonstration.
@tomReflector
class SampleAddress extends TomClass {
  final street = TomString('');
  final city = TomString('');
  final zipCode = TomString('');
}

/// A Customer class with nested TomClass member.
@tomReflector
class SampleCustomer extends TomClass {
  final customerId = TomString('');
  final name = TomString('');
  final address = SampleAddress();
}

// ============================================================================
// Example Class
// ============================================================================

class TomClassExample {
  // Captured results
  static late SamplePerson person;
  static late SampleCustomer customer;
  static int notificationCount = 0;
  static int batchNotifyCount = 0;
  static late Map<String, dynamic> personJson;

  // -------------------------------------------------------------------------
  // Example 1: Creating TomClass instances
  // -------------------------------------------------------------------------
  static void example1CreatingInstances() {
    print('1. Creating TomClass instances:');

    person = SamplePerson();

    // Set individual fields using | operator
    person.name | 'John Doe';
    person.age | 30;
    person.email | 'john@example.com';

    print('   name: ${~person.name}');
    print('   age: ${~person.age}');
    print('   email: ${~person.email}');
    print('   isActive: ${~person.isActive}');

    // Assertions
    assert(~person.name == 'John Doe', "Name should be 'John Doe'");
    assert(~person.age == 30, 'Age should be 30');
    assert(~person.email == 'john@example.com', 'Email should be set');
  }

  // -------------------------------------------------------------------------
  // Example 2: Observing TomClass changes
  // -------------------------------------------------------------------------
  static void example2ObservingChanges() {
    print('\n2. Observing TomClass changes:');

    notificationCount = 0;

    // Retain the returned observer. TomObservable holds its observers by
    // WeakReference, so the wrapper `>>` hands back is the only strong
    // reference keeping the callback alive; discard it and notifications stop
    // at the next garbage collection, silently and nondeterministically.
    final personObserver = person >> (obs) {
      notificationCount++;
      print('   Person changed! (notification #$notificationCount)');
    };

    person.name | 'Jane Doe';
    person.age | 25;

    print('   Total notifications: $notificationCount');

    // Assertions
    assert(notificationCount >= 2, 'Should notify for each member change');
    assert(~person.name == 'Jane Doe', 'Name should be updated');

    person.removeObserver(personObserver);
  }

  // -------------------------------------------------------------------------
  // Example 3: Batch updates with setValues
  // -------------------------------------------------------------------------
  static void example3BatchUpdates() {
    print('\n3. Batch updates with setValues:');

    final person2 = SamplePerson();
    batchNotifyCount = 0;

    final person2Observer = person2 >> (obs) {
      batchNotifyCount++;
      print('   Batch update notification #$batchNotifyCount');
    };

    // setValues mutes during update, then unmutes - single notification
    person2.setValues({
      'name': 'Alice Smith',
      'age': 28,
      'email': 'alice@example.com',
      'isActive': false,
    });

    print('   Updated person: name=${~person2.name}, age=${~person2.age}');

    // Assertions
    assert(~person2.name == 'Alice Smith', 'Name should be updated');
    assert(~person2.age == 28, 'Age should be updated');

    person2.removeObserver(person2Observer);
    assert(~person2.email == 'alice@example.com', 'Email should be updated');
    assert(~person2.isActive == false, 'isActive should be updated');
    assert(batchNotifyCount == 1, 'setValues should result in one notification');
  }

  // -------------------------------------------------------------------------
  // Example 4: JSON Serialization
  // -------------------------------------------------------------------------
  static void example4JsonSerialization() {
    print('\n4. JSON Serialization with toJson/fromJson:');

    final person3 = SamplePerson();
    person3.name | 'Bob Wilson';
    person3.age | 35;
    person3.email | 'bob@example.com';

    // Convert to JSON map
    personJson = person3.toJson();
    print('   toJson: $personJson');

    // Create new person from JSON string
    final person4 = SamplePerson();
    person4.fromJson(
        '{"name": "Carol Brown", "age": 40, "email": "carol@example.com", "isActive": true}');

    print('   fromJson: name=${~person4.name}, age=${~person4.age}');

    // Assertions
    assert(personJson['name'] == 'Bob Wilson', 'JSON name should match');
    assert(personJson['age'] == 35, 'JSON age should match');
    assert(~person4.name == 'Carol Brown', 'fromJson should set name');
    assert(~person4.age == 40, 'fromJson should set age');
  }

  // -------------------------------------------------------------------------
  // Example 5: Nested TomClass objects
  // -------------------------------------------------------------------------
  static void example5NestedTomClass() {
    print('\n5. Nested TomClass objects:');

    customer = SampleCustomer();
    int customerNotifyCount = 0;

    final customerObserver = customer >> (obs) {
      customerNotifyCount++;
      print('   Customer changed! (notification #$customerNotifyCount)');
    };

    customer.customerId | 'CUST-001';
    customer.name | 'Acme Corp';

    // Changes to nested address also notify the parent
    customer.address.street | '123 Main St';
    customer.address.city | 'New York';
    customer.address.zipCode | '10001';

    print('   Customer notifications from nested changes: $customerNotifyCount');

    // Assertions
    assert(~customer.address.street == '123 Main St', 'Nested street should be set');
    assert(~customer.address.city == 'New York', 'Nested city should be set');

    customer.removeObserver(customerObserver);
  }

  // -------------------------------------------------------------------------
  // Example 6: setValues with nested data
  // -------------------------------------------------------------------------
  static void example6SetValuesNested() {
    print('\n6. setValues with nested data:');

    final customer2 = SampleCustomer();
    customer2.setValues({
      'customerId': 'CUST-002',
      'name': 'Widget Inc',
      'address': {
        'street': '456 Oak Ave',
        'city': 'Los Angeles',
        'zipCode': '90001',
      },
    });

    print('   customer2.customerId: ${~customer2.customerId}');
    print('   customer2.address.city: ${~customer2.address.city}');

    // Assertions
    assert(~customer2.customerId == 'CUST-002', 'Customer ID should be set');
    assert(~customer2.address.city == 'Los Angeles', 'Nested city should be set via setValues');
  }

  // -------------------------------------------------------------------------
  // Example 7: getMembers - accessing registered members
  // -------------------------------------------------------------------------
  static void example7GetMembers() {
    print('\n7. getMembers - accessing registered members:');

    final members = person.getMembers();
    print('   Registered members: ${members.keys.toList()}');

    // Access member values through the map
    final nameFromMap = members['name'] as TomString;
    print('   name from getMembers(): ${~nameFromMap}');

    // Assertions
    assert(members.containsKey('name'), "Should have 'name' member");
    assert(members.containsKey('age'), "Should have 'age' member");
    assert(members.containsKey('email'), "Should have 'email' member");
    assert(~nameFromMap == ~person.name, 'Member map value should match field value');
  }

  // -------------------------------------------------------------------------
  // Example 8: Muting a TomClass (mutes all members)
  // -------------------------------------------------------------------------
  static void example8MutingTomClass() {
    print('\n8. Muting a TomClass (mutes all members):');

    final person5 = SamplePerson();
    int muteTestCount = 0;

    final person5Observer = person5 >> (obs) {
      muteTestCount++;
    };

    person5.mute();
    print('   isMuted: ${person5.isMuted}');

    person5.name | 'Muted Name';
    person5.age | 99;
    print('   Notifications while muted: $muteTestCount');

    person5.unmute();
    print('   Notifications after unmuting: $muteTestCount');

    // Assertions
    assert(person5.isMuted == false, 'Should not be muted after unmute');
    assert(~person5.name == 'Muted Name', 'Value should be set even while muted');
    assert(muteTestCount == 1, 'Single consolidated notification after unmute');

    person5.removeObserver(person5Observer);
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 03: TomClass Example ===\n');

    example1CreatingInstances();
    example2ObservingChanges();
    example3BatchUpdates();
    example4JsonSerialization();
    example5NestedTomClass();
    example6SetValuesNested();
    example7GetMembers();
    example8MutingTomClass();

    print('\n=== TomClass Example Complete ===\n');
  }
}

void run() => TomClassExample.run();

void main() {
  bootstrapSamples();
  run();
}
