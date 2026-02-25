# Tom Execution Context System

The Tom Execution Context System provides zone-based context propagation for passing request-scoped values through synchronous and asynchronous call chains without explicit parameter passing.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
  - [TomExecutionContext](#tomexecutioncontext)
  - [TomContextEntry](#tomcontextentry)
  - [TomContextProviders](#tomcontextproviders)
- [Context Propagation](#context-propagation)
- [Context Composition](#context-composition)
- [Default Context](#default-context)
- [Best Practices](#best-practices)

## Overview

The context system consists of three main components:

1. **`TomExecutionContext`**: Container for context entries that runs code in a Dart Zone with those values available.

2. **`TomContextEntry<T>`**: A typed wrapper for a function that provides a context value.

3. **`TomContextProviders`**: Static methods that extract common values from the current zone's `TomPrincipal`.

### How It Works

1. Create a `TomExecutionContext` with named entries
2. Call `runInContext()` or `runInContextAsync()` with your code
3. Inside that code, use `getFromCurrentZone<T>()` to retrieve values
4. Context flows automatically through async boundaries

## Quick Start

```dart
import 'package:tom_core/tom_core.dart';

void main() {
  // Create a context with custom values
  final context = TomExecutionContext({
    'requestId': TomContextEntry<String>(() => 'req-12345'),
    'userId': TomContextEntry<int>(() => 42),
  });

  // Run code within the context
  context.runInContext(() {
    processRequest();
  });
}

void processRequest() {
  // Access context from anywhere in the zone
  final ctx = getFromCurrentZone<TomExecutionContext>();
  final requestId = ctx?.contextMap['requestId']?.contextFunction();
  print('Processing request: $requestId');
}
```

## Core Components

### TomExecutionContext

The main context container that stores named entries and runs code in a zone.

#### Creating a Context

```dart
// Empty context
final context = TomExecutionContext({});

// With entries
final context = TomExecutionContext({
  'tenant': TomContextEntry<String>(() => 'acme-corp'),
  'user': TomContextEntry<User>(() => currentUser),
});

// With parent context (entries are inherited)
final childContext = TomExecutionContext(
  {'childKey': TomContextEntry(() => 'value')},
  parentContext: parentContext,
);
```

#### Getting Context Entries

```dart
// Get entry by name with type checking
final entry = context.getEntry<String>('tenant');
final value = entry?.value;  // Access via value getter

// Static method to get value from current zone
final userId = TomExecutionContext.getValueFromCurrentZone<String>('userId');
```

#### Modifying a Context

```dart
final context = TomExecutionContext({});

// Add entries
context.add('locale', TomContextEntry<String>(() => 'en-US'));

// Merge another context
final otherContext = TomExecutionContext({'theme': TomContextEntry(() => 'dark')});
context.combineWith(otherContext);

// Clear all entries
context.clear();
```

#### Running Code in Context

```dart
// Synchronous
final result = context.runInContext(() {
  return computeValue();
});

// Asynchronous
final result = await context.runInContextAsync(() async {
  return await fetchData();
});

// With additional zone values
context.runInContext(() {
  // Custom zone values available
}, zoneValues: {'customKey': 'customValue'});
```

### TomContextEntry

A typed wrapper for lazy value providers.

#### Creating Entries

```dart
// Static value
final entry = TomContextEntry<String>(() => 'constant-value');

// Dynamic value (computed each access)
final entry = TomContextEntry<DateTime>(() => DateTime.now());
```

#### Accessing Values

```dart
// Via contextFunction (original method)
final value = entry.contextFunction();

// Via value getter (recommended)
final value = entry.value;

// Via call operator (shortest)
final value = entry();

// Via ~ operator (alternative)
final value = ~entry;

// Value from another zone value
final entry = TomContextEntry<String>(() {
  return getFromCurrentZone<TomPrincipal>()?.organization ?? 'default';
});
```

### TomContextProviders

Static methods for extracting common values from `TomPrincipal`:

```dart
// Organization/tenant info
TomContextProviders.getOrganization()  // Returns 'default' if no principal
TomContextProviders.getApplication()
TomContextProviders.getProcess()

// Server locale
TomContextProviders.getLanguage()      // Returns 'en' if no principal
TomContextProviders.getCountry()       // Returns 'XX' if no principal
TomContextProviders.getTimezone()      // Returns 'utc' if no principal

// Client locale
TomContextProviders.getClientLanguage()
TomContextProviders.getClientCountry()
TomContextProviders.getClientTimezone()
```

## Context Propagation

Context values automatically propagate through async boundaries:

```dart
final context = TomExecutionContext({
  'traceId': TomContextEntry<String>(() => generateTraceId()),
});

await context.runInContextAsync(() async {
  // TraceId available here
  await step1();
  
  // Still available after await
  await step2();
  
  // And in nested async calls
  await step3();
});

Future<void> step1() async {
  final ctx = getFromCurrentZone<TomExecutionContext>();
  // TraceId still accessible
}
```

## Context Composition

Contexts can be nested, with inner contexts overriding outer values:

```dart
final tenantContext = TomExecutionContext({
  'tenant': TomContextEntry<String>(() => 'acme'),
});

final userContext = TomExecutionContext({
  'user': TomContextEntry<String>(() => 'john'),
});

final requestContext = TomExecutionContext({
  'requestId': TomContextEntry<String>(() => 'req-123'),
  'tenant': TomContextEntry<String>(() => 'override-tenant'),
});

tenantContext.runInContext(() {
  // tenant = 'acme'
  
  userContext.runInContext(() {
    // tenant = 'acme', user = 'john'
    
    requestContext.runInContext(() {
      // tenant = 'override-tenant', user = 'john', requestId = 'req-123'
    });
  });
});
```

## Default Context

The `tomExecutionContext` global provides a pre-configured context with standard providers:

```dart
// Pre-configured entries:
// - organization, application, process
// - language, country, timezone
// - clientLanguage, clientCountry, clientTimezone

tomExecutionContext.runInContext(() {
  // All standard context values available
  final org = TomContextProviders.getOrganization();
  final lang = TomContextProviders.getLanguage();
});
```

## Best Practices

### 1. Use Type-Safe Entries

Always specify the type parameter for type safety:

```dart
// Good
TomContextEntry<String>(() => 'value')
TomContextEntry<User>(() => currentUser)

// Avoid
TomContextEntry(() => 'value')  // Type inferred as dynamic
```

### 2. Handle Missing Context

Always check for null when retrieving context:

```dart
final ctx = getFromCurrentZone<TomExecutionContext>();
if (ctx == null) {
  // Handle case where code runs outside context
  return defaultValue;
}
```

### 3. Create Context Once

Create contexts at request boundaries, not inside loops:

```dart
// Good: Create once per request
void handleRequest(Request req) {
  final context = TomExecutionContext({
    'requestId': TomContextEntry(() => req.id),
  });
  
  context.runInContext(() => processRequest(req));
}

// Avoid: Creating context in inner loops
```

### 4. Use Async Version for Async Code

Use `runInContextAsync` for async code to ensure proper zone handling:

```dart
// Good
await context.runInContextAsync(() async {
  await asyncOperation();
});

// May have issues
context.runInContext(() {
  asyncOperation();  // Zone might not propagate correctly
});
```

### 5. Document Context Dependencies

Document which context values your functions expect:

```dart
/// Processes the order.
/// 
/// Requires the following context entries:
/// - `userId`: The current user's ID
/// - `tenantId`: The tenant identifier
Future<void> processOrder(Order order) async {
  final ctx = getFromCurrentZone<TomExecutionContext>()!;
  final userId = ctx.contextMap['userId']!.contextFunction();
  // ...
}
```

---

## Dependencies

This module depends on:

- **Little Things Module**: Zone utilities for context propagation
- **Security Module**: `TomPrincipal` for authenticated user context
