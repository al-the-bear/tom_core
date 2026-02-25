/// Example: TomClass - Complex Observable Objects
///
/// This example demonstrates TomClass:
/// - Creating observable domain objects
/// - Automatic member observation
/// - Cascading notifications
/// - JSON serialization with toJson/fromJson
/// - Batch updates with setValues
///
/// NOTE: This example requires the reflection build step to run.
/// Run: `dart run build_runner build` before executing this example.
/// Then run the generated .reflection.dart file instead.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A simple Person class demonstrating TomClass usage.
@tomReflector
class Person extends TomClass {
  final name = TomString("");
  final age = TomInt(0);
  final email = TomNString(null);
  final isActive = TomBool(true);
}

/// An Address class for nested object demonstration.
@tomReflector
class Address extends TomClass {
  final street = TomString("");
  final city = TomString("");
  final zipCode = TomString("");
}

/// A Customer class with nested TomClass member.
@tomReflector
class Customer extends TomClass {
  final customerId = TomString("");
  final name = TomString("");
  final address = Address();
}

void run() {
  print('=== TomClass Example ===\n');

  // --- Creating TomClass instances ---
  print('1. Creating TomClass instances');
  final person = Person();

  // Set individual fields using | operator
  person.name | "John Doe";
  person.age | 30;
  person.email | "john@example.com";

  assert(~person.name == "John Doe", "Name should be 'John Doe'");
  assert(~person.age == 30, "Age should be 30");
  assert(~person.email == "john@example.com", "Email should be set");

  print('   name: ${~person.name}');
  print('   age: ${~person.age}');
  print('   email: ${~person.email}');
  print('   isActive: ${~person.isActive}');

  // --- Observing TomClass changes ---
  print('\n2. Observing TomClass changes');
  int notificationCount = 0;

  person >> (obs) {
    notificationCount++;
    print('   Person changed! (notification #$notificationCount)');
  };

  person.name | "Jane Doe";
  assert(notificationCount == 1, "Should notify when member changes");

  person.age | 25;
  assert(notificationCount == 2, "Should notify for each member change");

  print('   Total notifications: $notificationCount');

  // --- Batch updates with setValues ---
  print('\n3. Batch updates with setValues');
  final person2 = Person();
  int batchNotifyCount = 0;

  person2 >> (obs) {
    batchNotifyCount++;
    print('   Batch update notification #$batchNotifyCount');
  };

  // setValues mutes during update, then unmutes - single notification
  person2.setValues({
    "name": "Alice Smith",
    "age": 28,
    "email": "alice@example.com",
    "isActive": false,
  });

  assert(~person2.name == "Alice Smith", "Name should be updated");
  assert(~person2.age == 28, "Age should be updated");
  assert(~person2.email == "alice@example.com", "Email should be updated");
  assert(~person2.isActive == false, "isActive should be updated");
  assert(batchNotifyCount == 1, "setValues should result in one notification");

  print('   Updated person: name=${~person2.name}, age=${~person2.age}');

  // --- JSON Serialization ---
  print('\n4. JSON Serialization with toJson/fromJson');
  final person3 = Person();
  person3.name | "Bob Wilson";
  person3.age | 35;
  person3.email | "bob@example.com";

  // Convert to JSON map
  final json = person3.toJson();
  print('   toJson: $json');

  assert(json["name"] == "Bob Wilson", "JSON name should match");
  assert(json["age"] == 35, "JSON age should match");
  assert(json["email"] == "bob@example.com", "JSON email should match");

  // Create new person from JSON string
  final person4 = Person();
  person4.fromJson('{"name": "Carol Brown", "age": 40, "email": "carol@example.com", "isActive": true}');

  assert(~person4.name == "Carol Brown", "fromJson should set name");
  assert(~person4.age == 40, "fromJson should set age");
  print('   fromJson: name=${~person4.name}, age=${~person4.age}');

  // --- Nested TomClass objects ---
  print('\n5. Nested TomClass objects');
  final customer = Customer();
  int customerNotifyCount = 0;

  customer >> (obs) {
    customerNotifyCount++;
    print('   Customer changed! (notification #$customerNotifyCount)');
  };

  customer.customerId | "CUST-001";
  customer.name | "Acme Corp";

  // Changes to nested address also notify the parent
  customer.address.street | "123 Main St";
  customer.address.city | "New York";
  customer.address.zipCode | "10001";

  assert(~customer.address.street == "123 Main St", "Nested street should be set");
  assert(~customer.address.city == "New York", "Nested city should be set");
  print('   Customer notifications from nested changes: $customerNotifyCount');

  // setValues with nested data
  final customer2 = Customer();
  customer2.setValues({
    "customerId": "CUST-002",
    "name": "Widget Inc",
    "address": {
      "street": "456 Oak Ave",
      "city": "Los Angeles",
      "zipCode": "90001",
    },
  });

  assert(~customer2.customerId == "CUST-002", "Customer ID should be set");
  assert(~customer2.address.city == "Los Angeles", "Nested city should be set via setValues");
  print('   customer2.address.city: ${~customer2.address.city}');

  // --- getMembers ---
  print('\n6. getMembers - accessing registered members');
  final members = person.getMembers();
  print('   Registered members: ${members.keys.toList()}');

  assert(members.containsKey("name"), "Should have 'name' member");
  assert(members.containsKey("age"), "Should have 'age' member");
  assert(members.containsKey("email"), "Should have 'email' member");
  assert(members.containsKey("isActive"), "Should have 'isActive' member");

  // Access member values through the map
  final nameFromMap = members["name"] as TomString;
  assert(~nameFromMap == ~person.name, "Member map value should match field value");
  print('   name from getMembers(): ${~nameFromMap}');

  // --- Muting a TomClass ---
  print('\n7. Muting a TomClass (mutes all members)');
  final person5 = Person();
  int muteTestCount = 0;

  person5 >> (obs) {
    muteTestCount++;
  };

  person5.mute();
  assert(person5.isMuted == true, "Person should be muted");

  person5.name | "Muted Name";
  person5.age | 99;
  assert(muteTestCount == 0, "No notifications while muted");

  person5.unmute();
  assert(muteTestCount == 1, "Single notification after unmute");
  print('   Notifications after unmuting: $muteTestCount');

  print('\n=== All assertions passed! ===');
}
