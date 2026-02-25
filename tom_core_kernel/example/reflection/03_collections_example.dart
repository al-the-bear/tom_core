/// Collections Example
///
/// This example demonstrates how to work with List and Map collections
/// in the reflection system, including primitive and object collections.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A class with various primitive list types.
@tomReflector
class PrimitiveLists {
  List<String> tags = [];
  List<int> scores = [];
  List<double> ratings = [];
  List<bool> flags = [];
}

/// A class with various primitive map types.
@tomReflector
class PrimitiveMaps {
  Map<String, String> labels = {};
  Map<String, int> counts = {};
  Map<String, double> measurements = {};
  Map<String, bool> settings = {};
  Map<String, dynamic> metadata = {};
}

/// An item for order examples.
@tomReflector
class OrderItem {
  String productId = '';
  String name = '';
  int quantity = 0;
  double price = 0.0;
}

/// An order with a list of items.
@tomReflector
class Order {
  String orderId = '';
  String customerName = '';
  List<OrderItem> items = [];  // List of annotated objects
  double total = 0.0;
}

/// A product for catalog examples.
@tomReflector
class Product {
  String sku = '';
  String name = '';
  String description = '';
  double price = 0.0;
  List<String> categories = [];
}

/// A catalog with a map of products by SKU.
@tomReflector
class Catalog {
  String name = '';
  Map<String, Product> products = {};  // Map of annotated objects
}

/// A complex class combining lists and maps.
@tomReflector
class UserProfile {
  String userId = '';
  String username = '';
  List<String> interests = [];
  Map<String, String> socialLinks = {};
  Map<String, int> activityCounts = {};
  List<Order> orderHistory = [];
}

// ============================================================================
// Example Code
// ============================================================================

void run() {
  print('=== 03: Collections Example ===\n');

  // -------------------------------------------------------------------------
  // Example 1: Primitive lists
  // -------------------------------------------------------------------------
  print('1. Primitive lists:');
  
  final primLists = PrimitiveLists();
  tomReflectionInfo.setValues(primLists, {
    'tags': ['dart', 'flutter', 'reflection'],
    'scores': [95, 87, 92, 88],
    'ratings': [4.5, 4.8, 4.2, 4.9],
    'flags': [true, false, true, true],
  });
  
  print('   Tags: ${primLists.tags}');
  print('   Scores: ${primLists.scores}');
  print('   Ratings: ${primLists.ratings}');
  print('   Flags: ${primLists.flags}\n');

  // -------------------------------------------------------------------------
  // Example 2: Primitive maps
  // -------------------------------------------------------------------------
  print('2. Primitive maps:');
  
  final primMaps = PrimitiveMaps();
  tomReflectionInfo.setValues(primMaps, {
    'labels': {'en': 'Hello', 'es': 'Hola', 'fr': 'Bonjour'},
    'counts': {'views': 1500, 'likes': 42, 'shares': 8},
    'measurements': {'height': 5.9, 'weight': 165.5},
    'settings': {'darkMode': true, 'notifications': false},
    'metadata': {'version': 2, 'created': '2024-01-15', 'active': true},
  });
  
  print('   Labels: ${primMaps.labels}');
  print('   Counts: ${primMaps.counts}');
  print('   Measurements: ${primMaps.measurements}');
  print('   Settings: ${primMaps.settings}');
  print('   Metadata: ${primMaps.metadata}\n');

  // -------------------------------------------------------------------------
  // Example 3: List of objects
  // -------------------------------------------------------------------------
  print('3. List of objects:');
  
  final order = Order();
  tomReflectionInfo.setValues(order, {
    'orderId': 'ORD-2024-001',
    'customerName': 'John Doe',
    'items': [
      {
        'productId': 'PROD-001',
        'name': 'Widget Pro',
        'quantity': 2,
        'price': 29.99,
      },
      {
        'productId': 'PROD-002',
        'name': 'Gadget Plus',
        'quantity': 1,
        'price': 49.99,
      },
      {
        'productId': 'PROD-003',
        'name': 'Accessory Pack',
        'quantity': 3,
        'price': 9.99,
      },
    ],
    'total': 139.94,
  });
  
  print('   Order: ${order.orderId}');
  print('   Customer: ${order.customerName}');
  print('   Items: ${order.items.length}');
  for (var item in order.items) {
    print('   - ${item.name} (${item.productId}): ${item.quantity} x \$${item.price}');
  }
  print('   Total: \$${order.total}\n');

  // -------------------------------------------------------------------------
  // Example 4: Map of objects
  // -------------------------------------------------------------------------
  print('4. Map of objects:');
  
  final catalog = Catalog();
  tomReflectionInfo.setValues(catalog, {
    'name': 'Electronics Catalog',
    'products': {
      'LAPTOP-001': {
        'sku': 'LAPTOP-001',
        'name': 'Pro Laptop 15"',
        'description': 'High-performance laptop',
        'price': 1299.99,
        'categories': ['electronics', 'computers', 'laptops'],
      },
      'PHONE-001': {
        'sku': 'PHONE-001',
        'name': 'Smart Phone X',
        'description': 'Latest smartphone model',
        'price': 899.99,
        'categories': ['electronics', 'phones', 'mobile'],
      },
      'TABLET-001': {
        'sku': 'TABLET-001',
        'name': 'Tablet Pro 10"',
        'description': 'Versatile tablet computer',
        'price': 599.99,
        'categories': ['electronics', 'tablets'],
      },
    },
  });
  
  print('   Catalog: ${catalog.name}');
  print('   Products: ${catalog.products.length}');
  catalog.products.forEach((sku, product) {
    print('   - $sku: ${product.name} @ \$${product.price}');
    print('     Categories: ${product.categories.join(", ")}');
  });
  print('');

  // -------------------------------------------------------------------------
  // Example 5: Complex nested collections
  // -------------------------------------------------------------------------
  print('5. Complex nested collections:');
  
  final profile = UserProfile();
  tomReflectionInfo.setValues(profile, {
    'userId': 'USR-12345',
    'username': 'johndoe',
    'interests': ['programming', 'music', 'travel', 'photography'],
    'socialLinks': {
      'twitter': 'https://twitter.com/johndoe',
      'github': 'https://github.com/johndoe',
      'linkedin': 'https://linkedin.com/in/johndoe',
    },
    'activityCounts': {
      'posts': 127,
      'comments': 543,
      'followers': 1250,
      'following': 89,
    },
    'orderHistory': [
      {
        'orderId': 'ORD-001',
        'customerName': 'John Doe',
        'items': [
          {'productId': 'P1', 'name': 'Item 1', 'quantity': 1, 'price': 19.99},
        ],
        'total': 19.99,
      },
      {
        'orderId': 'ORD-002',
        'customerName': 'John Doe',
        'items': [
          {'productId': 'P2', 'name': 'Item 2', 'quantity': 2, 'price': 29.99},
          {'productId': 'P3', 'name': 'Item 3', 'quantity': 1, 'price': 15.00},
        ],
        'total': 74.98,
      },
    ],
  });
  
  print('   User: ${profile.username} (${profile.userId})');
  print('   Interests: ${profile.interests.join(", ")}');
  print('   Social Links: ${profile.socialLinks.keys.join(", ")}');
  print('   Activity: ${profile.activityCounts}');
  print('   Order History: ${profile.orderHistory.length} orders');
  for (var order in profile.orderHistory) {
    print('   - ${order.orderId}: \$${order.total} (${order.items.length} items)');
  }
  print('');

  // -------------------------------------------------------------------------
  // Example 6: Serializing collections
  // -------------------------------------------------------------------------
  print('6. Serializing collections:');
  
  final catalogJson = tomReflectionInfo.convertToJsonString(catalog);
  print('   Catalog JSON length: ${catalogJson.length} chars');
  
  final orderJson = tomReflectionInfo.convertToJsonString(order);
  print('   Order JSON length: ${orderJson.length} chars');
  
  // Round-trip test
  final order2 = Order();
  tomReflectionInfo.convertFromJsonString(order2, orderJson);
  print('   Restored order: ${order2.orderId}');
  print('   Restored items: ${order2.items.length}');
  print('   First item: ${order2.items[0].name}\n');

  print('=== Collections Example Complete ===\n');
}
