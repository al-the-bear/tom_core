/// Basic Reflection Example
///
/// This example demonstrates the fundamental concepts of the Tom Reflection
/// system: creating instances, setting values, and getting values from
/// annotated classes.
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

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 01: Basic Reflection Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Create an instance using reflection
  // -------------------------------------------------------------------------
  print('1. Creating instance via reflection:');
  
  final person = tomReflectionInfo.createInstance<SimplePerson>();
  print('   Created SimplePerson instance');
  print('   Default values: name="${person.name}", age=${person.age}\n');

  // -------------------------------------------------------------------------
  // Example 2: Set values from a Map
  // -------------------------------------------------------------------------
  print('2. Setting values from Map:');
  
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
  print('   - isActive: ${person.isActive}\n');

  // -------------------------------------------------------------------------
  // Example 3: Get values as a Map
  // -------------------------------------------------------------------------
  print('3. Getting values as Map:');
  
  final values = tomReflectionInfo.getValues(person);
  print('   Values: $values\n');

  // -------------------------------------------------------------------------
  // Example 4: Convert to/from JSON string
  // -------------------------------------------------------------------------
  print('4. JSON serialization:');
  
  final jsonString = tomReflectionInfo.convertToJsonString(person);
  print('   JSON: $jsonString');
  
  // Create new person and populate from JSON
  final person2 = SimplePerson();
  tomReflectionInfo.convertFromJsonString(person2, jsonString);
  print('   Restored from JSON: name="${person2.name}", age=${person2.age}\n');

  // -------------------------------------------------------------------------
  // Example 5: Partial updates
  // -------------------------------------------------------------------------
  print('5. Partial updates:');
  
  final person3 = SimplePerson();
  person3.name = 'Existing Name';
  person3.age = 25;
  
  // Only update specific fields
  tomReflectionInfo.setValues(person3, {
    'email': 'updated@example.com',
  });
  
  print('   After partial update:');
  print('   - name: ${person3.name} (unchanged)');
  print('   - age: ${person3.age} (unchanged)');
  print('   - email: ${person3.email} (updated)\n');

  // -------------------------------------------------------------------------
  // Example 6: Handling null values
  // -------------------------------------------------------------------------
  print('6. Handling null values:');
  
  final person4 = SimplePerson();
  tomReflectionInfo.setValues(person4, {
    'name': 'Alice',
    'age': 28,
    'email': null,  // Explicitly set to null
  });
  
  print('   - name: ${person4.name}');
  print('   - email: ${person4.email} (null)\n');

  print('=== Basic Reflection Example Complete ===\n');
}
