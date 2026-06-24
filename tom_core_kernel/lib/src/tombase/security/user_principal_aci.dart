/// User identity, principal, and access control information types.
///
/// This library provides the core data structures for representing
/// authenticated users and their access rights in the Tom framework.
///
/// ## Key Concepts
///
/// - **User**: Basic identity information (name, email, etc.)
/// - **Principal**: Authenticated session with full context
/// - **ACI**: Access Control Information (roles, groups, entitlements)
/// - **CLI**: Client Limits Information (quotas, enabled features)
///
/// ## Authorization Model
///
/// The framework supports flexible authorization:
///
/// 1. **Roles**: Job functions (admin, manager, user)
/// 2. **Groups**: Organizational units (can be nested)
/// 3. **Entitlements**: Fine-grained permissions
/// 4. **Resource Keys**: Field-level access control
///
/// ## Usage Example
///
/// ```dart
/// // Check user's roles
/// var principal = TomBearerAuthentication.getPrincipal();
/// if (principal.aci.roles.contains('admin')) {
///   showAdminPanel();
/// }
///
/// // Access user information
/// print('Hello, ${principal.user.firstname}');
/// print('Organization: ${principal.organization}');
/// ```
///
/// See also:
/// - [TomAccessControl] for access control annotations
/// - [TomBearerAuthentication] for token management
library;

// =============================================================================
// ACCESS CONTROL INFORMATION
// =============================================================================

/// Groups together authorization information for a user.
///
/// The exact meaning of "roles", "groups", "entitlements" and "resourceKeys"
/// depends on the authorization concept of your application.
///
/// ## Authorization Concepts
///
/// - **Roles**: Job functions or responsibilities (e.g., 'admin', 'user')
/// - **Groups**: Organizational units; can be nested with inheritance
/// - **Entitlements**: Fine-grained permissions for features
/// - **Resource Keys**: Field-level access control identifiers
///
/// ## Simplified Authorization
///
/// For simple applications, you can use just one approach:
///
/// 1. Public vs. authenticated users only
/// 2. Role-based access control (RBAC)
/// 3. Group-based access control
/// 4. Entitlement-based access control
/// 5. Resource key-based access control
///
/// Mixing approaches is supported but not encouraged.
///
/// ## Example
///
/// ```dart
/// var aci = TomAccessControlInformation(
///   roles: ['admin', 'user'],
///   groups: ['engineering'],
///   entitlements: ['feature.reports.view'],
///   resourceKeys: ['user.email', 'user.phone'],
/// );
///
/// if (aci.roles.contains('admin')) {
///   // Grant admin access
/// }
/// ```
///
/// During login, these fields must be populated from your authorization
/// system. The definitions may change over time through administration.
class TomAccessControlInformation {
  final List<String> _roles = [];

  /// Unmodifiable list of roles assigned to the user.
  List<String> get roles => List.unmodifiable(_roles);

  final List<String> _groups = [];

  /// Unmodifiable list of groups the user belongs to.
  List<String> get groups => List.unmodifiable(_groups);

  final List<String> _entitlements = [];

  /// Unmodifiable list of entitlements granted to the user.
  List<String> get entitlements => List.unmodifiable(_entitlements);

  final List<String> _resourceKeys = [];

  /// Unmodifiable list of resource keys the user can access.
  List<String> get resourceKeys => List.unmodifiable(_resourceKeys);

  /// Creates access control information.
  ///
  /// All lists are optional and default to empty.
  TomAccessControlInformation({
    List<String> roles = const [],
    List<String> entitlements = const [],
    List<String> resourceKeys = const [],
    List<String> groups = const [],
  }) {
    if (roles.isNotEmpty) _roles.addAll(roles);
    if (entitlements.isNotEmpty) _entitlements.addAll(entitlements);
    if (resourceKeys.isNotEmpty) _resourceKeys.addAll(resourceKeys);
    if (groups.isNotEmpty) _groups.addAll(groups);
  }

  @override
  String toString() =>
      "ACI ${roles.length} roles, ${entitlements.length} entitlements, ${resourceKeys.length} resource key, ${groups.length} groups.";
}

// =============================================================================
// CLIENT LIMITS INFORMATION
// =============================================================================

/// Controls system capabilities independent of user rights.
///
/// This class enforces subscription-based limits and feature flags.
/// Even if a user has the rights to access a feature, it may be
/// disabled or quota-limited based on the client's subscription.
///
/// ## Use Cases
///
/// - Feature flags for gradual rollouts
/// - Subscription tier limits (e.g., API call quotas)
/// - Module enablement per client
///
/// ## Example
///
/// ```dart
/// var cli = TomClientLimitsInformation(
///   enabledModules: ['core', 'reporting'],
///   quotas: {'api_calls': 1000, 'storage_mb': 500},
/// );
///
/// if (cli.enabledModules.contains('reporting')) {
///   // Show reporting features
/// }
///
/// if (currentUsage < cli.quotas['api_calls']!) {
///   // Allow API call
/// }
/// ```
// TODO: determine where to get this from...
class TomClientLimitsInformation {
  /// List of module names that are enabled for this client.
  List<String> enabledModules;

  /// Map of quota names to their limits.
  Map<String, int> quotas;
  TomClientLimitsInformation({
    this.enabledModules = const [],
    this.quotas = const {},
  });

  @override
  String toString() => "CLI ${enabledModules.length} modules, quotas: $quotas.";
}

// =============================================================================
// ACCESS CONTROL DEFINITION
// =============================================================================

/// Global ACI schema definition for resolving complete permissions.
///
/// This class defines the authorization model for the application,
/// specifying how roles, groups, and entitlements relate to each other
/// and to resource keys.
///
/// ## Inheritance Model
///
/// - **Roles** can include other roles, grant group memberships,
///   entitlements, and resource keys
/// - **Groups** can include roles, other groups, entitlements,
///   and resource keys
/// - **Entitlements** can include other entitlements and resource keys
///
/// ## Resolution Process
///
/// When [completeFromDefinition] is called with a user's basic ACI,
/// it recursively resolves all inherited permissions to produce
/// the complete set of effective permissions.
///
/// ## Example
///
/// ```dart
/// var definition = TomAccessControlDefinition(
///   roles: [
///     TomRole(
///       name: 'admin',
///       entitlements: ['admin.*'],
///       resourceKeys: ['*'],
///     ),
///     TomRole(
///       name: 'user',
///       entitlements: ['feature.read'],
///     ),
///   ],
///   groups: [
///     TomGroup(
///       name: 'engineering',
///       rolesIncluded: ['user'],
///     ),
///   ],
/// );
///
/// // Resolve complete permissions for a user
/// var completeAci = definition.completeFromDefinition(userAci);
/// ```
class TomAccessControlDefinition {
  /// Maps entitlement names to their definitions.
  final Map<String, TomEntitlement> _entitlementDefinitions = {};

  /// Maps group names to their definitions.
  final Map<String, TomGroup> _groupDefinitions = {};

  /// Maps role names to their definitions.
  final Map<String, TomRole> _roleDefinitions = {};

  /// Creates an access control definition.
  ///
  /// - [roles]: List of role definitions
  /// - [groups]: List of group definitions
  /// - [entitlements]: List of entitlement definitions
  TomAccessControlDefinition({
    List<TomRole>? roles,
    List<TomGroup>? groups,
    List<TomEntitlement>? entitlements,
  }) {
    if (roles != null) {
      for (var r in roles) {
        _roleDefinitions[r.name] = r;
      }
    }
    if (groups != null) {
      for (var g in groups) {
        _groupDefinitions[g.name] = g;
      }
    }
    if (entitlements != null) {
      for (var e in entitlements) {
        _entitlementDefinitions[e.name] = e;
      }
    }
  }

  @override
  String toString() =>
      "ACD ${_roleDefinitions.length} roles, ${_entitlementDefinitions.length} entitlements, ${_groupDefinitions.length} groups.";

  /// Resolves complete permissions from a user's basic ACI.
  ///
  /// Takes the user's directly assigned roles, groups, entitlements,
  /// and resource keys, then recursively resolves all inherited
  /// permissions based on this definition.
  ///
  /// - [userProvided]: The user's directly assigned permissions
  ///
  /// Returns a new [TomAccessControlInformation] with all effective
  /// permissions resolved.
  TomAccessControlInformation completeFromDefinition(
    TomAccessControlInformation userProvided,
  ) {
    var start = _TomAci(userProvided);
    var touched =
        _TomAci(); // to avoid repeated recursion on elements already covered

    var result = _complete(start, touched);

    return TomAccessControlInformation(
      roles: result.roles.toList(),
      groups: result.groups.toList(),
      entitlements: result.entitlements.toList(),
      resourceKeys: result.resourceKeys.toList(),
    );
  }

  _TomAci _complete(_TomAci current, _TomAci touched) {
    bool touchedRoles = false;
    // Snapshot each subject set with `.toList()`: the loop body adds inherited
    // members back into the same set, which would otherwise throw a
    // ConcurrentModificationError. Newly-added members are picked up on the
    // next recursion, guarded by `touched` to ensure termination.
    for (var role in current.roles.toList()) {
      if (!touched.roles.contains(role)) {
        TomRole? r = _roleDefinitions[role];
        if (r != null) {
          current.roles.addAll(r.rolesIncluded);
          current.groups.addAll(r.groupMemberShips);
          current.entitlements.addAll(r.entitlements);
          current.resourceKeys.addAll(r.resourceKeys);
        }
        touched.roles.add(role);
        touchedRoles = true;
      }
    }
    bool touchedGroups = false;
    for (var group in current.groups.toList()) {
      if (!touched.groups.contains(group)) {
        TomGroup? g = _groupDefinitions[group];
        if (g != null) {
          current.roles.addAll(g.rolesIncluded);
          current.groups.addAll(g.groupMemberShips);
          current.entitlements.addAll(g.entitlements);
          current.resourceKeys.addAll(g.resourceKeys);
        }
        touched.groups.add(group);
        touchedGroups = true;
      }
    }
    bool touchedEntitlements = false;
    for (var entitlement in current.entitlements.toList()) {
      if (!touched.entitlements.contains(entitlement)) {
        TomEntitlement? e = _entitlementDefinitions[entitlement];
        if (e != null) {
          current.entitlements.addAll(e.entitlements);
          current.resourceKeys.addAll(e.resourceKeys);
        }
        touched.entitlements.add(entitlement);
        touchedEntitlements = true;
      }
    }
    if (touchedRoles || touchedGroups || touchedEntitlements) {
      return _complete(current, touched);
    } else {
      return current;
    }
  }
}

class _TomAci {
  Set<String> roles = {};
  Set<String> groups = {};
  Set<String> entitlements = {};
  Set<String> resourceKeys = {};

  _TomAci([TomAccessControlInformation? userProvided]) {
    if (userProvided != null) {
      roles.addAll(userProvided.roles);
      groups.addAll(userProvided.groups);
      entitlements.addAll(userProvided.entitlements);
      resourceKeys.addAll(userProvided.resourceKeys);
    }
  }
  @override
  String toString() =>
      "_ACI ${roles.length} roles, ${entitlements.length} entitlements, ${resourceKeys.length} resource key, ${groups.length} groups.";
}

// =============================================================================
// AUTHORIZATION ENTITIES
// =============================================================================

/// Represents a group in the authorization model.
///
/// Groups organize users and can inherit permissions from other groups
/// and roles. They're typically used to represent organizational units,
/// teams, or departments.
///
/// ## Inheritance
///
/// Groups can:
/// - Include roles (members get those roles)
/// - Be members of other groups (nested groups)
/// - Have direct entitlements
/// - Have direct resource keys
///
/// ## Example
///
/// ```dart
/// var engineeringGroup = TomGroup(
///   name: 'engineering',
///   rolesIncluded: ['developer'],
///   groupMemberShips: ['all-employees'],
///   entitlements: ['repo.access'],
/// );
/// ```
class TomGroup {
  late String _name;

  /// The unique name of this group.
  String get name => _name;

  List<String> _rolesIncluded = [];

  /// Roles that members of this group inherit.
  List<String> get rolesIncluded => _rolesIncluded;

  List<String> _groupMemberShips = [];

  /// Other groups that this group is a member of.
  List<String> get groupMemberShips => _groupMemberShips;

  List<String> _entitlements = [];

  /// Entitlements directly assigned to this group.
  List<String> get entitlements => _entitlements;

  List<String> _resourceKeys = [];

  /// Resource keys directly accessible to this group.
  List<String> get resourceKeys => _resourceKeys;

  /// Creates a group definition.
  ///
  /// - [name]: Unique identifier for the group (required)
  /// - [rolesIncluded]: Roles inherited by group members
  /// - [groupMemberShips]: Parent groups this group belongs to
  /// - [entitlements]: Direct entitlements for the group
  /// - [resourceKeys]: Direct resource key access
  TomGroup({
    required String name,
    List<String>? rolesIncluded,
    List<String>? groupMemberShips,
    List<String>? entitlements,
    List<String>? resourceKeys,
  }) {
    _name = name;
    _rolesIncluded = rolesIncluded ?? _rolesIncluded;
    _groupMemberShips = groupMemberShips ?? _groupMemberShips;
    _entitlements = entitlements ?? _entitlements;
    _resourceKeys = resourceKeys ?? _resourceKeys;
  }

  @override
  String toString() =>
      "Group $name ${rolesIncluded.length} roles, ${entitlements.length} entitlements, ${resourceKeys.length} resource key, ${groupMemberShips.length} groups.";
}

/// Represents a role in the authorization model.
///
/// Roles define job functions or responsibilities. They're the primary
/// mechanism for role-based access control (RBAC).
///
/// ## Inheritance
///
/// Roles can:
/// - Include other roles (role hierarchies)
/// - Grant group memberships
/// - Have direct entitlements
/// - Have direct resource keys
///
/// ## Example
///
/// ```dart
/// var adminRole = TomRole(
///   name: 'admin',
///   rolesIncluded: ['user'],  // admins get all user permissions
///   entitlements: ['admin.*'],
///   resourceKeys: ['*'],
/// );
///
/// var userRole = TomRole(
///   name: 'user',
///   entitlements: ['feature.read', 'profile.edit'],
/// );
/// ```
class TomRole {
  late String _name;

  /// The unique name of this role.
  String get name => _name;

  List<String> _rolesIncluded = [];

  /// Other roles that this role inherits from.
  List<String> get rolesIncluded => _rolesIncluded;

  List<String> _groupMemberShips = [];

  /// Groups that holders of this role automatically join.
  List<String> get groupMemberShips => _groupMemberShips;

  List<String> _entitlements = [];

  /// Entitlements directly granted by this role.
  List<String> get entitlements => _entitlements;

  List<String> _resourceKeys = [];

  /// Resource keys directly accessible with this role.
  List<String> get resourceKeys => _resourceKeys;

  /// Creates a role definition.
  ///
  /// - [name]: Unique identifier for the role (required)
  /// - [rolesIncluded]: Parent roles to inherit from
  /// - [groupMemberShips]: Groups granted by this role
  /// - [entitlements]: Direct entitlements for the role
  /// - [resourceKeys]: Direct resource key access
  TomRole({
    required String name,
    List<String>? rolesIncluded,
    List<String>? groupMemberShips,
    List<String>? entitlements,
    List<String>? resourceKeys,
  }) {
    _name = name;
    _rolesIncluded = rolesIncluded ?? _rolesIncluded;
    _groupMemberShips = groupMemberShips ?? _groupMemberShips;
    _entitlements = entitlements ?? _entitlements;
    _resourceKeys = resourceKeys ?? _resourceKeys;
  }

  @override
  String toString() =>
      "Role $name ${rolesIncluded.length} roles, ${entitlements.length} entitlements, ${resourceKeys.length} resource key, ${groupMemberShips.length} groups.";
}

/// Represents an entitlement in the authorization model.
///
/// Entitlements are fine-grained permissions that can be assigned
/// to users, groups, or roles. They can include other entitlements
/// and grant access to specific resource keys.
///
/// ## Naming Convention
///
/// Entitlements typically follow a hierarchical naming pattern:
/// - `feature.action` (e.g., `reports.view`)
/// - `module.feature.action` (e.g., `billing.invoices.create`)
///
/// ## Example
///
/// ```dart
/// var readReports = TomEntitlement(
///   name: 'reports.read',
///   resourceKeys: ['report.data', 'report.metadata'],
/// );
///
/// var manageReports = TomEntitlement(
///   name: 'reports.manage',
///   entitlements: ['reports.read', 'reports.create', 'reports.delete'],
/// );
/// ```
class TomEntitlement {
  late String _name;

  /// The unique name of this entitlement.
  String get name => _name;

  List<String> _entitlements = [];

  /// Other entitlements included in this entitlement.
  List<String> get entitlements => _entitlements;

  List<String> _resourceKeys = [];

  /// Resource keys accessible with this entitlement.
  List<String> get resourceKeys => _resourceKeys;

  /// Creates an entitlement definition.
  ///
  /// - [name]: Unique identifier for the entitlement (required)
  /// - [entitlements]: Child entitlements included
  /// - [resourceKeys]: Resource keys granted by this entitlement
  TomEntitlement({
    required String name,
    List<String>? entitlements,
    List<String>? resourceKeys,
  }) {
    _name = name;
    _entitlements = entitlements ?? _entitlements;
    _resourceKeys = resourceKeys ?? _resourceKeys;
  }

  @override
  String toString() =>
      "Entitlement $name  ${entitlements.length} entitlements, ${resourceKeys.length} resource keys.";
}

// =============================================================================
// USER
// =============================================================================

/// Represents a user's identity information.
///
/// Contains basic profile information like name, email, and contact
/// details. This is the identity portion of the authentication,
/// separate from the authorization information in [TomAccessControlInformation].
///
/// ## Guest Users
///
/// Unauthenticated or anonymous users are represented with the
/// special [guestUsername] value.
///
/// ## Privacy Protection
///
/// User fields can be protected using resource keys. When serialized
/// to tokens or transmitted, protected fields may be hidden based
/// on the recipient's access rights.
///
/// ## Example
///
/// ```dart
/// var user = TomUser(
///   id: 123,
///   username: 'jdoe',
///   firstname: 'John',
///   lastname: 'Doe',
///   email: 'john.doe@example.com',
///   timeZone: 'America/New_York',
/// );
///
/// // Check if guest
/// if (user.username == TomUser.guestUsername) {
///   promptLogin();
/// }
/// ```
class TomUser {
  /// The username value for unauthenticated/anonymous users.
  static const String guestUsername = "GUEST";

  late int _id;

  /// The user's unique identifier.
  int get id => _id;

  late String _username;

  /// The user's login username.
  String get username => _username;

  String? _firstname;

  /// The user's first name.
  String? get firstname => _firstname;

  String? _lastname;

  /// The user's last name.
  String? get lastname => _lastname;

  String? _email;

  /// The user's email address.
  String? get email => _email;

  String? _phone;

  /// The user's phone number.
  String? get phone => _phone;

  String? _mobile;

  /// The user's mobile phone number.
  String? get mobile => _mobile;

  String? _addressLine1;

  /// First line of the user's address.
  String? get addressLine1 => _addressLine1;

  String? _addressLine2;

  /// Second line of the user's address.
  String? get addressLine2 => _addressLine2;

  String? _city;

  /// The user's city.
  String? get city => _city;

  String? _postcode;

  /// The user's postal/zip code.
  String? get postcode => _postcode;

  String? _stateRegion;

  /// The user's state or region.
  String? get stateRegion => _stateRegion;

  String? _timeZone;

  /// The user's preferred timezone.
  String? get timeZone => _timeZone;

  Map<String, Object?> _attributes = {};

  /// Custom attributes for extending user data.
  ///
  /// Returns an unmodifiable view of the attributes map.
  Map<String, Object?> get attributes => Map.unmodifiable(_attributes);

  /// Creates a user instance.
  ///
  /// All fields are optional except that [username] defaults to
  /// [guestUsername] for unauthenticated users.
  TomUser({
    int id = -1,
    String username = guestUsername,
    String? firstname,
    String? lastname,
    String? email,
    String? phone,
    String? mobile,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? postcode,
    String? stateRegion,
    String? timeZone,
    Map<String, Object?>? attributes,
  }) {
    _id = id;
    _username = username;
    _firstname = firstname;
    _lastname = lastname;
    _email = email;
    _phone = phone;
    _mobile = mobile;
    _addressLine1 = addressLine1;
    _addressLine2 = addressLine2;
    _city = city;
    _postcode = postcode;
    _stateRegion = stateRegion;
    _timeZone = timeZone;
    _attributes = attributes ?? _attributes;
  }

  @override
  String toString() =>
      "User $username ID $id FN $firstname LN $lastname email $email.";
}

// =============================================================================
// PRINCIPAL
// =============================================================================

/// Represents an authenticated user session with full context.
///
/// The principal combines user identity, authorization information,
/// and session context into a single object. It's the primary way
/// to access the current user's information throughout the application.
///
/// ## Components
///
/// - **User**: Identity information ([user] property)
/// - **ACI**: Access control information ([aci] property)
/// - **CLI**: Client limits information ([cli] property)
/// - **Context**: Session-specific data ([currentContext])
///
/// ## Two-Factor Authentication
///
/// If [requires2FA] is true, the user has authenticated with
/// username/password but still needs to complete 2FA. The
/// [twoFactorType] indicates which method to use.
///
/// ## Localization
///
/// The principal tracks both application and client locale settings:
/// - [language], [country], [timezone]: Application/server settings
/// - [clientLanguage], [clientCountry], [clientTimezone]: Client device settings
///
/// ## Example
///
/// ```dart
/// var principal = TomBearerAuthentication.getPrincipal();
///
/// // Check authentication
/// if (principal.authenticated) {
///   print('Hello, ${principal.user.firstname}!');
/// }
///
/// // Check authorization
/// if (principal.aci.roles.contains('admin')) {
///   showAdminPanel();
/// }
///
/// // Add session context
/// principal.addToContext({'lastActivity': DateTime.now()});
/// ```
class TomPrincipal {
  late bool _authenticated;

  /// Whether the user has been authenticated.
  bool get authenticated => _authenticated;

  /// The user's unique identifier (from [user]).
  int get id => _user.id;

  /// The user's login name (from [user]).
  String get username => _user.username;

  TomUser _user = TomUser();

  /// The user's identity information.
  TomUser get user => _user;

  /// The organization identifier for multi-tenant systems.
  String? organization;

  /// The application identifier for multi-application deployments.
  String? application;

  /// The process identifier within the application.
  String? process;

  /// The organization's database ID.
  int organizationId = -1;

  /// The application's database ID.
  int applicationId = -1;

  /// The process's database ID.
  int processId = -1;

  /// The client's database ID.
  int clientId = -1;

  /// Application/server language (ISO 639-1 code).
  String? language;

  /// Application/server country (ISO 3166-1 alpha-2 code).
  String? country;

  /// Application/server timezone identifier.
  String? timezone;

  /// Client device language (ISO 639-1 code).
  String? clientLanguage;

  /// Client device country (ISO 3166-1 alpha-2 code).
  String? clientCountry;

  /// Client device timezone identifier.
  // Note: user.timeZone is the stored preference
  String? clientTimezone;

  final Map<String, Object?> _currentContext = {};

  /// Session-specific context data.
  Map<String, Object?> get currentContext => _currentContext;

  /// Adds attributes to the session context.
  void addToContext(Map<String, Object?> attributes) {
    _currentContext.addAll(attributes);
  }

  bool _requires2FA = false;

  /// Whether two-factor authentication is required.
  bool get requires2FA => _requires2FA;

  String? _twoFactorType;

  /// The type of 2FA required (e.g., 'totp', 'sms', 'email').
  String? get twoFactorType => _twoFactorType;

  /// The user's access control information (roles, groups, entitlements).
  TomAccessControlInformation aci = TomAccessControlInformation();

  TomClientLimitsInformation _cli = TomClientLimitsInformation();

  /// The client's limits information (quotas, enabled modules).
  TomClientLimitsInformation get cli => _cli;

  @override
  String toString() =>
      "Principal $user Auth $authenticated 2FA $requires2FA $twoFactorType $organization-$process-$application CL $clientLanguage-$clientCountry-$clientTimezone PL $language-$country-$timezone $aci $cli";

  /// Creates a principal instance.
  ///
  /// All parameters are optional with sensible defaults:
  /// - [user]: Defaults to a guest user
  /// - [aci]: Defaults to empty access control
  /// - [cli]: Defaults to no limits
  /// - [authenticated]: Defaults to false
  /// - [requires2FA]: Defaults to false
  TomPrincipal({
    TomClientLimitsInformation? cli,
    TomAccessControlInformation? aci,
    TomUser? user,
    bool authenticated = false,
    bool requires2FA = false,
    String? twoFactorType,
    Map<String, Object?> context = const {},
    this.organization,
    this.application,
    this.process,
    this.language,
    this.country,
    this.clientCountry,
    this.clientLanguage,
    this.timezone,
    this.clientTimezone,
    this.organizationId = -1,
    this.applicationId = -1,
    this.processId = -1,
    this.clientId = -1,
  }) {
    _user = user ?? _user;
    this.aci = aci ?? this.aci;
    _cli = cli ?? _cli;
    _authenticated = authenticated;
    _requires2FA = requires2FA;
    _twoFactorType = twoFactorType;
    addToContext(context);
  }
}
