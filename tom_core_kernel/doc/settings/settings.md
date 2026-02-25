# Settings Module

The Settings module provides client-server communication for retrieving application settings, authorization information, and localization preferences.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

This module enables clients to:
- Request configuration and text resources from the server
- Receive user authorization context (groups, roles, entitlements)
- Obtain localization preferences (country, language, timezone)

The settings system follows a request-response pattern where the client sends a `TomGetSettingsMessage` and receives a `TomGetSettingsResult` containing all necessary configuration data.

## Quick Start

### 1. Import the Module

```dart
import 'package:tom_core/src/tombase/settings/settings_client_authorization.dart';
```

### 2. Create a Settings Request

```dart
final message = TomGetSettingsMessage()
  ..authorizationToken = 'Bearer your-jwt-token';
```

### 3. Process the Response

```dart
final result = await settingsService.getSettings(message);

// Access configuration
final theme = result.config['theme'];

// Access localized text
final welcomeMessage = result.texts['welcome'];

// Check authorization
if (result.roles.contains('admin')) {
  // Enable admin features
}
```

## Core Components

### TomGetSettingsMessage

The request message for fetching settings from the server.

| Property | Type | Description |
|----------|------|-------------|
| `authorizationToken` | `String?` | JWT bearer token for authentication |

### TomGetSettingsResult

The response containing all settings data.

#### Resources

| Property | Type | Description |
|----------|------|-------------|
| `texts` | `Map<String, Object?>` | Localized text resources for UI |
| `config` | `Map<String, Object?>` | Application configuration values |

#### Authorization

| Property | Type | Description |
|----------|------|-------------|
| `groups` | `List<String>` | Security groups the user belongs to |
| `roles` | `List<String>` | Roles assigned to the user |
| `entitlements` | `List<String>` | Fine-grained permissions |
| `resourceKeys` | `List<String>` | Accessible resource identifiers |

#### Application Context

| Property | Type | Description |
|----------|------|-------------|
| `organization` | `String?` | Organization context |
| `process` | `String?` | Business process identifier |
| `application` | `String?` | Application identifier |

#### Localization

| Property | Type | Description |
|----------|------|-------------|
| `country` | `String?` | Server-side country code |
| `language` | `String?` | Server-side language code |
| `clientCountry` | `String?` | Client's preferred country (ISO 3166-1) |
| `clientLanguage` | `String?` | Client's preferred language (ISO 639-1) |
| `clientTimeZone` | `String?` | Client's timezone (IANA format) |

## Usage Examples

### Basic Settings Retrieval

```dart
Future<void> initializeApp() async {
  final message = TomGetSettingsMessage()
    ..authorizationToken = authService.currentToken;
  
  final settings = await settingsService.getSettings(message);
  
  // Apply configuration
  appConfig.theme = settings.config['theme'] as String?;
  appConfig.maxItems = settings.config['maxItems'] as int? ?? 50;
  
  // Store localization
  localization.language = settings.clientLanguage ?? 'en';
  localization.country = settings.clientCountry ?? 'US';
}
```

### Role-Based Feature Access

```dart
Widget buildDashboard(TomGetSettingsResult settings) {
  return Column(
    children: [
      // Always visible
      UserProfileCard(),
      
      // Only for users with 'reports' entitlement
      if (settings.entitlements.contains('view-reports'))
        ReportsWidget(),
      
      // Only for admins
      if (settings.roles.contains('admin'))
        AdminPanel(),
    ],
  );
}
```

### Localized Text Display

```dart
String getLocalizedText(TomGetSettingsResult settings, String key) {
  return settings.texts[key]?.toString() ?? 'Missing: $key';
}

// Usage
final welcomeText = getLocalizedText(settings, 'welcome_message');
final errorText = getLocalizedText(settings, 'error_generic');
```

### Multi-Tenant Configuration

```dart
void configureForTenant(TomGetSettingsResult settings) {
  print('Organization: ${settings.organization}');
  print('Application: ${settings.application}');
  print('Process: ${settings.process}');
  
  // Apply tenant-specific branding from config
  final brandConfig = settings.config['branding'] as Map<String, dynamic>?;
  if (brandConfig != null) {
    applyBranding(brandConfig);
  }
}
```

## Best Practices

### 1. Cache Settings Appropriately

Settings don't change frequently. Cache the result and refresh periodically or on specific events:

```dart
class SettingsCache {
  TomGetSettingsResult? _cached;
  DateTime? _lastFetch;
  
  Future<TomGetSettingsResult> getSettings() async {
    if (_cached != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!) < Duration(minutes: 15)) {
        return _cached!;
      }
    }
    
    _cached = await _fetchFromServer();
    _lastFetch = DateTime.now();
    return _cached!;
  }
}
```

### 2. Handle Missing Values Gracefully

Always provide defaults for optional settings:

```dart
final pageSize = (settings.config['pageSize'] as int?) ?? 20;
final language = settings.clientLanguage ?? 'en';
```

### 3. Validate Authorization Early

Check required roles/entitlements at app startup:

```dart
void validateAccess(TomGetSettingsResult settings) {
  if (!settings.roles.contains('user')) {
    throw UnauthorizedException('User role required');
  }
}
```

### 4. Separate Concerns

Keep authorization checks separate from UI logic:

```dart
class AuthorizationService {
  final TomGetSettingsResult settings;
  
  AuthorizationService(this.settings);
  
  bool canViewReports() => settings.entitlements.contains('view-reports');
  bool canEditUsers() => settings.roles.contains('admin');
  bool hasResourceAccess(String key) => settings.resourceKeys.contains(key);
}
```

### 5. Use Type-Safe Configuration Access

Create typed accessors for configuration values:

```dart
extension ConfigExtensions on TomGetSettingsResult {
  int get maxUploadSize => (config['maxUploadSize'] as int?) ?? 10485760;
  bool get darkModeEnabled => (config['darkMode'] as bool?) ?? false;
  String get apiVersion => (config['apiVersion'] as String?) ?? 'v1';
}
```

---

## Dependencies

This module depends on:

- **Security Module**: For authentication tokens
- **Resources Module**: For text and configuration resource handling
