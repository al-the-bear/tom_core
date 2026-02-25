/// Collections Example
///
/// This example demonstrates how to work with collections (List, Map)
/// in the reflection system.
///
/// Key concepts:
/// - Lists of primitives
/// - Lists of @tomReflector objects
/// - Maps with String keys and various value types
/// - Nested collections
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// ============================================================================
// Model Classes
// ============================================================================

/// A class with lists of primitive types.
@tomReflector
class PrimitiveLists {
  List<String> tags = [];
  List<int> scores = [];
  List<double> prices = [];
  List<bool> flags = [];
}

/// A simple item for list demos.
@tomReflector
class Item {
  String id = '';
  String name = '';
  double price = 0.0;
}

/// A cart containing items.
@tomReflector
class ShoppingCart {
  String cartId = '';
  String customerId = '';
  List<Item> items = [];
  double total = 0.0;
}

/// A class with maps.
@tomReflector
class Settings {
  Map<String, String> stringSettings = {};
  Map<String, int> intSettings = {};
  Map<String, bool> boolSettings = {};
  Map<String, dynamic> mixedSettings = {};
}

/// An article with a list of tags and map of metadata.
@tomReflector
class Article {
  String title = '';
  String content = '';
  List<String> tags = [];
  Map<String, String> metadata = {};
}

// ============================================================================
// Example Class
// ============================================================================

class CollectionsExample {
  // Captured results
  static late PrimitiveLists primLists;
  static late ShoppingCart cart;
  static late Settings settings;
  static late Article article;

  // -------------------------------------------------------------------------
  // Example 1: Lists of primitives
  // -------------------------------------------------------------------------
  static void example1PrimitiveLists() {
    print('1. Lists of primitives:');

    final lists = tomReflectionInfo.createInstance<PrimitiveLists>();
    tomReflectionInfo.setValues(lists, {
      'tags': ['flutter', 'dart', 'mobile'],
      'scores': [95, 87, 92, 88],
      'prices': [19.99, 29.99, 9.99],
      'flags': [true, false, true, true],
    });

    print('   Tags: ${lists.tags}');
    print('   Scores: ${lists.scores}');
    print('   Prices: ${lists.prices}');
    print('   Flags: ${lists.flags}');

    primLists = lists;

    // Assertions
    assert(lists.tags.length == 3, 'Should have 3 tags');
    assert(lists.tags.contains('flutter'), 'Should contain flutter');
    assert(lists.scores.length == 4, 'Should have 4 scores');
    assert(lists.scores[0] == 95, 'First score should be 95');
    assert(lists.prices.length == 3, 'Should have 3 prices');
  }

  // -------------------------------------------------------------------------
  // Example 2: List of objects
  // -------------------------------------------------------------------------
  static void example2ObjectList() {
    print('\n2. List of objects (ShoppingCart):');

    final cart = tomReflectionInfo.createInstance<ShoppingCart>();
    tomReflectionInfo.setValues(cart, {
      'cartId': 'CART-001',
      'customerId': 'CUST-123',
      'items': [
        {'id': 'ITEM-1', 'name': 'Widget A', 'price': 29.99},
        {'id': 'ITEM-2', 'name': 'Widget B', 'price': 49.99},
        {'id': 'ITEM-3', 'name': 'Widget C', 'price': 19.99},
      ],
      'total': 99.97,
    });

    print('   Cart ID: ${cart.cartId}');
    print('   Customer: ${cart.customerId}');
    print('   Items (${cart.items.length}):');
    for (final item in cart.items) {
      print('   - ${item.name}: \$${item.price}');
    }
    print('   Total: \$${cart.total}');

    CollectionsExample.cart = cart;

    // Assertions
    assert(cart.items.length == 3, 'Should have 3 items');
    assert(cart.items[0].name == 'Widget A', 'First item should be Widget A');
    assert(cart.items[1].price == 49.99, 'Second item price should match');
  }

  // -------------------------------------------------------------------------
  // Example 3: Maps with primitive values
  // -------------------------------------------------------------------------
  static void example3PrimitiveMaps() {
    print('\n3. Maps with primitive values:');

    final settings = tomReflectionInfo.createInstance<Settings>();
    tomReflectionInfo.setValues(settings, {
      'stringSettings': {
        'theme': 'dark',
        'language': 'en',
        'region': 'US',
      },
      'intSettings': {
        'maxItems': 100,
        'pageSize': 20,
        'timeout': 30,
      },
      'boolSettings': {
        'notifications': true,
        'analytics': false,
        'autoSave': true,
      },
    });

    print('   String settings: ${settings.stringSettings}');
    print('   Int settings: ${settings.intSettings}');
    print('   Bool settings: ${settings.boolSettings}');

    CollectionsExample.settings = settings;

    // Assertions
    assert(settings.stringSettings['theme'] == 'dark', 'Theme should be dark');
    assert(settings.intSettings['maxItems'] == 100, 'Max items should be 100');
    assert(settings.boolSettings['notifications'] == true, 'Notifications should be true');
  }

  // -------------------------------------------------------------------------
  // Example 4: Article with tags and metadata
  // -------------------------------------------------------------------------
  static void example4ArticleWithCollections() {
    print('\n4. Article with tags and metadata:');

    final article = tomReflectionInfo.createInstance<Article>();
    tomReflectionInfo.setValues(article, {
      'title': 'Introduction to Dart Reflection',
      'content': 'This article explains how to use reflection in Dart...',
      'tags': ['dart', 'reflection', 'tutorial', 'programming'],
      'metadata': {
        'author': 'Jane Developer',
        'publishDate': '2024-01-15',
        'category': 'Programming',
        'readTime': '5 min',
      },
    });

    print('   Title: ${article.title}');
    print('   Tags: ${article.tags}');
    print('   Metadata:');
    article.metadata.forEach((key, value) {
      print('   - $key: $value');
    });

    CollectionsExample.article = article;

    // Assertions
    assert(article.tags.length == 4, 'Should have 4 tags');
    assert(article.metadata['author'] == 'Jane Developer', 'Author should match');
  }

  // -------------------------------------------------------------------------
  // Example 5: Serializing collections
  // -------------------------------------------------------------------------
  static void example5SerializeCollections() {
    print('\n5. Serializing collections:');

    final cart = ShoppingCart()
      ..cartId = 'SER-001'
      ..customerId = 'CUST-999'
      ..items.addAll([
        Item()
          ..id = 'I1'
          ..name = 'Item One'
          ..price = 10.0,
        Item()
          ..id = 'I2'
          ..name = 'Item Two'
          ..price = 20.0,
      ])
      ..total = 30.0;

    final json = tomReflectionInfo.convertToJsonString(cart);
    print('   JSON: $json');

    // Restore
    final restored = ShoppingCart();
    tomReflectionInfo.convertFromJsonString(restored, json);

    print('   Restored cart ID: ${restored.cartId}');
    print('   Restored items count: ${restored.items.length}');

    // Assertions
    assert(json.contains('Item One'), 'JSON should contain Item One');
    assert(restored.items.length == 2, 'Should restore 2 items');
    assert(restored.items[0].name == 'Item One', 'First item should be Item One');
  }

  // -------------------------------------------------------------------------
  // Example 6: Empty collections
  // -------------------------------------------------------------------------
  static void example6EmptyCollections() {
    print('\n6. Empty collections:');

    final lists = tomReflectionInfo.createInstance<PrimitiveLists>();
    tomReflectionInfo.setValues(lists, {
      'tags': [],
      'scores': [],
    });

    print('   Empty tags: ${lists.tags}');
    print('   Empty scores: ${lists.scores}');
    print('   Is tags empty: ${lists.tags.isEmpty}');

    // Assertions
    assert(lists.tags.isEmpty, 'Tags should be empty');
    assert(lists.scores.isEmpty, 'Scores should be empty');
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static void run() {
    print('=== 03: Collections Example ===\n');

    example1PrimitiveLists();
    example2ObjectList();
    example3PrimitiveMaps();
    example4ArticleWithCollections();
    example5SerializeCollections();
    example6EmptyCollections();

    print('\n=== Collections Example Complete ===\n');
  }
}

void run() => CollectionsExample.run();

void main() => run();
