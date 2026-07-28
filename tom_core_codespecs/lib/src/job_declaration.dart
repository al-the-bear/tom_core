/// The spec-side job declaration a CodeSpec's `@CsJob` (CE-JB) is built on.
///
/// **Why this is a gap (`codespecs_mapping.md` §5.29, verdict *gap* — narrowed
/// by the csra2 cross-check).** The scheduling substrate in
/// `tom_core_kernel/lib/src/tombase/scheduling/` is now substantial: it carries
/// `TomJobDefinition` (name, schedule, body, retry policy, timeout,
/// missed-window policy, overlap rule), the `TomSchedule` family
/// (cron/calendar/interval/event), `TomScheduler`, the `TomJobStore`
/// implementations, the `TomLeaseLock` family for multi-node coordination, and
/// `TomJobDispatcher` for pluggable execution. **Everything a job needs to
/// *run* already exists** and is reused directly per pillar (b) — duplicating
/// any of it here would be exactly the mistake that pillar forbids.
///
/// What the substrate has no home for is the **deployment-and-ownership
/// envelope** a specification authors around a job: which service unit owns it,
/// which environments it is deployed to, which spec entities it touches, and
/// whether it is switched on at all. `TomJobDefinition` is a *runtime* object —
/// by the time it exists the decision to deploy the job has already been made.
/// So this thin declaration lands here as a concrete `tom_core`-family class —
/// never an abstract `Cs*` base (the framework carries annotations only, §0).
///
/// A CodeSpec `@CsJob` class *is a* [TomJobDeclaration] and supplies its own
/// `TomJobDefinition` for the runtime half. CE-JB is a *server* part (§4.2), so
/// the declaration lives in the server project of the three-project output trio.
class TomJobDeclaration {
  /// Stable identifier of the job, unique within the system.
  String jobId;

  /// Human-readable name of the job.
  String displayName;

  /// Whether the job is deployed at all.
  ///
  /// Gating is **opt-out**: a job that has been specified is meant to run, so
  /// the verbose case is switching one off rather than switching each one on.
  bool enabled;

  /// Environments the job is deployed to.
  ///
  /// An **empty list means every environment** — the common case is a job that
  /// runs everywhere, and making that the default keeps environment lists out
  /// of specs that do not need them.
  List<String> environments;

  /// Id of the service unit that owns this job.
  String? serviceUnitId;

  /// Names of the spec entities the job reads or writes.
  ///
  /// Declared so a change to an entity can find the jobs it affects — the
  /// runtime `TomJobDefinition.body` is an opaque closure and reveals nothing.
  List<String> targetRefs;

  /// Creates a job declaration.
  TomJobDeclaration({
    this.jobId = '',
    this.displayName = '',
    this.enabled = true,
    List<String>? environments,
    this.serviceUnitId,
    List<String>? targetRefs,
  })  : environments = environments ?? <String>[],
        targetRefs = targetRefs ?? <String>[];

  /// Whether the job is deployed to [environment].
  bool runsIn(String environment) =>
      enabled && (environments.isEmpty || environments.contains(environment));
}
