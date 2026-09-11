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
/// This library declares only the two DTOs; the exchange itself runs over
/// `TomServerEndpoint` from the `http_connection` module — settings is an
/// ordinary bearer-authenticated endpoint of the API server, not part of the
/// authentication exchange. Building an endpoint opens no connection.
///
/// ```dart
/// final endpoint =
///     TomServerEndpoint<TomGetSettingsMessage, TomGetSettingsResult>(
///       TomServerChannel('api.example.com', 443),
///       TomServerCallSpecs(
///         'POST',
///         Uri.parse('https://api.example.com/settings'),
///         includeBearerAuthentication: true,
///       ),
///     );
///
/// // Create a settings request with authorization token
/// final message = TomGetSettingsMessage()
///   ..authorizationToken = TomBearerAuthentication.authorizationToken;
///
/// // Process the result
/// final (result, error) = await endpoint.send(message);
/// if (error?.hasError ?? false) return;
///
/// print('User roles: ${result.roles}');
/// print('Config: ${result.config}');
/// ```
///
/// A real client takes the host and URI from
/// `TomClientRemoteContext.current!.baseUri` rather than spelling them out.
library;

// =============================================================================
// Imports
// =============================================================================

// `@tomReflector` is the only thing this module needs from the rest of the
// package, and it is declared here. The observable module re-exports it, but
// importing it from there would suggest a coupling to observable's own API
// that does not exist.
import '../reflection/reflection.dart';

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
  /// `null` when the client sent none — however the message was built, since
  /// the field has no initializer, exactly like every string on
  /// [TomGetSettingsResult]. A server treats `null` and an empty string alike,
  /// as an anonymous request, and may answer with default settings.
  String? authorizationToken;
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
/// | Localization | [country], [language], [timezone], [clientCountry], [clientLanguage], [clientTimezone] |
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
///
/// ## Mutable on the client too, by design
///
/// Every field is public and assignable, and the collections are plain `List`
/// and `Map`, on the client as on the server. The reflected deserializer needs
/// assignable fields, and the authorization lists here decide only what a
/// client *shows*: the server judges every call against the principal in the
/// bearer token, so a client editing its copy changes its own screen and
/// grants itself nothing. Code that wants to protect itself from editing the
/// answer takes an unmodifiable snapshot where it receives it.
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
  //
  // The six localization strings carry *conventional* formats, not validated
  // ones: country and language are usually ISO codes and the two timezones
  // IANA identifiers, but each is a plain string and nothing checks it — not
  // the constructor, not the reflected deserializer. A DTO that refused an
  // unexpected value would turn one odd field into a failed settings request,
  // and a deployment may need a code outside the standard (a regional
  // language tag, an internal country code). A consumer that relies on a
  // format validates it where it uses the value.
  // ---------------------------------------------------------------------------

  /// Server-determined country setting.
  ///
  /// The country the server resolved for server-side localization decisions.
  /// Conventionally an ISO 3166-1 alpha-2 code (`'US'`, `'GB'`, `'DE'`), but
  /// a plain string: nothing validates it, and a deployment may use another
  /// scheme. May differ from [clientCountry] based on server configuration.
  String? country;

  /// Server-determined language setting.
  ///
  /// The language the server resolved for server-side localization.
  /// Conventionally an ISO 639-1 code (`'en'`, `'de'`, `'fr'`), but a plain
  /// string: nothing validates it, and a deployment may need a regional tag
  /// such as `'de-CH'`. May differ from [clientLanguage] based on server
  /// configuration.
  String? language;

  /// Server-determined timezone setting.
  ///
  /// The timezone identifier the server resolved for this session —
  /// conventionally an IANA identifier, not validated — set
  /// when the deployment pins a timezone (a tenant fixed to one, say) or when
  /// it declines the client's request. May differ from [clientTimezone] based
  /// on server configuration.
  ///
  /// This completes the server/client pairing the other two localization
  /// concepts already had. Without it a client could not tell whether the
  /// timezone it got back was its own preference echoed or a server decision,
  /// because there was only ever one field to read. Compare the two to detect
  /// an override:
  ///
  /// ```dart
  /// final effective = result.timezone ?? result.clientTimezone;
  /// final overridden =
  ///     result.timezone != null && result.timezone != result.clientTimezone;
  /// ```
  ///
  /// `null` means the server expressed no opinion, which is not the same as
  /// agreeing with the client — see [country] and [language] for the same
  /// convention.
  String? timezone;

  /// Client's preferred country code.
  ///
  /// The country setting as determined by or requested from the client.
  /// Conventionally an ISO 3166-1 alpha-2 code (`'US'`, `'GB'`, `'DE'`); not
  /// validated.
  String? clientCountry;

  /// Client's preferred language code.
  ///
  /// The language setting as determined by or requested from the client.
  /// Conventionally an ISO 639-1 code (`'en'`, `'de'`, `'fr'`); not validated,
  /// so a regional tag such as `'de-CH'` passes through unchanged.
  String? clientLanguage;

  /// Client's timezone identifier.
  ///
  /// The timezone used for date/time display and calculations.
  /// Conventionally an IANA timezone database identifier
  /// (`'America/New_York'`); not validated, so a consumer that resolves the
  /// zone checks it there — `TomTimezone.fromName` answers `null` for an
  /// identifier the database does not know.
  String? clientTimezone;

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
    this.timezone,
    this.clientLanguage,
    this.clientCountry,
    this.clientTimezone,
  }) : texts = texts ?? <String, Object?>{},
       config = config ?? <String, Object?>{},
       groups = groups ?? <String>[],
       roles = roles ?? <String>[],
       entitlements = entitlements ?? <String>[],
       resourceKeys = resourceKeys ?? <String>[];
}
