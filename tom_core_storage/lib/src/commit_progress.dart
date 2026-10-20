/// How far a commit has got, for the status surface.
///
/// **Why this exists.** GitHub's git-data API takes one request per blob,
/// sequentially, and a large one takes seconds: measured at ~1.5 MiB/s in
/// August 2026 and at 4.7 to 5.9 MiB/s on 2026-09-30, so an embedded file
/// near the 41,820,160 B blob ceiling is between 7 and 27 s inside one atomic
/// commit. For text-sized documents that is invisible. A status indicator that
/// reports sync *state* and a
/// pending-change count, and neither moves during those seconds — so the only
/// inference available to a user is that it has hung.
///
/// About five seconds more pass after the last object, while the tree, the
/// commit and the ref are written, whatever the size of the save. That is
/// what a report with no [currentPath] stands for.
///
/// **Granularity is per object, and that is a real limit rather than an
/// oversight.** The GitHub backend uploads one blob per request, so
/// [bytesCompleted] advances when an object lands, not while it is in flight.
/// A changeset of twelve objects therefore shows a bar that moves twelve
/// times; a changeset of one 40 MiB object shows a bar that does not move at
/// all — which is why [currentPath] and [currentBytes] are on this class.
/// "Saving assets/hero.png — 41.8 MB" is what separates "working on something
/// large" from "hung", and it is true for both shapes.
///
/// Intra-object progress was considered and rejected: it needs a streamed
/// request body, and a consumed stream cannot be re-sent, so it would break
/// `GitHubRetryPolicy`'s replay. Trading a working retry for an approximate
/// number — bytes handed to a socket are not bytes the remote has accepted —
/// is not a trade worth making.
///
/// This does **not** reopen atomicity. Reporting progress
/// through a save is not splitting one: nothing is visible to any reader until
/// the ref moves.
class TomCommitProgress {
  /// Bytes of the changeset's writes that have landed.
  final int bytesCompleted;

  /// Bytes the changeset's writes total. Deletes cost nothing here — they ride
  /// in the tree, not in an upload.
  final int bytesTotal;

  /// Objects that have landed.
  final int objectsCompleted;

  /// Objects the changeset writes.
  final int objectsTotal;

  /// The object being sent right now, or null when none is.
  ///
  /// Null both before the first upload and after the last, while the tree,
  /// commit and ref steps run — which is the state a reader should render as
  /// "finishing" rather than as "done", since the ref has not moved yet.
  final String? currentPath;

  /// How large [currentPath] is, or 0 when nothing is in flight.
  final int currentBytes;

  const TomCommitProgress({
    required this.bytesCompleted,
    required this.bytesTotal,
    required this.objectsCompleted,
    required this.objectsTotal,
    this.currentPath,
    this.currentBytes = 0,
  });

  /// Landed bytes over total, in `[0, 1]`.
  ///
  /// A changeset with nothing to upload is 1, not 0: a bar at zero for a save
  /// that has no bytes to send would be reporting a wait that is not
  /// happening.
  double get fraction =>
      bytesTotal == 0 ? 1 : (bytesCompleted / bytesTotal).clamp(0, 1);

  /// Whether an object is on the wire.
  bool get isUploading => currentPath != null;

  @override
  String toString() =>
      'TomCommitProgress($objectsCompleted/$objectsTotal '
      'objects, $bytesCompleted/$bytesTotal bytes'
      '${currentPath == null ? '' : ', sending $currentPath'})';
}

/// Where a backend reports [TomCommitProgress] during a commit.
///
/// Optional on the port on purpose: the local filesystem writes a save in
/// milliseconds, and a backend that has nothing to report should not have to
/// pretend it does.
typedef TomCommitProgressSink = void Function(TomCommitProgress progress);
