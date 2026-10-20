/// A parsed `github:` document locator.
///
/// ```text
/// github:<owner>/<repo>[@<branch>]/<path>
/// ```
///
/// The branch is optional; omitting it means **the repository's default
/// branch**, which is a fact only the API knows. So an omitted branch parses to
/// `null` rather than to a guess — the storage backend resolves it once per
/// repository and calls [withBranch]. The path is the document's location
/// inside the repository — a file for the single-file serializations, a
/// directory for a YAML bundle.
class TomGitHubLocator {
  static const scheme = 'github:';

  final String owner;
  final String repo;

  /// The branch this locator names, or null when it defers to the
  /// repository's default branch.
  final String? branch;

  /// Repository-relative, `/`-separated, no leading or trailing slash.
  final String path;

  const TomGitHubLocator({
    required this.owner,
    required this.repo,
    required this.path,
    this.branch,
  });

  static bool matches(String locator) => locator.startsWith(scheme);

  static TomGitHubLocator parse(String locator) {
    if (!matches(locator)) {
      throw FormatException('Not a GitHub locator: "$locator"', locator);
    }
    final rest = locator.substring(scheme.length);
    final segments = rest.split('/');
    if (segments.length < 3 || segments[0].isEmpty || segments[1].isEmpty) {
      throw FormatException(
        'GitHub locator must be '
        '"$scheme<owner>/<repo>[@<branch>]/<path>": "$locator"',
        locator,
      );
    }
    final owner = segments[0];
    // The branch rides on the repo segment because a branch name may itself
    // contain slashes only after that point — `repo@feature/x` would be
    // ambiguous, so branches with slashes are not addressable here.
    final repoAndBranch = segments[1];
    final at = repoAndBranch.indexOf('@');
    final repo = at < 0 ? repoAndBranch : repoAndBranch.substring(0, at);
    final branch = at < 0 ? null : repoAndBranch.substring(at + 1);
    if (repo.isEmpty || branch != null && branch.isEmpty) {
      throw FormatException(
        'GitHub locator has an empty repo or branch: '
        '"$locator"',
        locator,
      );
    }
    final path = segments.sublist(2).join('/');
    if (path.isEmpty) {
      throw FormatException(
        'GitHub locator has no document path: "$locator"',
        locator,
      );
    }
    return TomGitHubLocator(
      owner: owner,
      repo: repo,
      branch: branch,
      path: path,
    );
  }

  /// Whether [branch] is known. An unresolved locator can be printed and
  /// compared, but cannot name a ref.
  bool get isResolved => branch != null;

  /// The same document on an explicitly named branch.
  TomGitHubLocator withBranch(String branch) =>
      TomGitHubLocator(owner: owner, repo: repo, path: path, branch: branch);

  /// `owner/repo` — the unit the default branch is resolved and cached per.
  String get repoSlug => '$owner/$repo';

  /// `heads/<branch>` — the git ref name, without the `refs/` prefix the API
  /// wants in some places and not others.
  String get refName => 'heads/$_resolvedBranch';

  /// Identifies the repository *and branch*, which is the unit a head check
  /// can be batched over: every document on one branch resolves from a single
  /// tree read.
  String get repoKey => '$repoSlug@$_resolvedBranch';

  String get _resolvedBranch =>
      branch ??
      (throw StateError(
        'Locator "$this" names no branch; resolve the repository default '
        'branch with withBranch() before addressing a ref',
      ));

  /// Rebuilds the locator string. Round-trips [parse].
  @override
  String toString() =>
      '$scheme$owner/$repo${branch == null ? '' : '@$branch'}/$path';

  @override
  bool operator ==(Object other) =>
      other is TomGitHubLocator &&
      other.owner == owner &&
      other.repo == repo &&
      other.branch == branch &&
      other.path == path;

  @override
  int get hashCode => Object.hash(owner, repo, branch, path);
}
