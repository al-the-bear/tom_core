import 'storage.dart';

/// the configurable per-asset ceiling, in bytes — **25 MB decimal**.
///
/// Decimal rather than binary because the spec writes "25 MB" while writing the
/// measured GitHub number as MiB, and because this one is an *authoring*
/// judgement about document weight rather than a transport limit: a round
/// number a user can type is the point of it.
const tomDefaultObjectCeilingBytes = 25000000;

/// Which of the two ceilings actually decided.
enum TomCeilingBound {
  /// Neither is set — nothing is refused.
  none,

  /// The configured authoring ceiling is the lower of the two, or the only one.
  configured,

  /// The backend's own ceiling is the lower of the two, or the only one. This
  /// is the case cares about: a configured ceiling raised above what
  /// the backend takes does not take effect, and the user has to be told so.
  backend,
}

/// The effective ceiling on **one** stored object: `min(configured, backend)`.
///
/// Two independent limits meet here and neither subsumes the other. The
/// configured one is an
/// authoring guard about how heavy a document should get. The backend one
/// ([TomStorage.maxObjectBytes]) is a fact about what the remote will
/// physically accept — 41,820,160 B on GitHub, measured, and null on the local
/// filesystem, which imposes none of its own.
///
/// **A null backend ceiling means "no limit of its own", never "skip the
/// check".** That distinction is the one a plausible implementation gets
/// wrong: treating null as unlimited-and-therefore-unguarded silently drops the
/// configured ceiling on exactly the backend where a user is most likely to
/// paste something enormous.
///
/// The ceiling is asked of the **document's** backend, so the same document
/// moved from local storage to a GitHub repository tightens. Resolving it once against a
/// globally configured backend would make the answer wrong for every document
/// that does not live there.
class TomObjectCeiling {
  /// The authoring ceiling, or null when none is configured.
  final int? configured;

  /// What the backend will physically accept, or null when it has no limit of
  /// its own.
  final int? backend;

  const TomObjectCeiling({this.configured, this.backend});

  /// The ceiling in force for [storage].
  factory TomObjectCeiling.of(
    TomStorage storage, {
    int? configured = tomDefaultObjectCeilingBytes,
  }) =>
      TomObjectCeiling(configured: configured, backend: storage.maxObjectBytes);

  /// The lower of the two, or null only when **both** are absent.
  int? get effective {
    final c = configured;
    final b = backend;
    if (c == null) return b;
    if (b == null) return c;
    return c < b ? c : b;
  }

  /// Which limit decided — and, when it is [TomCeilingBound.backend] with a
  /// larger [configured] beside it, the reason the refusal has to name two
  /// numbers rather than one.
  TomCeilingBound get boundBy {
    final c = configured;
    final b = backend;
    if (c == null && b == null) return TomCeilingBound.none;
    if (c == null) return TomCeilingBound.backend;
    if (b == null) return TomCeilingBound.configured;
    return b < c ? TomCeilingBound.backend : TomCeilingBound.configured;
  }

  /// Whether the backend's limit is what is binding **and** the configured one
  /// was set higher — the case where raising the setting had no effect.
  bool get configuredIsUnreachable {
    final c = configured;
    final b = backend;
    return c != null && b != null && b < c;
  }

  /// Whether an object of [byteCount] may be stored.
  bool admits(int byteCount) {
    final limit = effective;
    return limit == null || byteCount <= limit;
  }

  /// Throws [TomObjectTooLargeException] when [byteCount] is over the
  /// effective ceiling.
  ///
  /// [what] names the thing being refused as the user would recognise it — a
  /// bundle path at save time, "the pasted image" at ingest.
  void enforce(int byteCount, {required String locator, required String what}) {
    if (admits(byteCount)) return;
    throw TomObjectTooLargeException(
      locator,
      what: what,
      byteCount: byteCount,
      ceiling: this,
    );
  }

  @override
  String toString() =>
      'TomObjectCeiling(configured: $configured, backend: $backend, '
      'effective: $effective)';
}

/// A single object is larger than the effective ceiling.
///
/// It is a [TomStorageException] for the reason every other read/write
/// outcome is: the sync loop catches that base on a timer tick, and an outcome
/// it cannot name is one that escapes into an unhandled async error.
class TomObjectTooLargeException extends TomStorageException {
  /// What was refused, as the user would recognise it.
  final String what;

  /// How large it actually is.
  final int byteCount;

  /// The two limits, so a caller can report or re-check without re-deriving.
  final TomObjectCeiling ceiling;

  TomObjectTooLargeException(
    String locator, {
    required this.what,
    required this.byteCount,
    required this.ceiling,
  }) : super(locator, _message(what, byteCount, ceiling));

  static String _message(String what, int byteCount, TomObjectCeiling ceiling) {
    final limit = ceiling.effective;
    final over = '$what is ${_bytes(byteCount)}, over the ';
    if (ceiling.boundBy == TomCeilingBound.configured) {
      return '${over}configured ceiling of ${_bytes(limit!)}.';
    }
    final backend = '${_bytes(limit!)} this backend accepts.';
    if (!ceiling.configuredIsUnreachable) return over + backend;
    // Both numbers, because the user who raised the setting has to learn why
    // it did not take effect — the clamp is invisible otherwise.
    return '$over$backend The configured ceiling of '
        '${_bytes(ceiling.configured!)} cannot take effect here.';
  }

  /// Exact bytes **and** a rounded decimal-MB reading.
  ///
  /// Exact because it is what a user comparing against a setting needs, and
  /// one unit throughout because a message mixing MB with MiB makes two
  /// numbers look further apart than they are.
  static String _bytes(int count) {
    final mb = (count / 1000000).toStringAsFixed(1);
    return '$count B ($mb MB)';
  }
}

/// Refuses a [TomChangeset] carrying any single object over [storage]'s own
/// ceiling, before the commit spends anything on it.
///
/// Called by every backend at the top of `commit`, which is what makes "an
/// object already stored when a document moves to a tighter backend is not
/// retro-refused — it fails the save" a real, named path rather than
/// whatever the remote happens to say. On GitHub the alternative is a 422 with
/// an opaque body, arriving after the blobs before it have already been
/// uploaded.
///
/// Only the backend's ceiling applies here: the configured one is an authoring
/// guard and a save is not authoring. A document that arrived with a large
/// asset — from a merge, from another device, from a looser setting — must
/// still be saveable wherever the backend can take it.
void tomGuardChangeset(
  String locator,
  TomChangeset changeset,
  TomStorage storage,
) {
  final limit = storage.maxObjectBytes;
  if (limit == null) return;
  final ceiling = TomObjectCeiling(configured: null, backend: limit);
  for (final write in changeset.writes.entries) {
    ceiling.enforce(write.value.length, locator: locator, what: write.key);
  }
}
