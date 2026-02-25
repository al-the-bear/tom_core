/// Basic Reflection Example
///
/// This example demonstrates the fundamental concepts of the Tom Reflection
/// system: creating instances, setting values, and getting values from
/// annotated classes.
///
/// Key concepts:
/// - Annotating classes with @tomReflector
/// - Creating instances via `tomReflectionInfo.createInstance<T>()`
/// - Setting values from Map with tomReflectionInfo.setValues()
/// - Getting values as Map with tomReflectionInfo.getValues()
/// - JSON serialization/deserialization
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A simple person class with basic fields.
///
/// Note: All fields must be:
/// - Non-final (can be modified)
/// - Non-static (instance fields)
/// - Non-private (not starting with _)
/// - Initialized with default values
@tomReflector
class SimplePerson {
  String name = '';
  int age = 0;
  String? email;
  bool isActive = true;
}

/// A product class demonstrating numeric types.
@tomReflector
class Product {
  String sku = '';
  String name = '';
  double price = 0.0;
  int stockCount = 0;
  bool isAvailable = true;
}

// ============================================================================
// Example Class
// ============================================================================

class BasicReflectionExample {
  // Captured results for verification
  static late SimplePerson createdPerson;
  static late Map<String, dynamic> extractedValues;
  static late String jsonOutput;
  static late SimplePerson restoredPerson;

  // -------------------------------------------------------------------------
  // Example 1: Create an instance using reflection
  // -------------------------------------------------------------------------
  static void example1CreateInstance() {
    print('1. Creating instance via reflection:');

    final person = tomReflectionInfo.createInstance<SimplePerson>();
    print('   Created SimplePerson instance');
    print('   Default values: name="${person.name}", age=${person.age}');
    print('   Optional email: ${person.email}');
    print('   isActive: ${person.isActive}');

    createdPerson = person;

    // Assertions
    assert(person.name == '', 'Default name should be empty');
    assert(person.age == 0, 'Default age should be 0');
    assert(person.email == null, 'Default email should be null');
    assert(person.isActive == true, 'Default isActive should be true');
  }

  // -------------------------------------------------------------------------
  // Example 2: Set values from a Map
  // -------------------------------------------------------------------------
  static void example2SetValues() {
    print('\n2. Setting values from Map:');

    final person = tomReflectionInfo.createInstance<SimplePerson>();
    tomReflectionInfo.setValues(person, {
      'name': 'John Doe',
      'age': 30,
      'email': 'john@example.com',
      'isActive': true,
    });

    print('   After setValues:');
    print('   - name: ${person.name}');
    print('   - age: ${person.age}');
    print('   - email: ${person.email}');
    print('   - isActive: ${person.isActive}');

    // Assertions
    assert(person.name == 'John Doe', 'Name should be set');
    assert(person.age == 30, 'Age should be set');
    assert(person.email == 'john@example.com', 'Email should be set');
    assert(person.isActive == true, 'isActive should remain true');
  }

  // -------------------------------------------------------------------------
  // Example 3: Get values as a Map
  // -------------------------------------------------------------------------
  static void example3GetValues() {
    print('\n3. Getting values as Map:');

    final person = SimplePerson()
      ..name = 'Jane Smith'
      ..age = 25
      ..email = 'jane@example.com'
      ..isActive = false;

    final values = tomReflectionInfo.getValues(person);
    print('   Values: $values');

    extractedValues = values;

    // Assertions
    assert(values['name'] == 'Jane Smith', 'Name should be extracted');
    assert(values['age'] == 25, 'Age should be extracted');
    assert(values['email'] == 'jane@example.com', 'Email should be extracted');
    assert(values['isActive'] == false, 'isActive should be extracted');
  }

  // -------------------------------------------------------------------------
  // Example 4: Convert to/from JSON string
  // -------------------------------------------------------------------------
  static void example4JsonSerialization() {
    print('\n4. JSON serialization:');

    final person = SimplePerson()
      ..name = 'Bob Wilson'
      ..age = 45
      ..email = 'bob@example.com'
      ..isActive = true;

    final jsonString = tomReflectionInfo.convertToJsonString(person);
    print('   JSON: $jsonString');

    jsonOutput = jsonString;

    // Create new person and populate from JSON
    final person2 = SimplePerson();
    tomReflectionInfo.convertFromJsonString(person2, jsonString);
    print('   Restored from JSON: name="${person2.name}", age=${person2.age}');

    restoredPerson = person2;

    // Assertions
    assert(jsonString.contains('Bob Wilson'), 'JSON should contain name');
    assert(person2.name == 'Bob Wilson', 'Restored name should match');
    assert(person2.age == 45, 'Restored age should match');
    assert(person2.email == 'bob@example.com', 'Restored email should match');
  }

  // -------------------------------------------------------------------------
  // Example 5: Partial updates
  // -------------------------------------------------------------------------
  static void example5PartialUpdates() {
    print('\n5. Partial updates:');

    final person = SimplePerson()
      ..name = 'Existing Name'
      ..age = 25
      ..email = 'old@example.com';

    // Only update specific fields
    tomReflectionInfo.setValues(person, {
      'email': 'updated@example.com',
    });

    print('   After partial update:');
    print('   - name: ${person.name} (unchanged)');
    print('   - age: ${person.age} (unchanged)');
    print('   - email: ${person.email} (updated)');

    // Assertions
    assert(person.name == 'Existing Name', 'Name should be unchanged');
    assert(person.age == 25, 'Age should be unchanged');
    assert(person.email == 'updated@example.com', 'Email should be updated');
  }

  // -------------------------------------------------------------------------
  // Example 6: Handling null values
  // -------------------------------------------------------------------------
  static void example6NullHandling() {
    print('\n6. Handling null values:');

    final person = SimplePerson();
    tomReflectionInfo.setValues(person, {
      'name': 'Alice',
      'age': 28,
      'email': null, // Explicitly set to null
    });

    print('   - name: ${person.name}');
    print('   - email: ${person.email} (null)');

    // Assertions
    assert(person.name == 'Alice', 'Name should be set');
    assert(person.email == null, 'Email should be null');
  }

  // -------------------------------------------------------------------------
  // Example 7: Product with numeric types
  // -------------------------------------------------------------------------
  static void example7NumericTypes() {
    print('\n7. Numeric types (Product):');

    final product = tomReflectionInfo.createInstance<Product>();
    tomReflectionInfo.setValues(product, {
      'sku': 'PROD-001',
      'name': 'Widget Pro',
      'price': 99.95,
      'stockCount': 150,
      'isAvailable': true,
    });

    print('   - SKU: ${product.sku}');
    print('   - Name: ${product.name}');
    print('   - Price: \$${product.price}');
    print('   - Stock: ${product.stockCount}');
    print('   - Available: ${product.isAvailable}');

    // Assertions
    assert(product.price == 99.95, 'Price should be set correctly');
    assert(product.stockCount == 150, 'Stock count should be set');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 01: Basic Reflection Example ===\n');

    example1CreateInstance();
    example2SetValues();
    example3GetValues();
    example4JsonSerialization();
    example5PartialUpdates();
    example6NullHandling();
    example7NumericTypes();

    print('\n=== Basic Reflection Example Complete ===\n');
  }
}

void run() => BasicReflectionExample.run();

void main() => run();
