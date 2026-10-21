/// Where a document lives in a git repository reached over HTTP(S).
library;

/// `git:<repository-url>[#<branch>]::<path>` — a container at [path] on
/// [branch] (the remote's default branch when absent) of the repository at
/// [remote].
///
/// `::` separates the repository from the path because it never occurs in an
/// http(s) URL, while `/`, `@` and `:` all do.
class TomGitLocator {
  const TomGitLocator({required this.remote, required this.path, this.branch});

  static const scheme = 'git:';

  final Uri remote;
  final String? branch;

  /// Slash-separated, relative to the repository root, never empty.
  final String path;

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
    if (remote == null ||
        !(remote.isScheme('https') || remote.isScheme('http')) ||
        remote.host.isEmpty) {
      throw FormatException(
        'A git locator needs an http(s) repository URL',
        locator,
      );
    }
    if (path.isEmpty) {
      throw FormatException('A git locator has no document path', locator);
    }
    return TomGitLocator(remote: remote, path: path, branch: branch);
  }

  TomGitLocator withBranch(String branch) =>
      TomGitLocator(remote: remote, path: path, branch: branch);

  @override
  String toString() =>
      '$scheme$remote${branch == null ? '' : '#$branch'}::$path';
}
