/// Nested Objects Example
///
/// This example demonstrates how to work with nested objects and class
/// hierarchies in the reflection system.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

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
  Address address = Address();  // Initialize nested object!
}

/// A contact with optional address (nullable nested object).
@tomReflector
class Contact {
  String name = '';
  String phone = '';
  Address? billingAddress;   // Optional - may be null
  Address? shippingAddress;  // Optional - may be null
}

/// A company with multiple levels of nesting.
@tomReflector
class Employee {
  String employeeId = '';
  String name = '';
  String department = '';
  Address workAddress = Address();
}

@tomReflector
class Department {
  String name = '';
  String code = '';
  List<Employee> employees = [];  // List of nested objects
}

@tomReflector
class Company {
  String name = '';
  Address headquarters = Address();
  List<Department> departments = [];
}

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 02: Nested Objects Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Simple nested object
  // -------------------------------------------------------------------------
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
  print('   City: ${person.address.city}, ${person.address.zipCode}\n');

  // -------------------------------------------------------------------------
  // Example 2: Serializing nested objects
  // -------------------------------------------------------------------------
  print('2. Serializing nested objects:');
  
  final jsonString = tomReflectionInfo.convertToJsonString(person);
  print('   JSON: $jsonString\n');

  // -------------------------------------------------------------------------
  // Example 3: Optional nested objects
  // -------------------------------------------------------------------------
  print('3. Optional nested objects:');
  
  final contact = Contact();
  tomReflectionInfo.setValues(contact, {
    'name': 'Jane Smith',
    'phone': '555-1234',
    // billingAddress and shippingAddress are not provided, remain null
  });
  
  print('   Contact: ${contact.name}');
  print('   Phone: ${contact.phone}');
  print('   Billing Address: ${contact.billingAddress}');  // null
  print('   Shipping Address: ${contact.shippingAddress}\n');  // null

  // -------------------------------------------------------------------------
  // Example 4: Filling existing nested object
  // -------------------------------------------------------------------------
  print('4. Filling existing nested object:');
  
  final person2 = PersonWithAddress();
  // Set some initial values on the nested object
  person2.address.country = 'Canada';  // Pre-existing value
  
  tomReflectionInfo.setValues(person2, {
    'name': 'Alice Brown',
    'address': {
      'street': '456 Oak Avenue',
      'city': 'Toronto',
      'zipCode': 'M5V 1A1',
      // 'country' not provided - keeps existing value if object is filled
    },
  });
  
  print('   Person: ${person2.name}');
  print('   Address: ${person2.address.street}, ${person2.address.city}');
  print('   Country: ${person2.address.country}\n');

  // -------------------------------------------------------------------------
  // Example 5: Deep nesting with collections
  // -------------------------------------------------------------------------
  print('5. Deep nesting with collections:');
  
  final company = Company();
  tomReflectionInfo.setValues(company, {
    'name': 'Acme Corporation',
    'headquarters': {
      'street': '1 Corporate Plaza',
      'city': 'San Francisco',
      'zipCode': '94102',
      'country': 'USA',
    },
    'departments': [
      {
        'name': 'Engineering',
        'code': 'ENG',
        'employees': [
          {
            'employeeId': 'E001',
            'name': 'Bob Engineer',
            'department': 'Engineering',
            'workAddress': {
              'street': '1 Corporate Plaza, Floor 5',
              'city': 'San Francisco',
              'zipCode': '94102',
              'country': 'USA',
            },
          },
          {
            'employeeId': 'E002',
            'name': 'Carol Coder',
            'department': 'Engineering',
            'workAddress': {
              'street': '1 Corporate Plaza, Floor 5',
              'city': 'San Francisco',
              'zipCode': '94102',
              'country': 'USA',
            },
          },
        ],
      },
      {
        'name': 'Marketing',
        'code': 'MKT',
        'employees': [
          {
            'employeeId': 'M001',
            'name': 'Dan Marketer',
            'department': 'Marketing',
            'workAddress': {
              'street': '1 Corporate Plaza, Floor 3',
              'city': 'San Francisco',
              'zipCode': '94102',
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
  for (var dept in company.departments) {
    print('   - ${dept.name} (${dept.code}): ${dept.employees.length} employees');
    for (var emp in dept.employees) {
      print('     - ${emp.name} (${emp.employeeId})');
    }
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 6: Round-trip serialization of complex structure
  // -------------------------------------------------------------------------
  print('6. Round-trip serialization:');
  
  final companyJson = tomReflectionInfo.convertToJsonString(company);
  print('   Serialized company (${companyJson.length} chars)');
  
  final company2 = Company();
  tomReflectionInfo.convertFromJsonString(company2, companyJson);
  print('   Restored company: ${company2.name}');
  print('   Departments restored: ${company2.departments.length}');
  print('   First department: ${company2.departments[0].name}');
  print('   First employee: ${company2.departments[0].employees[0].name}\n');

  print('=== Nested Objects Example Complete ===\n');
}
