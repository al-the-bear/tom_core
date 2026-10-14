/// The sign-in organization: which organization of the user a session is
/// signed in for, which ones the user may sign in for, and how a session
/// changes to another one.
///
/// A user can be a member of several organizations of a tenant. A session is
/// signed in for one of them — the sign-in organization, `TomPrincipal
/// .organization` and the token's `organization` claim — and its application
/// rights are that organization's. The deployment knows the memberships; the
/// framework asks it through [TomSignInOrganizationDirectory] and keeps the
/// rule in one place:
///
/// - at sign-in, `TomAuthenticationServer` settles the organization against
///   the user's list ([TomSignInOrganizations.settle]): the organization the
///   login named when the user is a member, the default when it named none,
///   and for an organization the user is not a member of what the list's
///   [TomOrganizationFallback] says;
/// - within a session, `TomAuthenticationServer.switchOrganization` issues new
///   tokens for another organization of the user without asking for a
///   credential, where the list offers a choice, and audits the switch as
///   `session.organizationSwitched`.
///
/// With no directory installed nothing is settled: the organization stays
/// whatever the authentication service put on the principal.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'authentication_server.dart';

/// One organization a principal may sign in for.
class TomSignInOrganization {
  /// Creates an entry for the organization [id], shown as [name].
  const TomSignInOrganization(this.id, {this.name});

  /// The organization's id — what `TomPrincipal.organization` and the token's
  /// `organization` claim carry.
  final String id;

  /// The organization's display name, or `null`.
  final String? name;

  /// The entry as JSON, for a client listing the choices.
  Map<String, Object?> toJson() => {'id': id, if (name != null) 'name': name};

  @override
  String toString() => name == null ? id : '$id ($name)';
}

/// What a sign-in naming an organization the user is not a member of does.
enum TomOrganizationFallback {
  /// The sign-in is refused (`login.error.organization.not-member`).
  refuse,

  /// The sign-in is for the user's default organization instead.
  useDefault,
}

/// The organizations one principal may sign in for, the default among them,
/// and whether the user may choose.
class TomSignInOrganizations {
  /// Creates the list.
  ///
  /// [defaultOrganization] must be the id of one of [organizations]; an empty
  /// list has none.
  TomSignInOrganizations(
    List<TomSignInOrganization> organizations, {
    this.defaultOrganization,
    this.choiceOffered = false,
    this.fallback = TomOrganizationFallback.refuse,
  }) : organizations = List.unmodifiable(organizations) {
    final fallbackId = defaultOrganization;
    if (fallbackId != null && !contains(fallbackId)) {
      // throws-outside-family: programmer error — a default outside the list is
      // a bug in the deployment's directory, not a sign-in to refuse.
      throw ArgumentError.value(
        fallbackId,
        'defaultOrganization',
        'is not one of the organizations',
      );
    }
  }

  /// The organizations, in the order a client lists them.
  final List<TomSignInOrganization> organizations;

  /// The organization a sign-in naming none is for, or `null` when the user
  /// has none.
  final String? defaultOrganization;

  /// Whether the user may choose among [organizations] — at sign-in, and by
  /// switching within a session.
  final bool choiceOffered;

  /// What a sign-in naming an organization the user is not a member of does.
  final TomOrganizationFallback fallback;

  /// Whether [id] is one of [organizations].
  bool contains(String id) => organizations.any((o) => o.id == id);

  /// The organization a sign-in that named [requested] is for.
  ///
  /// [requested] when the user is a member of it; the default when [requested]
  /// is empty or `null`; for an organization the user is not a member of, the
  /// default under [TomOrganizationFallback.useDefault]. Throws
  /// `login.error.organization.not-member` under
  /// [TomOrganizationFallback.refuse], and
  /// `login.error.organization.none` when the user has no organization to
  /// sign in for.
  String settle(String? requested) {
    if (requested != null && requested.isNotEmpty && contains(requested)) {
      return requested;
    }
    final named = requested != null && requested.isNotEmpty;
    if (named && fallback == TomOrganizationFallback.refuse) {
      throw notMember(requested);
    }
    final fallbackId = defaultOrganization;
    if (fallbackId == null) {
      throw TomLoginException(
        'login.error.organization.none',
        'The account is a member of no organization it could sign in for.',
        reason: TomLoginFailure.accountProblem,
      );
    }
    return fallbackId;
  }

  /// The refusal of [organization], which the user is not a member of.
  static TomLoginException notMember(String organization) => TomLoginException(
    'login.error.organization.not-member',
    'The account is not a member of the organization it asked to sign in for.',
    reason: TomLoginFailure.accountProblem,
    parameters: {'organization': organization},
  );

  /// The list as JSON, for a client offering the choice.
  Map<String, Object?> toJson() => {
    'organizations': [for (final o in organizations) o.toJson()],
    'defaultOrganization': defaultOrganization,
    'choiceOffered': choiceOffered,
  };
}

/// What a deployment supplies so that the sign-in organization is checked and
/// can be changed: the organizations a principal may sign in for, and the
/// principal and its rights for one of them.
///
/// Install it as a bean:
///
/// ```dart
/// TomBean.withType<TomSignInOrganizationDirectory>(MyOrganizations());
/// ```
abstract interface class TomSignInOrganizationDirectory {
  /// The organizations [principal] may sign in for.
  Future<TomSignInOrganizations> organizationsFor(TomPrincipal principal);

  /// [principal] signed in for [organization] — the principal with that
  /// organization and the access-control definition of its rights there —
  /// without a credential check; [organization] is one of
  /// [organizationsFor]'s.
  ///
  /// Called at sign-in when the settled organization is not the one the
  /// authentication service resolved, and by a switch.
  Future<TomAuthenticationInfo> signInFor(
    TomPrincipal principal,
    String organization,
  );

  /// The installed directory, or `null`.
  static TomSignInOrganizationDirectory? resolve() {
    final installed = TomBean.getBeanByType(TomSignInOrganizationDirectory);
    return installed is TomSignInOrganizationDirectory ? installed : null;
  }
}
