import 'storage.dart';

/// One stored credential for a remote host.
class TomToken {
  /// The host the token authenticates against, e.g. `github.com`.
  final String host;

  /// The account the token belongs to, when known. Purely informational —
  /// nothing authenticates on it.
  final String? account;

  final String secret;

  const TomToken({required this.host, required this.secret, this.account});

  /// Deliberately does not include [secret]: tokens end up in log lines and
  /// exception messages, and a secret that is never stringified cannot leak
  /// that way.
  @override
  String toString() => 'TomToken($host${account == null ? '' : '/$account'})';
}

/// A held credential described without its secret — what a settings surface
/// lists.
///
/// A type of its own rather than a [TomToken] with the secret left out,
/// so a list of these cannot carry a secret by construction.
class TomTokenListing {
  final String host;
  final String? account;

  const TomTokenListing({required this.host, this.account});

  @override
  bool operator ==(Object other) =>
      other is TomTokenListing &&
      other.host == host &&
      other.account == account;

  @override
  int get hashCode => Object.hash(host, account);

  @override
  String toString() =>
      'TomTokenListing($host${account == null ? '' : '/$account'})';
}

/// Where a remote backend's credential comes from.
///
/// This is an interface rather than a lookup so the secret store can stay on
/// the far side of it: the real implementation reads the encrypted settings
/// KDBX, and nothing that talks to the network ever knows that. Secrets are
/// **never** in plaintext settings.
abstract class TomTokenSource {
  const TomTokenSource();

  /// The token for [host], or null when none is configured.
  Future<TomToken?> tokenFor(String host);
}

/// A token source holding values supplied directly.
///
/// For tests and for a session in which the user pasted a token without
/// choosing to persist it. It is **not** a settings store: nothing here is
/// written anywhere.
class TomInMemoryTokenSource extends TomTokenSource {
  final Map<String, TomToken> _tokens;

  TomInMemoryTokenSource([Iterable<TomToken> tokens = const []])
    : _tokens = {for (final token in tokens) token.host: token};

  void put(TomToken token) => _tokens[token.host] = token;

  void remove(String host) => _tokens.remove(host);

  /// The credentials held, by host and account; never a secret.
  List<TomTokenListing> get listings => [
    for (final token in _tokens.values)
      TomTokenListing(host: token.host, account: token.account),
  ];

  @override
  Future<TomToken?> tokenFor(String host) async => _tokens[host];
}

/// No credential is configured for [host].
class TomTokenRequiredException implements Exception {
  final String host;

  const TomTokenRequiredException(this.host);

  @override
  String toString() =>
      'TomTokenRequiredException($host): no token is configured — the '
      'shell asks for one when a command needs it.';
}

/// The credential configured for [host] was refused by the service.
///
/// Its own type, beside [TomTokenRequiredException], because the answer is
/// the same — ask for a token — and a plain storage failure would only be
/// reported, leaving the user no way to replace a token that has expired or
/// been revoked. A storage exception as well, so a caller that does not know
/// about tokens still reports it as a refusal with the locator it was about.
class TomTokenRejectedException extends TomStorageException {
  final String host;

  const TomTokenRejectedException(
    super.locator,
    this.host,
    super.message, {
    super.cause,
  });
}
