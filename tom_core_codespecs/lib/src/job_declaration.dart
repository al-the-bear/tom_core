/// The spec-side job declaration a CodeSpec's `@CsJob` (CE-JB) is built on.
///
/// **Why this is a narrow gap (`codespecs_mapping.md` §5.29).** The scheduling
/// substrate in `tom_core_kernel/lib/src/tombase/scheduling/` is complete: it
/// carries `TomJobDefinition` (name, schedule, body, retry policy, timeout,
/// missed-window policy, overlap rule), the `TomSchedule` family
/// (cron/calendar/interval/once/event), `TomScheduler`, the `TomJobStore`
/// implementations, the `TomLeaseLock` family for multi-node coordination,
/// `TomJobBase` with `@TomScheduledJob` discovery, and `TomJobDispatcher` for
/// pluggable execution. **Everything a job needs to *run* already exists** and
/// is reused directly per pillar (b) — duplicating any of it here would be
/// exactly the mistake that pillar forbids.
///
/// What the substrate has no home for is the **deployment-and-ownership
/// envelope** a specification authors around a job: which service unit owns it,
/// which environments it is deployed to, which spec entities it touches, and
/// whether it is switched on at all. `TomJobDefinition` is a *runtime* object —
/// by the time it exists the decision to deploy the job has already been made.
/// So this thin declaration lands here as a concrete `tom_core`-family class —
/// never an abstract `Cs*` base (the framework carries annotations only,
/// `codespecs_mapping.md` §1.1).
///
/// A CodeSpec `@CsJob` class *is a* [TomJobDeclaration] and supplies its own
/// `TomJobDefinition` for the runtime half. CE-JB is a *server* part
/// (`codespecs_mapping.md` §4.2), so the declaration lives in the server
/// project of the three-project output trio.
///
/// **Why only the entity targets are here.** `codespecs_mapping.md` §5.29 scope
/// part 3 is a job's
/// target references — CE-DB entities *and* CE-RP reports — and the two kinds
/// land in different places. Entities are already Dart types, so they are cited
/// as `Type` literals ([readEntities] / [writtenEntities]) and need nothing but
/// `dart:core`. Reports are cited as `CsReportRef` consts, and
/// `codespecs_mapping.md` §5.23 places the
/// `Cs*Ref` family in the **annotation parameter** vocabulary: they ride
/// `@CsJob(targetReports:)` in `tom_code_specs`, beside the `CsMessageKey` that
/// annotation already carries for `failureAlert`. That keeps this package
/// dependency-free — the same property that decides `TomReportResult` does not
/// extend `tom_core_server`'s `TomTabularResult` — and keeps ref consts out of
/// `tom_core`-family classes, which hold plain ids (`TomReportDefinition`
/// carries the `reportId` string a `CsReportRef` *wraps*).
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

  /// The CE-DB entities the job reads, as `Type` literals.
  ///
  /// Declared so a change to an entity can find the jobs it affects — the
  /// runtime `TomJobDefinition.body` is an opaque closure and reveals nothing.
  ///
  /// **`Type` literals, never strings** (`codespecs_mapping.md` §4.4.1, §5.29
  /// scope part 3). Entities are already Dart types, so `codespecs_mapping.md`
  /// §5.23 gives them no
  /// `Cs*Ref` const **by design**: citing the class directly makes a renamed
  /// entity a compile error, which a string could never be.
  List<Type> readEntities;

  /// The CE-DB entities the job writes, as `Type` literals.
  ///
  /// Separate from [readEntities] because `SCJOB-WORK` authors the two as
  /// distinct fields and impact analysis needs the difference: a schema change
  /// breaks a writer differently from a reader. [targetEntities] is the union
  /// for callers that only ask "does this job touch the entity at all?".
  List<Type> writtenEntities;

  /// Creates a job declaration.
  TomJobDeclaration({
    this.jobId = '',
    this.displayName = '',
    this.enabled = true,
    List<String>? environments,
    this.serviceUnitId,
    List<Type>? readEntities,
    List<Type>? writtenEntities,
  }) : environments = environments ?? <String>[],
       readEntities = readEntities ?? <Type>[],
       writtenEntities = writtenEntities ?? <Type>[];

  /// Every entity the job touches, read or written, without duplicates.
  ///
  /// An entity that is both read and written is **one** target — this is the
  /// set a "which jobs touch this entity?" query wants, and keeping the
  /// deduplication here stops each caller from re-deriving it.
  Set<Type> get targetEntities => {...readEntities, ...writtenEntities};

  /// Whether the job is deployed to [environment].
  bool runsIn(String environment) =>
      enabled && (environments.isEmpty || environments.contains(environment));
}
