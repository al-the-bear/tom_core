/// Where a document lives in a git repository: on a server, or in a folder.
library;

/// `git:<repository-url>[#<branch>]::<path>` — a container at [path] on
/// [branch] of the repository at [remote].
///
/// The repository is an `http(s)` URL of a server that speaks smart HTTP, or a
/// `file:` URL naming a repository in a folder on this device. Without a
/// branch the locator means the remote's default branch, or for a folder the
/// branch its `HEAD` names.
///
/// An empty [path] names the repository root — a folder, which is listed;
/// it is never a container, so reading or writing one is refused.
///
/// `::` separates the repository from the path because it never occurs in an
/// http(s) URL, while `/`, `@` and `:` all do.
class TomGitLocator {
  const TomGitLocator({required this.remote, required this.path, this.branch});

  static const scheme = 'git:';

  final Uri remote;
  final String? branch;

  /// Slash-separated, relative to the repository root; empty for the root.
  final String path;

  /// Whether [remote] is a folder on this device rather than a server.
  bool get isLocal => remote.isScheme('file');

  static bool matches(String locator) => locator.startsWith(scheme);

  static TomGitLocator parse(String locator) {
    if (!matches(locator)) {
      throw FormatException('Not a git locator', locator);
    }
    final rest = locator.substring(scheme.length);
    final split = rest.lastIndexOf('::');
    if (split < 0) {
      throw FormatException(
        'A git locator is "$scheme<url>[#<branch>]::<path>"',
        locator,
      );
    }
    var repository = rest.substring(0, split);
    final path = rest
        .substring(split + 2)
        .split('/')
        .where((s) => s.isNotEmpty)
        .join('/');
    String? branch;
    final hash = repository.indexOf('#');
    if (hash >= 0) {
      branch = repository.substring(hash + 1);
      repository = repository.substring(0, hash);
      if (branch.isEmpty) {
        throw FormatException('A git locator has an empty branch', locator);
      }
    }
    final remote = Uri.tryParse(repository);
    final served =
        remote != null &&
        (remote.isScheme('https') || remote.isScheme('http')) &&
        remote.host.isNotEmpty;
    final local =
        remote != null && remote.isScheme('file') && remote.path.isNotEmpty;
    if (!served && !local) {
      throw FormatException(
        'A git locator needs an http(s) repository URL or a file: URL of a '
        'folder',
        locator,
      );
    }
    return TomGitLocator(remote: remote, path: path, branch: branch);
  }

  TomGitLocator withBranch(String branch) =>
      TomGitLocator(remote: remote, path: path, branch: branch);

  @override
  String toString() =>
      '$scheme$remote${branch == null ? '' : '#$branch'}::$path';
}
