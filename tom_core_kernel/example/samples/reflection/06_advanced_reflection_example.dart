/// Advanced Reflection Example
///
/// This example demonstrates advanced reflection techniques including
/// type resolution, debugging, error handling, and custom serialization.
///
/// Key concepts:
/// - Getting ClassMirror for type introspection
/// - Type resolution for collections
/// - Custom serialization with jsonEncode getter
/// - Custom deserialization with jsonDecode method
/// - All supported field types demonstration
/// - Error handling for reflection operations
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/reflection/06_advanced_reflection_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A simple product class.
@tomReflector
class ProductAdvanced {
  String id = '';
  String name = '';
  double price = 0.0;
}

/// A class with custom jsonEncode for serialization.
@tomReflector
class CustomSerializedClass {
  String internalId = '';
  String displayName = '';
  int version = 1;

  /// Custom serialization via jsonEncode getter.
  /// When present, getValues() uses this instead of reflection.
  Map<String, Object?> get jsonEncode => {
    'id': internalId, // Custom key name
    'name': displayName, // Custom key name
    'v': version, // Shortened key
    '_type': 'CustomSerializedClass', // Type discriminator
  };
}

/// A class with jsonDecode method for deserialization.
@tomReflector
class CustomDeserializedClass {
  String data = '';
  int count = 0;
  bool processed = false;

  /// Custom deserialization via jsonDecode method.
  /// When present, setValues() calls this instead of reflection.
  void jsonDecode(Map<String, dynamic> values) {
    data = values['d'] ?? values['data'] ?? '';
    count = values['c'] ?? values['count'] ?? 0;
    processed = true; // Custom logic during deserialization
  }
}

/// A class demonstrating all supported field types.
@tomReflector
class AllTypesDemo {
  // Primitives
  String stringField = '';
  int intField = 0;
  double doubleField = 0.0;
  bool boolField = false;

  // Nullable primitives
  String? nullableString;
  int? nullableInt;
  double? nullableDouble;
  bool? nullableBool;

  // DateTime
  DateTime dateTime = DateTime.now();
  DateTime? nullableDateTime;

  // Lists
  List<String> stringList = [];
  List<int> intList = [];
  List<ProductAdvanced> productList = [];

  // Maps
  Map<String, String> stringMap = {};
  Map<String, int> intMap = {};
  Map<String, ProductAdvanced> productMap = {};

  // Nested
  ProductAdvanced nestedProduct = ProductAdvanced();
}

// ============================================================================
// Example Class
// ============================================================================

class AdvancedReflectionExample {
  // Captured results
  static late ClassMirror productMirror;
  static late ClassMirror listElementMirror;
  static late ClassMirror mapValueMirror;
  static late ProductAdvanced createdProduct;
  static late Map<String, dynamic> customSerializedJson;
  static late CustomDeserializedClass deserializedInstance;
  static late AllTypesDemo allTypesInstance;
  static late List<String> annotatedClassNames;
  static bool caughtException = false;

  // -------------------------------------------------------------------------
  // Example 1: Getting ClassMirror
  // -------------------------------------------------------------------------
  static void example1ClassMirror() {
    print('1. Getting ClassMirror:');

    productMirror = tomReflector.reflectType(ProductAdvanced) as ClassMirror;
    print('   Class name: ${productMirror.simpleName}');
    print('   Has reflected type: ${productMirror.hasReflectedType}');
    print('   Reflected type: ${productMirror.reflectedType}');
    print('   Declarations: ${productMirror.declarations.keys.toList()}');

    // Assertions
    assert(
      productMirror.simpleName == 'ProductAdvanced',
      'Class name should match',
    );
    assert(productMirror.hasReflectedType, 'Should have reflected type');
    assert(
      productMirror.declarations.containsKey('id'),
      'Should have id declaration',
    );
  }

  // -------------------------------------------------------------------------
  // Example 2: Type resolution for collections
  // -------------------------------------------------------------------------
  static void example2TypeResolution() {
    print('\n2. Type resolution for collections:');

    // List element type
    List<ProductAdvanced> productList = [];
    listElementMirror = tomReflectionInfo.singleElementType(productList);
    print(
      '   List<ProductAdvanced> element type: ${listElementMirror.simpleName}',
    );

    // Map value type
    Map<String, ProductAdvanced> productMap = {};
    mapValueMirror = tomReflectionInfo.mapValueElementType(productMap);
    print(
      '   Map<String, ProductAdvanced> value type: ${mapValueMirror.simpleName}',
    );

    // Assertions
    assert(
      listElementMirror.simpleName == 'ProductAdvanced',
      'List element type should match',
    );
    assert(
      mapValueMirror.simpleName == 'ProductAdvanced',
      'Map value type should match',
    );
  }

  // -------------------------------------------------------------------------
  // Example 3: Creating instances dynamically
  // -------------------------------------------------------------------------
  static void example3DynamicCreation() {
    print('\n3. Creating instances dynamically:');

    // Create by type parameter
    final product1 = tomReflectionInfo.createInstance<ProductAdvanced>();
    print('   Created via <ProductAdvanced>: ${product1.runtimeType}');

    // Create by Type object
    final product2 = tomReflectionInfo.createInstance(ProductAdvanced);
    print('   Created via Type: ${product2.runtimeType}');

    // Create from ClassMirror
    final product3 = productMirror.newInstance('', []) as ProductAdvanced;
    print('   Created via ClassMirror: ${product3.runtimeType}');

    createdProduct = product1;

    // Assertions. Only the middle one of the three is a real check: the
    // generic call and the ClassMirror call are both statically
    // `ProductAdvanced` already — one by its type argument, the other by its
    // cast — so `is` there asks the compiler a question it has already
    // answered. `createInstance(Type)` is the one that returns dynamic, and so
    // the one whose `is` can fail.
    assert(product2 is ProductAdvanced, 'Creating by Type should give one');

    // What the other two can still get wrong is the *runtime* type: a
    // reflector that handed back a subclass, a stand-in, or a shared instance
    // would satisfy the static types above and fail here.
    assert(
      product1.runtimeType == ProductAdvanced,
      'The generic call should construct the exact class, not a subtype',
    );
    assert(
      product3.runtimeType == ProductAdvanced,
      'newInstance should construct the exact class, not a subtype',
    );
    assert(
      !identical(product1, product2) && !identical(product2, product3),
      'Each call should construct a fresh instance, not return a cached one',
    );
  }

  // -------------------------------------------------------------------------
  // Example 4: Custom serialization (jsonEncode)
  // -------------------------------------------------------------------------
  static void example4CustomSerialization() {
    print('\n4. Custom serialization (jsonEncode getter):');

    final custom = CustomSerializedClass()
      ..internalId = 'INT-12345'
      ..displayName = 'My Custom Object'
      ..version = 3;

    customSerializedJson = tomReflectionInfo.getValues(custom);
    print(
      '   Object fields: internalId=${custom.internalId}, displayName=${custom.displayName}',
    );
    print('   Serialized: $customSerializedJson');
    print('   Note: Uses custom keys (id, name, v) and adds _type');

    // Assertions
    assert(
      customSerializedJson['id'] == 'INT-12345',
      'Custom key should be used',
    );
    assert(
      customSerializedJson['name'] == 'My Custom Object',
      'Custom key should be used',
    );
    assert(customSerializedJson['v'] == 3, 'Custom key should be used');
    assert(
      customSerializedJson['_type'] == 'CustomSerializedClass',
      'Type marker should exist',
    );
  }

  // -------------------------------------------------------------------------
  // Example 5: Custom deserialization (jsonDecode)
  // -------------------------------------------------------------------------
  static void example5CustomDeserialization() {
    print('\n5. Custom deserialization (jsonDecode method):');

    final custom2 = CustomDeserializedClass();
    print(
      '   Before: data="${custom2.data}", count=${custom2.count}, processed=${custom2.processed}',
    );

    // Uses shortened keys as defined in jsonDecode
    tomReflectionInfo.setValues(custom2, {'d': 'Custom data', 'c': 42});

    print(
      '   After: data="${custom2.data}", count=${custom2.count}, processed=${custom2.processed}',
    );
    print('   Note: processed=true set by custom logic');

    deserializedInstance = custom2;

    // Assertions
    assert(custom2.data == 'Custom data', 'Data should be set via custom keys');
    assert(custom2.count == 42, 'Count should be set via custom keys');
    assert(
      custom2.processed == true,
      'Processed should be true from custom logic',
    );
  }

  // -------------------------------------------------------------------------
  // Example 6: All types demo
  // -------------------------------------------------------------------------
  static void example6AllTypesDemo() {
    print('\n6. All types demo:');

    final allTypes = AllTypesDemo();
    tomReflectionInfo.setValues(allTypes, {
      'stringField': 'Hello World',
      'intField': 42,
      'doubleField': 3.14159,
      'boolField': true,
      'nullableString': 'Not null',
      'nullableInt': 100,
      'nullableDouble': null,
      'nullableBool': null,
      'dateTime': '2024-06-15T10:30:00.000Z',
      'nullableDateTime': '2024-12-25T00:00:00.000Z',
      'stringList': ['a', 'b', 'c'],
      'intList': [1, 2, 3, 4, 5],
      'productList': [
        {'id': 'P1', 'name': 'Product 1', 'price': 9.99},
        {'id': 'P2', 'name': 'Product 2', 'price': 19.99},
      ],
      'stringMap': {'key1': 'value1', 'key2': 'value2'},
      'intMap': {'count': 10, 'max': 100},
      'productMap': {
        'featured': {'id': 'F1', 'name': 'Featured', 'price': 29.99},
      },
      'nestedProduct': {'id': 'N1', 'name': 'Nested', 'price': 39.99},
    });

    print(
      '   Primitives: string="${allTypes.stringField}", int=${allTypes.intField}',
    );
    print(
      '   Nullables: string="${allTypes.nullableString}", double=${allTypes.nullableDouble}',
    );
    print('   DateTime: ${allTypes.dateTime}');
    print(
      '   Lists: strings=${allTypes.stringList.length}, products=${allTypes.productList.length}',
    );
    print(
      '   Maps: strings=${allTypes.stringMap.length}, products=${allTypes.productMap.length}',
    );
    print('   Nested: ${allTypes.nestedProduct.name}');

    allTypesInstance = allTypes;

    // Assertions
    assert(allTypes.stringField == 'Hello World', 'String should match');
    assert(allTypes.intField == 42, 'Int should match');
    assert(allTypes.productList.length == 2, 'Should have 2 products');
    assert(
      allTypes.nestedProduct.name == 'Nested',
      'Nested product name should match',
    );
  }

  // -------------------------------------------------------------------------
  // Example 7: Listing annotated classes
  // -------------------------------------------------------------------------
  static void example7ListAnnotatedClasses() {
    print('\n7. Listing annotated classes:');

    annotatedClassNames = [];
    print('   Annotated classes available:');
    for (var classMirror in tomReflector.annotatedClasses) {
      print('   - ${classMirror.simpleName}');
      annotatedClassNames.add(classMirror.simpleName);
    }

    // Assertions
    assert(annotatedClassNames.isNotEmpty, 'Should have annotated classes');
    assert(
      annotatedClassNames.contains('ProductAdvanced'),
      'Should contain ProductAdvanced',
    );
  }

  // -------------------------------------------------------------------------
  // Example 8: Error handling
  // -------------------------------------------------------------------------
  static void example8ErrorHandling() {
    print('\n8. Error handling:');

    caughtException = false;
    try {
      // Try to create an instance of a non-annotated type
      tomReflectionInfo.createInstance(DateTime);
    } on TomReflectorException catch (e) {
      caughtException = true;
      print('   Caught TomReflectorException:');
      print('   - Key: ${e.key}');
      final message = e.defaultUserMessage;
      print(
        '   - Message: ${message.substring(0, message.length.clamp(0, 50))}...',
      );
    }

    // Assertions
    assert(caughtException, 'Should catch exception for non-annotated type');
  }

  // -------------------------------------------------------------------------
  // Example 9: Round-trip with all types
  // -------------------------------------------------------------------------
  static void example9RoundTrip() {
    print('\n9. Round-trip with all types:');

    final allTypesJson = tomReflectionInfo.convertToJsonString(
      allTypesInstance,
    );
    print('   Serialized length: ${allTypesJson.length} chars');

    final allTypes2 = AllTypesDemo();
    tomReflectionInfo.convertFromJsonString(allTypes2, allTypesJson);

    print('   Restored stringField: ${allTypes2.stringField}');
    print('   Restored productList: ${allTypes2.productList.length} items');
    print('   Restored nestedProduct: ${allTypes2.nestedProduct.name}');

    // Assertions
    assert(allTypes2.stringField == 'Hello World', 'String should be restored');
    assert(
      allTypes2.productList.length == 2,
      'Product list should be restored',
    );
    assert(
      allTypes2.nestedProduct.name == 'Nested',
      'Nested product should be restored',
    );
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 06: Advanced Reflection Example ===\n');

    example1ClassMirror();
    example2TypeResolution();
    example3DynamicCreation();
    example4CustomSerialization();
    example5CustomDeserialization();
    example6AllTypesDemo();
    example7ListAnnotatedClasses();
    example8ErrorHandling();
    example9RoundTrip();

    print('\n=== Advanced Reflection Example Complete ===\n');
  }
}

void run() => AdvancedReflectionExample.run();

void main() {
  bootstrapSamples();
  run();
}
