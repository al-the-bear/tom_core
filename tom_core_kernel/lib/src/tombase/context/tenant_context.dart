/// The tenant a piece of work belongs to, carried in the zone.
///
/// ## Tenant and organization
///
/// A **tenant** is an isolation boundary: whose data a query may read, which
/// database or schema a connection reaches, whose cache entries and queued
/// jobs these are. Nothing crosses it. An **organization** is a business unit
/// *inside* a tenant — the `organization` a principal logs in for, which
/// authorization and context read and which a tenant may have several of. A
/// deployment that sells to companies typically makes each customer a tenant
/// and lets the customer model its departments as organizations; the two can
/// coincide, but the framework never infers one from the other.
///
/// ## Where the tenant comes from
///
/// The server's request pipeline resolves it (`tom_core_server`'s `tenancy`
/// module: the token's `tenant` claim first, then host or header) and runs the
/// request inside [TomTenantContext.run]. Work that leaves the request carries
/// it explicitly: a job run records it, and the scheduler runs the run's body
/// back inside it — across an isolate hop too, through [TomTenantScopedCommand].
library;

import 'dart:async';

import '../isolate_pooling/tom_worker.dart';
import '../little_things/exception_base.dart';

/// A tenant identifier or context that cannot be used.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `tenancy.id.invalid` | A tenant id is not a lower-case identifier of at most 32 characters. |
/// | `tenancy.context.missing` | Tenant-owned work ran with no tenant in context. |
class TomTenantException extends TomException {
  /// Creates the exception.
  TomTenantException(super.key, super.defaultUserMessage, {super.parameters});
}

/// The current tenant, held in the zone.
abstract final class TomTenantContext {
  static final Object _zoneKey = Object();

  /// The pattern a tenant id must match: a lower-case letter, then up to 31
  /// lower-case letters, digits or underscores.
  ///
  /// Narrow on purpose. A tenant id names a schema or a database in the
  /// stronger isolation models, is part of cache keys and job windows, and is
  /// written into tokens; an id that is a safe identifier everywhere is one
  /// that never needs quoting anywhere.
  static final RegExp idPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

  /// The tenant the current zone belongs to, or `null` when it belongs to
  /// none — a deployment without tenancy, a system task, an anonymous
  /// request that named no tenant.
  static String? get currentId => (Zone.current[_zoneKey] as _TenantBox?)?.id;

  /// Whether the current zone states a tenant (or states that it has none),
  /// as opposed to inheriting no statement at all.
  static bool get isSet => Zone.current[_zoneKey] != null;

  /// Runs [body] with [tenantId] as the current tenant; `null` runs it
  /// explicitly outside every tenant.
  ///
  /// Throws `tenancy.id.invalid` for an id that is not [idPattern].
  static R run<R>(String? tenantId, R Function() body) {
    if (tenantId != null) validate(tenantId);
    return runZoned(body, zoneValues: {_zoneKey: _TenantBox(tenantId)});
  }

  /// The current tenant, or throws `tenancy.context.missing` naming [what]
  /// needed it.
  static String require(String what) {
    final id = currentId;
    if (id != null) return id;
    throw TomTenantException(
      'tenancy.context.missing',
      '$what belongs to a tenant, and none is in context.',
      parameters: {'what': what},
    );
  }

  /// Throws `tenancy.id.invalid` unless [tenantId] matches [idPattern].
  static void validate(String tenantId) {
    if (idPattern.hasMatch(tenantId)) return;
    throw TomTenantException(
      'tenancy.id.invalid',
      'The tenant id "$tenantId" is not a lower-case identifier of at most 32 '
          'characters.',
      parameters: {'tenant': tenantId},
    );
  }

  /// [name] qualified by [tenantId] — `tenant:<id>/<name>` — or [name] itself
  /// when [tenantId] is `null`. The one spelling every tenant-scoped key
  /// uses (cache entries, revocations), so two tenants' `alice` never meet.
  static String qualify(String name, [String? tenantId]) =>
      tenantId == null ? name : 'tenant:$tenantId/$name';

  /// [name] qualified by the tenant in context — [qualify] with [currentId].
  ///
  /// The key a store files a per-tenant name under when the rows of several
  /// tenants can share one table: a principal id is unique within its tenant
  /// only, so two tenants' `u1` are two keys here.
  static String qualifyCurrent(String name) => qualify(name, currentId);

  /// The tenant [qualified] names — `acme` for `tenant:acme/u1` — or `null`
  /// for a name [qualify] left unqualified. The inverse of [qualify], for a
  /// store that has only a qualified key — a principal's `qualifiedId` — to
  /// find the tenant to run its work in.
  static String? tenantOf(String qualified) {
    if (!qualified.startsWith('tenant:')) return null;
    final slash = qualified.indexOf('/', 7);
    if (slash < 0) return null;
    final id = qualified.substring(7, slash);
    return idPattern.hasMatch(id) ? id : null;
  }
}

class _TenantBox {
  const _TenantBox(this.id);
  final String? id;
}

/// A [TomCommand] that runs [inner] inside [tenantId]'s context — wherever it
/// executes, including a worker isolate the command is copied into.
class TomTenantScopedCommand extends TomCommand {
  /// Wraps [inner] for [tenantId].
  TomTenantScopedCommand(this.tenantId, this.inner);

  /// The tenant the command runs for.
  final String tenantId;

  /// The work.
  final TomCommand inner;

  @override
  Future<Object?> execute() =>
      TomTenantContext.run(tenantId, () => inner.execute());
}

/// An event for an event-triggered job, carrying the tenant it was raised
/// for.
///
/// A stream listener runs in the zone it subscribed in, not the zone the
/// event was added from, so a tenant cannot reach an event-triggered run
/// through the zone. Adding a [TomTenantEvent] to the job's stream instead
/// makes the run record the tenant, and its body run inside it.
class TomTenantEvent {
  /// An event for [tenant] carrying [payload].
  const TomTenantEvent(this.tenant, this.payload);

  /// An event for the current tenant; throws `tenancy.context.missing` when
  /// there is none.
  factory TomTenantEvent.inCurrentTenant(Object? payload) =>
      TomTenantEvent(TomTenantContext.require('A tenant event'), payload);

  /// The tenant the run belongs to.
  final String tenant;

  /// The run's payload.
  final Object? payload;
}
