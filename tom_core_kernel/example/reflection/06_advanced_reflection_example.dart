/// Advanced Reflection Example
///
/// This example demonstrates advanced reflection techniques including
/// type resolution, debugging, error handling, and custom serialization.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A simple product class.
@tomReflector
class Product {
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
    'id': internalId,           // Custom key name
    'name': displayName,        // Custom key name
    'v': version,               // Shortened key
    '_type': 'CustomSerializedClass',  // Type discriminator
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
    processed = true;  // Custom logic during deserialization
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
  List<Product> productList = [];
  
  // Maps
  Map<String, String> stringMap = {};
  Map<String, int> intMap = {};
  Map<String, Product> productMap = {};
  
  // Nested
  Product nestedProduct = Product();
}

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 06: Advanced Reflection Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Getting ClassMirror
  // -------------------------------------------------------------------------
  print('1. Getting ClassMirror:');
  
  final productMirror = tomReflector.reflectType(Product) as ClassMirror;
  print('   Class name: ${productMirror.simpleName}');
  print('   Has reflected type: ${productMirror.hasReflectedType}');
  print('   Reflected type: ${productMirror.reflectedType}');
  print('   Declarations: ${productMirror.declarations.keys.toList()}\n');

  // -------------------------------------------------------------------------
  // Example 2: Type resolution for collections
  // -------------------------------------------------------------------------
  print('2. Type resolution for collections:');
  
  // List element type
  List<Product> productList = [];
  final listElementMirror = tomReflectionInfo.singleElementType(productList);
  print('   List<Product> element type: ${listElementMirror.simpleName}');
  
  // Map value type
  Map<String, Product> productMap = {};
  final mapValueMirror = tomReflectionInfo.mapValueElementType(productMap);
  print('   Map<String, Product> value type: ${mapValueMirror.simpleName}\n');

  // -------------------------------------------------------------------------
  // Example 3: Creating instances dynamically
  // -------------------------------------------------------------------------
  print('3. Creating instances dynamically:');
  
  // Create by type parameter
  final product1 = tomReflectionInfo.createInstance<Product>();
  print('   Created via <Product>: ${product1.runtimeType}');
  
  // Create by Type object
  final product2 = tomReflectionInfo.createInstance(Product);
  print('   Created via Type: ${product2.runtimeType}');
  
  // Create from ClassMirror
  final product3 = productMirror.newInstance('', []) as Product;
  print('   Created via ClassMirror: ${product3.runtimeType}\n');

  // -------------------------------------------------------------------------
  // Example 4: Custom serialization (jsonEncode)
  // -------------------------------------------------------------------------
  print('4. Custom serialization (jsonEncode getter):');
  
  final custom = CustomSerializedClass()
    ..internalId = 'INT-12345'
    ..displayName = 'My Custom Object'
    ..version = 3;
  
  final customJson = tomReflectionInfo.getValues(custom);
  print('   Object fields: internalId=${custom.internalId}, displayName=${custom.displayName}');
  print('   Serialized: $customJson');
  print('   Note: Uses custom keys (id, name, v) and adds _type\n');

  // -------------------------------------------------------------------------
  // Example 5: Custom deserialization (jsonDecode)
  // -------------------------------------------------------------------------
  print('5. Custom deserialization (jsonDecode method):');
  
  final custom2 = CustomDeserializedClass();
  print('   Before: data="${custom2.data}", count=${custom2.count}, processed=${custom2.processed}');
  
  // Uses shortened keys as defined in jsonDecode
  tomReflectionInfo.setValues(custom2, {
    'd': 'Custom data',
    'c': 42,
  });
  
  print('   After: data="${custom2.data}", count=${custom2.count}, processed=${custom2.processed}');
  print('   Note: processed=true set by custom logic\n');

  // -------------------------------------------------------------------------
  // Example 6: All types demo
  // -------------------------------------------------------------------------
  print('6. All types demo:');
  
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
  
  print('   Primitives: string="${allTypes.stringField}", int=${allTypes.intField}');
  print('   Nullables: string="${allTypes.nullableString}", double=${allTypes.nullableDouble}');
  print('   DateTime: ${allTypes.dateTime}');
  print('   Lists: strings=${allTypes.stringList.length}, products=${allTypes.productList.length}');
  print('   Maps: strings=${allTypes.stringMap.length}, products=${allTypes.productMap.length}');
  print('   Nested: ${allTypes.nestedProduct.name}\n');

  // -------------------------------------------------------------------------
  // Example 7: Debug reporting
  // -------------------------------------------------------------------------
  print('7. Debug reporting:');
  print('   (Uncomment reportReflectObject to see full output)\n');
  
  // Uncomment to see detailed reflection info:
  // tomReflectionInfo.reportReflectObject(allTypes);

  // -------------------------------------------------------------------------
  // Example 8: Listing annotated classes
  // -------------------------------------------------------------------------
  print('8. Listing annotated classes:');
  
  print('   Annotated classes available:');
  for (var classMirror in tomReflector.annotatedClasses) {
    print('   - ${classMirror.simpleName}');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 9: Error handling
  // -------------------------------------------------------------------------
  print('9. Error handling:');
  
  try {
    // Try to create an instance of a non-annotated type
    tomReflectionInfo.createInstance(DateTime);
  } on TomReflectorException catch (e) {
    print('   Caught TomReflectorException:');
    print('   - Key: ${e.key}');
    print('   - Message: ${e.defaultUserMessage.substring(0, 50)}...');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 10: Round-trip with all types
  // -------------------------------------------------------------------------
  print('10. Round-trip with all types:');
  
  final allTypesJson = tomReflectionInfo.convertToJsonString(allTypes);
  print('   Serialized length: ${allTypesJson.length} chars');
  
  final allTypes2 = AllTypesDemo();
  tomReflectionInfo.convertFromJsonString(allTypes2, allTypesJson);
  
  print('   Restored stringField: ${allTypes2.stringField}');
  print('   Restored productList: ${allTypes2.productList.length} items');
  print('   Restored nestedProduct: ${allTypes2.nestedProduct.name}\n');

  print('=== Advanced Reflection Example Complete ===\n');
}
