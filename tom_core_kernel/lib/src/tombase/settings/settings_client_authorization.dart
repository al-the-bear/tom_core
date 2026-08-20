/// Client authorization and settings retrieval module.
///
/// This library provides the message and result classes for retrieving
/// client-specific settings, authorization information, and localization
/// data from the server.
///
/// The settings system allows clients to:
/// - Request configuration and text resources from the server
/// - Receive authorization context (groups, roles, entitlements)
/// - Obtain localization preferences (country, language, timezone)
///
/// ## Example
///
/// ```dart
/// // Create a settings request with authorization token
/// final message = TomGetSettingsMessage()
///   ..authorizationToken = 'Bearer xyz123';
///
/// // Process the result
/// final result = await settingsService.getSettings(message);
/// print('User roles: ${result.roles}');
/// print('Config: ${result.config}');
/// ```
library;

// =============================================================================
// Imports
// =============================================================================

import '../observable/tom_observable_objects.dart';

// =============================================================================
// Settings Request Message
// =============================================================================

/// Message class for requesting client settings from the server.
///
/// This class encapsulates the authorization token needed to authenticate
/// the settings request. The server uses this token to determine which
/// settings and permissions to return.
///
/// ## Usage
///
/// ```dart
/// final message = TomGetSettingsMessage()
///   ..authorizationToken = 'Bearer your-jwt-token';
/// ```
///
/// See also:
/// - [TomGetSettingsResult] for the response containing settings data
@tomReflector
class TomGetSettingsMessage {
  /// The authorization token for authenticating the settings request.
  ///
  /// Typically a JWT bearer token obtained from the authentication process.
  /// If null or empty, the server may return default/anonymous settings.
  String? authorizationToken = "";
}

// =============================================================================
// Settings Response Result
// =============================================================================

/// Result class containing client settings, authorization data, and localization.
///
/// This class represents the server's response to a settings request,
/// containing everything a client needs to configure itself:
///
/// - **Resources**: Text strings and configuration values for UI rendering
/// - **Authorization**: User's groups, roles, entitlements, and resource access
/// - **Localization**: Country, language, and timezone preferences
///
/// ## Properties Overview
///
/// | Category | Properties |
/// |----------|------------|
/// | Resources | [texts], [config] |
/// | Authorization | [groups], [roles], [entitlements], [resourceKeys] |
/// | Context | [organization], [process], [application] |
/// | Localization | [country], [language], [clientCountry], [clientLanguage], [clientTimeZone] |
///
/// ## Example
///
/// ```dart
/// final result = TomGetSettingsResult(
///   texts: {'welcome': 'Hello, World!'},
///   config: {'theme': 'dark', 'maxItems': 50},
///   roles: ['admin', 'editor'],
///   groups: ['staff'],
///   entitlements: ['read', 'write'],
///   resourceKeys: ['dashboard', 'reports'],
///   organization: 'acme-corp',
///   clientLanguage: 'en',
///   clientCountry: 'US',
/// );
///
/// // Access localized text
/// final welcomeText = result.texts['welcome'];
///
/// // Check user authorization
/// if (result.roles.contains('admin')) {
///   // Show admin features
/// }
/// ```
@tomReflector
class TomGetSettingsResult {
  // ---------------------------------------------------------------------------
  // Resources and Configuration
  // ---------------------------------------------------------------------------

  /// Localized text resources for UI rendering.
  ///
  /// A key-value map where keys are text identifiers and values are
  /// the localized strings. Used for labels, messages, and other
  /// user-facing text.
  Map<String, Object?> texts;

  /// Application configuration settings.
  ///
  /// A key-value map containing configuration options that control
  /// application behavior. Values can be of various types (strings,
  /// numbers, booleans, nested maps).
  Map<String, Object?> config;

  // ---------------------------------------------------------------------------
  // Client Authorization Information
  // ---------------------------------------------------------------------------

  /// Security groups the user belongs to.
  ///
  /// Groups are typically used for coarse-grained access control.
  /// Note: These may differ from what was sent in the request,
  /// as the server determines the authoritative group membership.
  List<String> groups;

  /// Roles assigned to the user.
  ///
  /// Roles define what actions a user can perform within the application.
  /// Common examples: 'admin', 'editor', 'viewer'.
  List<String> roles;

  /// Specific entitlements granted to the user.
  ///
  /// Entitlements are fine-grained permissions for specific features
  /// or operations. Examples: 'create-report', 'delete-user'.
  List<String> entitlements;

  /// Resource keys the user has access to.
  ///
  /// Identifies specific resources (screens, modules, data sets)
  /// that the user is permitted to access.
  List<String> resourceKeys;

  // ---------------------------------------------------------------------------
  // Application Context
  // ---------------------------------------------------------------------------

  /// The organization context for this session.
  ///
  /// May differ from the requested organization if the server
  /// applies defaults or overrides.
  ///
  /// Defaults to null (the constructor's initializing formal supplies the
  /// value; there is no field-level default).
  String? organization;

  /// The business process context.
  ///
  /// Identifies which business process or workflow is active.
  String? process;

  /// The application identifier.
  ///
  /// Specifies which application configuration to use.
  String? application;

  // ---------------------------------------------------------------------------
  // Localization Settings
  // ---------------------------------------------------------------------------

  /// Server-determined country setting.
  ///
  /// The country code used for server-side localization decisions.
  /// May differ from [clientCountry] based on server configuration.
  String? country;

  /// Server-determined language setting.
  ///
  /// The language code used for server-side localization.
  /// May differ from [clientLanguage] based on server configuration.
  String? language;

  /// Client's preferred country code.
  ///
  /// The country setting as determined by or requested from the client.
  /// Follows ISO 3166-1 alpha-2 format (e.g., 'US', 'GB', 'DE').
  String? clientCountry;

  /// Client's preferred language code.
  ///
  /// The language setting as determined by or requested from the client.
  /// Follows ISO 639-1 format (e.g., 'en', 'de', 'fr').
  String? clientLanguage;

  /// Client's timezone identifier.
  ///
  /// The timezone used for date/time display and calculations.
  /// Uses IANA timezone database identifiers (e.g., 'America/New_York').
  String? clientTimeZone;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a new [TomGetSettingsResult] instance.
  ///
  /// All collection parameters default to fresh, empty **mutable** collections
  /// (a new instance per result), so callers can mutate them in place — e.g.
  /// `result.roles.add(...)` or `result.config['k'] = v`. All string parameters
  /// default to null.
  TomGetSettingsResult({
    Map<String, Object?>? texts,
    Map<String, Object?>? config,
    List<String>? groups,
    List<String>? roles,
    List<String>? entitlements,
    List<String>? resourceKeys,
    this.organization,
    this.process,
    this.application,
    this.country,
    this.language,
    this.clientLanguage,
    this.clientCountry,
    this.clientTimeZone,
  }) : texts = texts ?? <String, Object?>{},
       config = config ?? <String, Object?>{},
       groups = groups ?? <String>[],
       roles = roles ?? <String>[],
       entitlements = entitlements ?? <String>[],
       resourceKeys = resourceKeys ?? <String>[];
}
