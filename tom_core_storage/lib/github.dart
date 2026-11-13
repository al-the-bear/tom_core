/// Storage in a GitHub repository: [TomGitHubStorage] — one save is one
/// commit, guarded by compare-and-swap on the branch head — and the waits it
/// takes from GitHub's rate limits ([tomGitHubWaitOf]). Its locator,
/// `TomGitHubLocator` (`github:<owner>/<repo>[@<branch>]/<path>`), is pure
/// parsing and is in the default entry point. Reaches the
/// network through `tom_github_api`, so it is an entry point of its own: the
/// default entry point stays network-free.
library;

export 'src/github/github_rate_limits.dart';
export 'src/github/github_storage.dart';

// The identity TomGitHubStorage.committer takes.
export 'package:tom_github_api/tom_github_api.dart' show GitHubGitIdentity;
