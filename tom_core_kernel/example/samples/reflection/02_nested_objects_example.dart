/// Nested Objects Example
///
/// This example demonstrates how to work with nested objects and class
/// hierarchies in the reflection system.
///
/// Key concepts:
/// - Nested @tomReflector annotated classes
/// - Setting nested object values from Maps
/// - Optional (nullable) nested objects
/// - Multi-level nesting
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// An address with street, city, and postal information.
@tomReflector
class Address {
  String street = '';
  String city = '';
  String zipCode = '';
  String country = 'USA';
}

/// A person with a nested address.
///
/// Note: Nested objects should be initialized in the field declaration
/// to ensure they're available for population during deserialization.
@tomReflector
class PersonWithAddress {
  String name = '';
  int age = 0;
  Address address = Address(); // Initialize nested object!
}

/// A contact with optional address (nullable nested object).
@tomReflector
class Contact {
  String name = '';
  String phone = '';
  Address? billingAddress; // Optional - may be null
  Address? shippingAddress; // Optional - may be null
}

/// An employee for company example.
@tomReflector
class Employee {
  String employeeId = '';
  String name = '';
  String department = '';
  Address workAddress = Address();
}

/// A department containing employees.
@tomReflector
class Department {
  String name = '';
  String code = '';
  List<Employee> employees = [];
}

/// A company with nested address and departments.
@tomReflector
class Company {
  String name = '';
  Address headquarters = Address();
  List<Department> departments = [];
}

// ============================================================================
// Example Class
// ============================================================================

class NestedObjectsExample {
  // Captured results
  static late PersonWithAddress person1;
  static late String serializedPerson;
  static late Contact contactWithNulls;
  static late Company company;

  // -------------------------------------------------------------------------
  // Example 1: Simple nested object
  // -------------------------------------------------------------------------
  static void example1SimpleNested() {
    print('1. Simple nested object:');

    final person = PersonWithAddress();
    tomReflectionInfo.setValues(person, {
      'name': 'John Doe',
      'age': 35,
      'address': {
        'street': '123 Main Street',
        'city': 'New York',
        'zipCode': '10001',
        'country': 'USA',
      },
    });

    print('   Person: ${person.name}, age ${person.age}');
    print('   Address: ${person.address.street}');
    print('   City: ${person.address.city}, ${person.address.zipCode}');

    person1 = person;

    // Assertions
    assert(person.name == 'John Doe', 'Name should be set');
    assert(person.age == 35, 'Age should be set');
    assert(person.address.street == '123 Main Street', 'Street should be set');
    assert(person.address.city == 'New York', 'City should be set');
  }

  // -------------------------------------------------------------------------
  // Example 2: Serializing nested objects
  // -------------------------------------------------------------------------
  static void example2SerializeNested() {
    print('\n2. Serializing nested objects:');

    final person = PersonWithAddress()
      ..name = 'Jane Smith'
      ..age = 28
      ..address.street = '456 Oak Avenue'
      ..address.city = 'Los Angeles'
      ..address.zipCode = '90001'
      ..address.country = 'USA';

    final jsonString = tomReflectionInfo.convertToJsonString(person);
    print('   JSON: $jsonString');

    serializedPerson = jsonString;

    // Assertions
    assert(jsonString.contains('Jane Smith'), 'JSON should contain name');
    assert(jsonString.contains('456 Oak Avenue'), 'JSON should contain street');
    assert(jsonString.contains('Los Angeles'), 'JSON should contain city');
  }

  // -------------------------------------------------------------------------
  // Example 3: Optional nested objects
  // -------------------------------------------------------------------------
  static void example3OptionalNested() {
    print('\n3. Optional nested objects:');

    final contact = Contact();
    tomReflectionInfo.setValues(contact, {
      'name': 'Jane Smith',
      'phone': '555-1234',
      // billingAddress and shippingAddress are not provided, remain null
    });

    print('   Contact: ${contact.name}');
    print('   Phone: ${contact.phone}');
    print('   Billing Address: ${contact.billingAddress}');
    print('   Shipping Address: ${contact.shippingAddress}');

    contactWithNulls = contact;

    // Assertions
    assert(contact.name == 'Jane Smith', 'Name should be set');
    assert(contact.billingAddress == null, 'Billing should be null');
    assert(contact.shippingAddress == null, 'Shipping should be null');
  }

  // -------------------------------------------------------------------------
  // Example 4: Filling optional nested object
  // -------------------------------------------------------------------------
  static void example4FillOptionalNested() {
    print('\n4. Filling optional nested object:');

    final contact = Contact();
    tomReflectionInfo.setValues(contact, {
      'name': 'Bob Wilson',
      'phone': '555-9876',
      'billingAddress': {
        'street': '789 Billing Street',
        'city': 'Chicago',
        'zipCode': '60601',
        'country': 'USA',
      },
      // shippingAddress left null
    });

    print('   Contact: ${contact.name}');
    print('   Has billing address: ${contact.billingAddress != null}');
    print('   Billing street: ${contact.billingAddress?.street}');
    print('   Has shipping address: ${contact.shippingAddress != null}');

    // Assertions
    assert(contact.billingAddress != null, 'Billing should be set');
    assert(contact.billingAddress!.street == '789 Billing Street');
    assert(contact.shippingAddress == null, 'Shipping should still be null');
  }

  // -------------------------------------------------------------------------
  // Example 5: Multi-level nesting with Company
  // -------------------------------------------------------------------------
  static void example5MultiLevelNesting() {
    print('\n5. Multi-level nesting (Company):');

    final company = Company();
    tomReflectionInfo.setValues(company, {
      'name': 'Acme Corporation',
      'headquarters': {
        'street': '1 Corporate Plaza',
        'city': 'San Francisco',
        'zipCode': '94105',
        'country': 'USA',
      },
      'departments': [
        {
          'name': 'Engineering',
          'code': 'ENG',
          'employees': [
            {
              'employeeId': 'E001',
              'name': 'Alice Engineer',
              'department': 'Engineering',
              'workAddress': {
                'street': '100 Tech Drive',
                'city': 'Palo Alto',
                'zipCode': '94301',
                'country': 'USA',
              },
            },
            {
              'employeeId': 'E002',
              'name': 'Bob Developer',
              'department': 'Engineering',
              'workAddress': {
                'street': '100 Tech Drive',
                'city': 'Palo Alto',
                'zipCode': '94301',
                'country': 'USA',
              },
            },
          ],
        },
        {
          'name': 'Sales',
          'code': 'SAL',
          'employees': [
            {
              'employeeId': 'S001',
              'name': 'Charlie Sales',
              'department': 'Sales',
              'workAddress': {
                'street': '200 Commerce Ave',
                'city': 'New York',
                'zipCode': '10001',
                'country': 'USA',
              },
            },
          ],
        },
      ],
    });

    print('   Company: ${company.name}');
    print('   HQ: ${company.headquarters.city}');
    print('   Departments: ${company.departments.length}');
    for (final dept in company.departments) {
      print('   - ${dept.name} (${dept.code}): ${dept.employees.length} employees');
      for (final emp in dept.employees) {
        print('     - ${emp.name} (${emp.employeeId})');
      }
    }

    NestedObjectsExample.company = company;

    // Assertions
    assert(company.name == 'Acme Corporation', 'Company name should be set');
    assert(company.departments.length == 2, 'Should have 2 departments');
    assert(company.departments[0].employees.length == 2, 'Eng should have 2 employees');
    assert(company.departments[1].employees.length == 1, 'Sales should have 1 employee');
  }

  // -------------------------------------------------------------------------
  // Example 6: Deserialize and verify round-trip
  // -------------------------------------------------------------------------
  static void example6RoundTrip() {
    print('\n6. Round-trip serialization:');

    final original = PersonWithAddress()
      ..name = 'Round Trip Test'
      ..age = 40
      ..address.street = '999 Test Lane'
      ..address.city = 'Test City'
      ..address.zipCode = '00000';

    final json = tomReflectionInfo.convertToJsonString(original);
    print('   Original JSON: $json');

    final restored = PersonWithAddress();
    tomReflectionInfo.convertFromJsonString(restored, json);

    print('   Restored name: ${restored.name}');
    print('   Restored address: ${restored.address.street}, ${restored.address.city}');

    // Assertions
    assert(restored.name == original.name, 'Names should match');
    assert(restored.age == original.age, 'Ages should match');
    assert(restored.address.street == original.address.street, 'Streets should match');
    assert(restored.address.city == original.address.city, 'Cities should match');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 02: Nested Objects Example ===\n');

    example1SimpleNested();
    example2SerializeNested();
    example3OptionalNested();
    example4FillOptionalNested();
    example5MultiLevelNesting();
    example6RoundTrip();

    print('\n=== Nested Objects Example Complete ===\n');
  }
}

void run() => NestedObjectsExample.run();

void main() {
  bootstrapSamples();
  run();
}
